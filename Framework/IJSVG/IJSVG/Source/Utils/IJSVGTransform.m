//
//  IJSVGTransform.m
//  IconJar
//
//  Created by Curtis Hard on 01/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGMath.h"
#import "IJSVGTransform.h"

@implementation IJSVGTransform

@synthesize command;
@synthesize parameters;
@synthesize parameterCount;
@synthesize sort;

- (void)dealloc
{
    free(parameters);
    [super dealloc];
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGTransform* trans = [[self.class alloc] init];
    trans.command = self.command;
    trans.parameters = (CGFloat*)malloc(sizeof(CGFloat) * self.parameterCount);
    trans.sort = sort;
    trans.parameterCount = self.parameterCount;
    memcpy(trans.parameters, self.parameters, sizeof(CGFloat) * self.parameterCount);
    return trans;
}

CGAffineTransform IJSVGConcatTransforms(NSArray<IJSVGTransform*>* transforms)
{
    __block CGAffineTransform trans = CGAffineTransformIdentity;
    IJSVGApplyTransform(transforms, ^(IJSVGTransform* transform) {
        trans = CGAffineTransformConcat(trans, transform.CGAffineTransform);
    });
    return trans;
}

NSString* IJSVGTransformAttributeString(CGAffineTransform transform)
{
    return [IJSVGTransform affineTransformToSVGMatrixString:transform];
}

void IJSVGApplyTransform(NSArray<IJSVGTransform*>* transforms, IJSVGTransformApplyBlock block)
{
    for (IJSVGTransform* transform in transforms) {
        block(transform);
    }
};

+ (IJSVGTransform*)transformByTranslatingX:(CGFloat)x
                                         y:(CGFloat)y
{
    IJSVGTransform* transform = [[[self alloc] init] autorelease];
    transform.command = IJSVGTransformCommandTranslate;
    transform.parameterCount = 2;
    CGFloat* params = (CGFloat*)malloc(sizeof(CGFloat) * 2);
    params[0] = x;
    params[1] = y;
    transform.parameters = params;
    return transform;
}

+ (IJSVGTransform*)transformByScaleX:(CGFloat)x
                                   y:(CGFloat)y
{
    IJSVGTransform* transform = [[[self alloc] init] autorelease];
    transform.command = IJSVGTransformCommandScale;
    transform.parameterCount = 2;
    CGFloat* params = (CGFloat*)malloc(sizeof(CGFloat) * 2);
    params[0] = x;
    params[1] = y;
    transform.parameters = params;
    return transform;
}

- (void)recalculateWithBounds:(CGRect)bounds
{
    CGFloat max = bounds.size.width > bounds.size.height ? bounds.size.width : bounds.size.height;
    switch (self.command) {
    case IJSVGTransformCommandRotate: {
        if (self.parameterCount == 1) {
            return;
        }
        self.parameters[1] = self.parameters[1] * max;
        self.parameters[2] = self.parameters[2] * max;
    }
    default:
        return;
    }
}

+ (IJSVGTransformCommand)commandForCommandString:(NSString*)str
{
    str = str.lowercaseString;
    if ([str isEqualToString:@"matrix"])
        return IJSVGTransformCommandMatrix;
    if ([str isEqualToString:@"translate"])
        return IJSVGTransformCommandTranslate;
    if ([str isEqualToString:@"translatex"])
        return IJSVGTransformCommandTranslateX;
    if ([str isEqualToString:@"translatey"])
        return IJSVGTransformCommandTranslateY;
    if ([str isEqualToString:@"scale"])
        return IJSVGTransformCommandScale;
    if ([str isEqualToString:@"skewx"])
        return IJSVGTransformCommandSkewX;
    if ([str isEqualToString:@"skewy"])
        return IJSVGTransformCommandSkewY;
    if ([str isEqualToString:@"rotate"])
        return IJSVGTransformCommandRotate;
    return IJSVGTransformCommandNotImplemented;
}

+ (NSInteger)sortForTransformCommand:(IJSVGTransformCommand)command
{
    switch (command) {
    case IJSVGTransformCommandScale:
        return 0;
    case IJSVGTransformCommandRotate:
        return 1;
    case IJSVGTransformCommandMatrix:
        return 2;
    case IJSVGTransformCommandTranslateX:
    case IJSVGTransformCommandTranslateY:
    case IJSVGTransformCommandTranslate:
        return -1;
    default:
        return 10;
    }
    return 10;
}

