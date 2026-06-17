//
//  IJSVGExporterPathInstruction.m
//  IconJar
//
//  Created by Curtis Hard on 08/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGExporter.h>
#import <IJSVG/IJSVGExporterPathInstruction.h>
#import <IJSVG/IJSVGUtils.h>
#import <math.h>

@implementation IJSVGExporterPathInstructionCommand
@end

@implementation IJSVGExporterPathInstruction

@synthesize instruction = _instruction;

- (void)dealloc
{
    if(_data != NULL && _data != _inlineData) {
        (void)free(_data), _data = NULL;
    }
}

- (id)initWithInstruction:(char)instruction
                dataCount:(NSInteger)floatCount
{
    if((self = [super init]) != nil) {
        _instruction = instruction;

        _dataCount = floatCount;
        if(floatCount <= 7) {
            _data = _inlineData;
        } else {
            _data = (CGFloat*)calloc(sizeof(CGFloat), floatCount);
        }

    }
    return self;
}

- (NSInteger)dataLength
{
    return _dataCount;
}

- (CGFloat*)data
{
    return _data;
}

- (CGFloat*)base
{
    return _base;
}

- (CGFloat*)coords
{
    return _coords;
}

static void IJSVGExporterAppendCompressedFloatString(NSMutableString* string,
                                                     NSString* dataString,
                                                     BOOL* isFirst,
                                                     BOOL* lastWasDecimal)
{
    const char* chars = dataString.UTF8String;

    BOOL isSigned = chars[0] == '-';
    BOOL isDecimal = (isSigned == NO && chars[0] == '.') || (isSigned == YES && chars[1] == '.');
    if(*isFirst == YES || isSigned == YES || (isDecimal == YES && *lastWasDecimal == YES)) {
        [string appendString:dataString];
    } else {
        [string appendFormat:@" %@", dataString];
    }

    *isFirst = NO;
    *lastWasDecimal = strchr(chars, '.') != NULL;
}

static void IJSVGExporterAppendCompressedFloatCString(NSMutableString* string,
                                                      const char* dataString,
                                                      BOOL* isFirst,
                                                      BOOL* lastWasDecimal)
{
    BOOL isSigned = dataString[0] == '-';
    BOOL isDecimal = (isSigned == NO && dataString[0] == '.') || (isSigned == YES && dataString[1] == '.');
    if(*isFirst == NO && isSigned == NO && (isDecimal == NO || *lastWasDecimal == NO)) {
        CFStringAppendCString((CFMutableStringRef)string, " ", kCFStringEncodingUTF8);
    }
    CFStringAppendCString((CFMutableStringRef)string, dataString, kCFStringEncodingUTF8);

    *isFirst = NO;
    *lastWasDecimal = strchr(dataString, '.') != NULL;
}

static void IJSVGExporterAppendPathFloat(NSMutableString* string,
                                         CGFloat value,
                                         IJSVGFloatingPointOptions floatingPointOptions,
                                         BOOL* isFirst,
                                         BOOL* lastWasDecimal)
{
    if(floatingPointOptions.round == YES) {
        value = IJSVGExporterPathFloatToFixed(value, floatingPointOptions.precision);
    }

    char buffer[64];
    int length = snprintf(buffer, sizeof(buffer), "%g", value);
    if(length < 0 || length >= sizeof(buffer)) {
        NSString* floatString = IJSVGShortFloatStringWithOptions(value, floatingPointOptions);
        IJSVGExporterAppendCompressedFloatString(string, floatString, isFirst, lastWasDecimal);
        return;
    }

    const char* output = buffer;
    if(buffer[0] == '-' && buffer[1] == '0' && strchr(buffer, '.') != NULL) {
        buffer[1] = '-';
        output = buffer + 1;
    } else if(buffer[0] == '0' && buffer[1] == '.') {
        output = buffer + 1;
    }

    IJSVGExporterAppendCompressedFloatCString(string, output, isFirst, lastWasDecimal);
}

