//
//  IJSVGCommandParser.m
//  IJSVG
//
//  Created by Curtis Hard on 23/12/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import "IJSVGCommandParser.h"

@implementation IJSVGCommandParser

#define VALID_DIGIT(c) ((c ^ '0') <= 9)

IJSVGPathDataSequence* IJSVGPathDataSequenceCreateWithType(IJSVGPathDataSequence type, NSInteger length)
{
    size_t size = sizeof(IJSVGPathDataSequence) * length;
    IJSVGPathDataSequence* sequence = (IJSVGPathDataSequence*)malloc(size);
    memset(sequence, type, size);
    return sequence;
};

// Datastreams work by setting up one stream of bits/memory per SVG
// so that each SVG has a reusable memory block to read and parse paths into.
// As its all linear and one SVG per thread, this saves alot of memory allocation
// calls as we simple can just reuse the buffer that already exists - this also
// allows us to specify the default allocation size, so when parsing viewBox we
// can simply allocate (4*sizeof(CGFloat)) instead of the default 50 slots
IJSVGParsePathDataStream* IJSVGParsePathDataStreamCreateDefault(void)
{
    return IJSVGParsePathDataStramCreate(IJSVG_DATA_STREAM_DEFAULT_BUFFER_COUNT_FLOAT,
        IJSVG_DATA_STREAM_DEFAULT_BUFFER_COUNT_CHAR);
}

IJSVGParsePathDataStream* IJSVGParsePathDataStramCreate(NSUInteger floatCount, NSUInteger charCount)
{
    floatCount = floatCount ?: IJSVG_DATA_STREAM_DEFAULT_BUFFER_COUNT_FLOAT;
    charCount = charCount ?: IJSVG_DATA_STREAM_DEFAULT_BUFFER_COUNT_CHAR;
    IJSVGParsePathDataStream* buffer = (IJSVGParsePathDataStream*)malloc(sizeof(IJSVGParsePathDataStream));
    buffer->floatBuffer = (CGFloat*)malloc(sizeof(CGFloat) * floatCount);
    buffer->floatCount = floatCount;
    buffer->charBuffer = (char*)calloc(sizeof(char), charCount);
    buffer->charCount = charCount;
    return buffer;
}

void IJSVGParsePathDataStreamRelease(IJSVGParsePathDataStream* buffer)
{
    free(buffer->charBuffer);
    free(buffer->floatBuffer);
    free(buffer);
};

