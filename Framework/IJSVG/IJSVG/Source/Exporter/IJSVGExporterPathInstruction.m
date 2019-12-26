//
//  IJSVGExporterPathInstruction.m
//  IconJar
//
//  Created by Curtis Hard on 08/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGExporter.h"
#import "IJSVGExporterPathInstruction.h"
#import "IJSVGUtils.h"

@implementation IJSVGExporterPathInstruction

- (void)dealloc
{
    if (_data != NULL) {
        free(_data);
    }
    [super dealloc];
}

- (id)initWithInstruction:(char)instruction
                dataCount:(NSInteger)floatCount
{
    if ((self = [super init]) != nil) {
        _instruction = instruction;

        // only allocate if not zero
        if (floatCount != 0) {
            _data = (CGFloat*)calloc(sizeof(CGFloat), floatCount);
        }
    }
    return self;
}

- (NSInteger)dataLength
{
    return _dataCount;
}

- (void)setInstruction:(char)newInstruction
{
    _instruction = newInstruction;
}

- (char)instruction
{
    return _instruction;
}

- (CGFloat*)data
{
    return _data;
}

+ (NSString*)pathStringWithInstruction:(const char)instruction
                   previousInstruction:(const char)previousInstruction
                          instructions:(NSArray<NSArray<NSString*>*>* _Nullable)instructions
{
    if (instructions == nil || instructions.count == 0) {
        return [NSString stringWithFormat:@"%c", instruction];
    }

    NSMutableArray<NSString*>* strings = [[[NSMutableArray alloc] init] autorelease];
    for (NSArray<NSString*>* params in instructions) {
        NSString* c1 = params[0];
        if (params.count == 2) {
            NSString* c2 = params[1];
            if ([c2 characterAtIndex:0] == '-') {
                [strings addObject:[NSString stringWithFormat:@"%@%@", c1, c2]];
            } else {
                [strings addObject:[NSString stringWithFormat:@"%@ %@", c1, c2]];
            }
        } else {
            [strings addObject:c1];
        }
    }
    NSString* pathData = [strings componentsJoinedByString:@" "];
    if (previousInstruction == instruction) {
        return [NSString stringWithFormat:@" %@", pathData];
    }
    return [NSString stringWithFormat:@"%c%@", instruction, pathData];
}

+ (NSString*)pathStringFromInstructions:(NSArray<IJSVGExporterPathInstruction*>*)instructions
{
    NSMutableArray* pathData = [[[NSMutableArray alloc] init] autorelease];
    char previousInstruction = '\0';
    for (IJSVGExporterPathInstruction* instruction in instructions) {
        CGFloat* data = instruction.data;
        const char lowerInstruction = tolower(instruction.instruction);
        switch (lowerInstruction) {

        case 'm':
        case 'l': {
            NSArray* set = @[
                @[ IJSVGShortFloatString(data[0]), IJSVGShortFloatString(data[1]) ]
            ];
            NSString* string = nil;
            string = [self pathStringWithInstruction:instruction.instruction
                                 previousInstruction:previousInstruction
                                        instructions:set];
            [pathData addObject:string];
            break;
        }

        case 'v':
        case 'h': {
            NSArray* set = @[
                @[ IJSVGShortFloatString(data[0]) ]
            ];
            NSString* string = nil;
            string = [self pathStringWithInstruction:instruction.instruction
                                 previousInstruction:previousInstruction
                                        instructions:set];
            [pathData addObject:string];
            break;
        }

        case 'c': {
            NSArray* set = @[
                @[ IJSVGShortFloatString(data[0]), IJSVGShortFloatString(data[1]) ],
                @[ IJSVGShortFloatString(data[2]), IJSVGShortFloatString(data[3]) ],
                @[ IJSVGShortFloatString(data[4]), IJSVGShortFloatString(data[5]) ]
            ];
            NSString* string = nil;
            string = [self pathStringWithInstruction:instruction.instruction
                                 previousInstruction:previousInstruction
                                        instructions:set];
            [pathData addObject:string];
            break;
        }

        case 'q': {
            NSArray* set = @[
                @[ IJSVGShortFloatString(data[0]), IJSVGShortFloatString(data[1]) ],
                @[ IJSVGShortFloatString(data[2]), IJSVGShortFloatString(data[3]) ]
            ];
            NSString* string = nil;
            string = [self pathStringWithInstruction:instruction.instruction
                                 previousInstruction:previousInstruction
                                        instructions:set];
            [pathData addObject:string];
            break;
        }

            // close path
        case 'z': {
            NSString* string = nil;
            string = [self pathStringWithInstruction:instruction.instruction
                                 previousInstruction:previousInstruction
                                        instructions:nil];
            [pathData addObject:string];
        }
        }
        previousInstruction = instruction.instruction;
    }
    return [pathData componentsJoinedByString:@""];
}