static void IJSVGExporterAppendPathInstructionData(NSMutableString* string,
                                                   char instruction,
                                                   CGFloat* data,
                                                   IJSVGFloatingPointOptions floatingPointOptions)
{
    BOOL isFirst = YES;
    BOOL lastWasDecimal = NO;
    switch (tolower(instruction)) {
    case 't':
    case 'm':
    case 'l': {
        IJSVGExporterAppendPathFloat(string, data[0], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[1], floatingPointOptions, &isFirst, &lastWasDecimal);
        break;
    }

    case 'v':
    case 'h': {
        IJSVGExporterAppendPathFloat(string, data[0], floatingPointOptions, &isFirst, &lastWasDecimal);
        break;
    }

    case 'c': {
        IJSVGExporterAppendPathFloat(string, data[0], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[1], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[2], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[3], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[4], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[5], floatingPointOptions, &isFirst, &lastWasDecimal);
        break;
    }

    case 's':
    case 'q': {
        IJSVGExporterAppendPathFloat(string, data[0], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[1], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[2], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[3], floatingPointOptions, &isFirst, &lastWasDecimal);
        break;
    }

    case 'a': {
        IJSVGExporterAppendPathFloat(string, data[0], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[1], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[2], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[3], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[4], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[5], floatingPointOptions, &isFirst, &lastWasDecimal);
        IJSVGExporterAppendPathFloat(string, data[6], floatingPointOptions, &isFirst, &lastWasDecimal);
        break;
    }
    }
}

static NSString* IJSVGExporterPathStringForInstruction(char instruction,
                                                       CGFloat* data,
                                                       IJSVGFloatingPointOptions floatingPointOptions)
{
    NSMutableString* string = [[NSMutableString alloc] init];
    [string appendFormat:@"%c", instruction];
    IJSVGExporterAppendPathInstructionData(string, instruction, data, floatingPointOptions);
    return string;
}

+ (NSString*)pathStringWithInstructionSet:(NSArray<IJSVGExporterPathInstructionCommand*>*)instructionSets
                     floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    IJSVGExporterPathInstructionCommand* lastCommand = NULL;
    NSMutableString* string = [[NSMutableString alloc] init];
    for (IJSVGExporterPathInstructionCommand* command in instructionSets) {
        if(lastCommand == nil || lastCommand.instruction != command.instruction) {
            [string appendFormat:@"%c", command.instruction];
        } else {
            [string appendString:@" "];
        }

        BOOL isFirst = YES;
        BOOL lastWasDecimal = NO;
        for (NSString* param in command.params) {
            IJSVGExporterAppendCompressedFloatString(string, param, &isFirst, &lastWasDecimal);
        }
        lastCommand = command;
    }
    return string;
}

+ (NSString*)pathStringFromInstructions:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                   floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    IJSVGExporterPathInstruction* lastInstruction = nil;
    NSMutableString* string = [[NSMutableString alloc] init];
    for (IJSVGExporterPathInstruction* instruction in instructions) {
        if(lastInstruction == nil || lastInstruction.instruction != instruction.instruction) {
            [string appendFormat:@"%c", instruction.instruction];
        } else {
            [string appendString:@" "];
        }

        IJSVGExporterAppendPathInstructionData(string, instruction.instruction, instruction.data, floatingPointOptions);
        lastInstruction = instruction;
    }
    return string;
}

static CGFloat IJSVGExporterPathPrecisionMultiplier(int precision)
{
    switch (precision) {
        case 0: return 1.f;
        case 1: return 10.f;
        case 2: return 100.f;
        case 3: return 1000.f;
        case 4: return 10000.f;
        case 5: return 100000.f;
        case 6: return 1000000.f;
        case 7: return 10000000.f;
        case 8: return 100000000.f;
        case 9: return 1000000000.f;
        case 10: return 10000000000.f;
        default: return pow(10, precision);
    }
}

