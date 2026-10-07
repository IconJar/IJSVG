//
//  IJSVGCommandParser.m
//  IJSVG
//
//  Created by Curtis Hard on 23/12/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGCommandParser.h>
#import <IJSVG/IJSVGCommandEllipticalArc.h>
#import <IJSVG/IJSVGUtils.h>

@implementation IJSVGCommandParser

#define VALID_DIGIT(c) (((unsigned char)(c) ^ '0') <= 9)

IJSVGPathDataSequence* IJSVGPathDataSequenceCreateWithType(IJSVGPathDataSequence type, NSInteger length)
{
    size_t size = sizeof(IJSVGPathDataSequence) * length;
    IJSVGPathDataSequence* sequence = (IJSVGPathDataSequence*)malloc(size);
    memset(sequence, (int)type, size);
    return sequence;
};

// Datastreams work by setting up one stream of bits/memory per SVG
// so that each SVG has a reusable memory block to read and parse paths into.
// As its all linear and one SVG per thread, this saves alot of memory allocation
// calls as we simple can just reuse the buffer that already exists, this also
// allows us to specify the default allocation size, so when parsing viewBox we
// can simply allocate (4*sizeof(CGFloat)) instead of the default 50 slots
IJSVGPathDataStream* IJSVGPathDataStreamCreateDefault(void)
{
    return IJSVGPathDataStreamCreate(IJSVG_STREAM_FLOAT_BLOCK_SIZE,
        IJSVG_STREAM_CHAR_BLOCK_SIZE);
}

IJSVGPathDataStream* IJSVGPathDataStreamCreate(NSUInteger floatCount, NSUInteger charCount)
{
    floatCount = floatCount ?: IJSVG_STREAM_FLOAT_BLOCK_SIZE;
    charCount = charCount ?: IJSVG_STREAM_CHAR_BLOCK_SIZE;
    IJSVGPathDataStream* buffer = (IJSVGPathDataStream*)malloc(sizeof(IJSVGPathDataStream));
    buffer->floatBuffer = (CGFloat*)malloc(sizeof(CGFloat) * floatCount);
    buffer->floatCount = floatCount;
    buffer->charBuffer = (char*)calloc(sizeof(char), charCount);
    buffer->charCount = charCount;
    return buffer;
}

void IJSVGPathDataStreamRelease(IJSVGPathDataStream* buffer)
{
    free(buffer->charBuffer);
    free(buffer->floatBuffer);
    free(buffer);
};

static void* IJSVGPathDataStreamGrow(void* buffer, NSInteger* capacity,
    NSUInteger required, size_t itemSize)
{
    NSUInteger limit = MIN((NSUInteger)NSIntegerMax, SIZE_MAX / itemSize);
    if(required > limit) {
        return NULL;
    }
    NSUInteger count = MAX((NSUInteger)*capacity, 1);
    while(count < required) {
        if(count > limit / 2) {
            count = required;
            break;
        }
        count *= 2;
    }
    void* resized = realloc(buffer, count * itemSize);
    if(resized != NULL) {
        *capacity = (NSInteger)count;
    }
    return resized;
}

