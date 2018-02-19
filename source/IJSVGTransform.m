//
//  IJSVGTransform.m
//  IconJar
//
//  Created by Curtis Hard on 01/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGTransform.h"
#import "IJSVGMath.h"

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

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGTransform * trans = [[[self class] alloc] init];
    trans.command = self.command;
    trans.parameters = (CGFloat*)malloc(sizeof(CGFloat)*self.parameterCount);
    trans.sort = sort;
    trans.parameterCount = self.parameterCount;
    memcpy( trans.parameters, self.parameters, sizeof(CGFloat)*self.parameterCount);
    return trans;
}

NSString * IJSVGDebugAffineTransform(CGAffineTransform transform)
{
    NSMutableArray * strings = [[[NSMutableArray alloc] init] autorelease];
    [strings addObjectsFromArray:[IJSVGTransform affineTransformToSVGTransformAttributeString:transform]];
    return [strings componentsJoinedByString:@" "];
}

NSString * IJSVGDebugTransforms(NSArray<IJSVGTransform *> * transforms)
{
    NSMutableArray * strings = [[[NSMutableArray alloc] init] autorelease];
    IJSVGApplyTransform(transforms, ^(IJSVGTransform *transform) {
        [strings addObjectsFromArray:[IJSVGTransform affineTransformToSVGTransformAttributeString:transform.CGAffineTransform]];
    });
    return [strings componentsJoinedByString:@" "];
}

CGAffineTransform IJSVGConcatTransforms(NSArray<IJSVGTransform *> * transforms)
{
    __block CGAffineTransform trans = CGAffineTransformIdentity;
    IJSVGApplyTransform(transforms, ^(IJSVGTransform *transform) {
        trans = CGAffineTransformConcat(trans, transform.CGAffineTransform);
    });
    return trans;
}

void IJSVGApplyTransform(NSArray<IJSVGTransform *> * transforms,  IJSVGTransformApplyBlock block)
{
    for(IJSVGTransform * transform in transforms) {
        block(transform);
    }
};

+ (IJSVGTransform *)transformByTranslatingX:(CGFloat)x
                                          y:(CGFloat)y
{
    IJSVGTransform * transform = [[[self alloc] init] autorelease];
    transform.command = IJSVGTransformCommandTranslate;
    transform.parameterCount = 2;
    CGFloat * params = (CGFloat *)malloc(sizeof(CGFloat)*2);
    params[0] = x;
    params[1] = y;
    transform.parameters = params;
    return transform;
}

- (void)recalculateWithBounds:(CGRect)bounds
{
    CGFloat max = bounds.size.width>bounds.size.height?bounds.size.width:bounds.size.height;
    switch (self.command) {
        case IJSVGTransformCommandRotate: {
            if( self.parameterCount == 1 )
                return;
            self.parameters[1] = self.parameters[1]*max;
            self.parameters[2] = self.parameters[2]*max;
        }
        default:
            return;
    }
}

+ (IJSVGTransformCommand)commandForCommandString:(NSString *)str
{
    str = str.lowercaseString;
    if( [str isEqualToString:@"matrix"] )
        return IJSVGTransformCommandMatrix;
    if( [str isEqualToString:@"translate"] )
        return IJSVGTransformCommandTranslate;
    if( [str isEqualToString:@"scale"] )
        return IJSVGTransformCommandScale;
    if( [str isEqualToString:@"skewx"])
        return IJSVGTransformCommandSkewX;
    if( [str isEqualToString:@"skewy"])
        return IJSVGTransformCommandSkewY;
    if( [str isEqualToString:@"rotate"] )
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
        case IJSVGTransformCommandTranslate:
            return -1;
        default:
            return 10;
    }
    return 10;
}