static CGFloat IJSVGExporterPathFloatToFixedWithMultiplier(CGFloat number, CGFloat multiplier)
{
    return floorf(multiplier * number) / multiplier;
}

CGFloat IJSVGExporterPathFloatToFixed(CGFloat number, int precision)
{
    return IJSVGExporterPathFloatToFixedWithMultiplier(number,
        IJSVGExporterPathPrecisionMultiplier(precision));
}

void IJSVGExporterPathInstructionRoundData(CGFloat* data, NSInteger length,
    IJSVGFloatingPointOptions options)
{
    int precision = options.precision;
    CGFloat multiplier = IJSVGExporterPathPrecisionMultiplier(precision);
    CGFloat lowerMultiplier = IJSVGExporterPathPrecisionMultiplier(precision - 1);
    CGFloat errorMultiplier = IJSVGExporterPathPrecisionMultiplier(precision + 1);

    for (NSInteger i = length; i-- > 0;) {
        CGFloat d = data[i];
        CGFloat proposed = IJSVGExporterPathFloatToFixedWithMultiplier(d, multiplier);
        if(proposed != d) {
            CGFloat rounded = IJSVGExporterPathFloatToFixedWithMultiplier(d, lowerMultiplier);
            data[i] = IJSVGExporterPathFloatToFixedWithMultiplier(fabs(rounded - d), errorMultiplier)
                    >= kIJSVGExporterPathInstructionErrorThreshold ? proposed : rounded;
        }
    }
}

+ (void)convertInstructionsToRoundRelativeCoordinates:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                                 floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    CGFloat relSubPoint[2] = { 0.f, 0.f };
    for (IJSVGExporterPathInstruction* instruction in instructions) {
        char instructionChar = instruction.instruction;
        NSInteger length = instruction.dataLength;
        CGFloat* data = instruction.data;
        if(strchr("mltqsc", instructionChar) != NULL) {
            for (NSInteger i = length; i--;) {
                data[i] += instruction.base[i % 2] - relSubPoint[i % 2];
            }
        } else if(instructionChar == 'h') {
            data[0] += instruction.base[0] - relSubPoint[0];
        } else if(instructionChar == 'v') {
            data[0] += instruction.base[1] - relSubPoint[1];
        } else if(instructionChar == 'a') {
            data[5] += instruction.base[0] - relSubPoint[0];
            data[6] += instruction.base[1] - relSubPoint[1];
        }
        IJSVGExporterPathInstructionRoundData(data, length, floatingPointOptions);
        if(instructionChar == 'h') {
            relSubPoint[0] += data[0];
        } else if(instructionChar == 'v') {
            relSubPoint[1] += data[0];
        } else {
            relSubPoint[0] += data[length - 2];
            relSubPoint[1] += data[length - 1];
        }
        IJSVGExporterPathInstructionRoundData(relSubPoint, 2, floatingPointOptions);
    }
}

+ (void)convertInstructionsToMixedAbsoluteRelative:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                              floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    IJSVGExporterPathInstruction* prevInstruction = nil;
    for (IJSVGExporterPathInstruction* instruction in instructions) {
        if(prevInstruction == nil || instruction.dataLength == 0) {
            prevInstruction = instruction;
            continue;
        }

        char instructionChar = instruction.instruction;
        CGFloat* data = instruction.data;
        NSInteger length = instruction.dataLength;
        CGFloat adata[7];
        memcpy(adata, data, sizeof(CGFloat) * length);

        if(strchr("mltqsc", instructionChar) != NULL) {
            for (NSInteger i = length; i--;) {
                adata[i] += instruction.base[i % 2];
            }
        } else if(instructionChar == 'h') {
            adata[0] += instruction.base[0];
        } else if(instructionChar == 'v') {
            adata[0] += instruction.base[1];
        } else if(instructionChar == 'a') {
            adata[5] += instruction.base[0];
            adata[6] += instruction.base[1];
        }

        IJSVGExporterPathInstructionRoundData(adata, length, floatingPointOptions);

        // run these through our default string runner
        // to compare the outputs
        NSString* orig = IJSVGExporterPathStringForInstruction(instructionChar, data, floatingPointOptions);
        NSString* comp = IJSVGExporterPathStringForInstruction(instructionChar, adata, floatingPointOptions);

        if(comp.length < orig.length && !(instructionChar == prevInstruction.instruction &&
                                           prevInstruction.instruction > 96 &&
                                           comp.length == orig.length - 1 &&
                                           data[0] < 0.f &&
                                           fmod(prevInstruction.data[prevInstruction.dataLength - 1], 1) != 0.f)) {
            instruction.instruction = toupper(instructionChar);
            memcpy(data, adata, sizeof(CGFloat) * length);
        }
        prevInstruction = instruction;
    }
}