+ (void)convertInstructionsToRelativeCoordinates:(NSArray<IJSVGExporterPathInstruction*>*)instructions
{
    CGFloat point[2] = { 0, 0 };
    CGFloat subpathPoint[2] = { 0, 0 };

    NSInteger index = 0;
    for (IJSVGExporterPathInstruction* anInstruction in instructions) {
        char instruction = anInstruction.instruction;
        CGFloat* data = anInstruction.data;
        NSInteger length = anInstruction.dataLength;

        if (data != NULL) {

            // already relative
            if (instruction == 'm' || instruction == 'c' || instruction == 's' || instruction == 'l' || instruction == 'q' || instruction == 't' || instruction == 'a') {

                point[0] += data[length - 2];
                point[1] += data[length - 1];

                if (instruction == 'm') {
                    subpathPoint[0] = point[0];
                    subpathPoint[1] = point[1];
                }

            } else if (instruction == 'h') {
                point[0] += data[0];
            } else if (instruction == 'v') {
                point[1] += data[0];
            }

            // convert absolute to relative
            if (instruction == 'M') {
                if (index > 0) {
                    instruction = 'm';
                }

                data[0] -= point[0];
                data[1] -= point[1];

                subpathPoint[0] = point[0] += data[0];
                subpathPoint[1] = point[1] += data[1];

            } else if (instruction == 'L' || instruction == 'T') {

                instruction = tolower(instruction);

                data[0] -= point[0];
                data[1] -= point[1];

                point[0] += data[0];
                point[1] += data[1];

            } else if (instruction == 'C') {

                instruction = 'c';

                data[0] -= point[0];
                data[1] -= point[1];
                data[2] -= point[0];
                data[3] -= point[1];
                data[4] -= point[0];
                data[5] -= point[1];

                point[0] += data[4];
                point[1] += data[5];

            } else if (instruction == 'S' || instruction == 'Q') {

                instruction = tolower(instruction);

                data[0] -= point[0];
                data[1] -= point[1];
                data[2] -= point[0];
                data[3] -= point[1];

                point[0] += data[2];
                point[1] += data[3];

            } else if (instruction == 'A') {

                instruction = 'a';

                data[5] -= point[0];
                data[6] -= point[1];

                point[0] += data[5];
                point[1] += data[6];

            } else if (instruction == 'H') {

                instruction = 'h';

                data[0] -= point[0];

                point[0] += data[0];

            } else if (instruction == 'V') {

                instruction = 'v';

                data[0] -= point[1];

                point[1] += data[0];
            }

            // reset the instruction
            [anInstruction setInstruction:instruction];

        } else if (instruction == 'Z' || instruction == 'z') {
            point[0] = subpathPoint[0];
            point[1] = subpathPoint[1];
        }

        // increment index
        index++;
    }
}

+ (NSArray<IJSVGExporterPathInstruction*>*)instructionsFromPath:(CGPathRef)path
{

    // keep track of the current point
    __block CGPoint currentPoint = CGPointZero;
    NSMutableArray* instructions = [[[NSMutableArray alloc] init] autorelease];

    // create the path callback
    IJSVGCGPathHandler callback = ^(const CGPathElement* pathElement) {
        IJSVGExporterPathInstruction* instruction = nil;
        // work out what to do
        switch (pathElement->type) {

        case kCGPathElementMoveToPoint: {
            // move to command
            instruction = [[[IJSVGExporterPathInstruction alloc] initWithInstruction:'M'
                                                                           dataCount:2] autorelease];
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
            if (point.x == currentPoint.x) {
                instruction = [[[IJSVGExporterPathInstruction alloc] initWithInstruction:'V'
                                                                               dataCount:1] autorelease];
                instruction.data[0] = point.y;
            } else if (point.y == currentPoint.y) {
                instruction = [[[IJSVGExporterPathInstruction alloc] initWithInstruction:'H'
                                                                               dataCount:1] autorelease];
                instruction.data[0] = point.x;
            } else {
                instruction = [[[IJSVGExporterPathInstruction alloc] initWithInstruction:'L'
                                                                               dataCount:2] autorelease];
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
            instruction = [[[IJSVGExporterPathInstruction alloc] initWithInstruction:'Q'
                                                                           dataCount:4] autorelease];
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
            instruction = [[[IJSVGExporterPathInstruction alloc] initWithInstruction:'C'
                                                                           dataCount:6] autorelease];
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
            instruction = [[[IJSVGExporterPathInstruction alloc] initWithInstruction:'Z'
                                                                           dataCount:0] autorelease];
            [instructions addObject:instruction];
            break;
        }
        }
    };

    // apply the
    CGPathApply(path, (__bridge void*)callback, IJSVGExporterPathCaller);

    // remove last instruction if it was Z -> M
    IJSVGExporterPathInstruction* lastInstruction = instructions.lastObject;
    if (lastInstruction.instruction == 'M' || lastInstruction.instruction == 'm') {
        if (instructions.count >= 2) {
            NSInteger index = [instructions indexOfObject:lastInstruction] - 1;
            IJSVGExporterPathInstruction* prevInstruction = instructions[index];
            if (prevInstruction.instruction == 'z' || prevInstruction.instruction == 'Z') {
                [instructions removeLastObject];
            }
        }
    }

    return instructions;
}

@end
