//
//  IJSVGTransform.m
//  IconJar
//
//  Created by Curtis Hard on 01/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

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

+ (IJSVGTransformCommand)commandForCommandString:(NSString *)str
{
    if( [str isEqualToString:@"matrix"] )
        return IJSVGTransformCommandMatrix;
    if( [str isEqualToString:@"translate"] )
        return IJSVGTransformCommandTranslate;
    if( [str isEqualToString:@"scale"] )
        return IJSVGTransformCommandScale;
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
            if( commandType == IJSVGTransformCommandNotImplemented )
                return;
            
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

+ (void)performTransform:(IJSVGTransform *)transform
               inContext:(CGContextRef)context
{
    switch( transform.command )
    {
        // matrix
        case IJSVGTransformCommandMatrix: {
            CGContextConcatCTM( context, CGAffineTransformMake( transform.parameters[0],
                                                               transform.parameters[1],
                                                               transform.parameters[2],
                                                               transform.parameters[3],
                                                               transform.parameters[4],
                                                               transform.parameters[5]));
            break;
        }
        
        // translate
        case IJSVGTransformCommandTranslate: {
            if( transform.parameterCount == 1 )
                CGContextTranslateCTM( context, transform.parameters[0], 0 );
            else
                CGContextTranslateCTM( context, transform.parameters[0], transform.parameters[1]);
            break;
        }
            
        // scale
        case IJSVGTransformCommandScale: {
            if( transform.parameterCount == 1 )
                CGContextScaleCTM( context, transform.parameters[0], transform.parameters[0] );
            else
                CGContextScaleCTM( context, transform.parameters[0], transform.parameters[1] );
            break;
        }
            
        // rotate
        case IJSVGTransformCommandRotate: {
            // these are in radians, not degrees
            if( transform.parameterCount == 1 )
                CGContextRotateCTM( context, (transform.parameters[0] / 180) * M_PI);
            // need support for rotate around a point
        }
            
        // do nothing
        case IJSVGTransformCommandNotImplemented: {
            
        }
    }
    
}

@end