+ (void)convertInstructionsDataToRounded:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                    floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    for (IJSVGExporterPathInstruction* instruction in instructions) {
        CGFloat* data = instruction.data;
        IJSVGExporterPathInstructionRoundData(data, instruction.dataLength,
            floatingPointOptions);
    }
}

+ (void)convertInstructionsDataToRoundedAndRecalculateCoordinates:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                                             floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    CGFloat start[2] = {0, 0};
    CGFloat cursor[2] = {0, 0};
    CGFloat prevCoords[2] = {0, 0};

    NSInteger index = 0;
    for (IJSVGExporterPathInstruction* anInstruction in instructions) {
        char instruction = anInstruction.instruction;
        CGFloat* data = anInstruction.data;
        CGFloat* base = anInstruction.base;
        CGFloat* coords = anInstruction.coords;
        IJSVGExporterPathInstructionRoundData(data, anInstruction.dataLength,
            floatingPointOptions);

        switch(instruction) {
            case 'm': {
                cursor[0] += data[0];
                cursor[1] += data[1];
                start[0] = cursor[0];
                start[1] = cursor[1];
                break;
            }
            case 'M': {
                if(index != 0) {
                    instruction = 'm';
                }
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                cursor[0] += data[0];
                cursor[1] += data[1];
                start[0] = cursor[0];
                start[1] = cursor[1];
                break;
            }
            case 'l': {
                cursor[0] += data[0];
                cursor[1] += data[1];
                break;
            }
            case 'L': {
                instruction = 'l';
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                cursor[0] += data[0];
                cursor[1] += data[1];
                break;
            }
            case 'h': {
                cursor[0] += data[0];
                break;
            }
            case 'H': {
                instruction = 'h';
                data[0] -= cursor[0];
                cursor[0] += data[0];
                break;
            }
            case 'v': {
                cursor[1] += data[0];
                break;
            }
            case 'V': {
                instruction = 'v';
                data[0] -= cursor[1];
                cursor[1] += data[0];
                break;
            }
            case 'c': {
                cursor[0] += data[4];
                cursor[1] += data[5];
                break;
            }
            case 'C': {
                instruction = 'c';
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                data[2] -= cursor[0];
                data[3] -= cursor[1];
                data[4] -= cursor[0];
                data[5] -= cursor[1];
                cursor[0] += data[4];
                cursor[1] += data[5];
                break;
            }
            case 's': {
                cursor[0] += data[2];
                cursor[1] += data[3];
                break;
            }
            case 'S': {
                instruction = 's';
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                data[2] -= cursor[0];
                data[3] -= cursor[1];
                cursor[0] += data[2];
                cursor[1] += data[3];
                break;
            }
            case 'q': {
                cursor[0] += data[2];
                cursor[1] += data[3];
                break;
            }
            case 'Q': {
                instruction = 'q';
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                data[2] -= cursor[0];
                data[3] -= cursor[1];
                cursor[0] += data[2];
                cursor[1] += data[3];
                break;
            }
            case 't': {
                cursor[0] += data[0];
                cursor[1] += data[1];
                break;
            }
            case 'T': {
                instruction = 't';
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                cursor[0] += data[0];
                cursor[1] += data[1];
                break;
            }
            case 'a': {
                cursor[0] += data[5];
                cursor[1] += data[6];
                break;
            }
            case 'A': {
                instruction = 'a';
                data[5] -= cursor[0];
                data[6] -= cursor[1];
                cursor[0] += data[5];
                cursor[1] += data[6];
                break;
            }
            case 'Z':
            case 'z': {
                cursor[0] = start[0];
                cursor[1] = start[1];
                break;
            }
        }

        // set the instruction back
        anInstruction.instruction = instruction;
        base[0] = prevCoords[0];
        base[1] = prevCoords[1];
        coords[0] = cursor[0];
        coords[1] = cursor[1];
        prevCoords[0] = cursor[0];
        prevCoords[1] = cursor[1];
        index++;
    }
}