static const CGFloat* IJSVGReadPathDataStreamSequence(const char* commandChars, NSInteger commandCharLength,
    IJSVGPathDataStream* dataStream, IJSVGPathDataSequence* _Nullable sequence,
    NSInteger commandLength, NSInteger* commandsFound, NSInteger* numberCount)
{
    *numberCount = 0;
    // if no command length, its completely pointless function,
    // so just return null and set commandsFound to 0, if we dont
    // we get a arithmetic error later on due to zero
    if(commandLength <= 0 || commandChars == NULL || commandCharLength <= 0) {
        if(commandsFound != NULL) {
            *commandsFound = 0;
        }
        return NULL;
    }

    // default memory size for the float
    NSInteger i = 0;
    NSInteger counter = 0;

    const char* cString = commandChars;

    // this is much faster then doing strlen as it doesnt need
    // to compute the length
    NSInteger sLength = commandCharLength;
    NSInteger sLengthMinusOne = sLength - 1;

    bool isDecimal = false;
    NSInteger bufferCount = 0;

    while (i < sLength) {
        char currentChar = *cString++;

        // work out next char, cString already points at it after the
        // post increment above, so no need to step forwards and back
        char nextChar = (char)0;
        if(i < sLengthMinusOne) {
            nextChar = *cString;
        }

        // check for validator
        bool isE = (currentChar | ('E' ^ 'e')) == 'e';
        bool isValid = VALID_DIGIT(currentChar) || isE || currentChar == '+' ||
          currentChar == '-' || currentChar == '.';

        // in order to work out the split, its either because the next char is
        // a  hyphen or a plus, or next char is a decimal and the current number is a decimal
        bool nIsSign = nextChar == '-' || nextChar == '+';
        bool wantsEnd = nIsSign || (nextChar == '.' && isDecimal);

        // work our what the sequence is...
        IJSVGPathDataSequence seq = kIJSVGPathDataSequenceTypeFloat;
        if(sequence != NULL) {
            seq = sequence[counter % commandLength];
        }

        // is a flag, consists of one value
        // if its invalid, make sure we free the memory
        // and return null, or hell breaks lose
        if(isValid == YES && seq == kIJSVGPathDataSequenceTypeFlag) {
            if(bufferCount != 0 || (currentChar != '0' && currentChar != '1')) {
                return NULL;
            }
            wantsEnd = YES;
        }

        // A float exponent can be negative, so do not break on the minus sign
        if(wantsEnd && isE && nIsSign) {
            wantsEnd = false;
        }

        // make sure its a valid string
        if(isValid == YES) {
            if(bufferCount + 1 >= dataStream->charCount) {
                NSUInteger required = (NSUInteger)bufferCount + 2;
                void* buffer = IJSVGPathDataStreamGrow(dataStream->charBuffer,
                    &dataStream->charCount, required, sizeof(char));
                if(buffer == NULL) {
                    return NULL;
                }
                dataStream->charBuffer = buffer;
            }
            // set the actual char against it
            if(currentChar == '.') {
                isDecimal = true;
            }
            dataStream->charBuffer[bufferCount++] = currentChar;
        } else {
            // if its an invalid char, just stop it
            wantsEnd = true;
        }

        // is at end of string, or wants to be stopped
        // buffer has to actually exist or its completly
        // useless and will cause a crash
        if(bufferCount != 0 && (wantsEnd || i == sLengthMinusOne)) {
            if(counter >= dataStream->floatCount) {
                NSUInteger required = (NSUInteger)counter + 1;
                void* buffer = IJSVGPathDataStreamGrow(dataStream->floatBuffer,
                    &dataStream->floatCount, required, sizeof(CGFloat));
                if(buffer == NULL) {
                    return NULL;
                }
                dataStream->floatBuffer = buffer;
            }

            // add the float, for performance reasons, we can simply set the
            // null value of the end of the string instead of nulling out
            // with memset \0, huzzah!
            dataStream->charBuffer[bufferCount] = '\0';
            
            // lets check to make the buffer actually has a valid float, and
            // not either just a sign or white space or some random char.
            if(bufferCount == 1 && !VALID_DIGIT(dataStream->charBuffer[0])) {
                isDecimal = false;
                bufferCount = 0;
                i++;
                continue;
            }
            
            // actually add the float into the buffer
            dataStream->floatBuffer[counter++] = IJSVGParseFloat(dataStream->charBuffer);

            // reset
            isDecimal = false;
            bufferCount = 0;
        }
        i++;
    }

    // set commands found, only if there is one
    if(commandsFound != NULL) {
        *commandsFound = counter / commandLength;
    }
    
    *numberCount = counter;
    return dataStream->floatBuffer;
}

CGFloat* IJSVGParsePathDataStreamSequence(const char* commandChars, NSInteger commandCharLength,
    IJSVGPathDataStream* dataStream, IJSVGPathDataSequence* sequence,
    NSInteger commandLength, NSInteger* commandsFound)
{
    NSInteger count = 0;
    const CGFloat* values = IJSVGReadPathDataStreamSequence(commandChars, commandCharLength,
        dataStream, sequence, commandLength, commandsFound, &count);
    if(values == NULL || count == 0) {
        return NULL;
    }
    size_t size = (size_t)count * sizeof(CGFloat);
    CGFloat* result = malloc(size);
    if(result == NULL) {
        if(commandsFound != NULL) {
            *commandsFound = 0;
        }
        return NULL;
    }
    memcpy(result, values, size);
    return result;
}

typedef struct {
    CGMutablePathRef path;
    CGPoint cubicControl;
    CGPoint quadraticControl;
    char previousCommand;
} IJSVGPathBuilder;

static NSInteger IJSVGPathCommandParameterCount(char command)
{
    switch(command) {
        case 'm':
        case 'l':
        case 't':
            return 2;
        case 'h':
        case 'v':
            return 1;
        case 'c':
            return 6;
        case 's':
        case 'q':
            return 4;
        case 'a':
            return 7;
        case 'z':
            return 0;
    }
    return -1;
}

static CGPoint IJSVGPathParameterPoint(const CGFloat* parameters, NSUInteger index, CGPoint origin)
{
    return CGPointMake(origin.x + parameters[index], origin.y + parameters[index + 1]);
}