+ (NSArray<IJSVGTransform*>*)transformsForString:(NSString*)string
{
    static NSRegularExpression* _reg = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _reg = [[NSRegularExpression alloc] initWithPattern:@"([a-zA-Z]+)(?:[\\s]+)?\\(([^\\)]+)\\)"
                                                    options:0
                                                      error:nil];
    });
    NSMutableArray* transforms = [[[NSMutableArray alloc] init] autorelease];
    @autoreleasepool {
        [_reg enumerateMatchesInString:string
                               options:0
                                 range:NSMakeRange(0, string.length)
                            usingBlock:^(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop) {
                                NSString* command = [string substringWithRange:[result rangeAtIndex:1]];
                                IJSVGTransformCommand commandType = [self.class commandForCommandString:command];
                                if (commandType == IJSVGTransformCommandNotImplemented) {
                                    return;
                                }

                                // create the transform
                                NSString* params = [string substringWithRange:[result rangeAtIndex:2]];
                                IJSVGTransform* transform = [[[self.class alloc] init] autorelease];
                                NSInteger count = 0;
                                transform.command = commandType;
                                transform.parameters = [IJSVGUtils commandParameters:params
                                                                               count:&count];
                                transform.parameterCount = count;
                                transform.sort = [self.class sortForTransformCommand:commandType];
                                [transforms addObject:transform];
                            }];
    }
    return transforms;
}

+ (NSBezierPath*)transformedPath:(IJSVGPath*)path
{
    if (path.transforms.count == 0) {
        return path.path;
    }
    NSBezierPath* cop = [[path.path copy] autorelease];
    for (IJSVGTransform* transform in path.transforms) {
        NSAffineTransform* at = NSAffineTransform.transform;
        switch (transform.command) {
        // matrix
        case IJSVGTransformCommandMatrix: {
            at.transformStruct = (NSAffineTransformStruct) {
                .m11 = transform.parameters[0],
                .m12 = transform.parameters[1],
                .m21 = transform.parameters[2],
                .m22 = transform.parameters[3],
                .tX = transform.parameters[4],
                .tY = transform.parameters[5],
            };
            break;
        }

        // skewX
        case IJSVGTransformCommandSkewX: {
            CGFloat degrees = transform.parameters[0];
            CGFloat radians = degrees * M_PI / 180.f;
            at.transformStruct = (NSAffineTransformStruct) {
                .m11 = 1.f,
                .m12 = 0.f,
                .m21 = tan(radians),
                .m22 = 1.f,
                .tX = 0.f,
                .tY = 0.f
            };
            break;
        }

        // skewX
        case IJSVGTransformCommandSkewY: {
            CGFloat degrees = transform.parameters[0];
            CGFloat radians = degrees * M_PI / 180.f;
            at.transformStruct = (NSAffineTransformStruct) {
                .m11 = 1.f,
                .m12 = tan(radians),
                .m21 = 0.f,
                .m22 = 1.f,
                .tX = 0.f,
                .tY = 0.f
            };
            break;
        }

        // translate
        case IJSVGTransformCommandTranslate: {
            if (transform.parameterCount == 1)
                [at translateXBy:transform.parameters[0]
                             yBy:0];
            else
                [at translateXBy:transform.parameters[0]
                             yBy:transform.parameters[1]];
            break;
        }

        // translateX
        case IJSVGTransformCommandTranslateX: {
            [at translateXBy:transform.parameters[0] yBy:0.f];
            break;
        }

        // translateY
        case IJSVGTransformCommandTranslateY: {
            [at translateXBy:0.f yBy:transform.parameters[0]];
            break;
        }

        // scale
        case IJSVGTransformCommandScale: {
            if (transform.parameterCount == 1)
                [at scaleBy:transform.parameters[0]];
            else
                [at scaleXBy:transform.parameters[0]
                         yBy:transform.parameters[1]];
            break;
        }

        // rotate
        case IJSVGTransformCommandRotate: {
            if (transform.parameterCount == 1)
                [at rotateByDegrees:transform.parameters[0]];
            else {
                CGFloat centerX = transform.parameters[1];
                CGFloat centerY = transform.parameters[2];
                CGFloat angle = transform.parameters[0] * (M_PI / 180.f);
                [at translateXBy:centerX
                             yBy:centerY];
                [at rotateByRadians:angle];
                [at translateXBy:-1.f * centerX
                             yBy:-1.f * centerY];
            }
            break;
        }

        // do nothing
        case IJSVGTransformCommandNotImplemented: {
        }
        }
        [cop transformUsingAffineTransform:at];
    }
    return cop;
}