+ (NSArray<IJSVGExporterPathInstruction*>*)convertInstructionsCurves:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                                                floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    NSMutableArray<IJSVGExporterPathInstruction*>* nInstructions = nil;
    nInstructions = [[NSMutableArray alloc] initWithCapacity:instructions.count];
    IJSVGExporterPathInstruction* lastInstruction = nil;
    for (IJSVGExporterPathInstruction* instruction in instructions) {
        lastInstruction = nInstructions.lastObject;
        if(lastInstruction == nil) {
            [nInstructions addObject:instruction];
            continue;
        }
        if(instruction.instruction == 'c') {
            if(lastInstruction.instruction == 'c' &&
                instruction.data[0] == -(lastInstruction.data[2] - lastInstruction.data[4]) &&
                instruction.data[1] == -(lastInstruction.data[3] - lastInstruction.data[5])) {
                IJSVGExporterPathInstruction* nInstruction = nil;
                nInstruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'s'
                                                                                dataCount:4];
                nInstruction.data[0] = instruction.data[2];
                nInstruction.data[1] = instruction.data[3];
                nInstruction.data[2] = instruction.data[4];
                nInstruction.data[3] = instruction.data[5];
                [nInstructions addObject:nInstruction];
                continue;
            } else if(lastInstruction.instruction == 's' &&
                       instruction.data[0] == -(lastInstruction.data[0] - lastInstruction.data[2]) &&
                       instruction.data[1] == -(lastInstruction.data[1] - lastInstruction.data[3])) {
                IJSVGExporterPathInstruction* nInstruction = nil;
                nInstruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'s'
                                                                                dataCount:4];
                nInstruction.data[0] = instruction.data[2];
                nInstruction.data[1] = instruction.data[3];
                nInstruction.data[2] = instruction.data[4];
                nInstruction.data[3] = instruction.data[5];
                [nInstructions addObject:nInstruction];
                continue;
            } else if(lastInstruction.instruction != 'c' &&
                       lastInstruction.instruction != 's' &&
                       instruction.data[0] == 0.f && instruction.data[1] == 0.f) {
                IJSVGExporterPathInstruction* nInstruction = nil;
                nInstruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'s'
                                                                                dataCount:4];
                nInstruction.data[0] = instruction.data[2];
                nInstruction.data[1] = instruction.data[3];
                nInstruction.data[2] = instruction.data[4];
                nInstruction.data[3] = instruction.data[5];
                [nInstructions addObject:nInstruction];
                continue;
            }
        } else if(instruction.instruction == 'q') {
            if(lastInstruction.instruction == 'q' &&
                instruction.data[0] == (lastInstruction.data[2] - lastInstruction.data[0]) &&
                instruction.data[1] == (lastInstruction.data[3] - lastInstruction.data[1])) {
                IJSVGExporterPathInstruction* nInstruction = nil;
                nInstruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'t'
                                                                                dataCount:2];
                nInstruction.data[0] = instruction.data[2];
                nInstruction.data[1] = instruction.data[3];
                [nInstructions addObject:nInstruction];
                continue;
            } else if(lastInstruction.instruction == 't' &&
                       instruction.data[2] == lastInstruction.data[0] &&
                       instruction.data[3] == lastInstruction.data[1]) {
                IJSVGExporterPathInstruction* nInstruction = nil;
                nInstruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'t'
                                                                                dataCount:2];
                nInstruction.data[0] = instruction.data[2];
                nInstruction.data[1] = instruction.data[3];
                [nInstructions addObject:nInstruction];
                continue;
            }
        }
        [nInstructions addObject:instruction];
    }
    return nInstructions;
}