CGFloat* _Nullable IJSVGParsePathDataSequence(NSString* string, IJSVGParsePathDataStream* stream,
    IJSVGPathDataSequence* _Nullable sequence, NSInteger commandLength, NSInteger* _Nullable commandsFound)
{
    // if no command length, its completely pointless function,
    // so just return null and set commandsFound to 0, if we dont
    // we get a arithmetic error later on due to zero
    if (commandLength == 0) {
        *commandsFound = 0;
        return NULL;
    }

    // default sizes and memory
    // sizes for the string buffer
    const NSInteger defFloatSize = 20;
    const NSInteger defSize = 10;

    // default memory size for the float
    NSInteger i = 0;
    NSInteger counter = 0;

    const char* cString = string.UTF8String;
    const char* validChars = "eE+-.";

    // this is much faster then doing strlen as it doesnt need
    // to compute the length
    NSInteger sLength = string.length;
    NSInteger sLengthMinusOne = sLength - 1;

    bool isDecimal = false;
    int bufferCount = 0;

    while (i < sLength) {
        char currentChar = cString[i];

        // work out next char
        char nextChar = (char)0;
        if (i < sLengthMinusOne) {
            nextChar = cString[i + 1];
        }

        // check for validator
        bool isValid = VALID_DIGIT(currentChar) || strchr(validChars, currentChar) != NULL;

        // in order to work out the split, its either because the next char is
        // a  hyphen or a plus, or next char is a decimal and the current number is a decimal
        bool isE = (currentChar | ('E' ^ 'e')) == 'e';
        bool wantsEnd = nextChar == '-' || nextChar == '+' || (nextChar == '.' && isDecimal);

        // work our what the sequence is...
        IJSVGPathDataSequence seq = kIJSVGPathDataSequenceTypeFloat;
        if (sequence != NULL) {
            seq = sequence[counter % commandLength];
        }

        // is a flag, consists of one value
        // if its invalid, make sure we free the memory
        // and return null - or hell breaks lose
        if (isValid == YES && seq == kIJSVGPathDataSequenceTypeFlag) {
            if (bufferCount != 0 || (currentChar != '0' && currentChar != '1')) {
                return NULL;
            }
            wantsEnd = YES;
        }

        // could be a float like 5.334e-5 so dont break on the hypen
        if (wantsEnd && isE && (nextChar == '-' || nextChar == '+')) {
            wantsEnd = false;
        }

        // make sure its a valid string
        if (isValid == YES) {
            // alloc the buffer if needed
            if ((bufferCount + 1) == stream->charCount) {
                // realloc the buffer, incase the string is overflowing the
                // allocated memory
                stream->charCount += defSize;
                stream->charBuffer = (char*)realloc(stream->charBuffer,
                    sizeof(char) * stream->charCount);
            }
            // set the actual char against it
            if (currentChar == '.') {
                isDecimal = true;
            }
            stream->charBuffer[bufferCount++] = currentChar;
        } else {
            // if its an invalid char, just stop it
            wantsEnd = true;
        }

        // is at end of string, or wants to be stopped
        // buffer has to actually exist or its completly
        // useless and will cause a crash
        if (bufferCount != 0 && (wantsEnd || i == sLengthMinusOne)) {
            // make sure there is enough room in the float pool
            if ((counter + 1) == stream->floatCount) {
                stream->floatCount += defFloatSize;
                stream->floatBuffer = (CGFloat*)realloc(stream->floatBuffer,
                    sizeof(CGFloat) * stream->floatCount);
            }

            // add the float
            stream->floatBuffer[counter++] = IJSVGParseFloat(stream->charBuffer);

            // memory clean and counter resets
            memset(stream->charBuffer, '\0', sizeof(char) * bufferCount);
            isDecimal = false;
            bufferCount = 0;
        }
        i++;
    }

    if (commandsFound != NULL) {
        *commandsFound = (NSInteger)round(counter / commandLength);
    }

    // allocate the new buffer from memory
    CGFloat* floats = (CGFloat*)malloc(sizeof(CGFloat) * counter);
    memcpy(floats, stream->floatBuffer, counter * sizeof(CGFloat));

    // return the floats just set into the memory
    return floats;
}

// this method is finely tuned to just handle the buffer
// that IJSVGParsePathDataSequence produces for each float
// it does not look or skip white space as the previous method
// handles this for us
// inspired and modified from http://www.leapsecond.com/tools/fast_atof.c
CGFloat IJSVGParseFloat(char* buffer)
{
    int fraction;
    double sign, value, scale;

    // work out a sign, if any, might not be, who knows
    sign = 1.f;
    if (*buffer == '-') {
        sign = -1.f;
        buffer += 1;
    } else if (*buffer == '+') {
        buffer += 1;
    }

    // get numbers before decimal point or exponent
    for (value = 0.f; VALID_DIGIT(*buffer); buffer += 1) {
        value = value * 10.f + (*buffer - '0');
    }

    // get digits after decimal point
    if (*buffer == '.') {
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
    if ((*buffer | ('E' ^ 'e')) == 'e') {
        unsigned int exponent;
        buffer += 1;
        if (*buffer == '-') {
            fraction = 1;
            buffer += 1;
        } else if (*buffer == '+') {
            buffer += 1;
        }
        for (exponent = 0; VALID_DIGIT(*buffer); buffer += 1) {
            exponent = exponent * 10 + (*buffer - '0');
        }
        if (exponent > 308) {
            exponent = 308;
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