- (CGAffineTransform)CGAffineTransform
{
    return [self CGAffineTransformWithModifier:nil];
}

- (CGAffineTransform)stackIdentity:(CGAffineTransform)identity
{
    switch (self.command) {

    // translate
    case IJSVGTransformCommandTranslate: {
        if (self.parameterCount == 1) {
            return CGAffineTransformTranslate(identity, self.parameters[0], 0.f);
        }
        return CGAffineTransformTranslate(identity, self.parameters[0], self.parameters[1]);
    }

    // translateX
    case IJSVGTransformCommandTranslateX: {
        return CGAffineTransformTranslate(identity, self.parameters[0], 0.f);
    }

    // translateY
    case IJSVGTransformCommandTranslateY: {
        return CGAffineTransformTranslate(identity, 0.f, self.parameters[0]);
    }

    // rotate
    case IJSVGTransformCommandRotate: {
        if (self.parameterCount == 1) {
            return CGAffineTransformRotate(identity, (self.parameters[0] / 180) * M_PI);
        }
        CGFloat p0 = self.parameters[0];
        CGFloat p1 = self.parameters[1];
        CGFloat p2 = self.parameters[2];
        CGFloat angle = p0 * (M_PI / 180.f);

        identity = CGAffineTransformTranslate(identity, p1, p2);
        identity = CGAffineTransformRotate(identity, angle);
        return CGAffineTransformTranslate(identity, -1.f * p1, -1.f * p2);
    }

    // scale
    case IJSVGTransformCommandScale: {
        CGFloat p0 = self.parameters[0];
        if (self.parameterCount == 1) {
            return CGAffineTransformScale(identity, p0, p0);
        }
        CGFloat p1 = self.parameters[1];
        return CGAffineTransformScale(identity, p0, p1);
    }

    // matrix
    case IJSVGTransformCommandMatrix: {
        CGFloat p0 = self.parameters[0];
        CGFloat p1 = self.parameters[1];
        CGFloat p2 = self.parameters[2];
        CGFloat p3 = self.parameters[3];
        CGFloat p4 = self.parameters[4];
        CGFloat p5 = self.parameters[5];
        return CGAffineTransformMake(p0, p1, p2, p3, p4, p5);
    }

    // skewX
    case IJSVGTransformCommandSkewX: {
        CGFloat degrees = self.parameters[0];
        CGFloat radians = degrees * M_PI / 180.f;
        return CGAffineTransformMake(1.f, 0.f, tan(radians), 1.f, 0.f, 0.f);
    }

    // skewY
    case IJSVGTransformCommandSkewY: {
        CGFloat degrees = self.parameters[0];
        CGFloat radians = degrees * M_PI / 180.f;
        return CGAffineTransformMake(1.f, tan(radians), 0.f, 1.f, 0.f, 0.f);
    }

    case IJSVGTransformCommandNotImplemented: {
        return CGAffineTransformIdentity;
    }
    }
    return CGAffineTransformIdentity;
}