static CGPoint IJSVGPathReflectedPoint(CGPoint control, CGPoint current)
{
    return CGPointMake(2 * current.x - control.x, 2 * current.y - control.y);
}

static void IJSVGPathAppendCubic(IJSVGPathBuilder* builder, char command,
    const CGFloat* parameters, CGPoint current, CGPoint origin)
{
    CGPoint first;
    CGPoint second;
    CGPoint end;
    if(command == 'c') {
        first = IJSVGPathParameterPoint(parameters, 0, origin);
        second = IJSVGPathParameterPoint(parameters, 2, origin);
        end = IJSVGPathParameterPoint(parameters, 4, origin);
    } else {
        BOOL reflects = builder->previousCommand == 'c' || builder->previousCommand == 's';
        first = reflects ? IJSVGPathReflectedPoint(builder->cubicControl, current) : current;
        second = IJSVGPathParameterPoint(parameters, 0, origin);
        end = IJSVGPathParameterPoint(parameters, 2, origin);
    }
    CGPathAddCurveToPoint(builder->path, NULL, first.x, first.y, second.x, second.y, end.x, end.y);
    builder->cubicControl = second;
}

static void IJSVGPathAppendQuadratic(IJSVGPathBuilder* builder, char command,
    const CGFloat* parameters, CGPoint current, CGPoint origin)
{
    CGPoint control;
    CGPoint end;
    if(command == 'q') {
        control = IJSVGPathParameterPoint(parameters, 0, origin);
        end = IJSVGPathParameterPoint(parameters, 2, origin);
    } else {
        BOOL reflects = builder->previousCommand == 'q' || builder->previousCommand == 't';
        control = reflects ? IJSVGPathReflectedPoint(builder->quadraticControl, current) : current;
        end = IJSVGPathParameterPoint(parameters, 0, origin);
    }
    CGPathAddQuadCurveToPoint(builder->path, NULL, control.x, control.y, end.x, end.y);
    builder->quadraticControl = control;
}

static void IJSVGPathAppendCommand(IJSVGPathBuilder* builder, char command,
    BOOL relative, const CGFloat* parameters)
{
    BOOL initial = builder->previousCommand == 0;
    if(command != 'm' && initial) {
        CGPathMoveToPoint(builder->path, NULL, 0, 0);
    }
    CGPoint current = initial ? CGPointZero : CGPathGetCurrentPoint(builder->path);
    CGPoint origin = relative ? current : CGPointZero;
    switch(command) {
        case 'm':
            CGPathMoveToPoint(builder->path, NULL, origin.x + parameters[0], origin.y + parameters[1]);
            break;
        case 'l':
            CGPathAddLineToPoint(builder->path, NULL, origin.x + parameters[0], origin.y + parameters[1]);
            break;
        case 'h':
            CGPathAddLineToPoint(builder->path, NULL, origin.x + parameters[0], current.y);
            break;
        case 'v':
            CGPathAddLineToPoint(builder->path, NULL, current.x, origin.y + parameters[0]);
            break;
        case 'c':
        case 's':
            IJSVGPathAppendCubic(builder, command, parameters, current, origin);
            break;
        case 'q':
        case 't':
            IJSVGPathAppendQuadratic(builder, command, parameters, current, origin);
            break;
        case 'a':
            IJSVGPathAddEllipticalArc(builder->path, parameters, relative);
            break;
        case 'z':
            CGPathCloseSubpath(builder->path);
            break;
    }
    builder->previousCommand = command;
}

void IJSVGAppendPathData(CGMutablePathRef path, const char* characters, NSUInteger length,
    IJSVGPathDataStream* dataStream)
{
    IJSVGPathBuilder builder = { .path = path };
    if(characters == NULL || length > NSIntegerMax) {
        return;
    }
    static IJSVGPathDataSequence arcSequence[] = {
        kIJSVGPathDataSequenceTypeFloat, kIJSVGPathDataSequenceTypeFloat,
        kIJSVGPathDataSequenceTypeFloat, kIJSVGPathDataSequenceTypeFlag,
        kIJSVGPathDataSequenceTypeFlag, kIJSVGPathDataSequenceTypeFloat,
        kIJSVGPathDataSequenceTypeFloat
    };
    NSUInteger index = 0;
    while(index < length && characters[index] != '\0') {
        char original = characters[index++];
        char command = (char)tolower((unsigned char)original);
        NSInteger parameterCount = IJSVGPathCommandParameterCount(command);
        if(parameterCount < 0) {
            continue;
        }
        NSUInteger start = index;
        while(index < length && characters[index] != '\0' &&
              !IJSVGIsLegalCommandCharacter(characters[index])) {
            index++;
        }
        BOOL relative = original >= 'a' && original <= 'z';
        if(parameterCount == 0) {
            IJSVGPathAppendCommand(&builder, command, relative, NULL);
            continue;
        }
        NSInteger sets = 0;
        NSInteger numberCount = 0;
        IJSVGPathDataSequence* sequence = command == 'a' ? arcSequence : NULL;
        const char* parametersStart = characters + start;
        NSInteger parametersLength = (NSInteger)(index - start);
        const CGFloat* parameters = IJSVGReadPathDataStreamSequence(parametersStart, parametersLength,
            dataStream, sequence, parameterCount, &sets, &numberCount);
        if(parameters == NULL) {
            continue;
        }
        for(NSInteger set = 0; set < sets; set++) {
            const CGFloat* values = parameters + set * parameterCount;
            BOOL finite = YES;
            for(NSInteger value = 0; value < parameterCount; value++) {
                finite &= isfinite(values[value]);
            }
            if(!finite) {
                break;
            }
            char effectiveCommand = command == 'm' && set != 0 ? 'l' : command;
            IJSVGPathAppendCommand(&builder, effectiveCommand, relative, values);
        }
    }
}