+ (NSArray *)transformsForString:(NSString *)string
{
    static NSRegularExpression * _reg = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _reg = [[NSRegularExpression alloc] initWithPattern:@"([a-zA-Z]+)\\((.*?)\\)"
                                                    options:0
                                                      error:nil];
    });
    NSMutableArray * transforms = [[[NSMutableArray alloc] init] autorelease];
    @autoreleasepool {
        [_reg enumerateMatchesInString:string
                               options:0
                                 range:NSMakeRange( 0, string.length )
                            usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
        {
            NSString * command = [string substringWithRange:[result rangeAtIndex:1]];
            IJSVGTransformCommand commandType = [[self class] commandForCommandString:command];
            if( commandType == IJSVGTransformCommandNotImplemented ) {
                return;
            }
            
            // create the transform
            NSString * params = [string substringWithRange:[result rangeAtIndex:2]];
            IJSVGTransform * transform = [[[[self class] alloc] init] autorelease];
            NSInteger count = 0;
            transform.command = commandType;
            transform.parameters = [IJSVGUtils commandParameters:params
                                                           count:&count];
            transform.parameterCount = count;
            transform.sort = [[self class] sortForTransformCommand:commandType];
            [transforms addObject:transform];
        }];
    }
    return transforms;
}

+ (NSBezierPath *)transformedPath:(IJSVGPath *)path
{
    if( path.transforms.count == 0 )
        return path.path;
    NSBezierPath * cop = [[path.path copy] autorelease];
    for( IJSVGTransform * transform in path.transforms )
    {
        NSAffineTransform * at = [NSAffineTransform transform];
        switch( transform.command )
        {
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
                if( transform.parameterCount == 1 )
                    [at translateXBy:transform.parameters[0]
                                 yBy:0];
                else
                    [at translateXBy:transform.parameters[0]
                                 yBy:transform.parameters[1]];
                break;
            }
            
            // scale
            case IJSVGTransformCommandScale: {
                if( transform.parameterCount == 1 )
                    [at scaleBy:transform.parameters[0]];
                else
                    [at scaleXBy:transform.parameters[0]
                             yBy:transform.parameters[1]];
                break;
            }
                
            // rotate
            case IJSVGTransformCommandRotate: {
                if( transform.parameterCount == 1 )
                    [at rotateByDegrees:transform.parameters[0]];
                else {
                    CGFloat centerX = transform.parameters[1];
                    CGFloat centerY = transform.parameters[2];
                    CGFloat angle = transform.parameters[0]*(M_PI/180.f);
                    [at translateXBy:centerX
                                 yBy:centerY];
                    [at rotateByRadians:angle];
                    [at translateXBy:-1.f*centerX
                                 yBy:-1.f*centerY];
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
    switch(self.command) {
        
        // translate
        case IJSVGTransformCommandTranslate: {
            if(self.parameterCount == 1) {
                return CGAffineTransformTranslate(identity, self.parameters[0], 0.f);
            }
            return CGAffineTransformTranslate(identity, self.parameters[0], self.parameters[1]);
        }
        
        // rotate
        case IJSVGTransformCommandRotate: {
            if(self.parameterCount == 1) {
                return CGAffineTransformRotate(identity, (self.parameters[0]/180) * M_PI);
            }
            CGFloat p0 = self.parameters[0];
            CGFloat p1 = self.parameters[1];
            CGFloat p2 = self.parameters[2];
            CGFloat angle = p0*(M_PI/180.f);
            
            identity = CGAffineTransformTranslate(identity, p1, p2);
            identity = CGAffineTransformRotate(identity, angle);
            return CGAffineTransformTranslate(identity, -1.f*p1, -1.f*p2);
        }
            
        // scale
        case IJSVGTransformCommandScale: {
            CGFloat p0 = self.parameters[0];
            CGFloat p1 = self.parameters[1];
            if(self.parameterCount == 1) {
                return CGAffineTransformScale(identity, p0, p0);
            }
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
            return CGAffineTransformMake( 1.f, 0.f, tan(radians), 1.f, 0.f, 0.f);
        }
        
        // skewY
        case IJSVGTransformCommandSkewY: {
            CGFloat degrees = self.parameters[0];
            CGFloat radians = degrees * M_PI / 180.f;
            return CGAffineTransformMake( 1.f, tan(radians), 0.f, 1.f, 0.f, 0.f);
        }
            
        case IJSVGTransformCommandNotImplemented: {
            return CGAffineTransformIdentity;
        }

    }
    return CGAffineTransformIdentity;
}

- (CGAffineTransform)CGAffineTransformWithModifier:(IJSVGTransformParameterModifier)modifier
{
    switch(self.command)
    {
        // matrix
        case IJSVGTransformCommandMatrix: {
            CGFloat p0 = self.parameters[0];
            CGFloat p1 = self.parameters[1];
            CGFloat p2 = self.parameters[2];
            CGFloat p3 = self.parameters[3];
            CGFloat p4 = self.parameters[4];
            CGFloat p5 = self.parameters[5];
            if(modifier != nil)
            {
                p0 = modifier(0,p0);
                p1 = modifier(1,p1);
                p2 = modifier(2,p2);
                p3 = modifier(2,p3);
                p4 = modifier(2,p4);
                p5 = modifier(2,p5);
            }
            return CGAffineTransformMake(p0, p1, p2, p3, p4, p5);
        }
            
        // translate
        case IJSVGTransformCommandTranslate: {
            CGFloat p0 = self.parameters[0];
            CGFloat p1 = self.parameters[1];
            if(modifier != nil)
            {
                p0 = modifier(0,p0);
                p1 = modifier(1,p1);
            }
            if(self.parameterCount == 1)
                return CGAffineTransformMakeTranslation( p0, 0 );
            return CGAffineTransformMakeTranslation(p0, p1);
        }
            
        // scale
        case IJSVGTransformCommandScale: {
            CGFloat p0 = self.parameters[0];
            CGFloat p1 = self.parameters[1];
            if(modifier != nil)
            {
                p0 = modifier(0,p0);
                p1 = modifier(1,p1);
            }
            if(self.parameterCount == 1)
                return CGAffineTransformMakeScale( p0, p0);
            return CGAffineTransformMakeScale( p0, p1);
        }
            
        // skewX
        case IJSVGTransformCommandSkewX: {
            CGFloat degrees = self.parameters[0];
            if(modifier != nil) {
                degrees = modifier(0,degrees);
            }
            CGFloat radians = degrees * M_PI / 180.f;
            return CGAffineTransformMake( 1.f, 0.f, tan(radians), 1.f, 0.f, 0.f);
        }
            
        // skewY
        case IJSVGTransformCommandSkewY: {
            CGFloat degrees = self.parameters[0];
            if(modifier != nil) {
                degrees = modifier(0,degrees);
            }
            CGFloat radians = degrees * M_PI / 180.f;
            return CGAffineTransformMake( 1.f, tan(radians), 0.f, 1.f, 0.f, 0.f);
        }
        
        // rotate
        case IJSVGTransformCommandRotate: {
            if(self.parameterCount == 1)
                return CGAffineTransformMakeRotation((self.parameters[0]/180) * M_PI);
            else {
                CGFloat p0 = self.parameters[0];
                CGFloat p1 = self.parameters[1];
                CGFloat p2 = self.parameters[2];
                if(modifier != nil)
                {
                    p0 = modifier(0,p0);
                    p1 = modifier(1,p1);
                    p2 = modifier(2,p2);
                }
                CGFloat angle = p0*(M_PI/180.f);
                CGAffineTransform def = CGAffineTransformIdentity;
                def = CGAffineTransformTranslate(def, p1, p2);
                def = CGAffineTransformRotate(def, angle);
                def = CGAffineTransformTranslate(def, -1.f*p1, -1.f*p2);
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

+ (NSArray<IJSVGTransform *> *)transformsFromAffineTransform:(CGAffineTransform)affineTransform
{
    NSArray * strings = [self affineTransformToSVGTransformAttributeString:affineTransform];
    return [self transformsForString:[strings componentsJoinedByString:@" "]];
}

+ (NSString *)affineTransformToSVGMatrixString:(CGAffineTransform)transform
{
    return [NSString stringWithFormat:@"matrix(%g,%g,%g,%g,%g,%g)",
            transform.a, transform.b, transform.c, transform.d,
            transform.tx, transform.ty];
}

// this is an Object-C version of the matrixToTransform method from SVGO
+ (NSArray<NSString *> *)affineTransformToSVGTransformAttributeString:(CGAffineTransform)affineTransform
{
    const CGFloat data[6] = {
        affineTransform.a,
        affineTransform.b,
        affineTransform.c,
        affineTransform.d,
        affineTransform.tx,
        affineTransform.ty
    };
    
    CGFloat sx = sqrtf(data[0]*data[0] + data[1] * data[1]);
    CGFloat sy = (data[0]*data[3] - data[1]*data[2])/sx;
    
    CGFloat colSum = data[0]*data[2] + data[1]*data[3];
    CGFloat rowSum = data[0]*data[1] + data[2]*data[3];
    BOOL scaleBefore = rowSum != 0.f || (sx == sy);
    
    NSMutableArray * trans = [[[NSMutableArray alloc] init] autorelease];
    
    // translate
    if(data[4] != 0.f || data[5] != 0.f) {
        NSString * str = [NSString stringWithFormat:@"translate(%g, %g)",data[4],data[5]];
        [trans addObject:str];
    }
    
    // skewX
    if(data[1] == 0.f && data[2] != 0.f) {
        NSString * str = [NSString stringWithFormat:@"skewX(%g)",IJSVGMathAtan(data[2]/sy)];
        [trans addObject:str];
        
        // skewY
    } else if(data[1] != 0.f && data[2] == 0.f) {
        NSString * str = [NSString stringWithFormat:@"skewY(%g)",IJSVGMathAtan(data[1]/data[0])];
        [trans addObject:str];
        sx = data[0];
        sy = data[3];
    } else if(colSum == 0.f || (sx == 1.f && sy == 1.f) || scaleBefore == NO) {
        if(scaleBefore == NO) {
            sx = (data[0] < 0.f ? -1.f : 1.f) * sqrtf(data[0] * data[0] + data[2] * data[2]);
            sy = (data[3] < 0.f ? -1.f : 1.f) * sqrtf(data[1] * data[1] + data[3] * data[3]);
            NSString * str = nil;
            if(sx == sy) {
                str = [NSString stringWithFormat:@"scale(%g)",sx];
            } else {
                str = [NSString stringWithFormat:@"scale(%g, %g)",sx,sy];
            }
            [trans addObject:str];
        }
        
        // rotate
        CGFloat rotate = IJSVGMathAcos(data[0]/sx)*(data[1]*sy < 0.f ? -1.f : 1.f);
        NSString * rotateString = nil;
        if(rotate != 0.f) {
            rotateString = [NSString stringWithFormat:@"rotate(%g)",rotate];
        }
        
        // skewX
        if(rowSum != 0.f && colSum != 0.f) {
            NSString * str = [NSString stringWithFormat:@"skewX(%g)",IJSVGMathAtan(colSum/(sx * sx))];
            [trans addObject:str];
        }
        
        // rotate around center
        if(rotate != 0.f && (data[4] != 0.f || data[5] != 0.f)) {
            [trans removeObjectAtIndex:0];
            
            CGFloat cos = data[0]/sx;
            CGFloat sin = data[1]/(scaleBefore ? sx : sy);
            CGFloat x = data[4] * (scaleBefore ? 1.f : sy);
            CGFloat y = data[5] * (scaleBefore ? 1.f : sx);
            CGFloat denom = (powf(1.f - cos, 2.f) + powf(sin,2.f)) * (scaleBefore ? 1.f : sx * sy);
            
            CGFloat r1 = rotate;
            CGFloat r2 = ((1.f - cos) * x - sin * y) / denom;
            CGFloat r3 = ((1.f - cos) * y + sin * x) / denom;
            
            rotateString = [NSString stringWithFormat:@"rotate(%g, %g, %g)",r1,r2,r3];
        }
        
        if(rotateString != nil) {
            [trans addObject:rotateString];
        }
    }
    
    // scale
    if((scaleBefore && (sx != 1.f || sy != 1.f)) || trans.count == 0.f) {
        NSString * str = nil;
        if(sx == sy) {
            str = [NSString stringWithFormat:@"scale(%g)",sx];
        } else {
            str = [NSString stringWithFormat:@"scale(%g, %g)",sx, sy];
        }
        [trans addObject:str];
    }
    
    return trans;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@",[super description],
            [self.class affineTransformToSVGTransformAttributeString:self.CGAffineTransform]];
}


@end