- (CGAffineTransform)CGAffineTransformWithModifier:(IJSVGTransformParameterModifier)modifier
{
    switch (self.command) {
    // matrix
    case IJSVGTransformCommandMatrix: {
        CGFloat p0 = self.parameters[0];
        CGFloat p1 = self.parameters[1];
        CGFloat p2 = self.parameters[2];
        CGFloat p3 = self.parameters[3];
        CGFloat p4 = self.parameters[4];
        CGFloat p5 = self.parameters[5];
        if (modifier != nil) {
            p0 = modifier(0, p0);
            p1 = modifier(1, p1);
            p2 = modifier(2, p2);
            p3 = modifier(3, p3);
            p4 = modifier(4, p4);
            p5 = modifier(5, p5);
        }
        return CGAffineTransformMake(p0, p1, p2, p3, p4, p5);
    }

    // translate
    case IJSVGTransformCommandTranslate: {
        CGFloat p0 = self.parameters[0];
        if (self.parameterCount == 1) {
            return CGAffineTransformMakeTranslation(p0, 0);
        }
        CGFloat p1 = self.parameters[1];
        if (modifier != nil) {
            p0 = modifier(0, p0);
            p1 = modifier(1, p1);
        }
        return CGAffineTransformMakeTranslation(p0, p1);
    }

    // translateX
    case IJSVGTransformCommandTranslateX: {
        CGFloat p0 = self.parameters[0];
        if (modifier != nil) {
            p0 = modifier(0, p0);
        }
        return CGAffineTransformMakeTranslation(p0, 0.f);
    }

    // translateY
    case IJSVGTransformCommandTranslateY: {
        CGFloat p0 = self.parameters[0];
        if (modifier != nil) {
            p0 = modifier(0, p0);
        }
        return CGAffineTransformMakeTranslation(0.f, p0);
    }

    // scale
    case IJSVGTransformCommandScale: {
        CGFloat p0 = self.parameters[0];
        if (self.parameterCount == 1) {
            return CGAffineTransformMakeScale(p0, p0);
        }
        CGFloat p1 = self.parameters[1];
        if (modifier != nil) {
            p0 = modifier(0, p0);
            p1 = modifier(1, p1);
        }
        return CGAffineTransformMakeScale(p0, p1);
    }

    // skewX
    case IJSVGTransformCommandSkewX: {
        CGFloat degrees = self.parameters[0];
        if (modifier != nil) {
            degrees = modifier(0, degrees);
        }
        CGFloat radians = degrees * M_PI / 180.f;
        return CGAffineTransformMake(1.f, 0.f, tan(radians), 1.f, 0.f, 0.f);
    }

    // skewY
    case IJSVGTransformCommandSkewY: {
        CGFloat degrees = self.parameters[0];
        if (modifier != nil) {
            degrees = modifier(0, degrees);
        }
        CGFloat radians = degrees * M_PI / 180.f;
        return CGAffineTransformMake(1.f, tan(radians), 0.f, 1.f, 0.f, 0.f);
    }

    // rotate
    case IJSVGTransformCommandRotate: {
        if (self.parameterCount == 1) {
            return CGAffineTransformMakeRotation((self.parameters[0] / 180) * M_PI);
        } else {
            CGFloat p0 = self.parameters[0];
            CGFloat p1 = self.parameters[1];
            CGFloat p2 = self.parameters[2];
            if (modifier != nil) {
                p0 = modifier(0, p0);
                p1 = modifier(1, p1);
                p2 = modifier(2, p2);
            }
            CGFloat angle = p0 * (M_PI / 180.f);
            CGAffineTransform def = CGAffineTransformIdentity;
            def = CGAffineTransformTranslate(def, p1, p2);
            def = CGAffineTransformRotate(def, angle);
            def = CGAffineTransformTranslate(def, -1.f * p1, -1.f * p2);
            return def;
        }
        break;
    }

    // do nothing
    case IJSVGTransformCommandNotImplemented: {
        return CGAffineTransformIdentity;
    }
    }
    return CGAffineTransformIdentity;
}

+ (NSArray<IJSVGTransform*>*)transformsFromAffineTransform:(CGAffineTransform)affineTransform
{
    NSString* matrix = [self affineTransformToSVGMatrixString:affineTransform];
    return [self transformsForString:matrix];
}

+ (NSString*)affineTransformToSVGTransformComponentString:(CGAffineTransform)transform
                                     floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    NSArray<NSDictionary*>* trans = [self affineTransformToSVGTransformComponents:transform];
    trans = [self filterUselessAffineTransformComponents:trans];
    NSMutableArray<NSString*>* strings = [[[NSMutableArray alloc] initWithCapacity:trans.count] autorelease];
    for (NSDictionary* dict in trans) {
        NSArray<NSNumber*>* data = dict[@"data"];
        NSString* method = dict[@"name"];
        NSMutableArray* dataStrings = [[[NSMutableArray alloc] initWithCapacity:data.count] autorelease];
        for (NSNumber* number in data) {
            [dataStrings addObject:IJSVGShortFloatStringWithOptions(number.floatValue,
                                                                    floatingPointOptions)];
        }
        [strings addObject:[NSString stringWithFormat:@"%@(%@)", method,
                                     IJSVGCompressFloatParameterArray(dataStrings)]];
    }
    NSString* componentsString = [strings componentsJoinedByString:@" "];
    NSString* matrixString = [self affineTransformToSVGMatrixString:transform
                                               floatingPointOptions:floatingPointOptions];
    return componentsString.length < matrixString.length ? componentsString : matrixString;
}