CGMutablePathRef IJSVGCreatePathFromData(const char* characters, NSUInteger length,
    IJSVGPathDataStream* dataStream)
{
    CGMutablePathRef path = CGPathCreateMutable();
    IJSVGAppendPathData(path, characters, length, dataStream);
    return path;
}

BOOL IJSVGAppendPolyPoints(CGMutablePathRef path, const char* characters, NSUInteger length,
    BOOL closePath, IJSVGPathDataStream* dataStream)
{
    if(characters == NULL || length > NSIntegerMax) {
        return NO;
    }
    NSInteger count = 0;
    const CGFloat* values = IJSVGReadPathDataStreamSequence(characters, (NSInteger)length,
        dataStream, NULL, 1, NULL, &count);
    if(values == NULL || count < 2 || count % 2 != 0) {
        return NO;
    }
    for(NSInteger index = 0; index < count; index++) {
        if(!isfinite(values[index])) {
            return NO;
        }
    }
    CGPathMoveToPoint(path, NULL, values[0], values[1]);
    for(NSInteger index = 2; index < count; index += 2) {
        CGPathAddLineToPoint(path, NULL, values[index], values[index + 1]);
    }
    if(closePath) {
        CGPathCloseSubpath(path);
    }
    return YES;
}

// this method is finely tuned to just handle the buffer
// that IJSVGParsePathDataSequence produces for each float
// it does not look or skip white space as the previous method
// handles this for us
// inspired and modified from http://www.leapsecond.com/tools/fast_atof.c
CGFloat IJSVGParseFloat(const char* buffer)
{
    const char* start = buffer;
    int fraction;
    double sign, value, scale;

    // work out a sign, if any, might not be, who knows
    sign = 1.f;
    if(*buffer == '-') {
        sign = -1.f;
        buffer += 1;
    } else if(*buffer == '+') {
        buffer += 1;
    }

    // get numbers before decimal point or exponent
    for (value = 0.f; VALID_DIGIT(*buffer); buffer += 1) {
        value = value * 10.f + (*buffer - '0');
    }

    // get digits after decimal point
    if(*buffer == '.') {
        double pow10 = 10.f;
        buffer += 1;
        while (VALID_DIGIT(*buffer)) {
            value += (*buffer - '0') / pow10;
            pow10 *= 10.f;
            buffer += 1;
        }
    }

    // handle exponent
    fraction = 0;
    scale = 1.f;
    if((*buffer | ('E' ^ 'e')) == 'e') {
        unsigned int exponent;
        buffer += 1;
        if(*buffer == '-') {
            fraction = 1;
            buffer += 1;
        } else if(*buffer == '+') {
            buffer += 1;
        }
        for (exponent = 0; VALID_DIGIT(*buffer); buffer += 1) {
            if(exponent <= 308) {
                exponent = exponent * 10 + (*buffer - '0');
            }
        }
        if(exponent > 308) {
            // Preserve overflow and subnormal values instead of silently clamping
            // the exponent. Keep the fast conversion for ordinary SVG numbers.
            return (CGFloat)[[NSString stringWithUTF8String:start] doubleValue];
        }
        while (exponent >= 50) {
            scale *= 1E50;
            exponent -= 50;
        }
        while (exponent >= 8) {
            scale *= 1E8;
            exponent -= 8;
        }
        while (exponent > 0) {
            scale *= 10.f;
            exponent -= 1;
        }
    }

    // make sure we cast this to a CGFloat before return
    return (CGFloat)(sign * (fraction ? (value / scale) : (value * scale)));
}

@end
