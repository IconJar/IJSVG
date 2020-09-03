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

+ (NSArray*)transformsForString:(NSString*)string
{
    static NSRegularExpression* _reg = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _reg = [[NSRegularExpression alloc] initWithPattern:@"([a-zA-Z]+)\\(([^\\)]+)\\)"
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

+ (NSString*)affineTransformToSVGMatrixString:(CGAffineTransform)transform
                         floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    return [NSString stringWithFormat:@"matrix(%@ %@ %@ %@ %@ %@)",
                     IJSVGShortFloatStringWithOptions(transform.a, floatingPointOptions),
                     IJSVGShortFloatStringWithOptions(transform.b, floatingPointOptions),
                     IJSVGShortFloatStringWithOptions(transform.c, floatingPointOptions),
                     IJSVGShortFloatStringWithOptions(transform.d, floatingPointOptions),
                     IJSVGShortFloatStringWithOptions(transform.tx, floatingPointOptions),
                     IJSVGShortFloatStringWithOptions(transform.ty, floatingPointOptions)];
}

+ (NSString*)affineTransformToSVGMatrixString:(CGAffineTransform)transform
{
    return [NSString stringWithFormat:@"matrix(%@ %@ %@ %@ %@ %@)",
                     IJSVGShortFloatString(transform.a),
                     IJSVGShortFloatString(transform.b),
                     IJSVGShortFloatString(transform.c),
                     IJSVGShortFloatString(transform.d),
                     IJSVGShortFloatString(transform.tx),
                     IJSVGShortFloatString(transform.ty)];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ %@", [super description],
                     [self.class affineTransformToSVGMatrixString:self.CGAffineTransform]];
}

@end