+ (NSString*)affineTransformToSVGTransformComponentString:(CGAffineTransform)transform
{
    NSArray<NSDictionary*>* trans = [self affineTransformToSVGTransformComponents:transform];
    trans = [self filterUselessAffineTransformComponents:trans];
    NSMutableArray<NSString*>* strings = [[[NSMutableArray alloc] initWithCapacity:trans.count] autorelease];
    for (NSDictionary* dict in trans) {
        NSArray<NSNumber*>* data = dict[@"data"];
        NSString* method = dict[@"name"];
        NSMutableArray* dataStrings = [[[NSMutableArray alloc] initWithCapacity:data.count] autorelease];
        for (NSNumber* number in data) {
            [dataStrings addObject:IJSVGShortFloatString(number.floatValue)];
        }
        [strings addObject:[NSString stringWithFormat:@"%@(%@)", method,
                                     IJSVGCompressFloatParameterArray(dataStrings)]];
    }
    NSString* componentsString = [strings componentsJoinedByString:@" "];
    NSString* matrixString = [self affineTransformToSVGMatrixString:transform];
    return componentsString.length < matrixString.length ? componentsString : matrixString;
}

+ (NSString*)affineTransformToSVGMatrixString:(CGAffineTransform)transform
                         floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    NSArray<NSString*>* numbers = @[
        IJSVGShortFloatStringWithOptions(transform.a, floatingPointOptions),
        IJSVGShortFloatStringWithOptions(transform.b, floatingPointOptions),
        IJSVGShortFloatStringWithOptions(transform.c, floatingPointOptions),
        IJSVGShortFloatStringWithOptions(transform.d, floatingPointOptions),
        IJSVGShortFloatStringWithOptions(transform.tx, floatingPointOptions),
        IJSVGShortFloatStringWithOptions(transform.ty, floatingPointOptions)
    ];
    return [NSString stringWithFormat:@"matrix(%@)", IJSVGCompressFloatParameterArray(numbers)];
}

+ (NSString*)affineTransformToSVGMatrixString:(CGAffineTransform)transform
{
    NSArray<NSString*>* numbers = @[
        IJSVGShortFloatString(transform.a),
        IJSVGShortFloatString(transform.b),
        IJSVGShortFloatString(transform.c),
        IJSVGShortFloatString(transform.d),
        IJSVGShortFloatString(transform.tx),
        IJSVGShortFloatString(transform.ty)
    ];
    return [NSString stringWithFormat:@"matrix(%@)",
                     IJSVGCompressFloatParameterArray(numbers)];
}

+ (NSArray<NSDictionary*>*)filterUselessAffineTransformComponents:(NSArray<NSDictionary*>*)components
{
    NSMutableArray* comps = [[[NSMutableArray alloc] initWithCapacity:components.count] autorelease];
    NSArray<NSString*>* names = @[ @"translate", @"rotate", @"skewX", @"skewY" ];
    for (NSDictionary* transform in components) {
        NSString* name = transform[@"name"];
        NSArray<NSNumber*>* data = transform[@"data"];
        if ([names containsObject:name] && (data.count == 1 || [name isEqualToString:@"rotate"]) && data[0].floatValue == 0.f) {
            continue;
        } else if ([name isEqualToString:@"translate"] && data[0].floatValue == 0.f && data[1].floatValue == 0.f) {
            continue;
        } else if ([name isEqualToString:@"scale"] && data[0].floatValue == 1.f && (data.count < 2 || (data.count == 2 && data[1].floatValue == 1.f))) {
            continue;
        } else if ([name isEqualToString:@"matrix"] && data[0].floatValue == 1.f && data[3].floatValue == 1.f && !(data[1].floatValue != 0.f || data[2].floatValue != 0.f || data[4].floatValue != 0.f || data[5].floatValue != 0.f)) {
            continue;
        }
        [comps addObject:transform];
    }
    return comps;
}