+ (void)convertInstructionsToRelativeCoordinates:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                            floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    CGFloat start[2] = {0, 0};
    CGFloat cursor[2] = {0, 0};
    CGFloat prevCoords[2] = {0, 0};

    NSInteger index = 0;
    for (IJSVGExporterPathInstruction* anInstruction in instructions) {
        char instruction = anInstruction.instruction;
        CGFloat* data = anInstruction.data;
        CGFloat* base = anInstruction.base;
        CGFloat* coords = anInstruction.coords;
        
        switch(instruction) {
            case 'm': {
                cursor[0] += data[0];
                cursor[1] += data[1];
                start[0] = cursor[0];
                start[1] = cursor[1];
                break;
            }
            case 'M': {
                if(index != 0) {
                    instruction = 'm';
                }
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                cursor[0] += data[0];
                cursor[1] += data[1];
                start[0] = cursor[0];
                start[1] = cursor[1];
                break;
            }
            case 'l': {
                cursor[0] += data[0];
                cursor[1] += data[1];
                break;
            }
            case 'L': {
                instruction = 'l';
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                cursor[0] += data[0];
                cursor[1] += data[1];
                break;
            }
            case 'h': {
                cursor[0] += data[0];
                break;
            }
            case 'H': {
                instruction = 'h';
                data[0] -= cursor[0];
                cursor[0] += data[0];
                break;
            }
            case 'v': {
                cursor[1] += data[0];
                break;
            }
            case 'V': {
                instruction = 'v';
                data[0] -= cursor[1];
                cursor[1] += data[0];
                break;
            }
            case 'c': {
                cursor[0] += data[4];
                cursor[1] += data[5];
                break;
            }
            case 'C': {
                instruction = 'c';
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                data[2] -= cursor[0];
                data[3] -= cursor[1];
                data[4] -= cursor[0];
                data[5] -= cursor[1];
                cursor[0] += data[4];
                cursor[1] += data[5];
                break;
            }
            case 's': {
                cursor[0] += data[2];
                cursor[1] += data[3];
                break;
            }
            case 'S': {
                instruction = 's';
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                data[2] -= cursor[0];
                data[3] -= cursor[1];
                cursor[0] += data[2];
                cursor[1] += data[3];
                break;
            }
            case 'q': {
                cursor[0] += data[2];
                cursor[1] += data[3];
                break;
            }
            case 'Q': {
                instruction = 'q';
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                data[2] -= cursor[0];
                data[3] -= cursor[1];
                cursor[0] += data[2];
                cursor[1] += data[3];
                break;
            }
            case 't': {
                cursor[0] += data[0];
                cursor[1] += data[1];
                break;
            }
            case 'T': {
                instruction = 't';
                data[0] -= cursor[0];
                data[1] -= cursor[1];
                cursor[0] += data[0];
                cursor[1] += data[1];
                break;
            }
            case 'a': {
                cursor[0] += data[5];
                cursor[1] += data[6];
                break;
            }
            case 'A': {
                instruction = 'a';
                data[5] -= cursor[0];
                data[6] -= cursor[1];
                cursor[0] += data[5];
                cursor[1] += data[6];
                break;
            }
            case 'Z':
            case 'z': {
                cursor[0] = start[0];
                cursor[1] = start[1];
                break;
            }
        }

        // set the instruction back
        anInstruction.instruction = instruction;
        base[0] = prevCoords[0];
        base[1] = prevCoords[1];
        coords[0] = cursor[0];
        coords[1] = cursor[1];
        prevCoords[0] = cursor[0];
        prevCoords[1] = cursor[1];
        index++;
    }
}