+ (NSArray<NSDictionary*>*)affineTransformToSVGTransformComponents:(CGAffineTransform)transform
{
    const NSUInteger precision = 5;
    CGFloat data[6] = {
        IJSVGMathToFixed(transform.a, precision),
        IJSVGMathToFixed(transform.b, precision),
        IJSVGMathToFixed(transform.c, precision),
        IJSVGMathToFixed(transform.d, precision),
        IJSVGMathToFixed(transform.tx, precision),
        IJSVGMathToFixed(transform.ty, precision)
    };

    CGFloat sx = IJSVGMathToFixed(hypotf(data[0], data[1]), precision);
    CGFloat sy = IJSVGMathToFixed(((data[0] * data[3] - data[1] * data[2]) / sx), precision);
    CGFloat colSum = data[0] * data[2] + data[1] * data[3];
    CGFloat rowSum = data[0] * data[1] + data[2] * data[3];
    BOOL scaleBefore = rowSum != 0.f || sx == sy;

    NSMutableArray* transforms = [[[NSMutableArray alloc] init] autorelease];

    // tx, ty -> translate
    if (data[4] != 0.f || data[5] != 0.f) {
        [transforms addObject:@{
            @"name" : @"translate",
            @"data" : @[ @(data[4]), @(data[5]) ]
        }];
    }

    // [sx, 0, tan(a).sy, sy, 0, 0] -> skewX(a).scale(sx,sy)
    if (data[1] == 0.f && data[2] != 0.f) {
        [transforms addObject:@{
            @"name" : @"skewX",
            @"data" : @[ @(IJSVGMathToFixed(IJSVGMathAtan(data[2] / sy), precision)) ]
        }];

        // [sx, sy.tan(a), 0, sy, 0, 0] -> skewX(a).scale(sx, sy)
    } else if (data[1] != 0.f && data[2] == 0.f) {
        [transforms addObject:@{
            @"name" : @"skewY",
            @"data" : @[ @(IJSVGMathToFixed(IJSVGMathAtan(data[1] / data[0]), precision)) ]
        }];
        sx = data[0];
        sy = data[3];
    } else if (colSum == 0.f || (sx == 1.f && sy == 1.f) || !scaleBefore) {
        if (!scaleBefore) {
            sx = (data[0] < 0.f ? -1.f : 1.f) * hypotf(data[0], data[2]);
            sy = (data[3] < 0.f ? -1.f : 1.f) * hypotf(data[1], data[3]);
            if (sx != 1.f || sy != 1.f) {
                [transforms addObject:@{
                    @"name" : @"scale",
                    @"data" : (sx == sy) ? @[ @(sx) ] : @[ @(sx), @(sy) ]
                }];
            }
        }

        CGFloat angle = MIN(MAX(-1.f, data[0] / sx), 1.f);
        NSMutableArray<NSNumber*>* rotate = [[[NSMutableArray alloc] initWithCapacity:3] autorelease];
        [rotate addObject:@(IJSVGMathToFixed(IJSVGMathAcos(angle), precision) * ((scaleBefore ? 1.f : sy) * data[1] < 0.f ? -1.f : 1.f))];

        if (rotate[0].floatValue != 0.f) {
            [transforms addObject:@{
                @"name" : @"rotate",
                @"data" : rotate
            }];
        }

        if (rowSum != 0.f && colSum != 0.f) {
            [transforms addObject:@{
                @"name" : @"skewX",
                @"data" : @[ @(IJSVGMathToFixed(IJSVGMathAtan(colSum / (sx * sx)), precision)) ]
            }];
        }

        // rotate can consume translate
        if (rotate[0].floatValue != 0.f && (data[4] != 0.f || data[5] != 0.f)) {
            [transforms removeObjectAtIndex:0];
            CGFloat cos = data[0] / sx;
            CGFloat sin = data[1] / (scaleBefore ? sx : sy);
            CGFloat x = data[4] * (scaleBefore ? 1.f : sy);
            CGFloat y = data[5] * (scaleBefore ? 1.f : sx);
            CGFloat denom = (powf(1.f - cos, 2.f) + powf(sin, 2.f)) * (scaleBefore ? 1.f : (sx * sy));
            [rotate addObject:@(((1.f - cos) * x - sin * y) / denom)];
            [rotate addObject:@(((1.f - cos) * y + sin * x) / denom)];
        }
    } else if (data[1] != 0.f || data[2] != 0.f) {
        NSDictionary* trans = @{
            @"name" : @"matrix",
            @"data" : @[ @(data[0]), @(data[1]), @(data[2]), @(data[3]), @(data[4]), @(data[5]) ]
        };
        return @[ trans ];
    }

    if (scaleBefore == YES && ((sx != 1.f || sy != 1.f) || transforms.count == 0)) {
        NSDictionary* trans = @{
            @"name" : @"scale",
            @"data" : (sx == sy) ? @[ @(sx) ] : @[ @(sx), @(sy) ]
        };
        [transforms addObject:trans];
    }

    return transforms;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ %@", [super description],
                     [self.class affineTransformToSVGMatrixString:self.CGAffineTransform]];
}

@end