+ (NSArray<IJSVGExporterPathInstruction*>*)instructionsFromPath:(CGPathRef)path
                                           floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{

    // keep track of the current point
    __block CGPoint currentPoint = CGPointZero;
    NSMutableArray* instructions = [[NSMutableArray alloc] init];

    // create the path callback
    IJSVGCGPathHandler callback = ^(const CGPathElement* pathElement) {
        IJSVGExporterPathInstruction* instruction = nil;
        // work out what to do
        switch (pathElement->type) {

        case kCGPathElementMoveToPoint: {
            // move to command
            instruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'M'
                                                                           dataCount:2];
            CGPoint point = pathElement->points[0];
            instruction.data[0] = point.x;
            instruction.data[1] = point.y;
            currentPoint = point;

            [instructions addObject:instruction];
            break;
        }

        case kCGPathElementAddLineToPoint: {
            // line to command
            CGPoint point = pathElement->points[0];
            if(point.x == currentPoint.x) {
                instruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'V'
                                                                               dataCount:1];
                instruction.data[0] = point.y;
            } else if(point.y == currentPoint.y) {
                instruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'H'
                                                                               dataCount:1];
                instruction.data[0] = point.x;
            } else {
                instruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'L'
                                                                               dataCount:2];
                instruction.data[0] = point.x;
                instruction.data[1] = point.y;
            }
            currentPoint = point;

            [instructions addObject:instruction];
            break;
        }

        case kCGPathElementAddQuadCurveToPoint: {
            // quad curve to command
            CGPoint controlPoint = pathElement->points[0];
            CGPoint point = pathElement->points[1];
            instruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'Q'
                                                                           dataCount:4];
            instruction.data[0] = controlPoint.x;
            instruction.data[1] = controlPoint.y;
            instruction.data[2] = point.x;
            instruction.data[3] = point.y;
            currentPoint = point;

            [instructions addObject:instruction];
            break;
        }

        case kCGPathElementAddCurveToPoint: {
            // curve to command
            CGPoint controlPoint1 = pathElement->points[0];
            CGPoint controlPoint2 = pathElement->points[1];
            CGPoint point = pathElement->points[2];

            currentPoint = point;
            instruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'C'
                                                                           dataCount:6];
            instruction.data[0] = controlPoint1.x;
            instruction.data[1] = controlPoint1.y;
            instruction.data[2] = controlPoint2.x;
            instruction.data[3] = controlPoint2.y;
            instruction.data[4] = point.x;
            instruction.data[5] = point.y;

            [instructions addObject:instruction];
            break;
        }

        case kCGPathElementCloseSubpath: {
            // close command
            instruction = [[IJSVGExporterPathInstruction alloc] initWithInstruction:'Z'
                                                                           dataCount:0];
            [instructions addObject:instruction];
            break;
        }
        }
    };

    // apply the
    CGPathApply(path, (__bridge void*)callback, IJSVGExporterPathCaller);

    // remove last instruction if it was Z -> M
    IJSVGExporterPathInstruction* lastInstruction = instructions.lastObject;
    if(lastInstruction.instruction == 'M' || lastInstruction.instruction == 'm') {
        if(instructions.count >= 2) {
            NSInteger index = [instructions indexOfObject:lastInstruction] - 1;
            IJSVGExporterPathInstruction* prevInstruction = instructions[index];
            if(prevInstruction.instruction == 'z' || prevInstruction.instruction == 'Z') {
                [instructions removeLastObject];
            }
        }
    }

    return instructions;
}

@end
