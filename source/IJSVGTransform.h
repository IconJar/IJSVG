//
//  IJSVGTransform.h
//  IconJar
//
//  Created by Curtis Hard on 01/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGUtils.h"

typedef NS_OPTIONS( NSInteger, IJSVGTransformCommand ) {
    IJSVGTransformCommandMatrix,
    IJSVGTransformCommandTranslate,
    IJSVGTransformCommandScale,
    IJSVGTransformCommandRotate,
    IJSVGTransformCommandNotImplemented
};

@interface IJSVGTransform : NSObject {
    
    IJSVGTransformCommand command;
    CGFloat * parameters;
    NSInteger parameterCount;
    NSInteger sort;
    
}

@property ( nonatomic, assign ) IJSVGTransformCommand command;
@property ( nonatomic, assign ) CGFloat * parameters;
@property ( nonatomic, assign ) NSInteger parameterCount;
@property ( nonatomic, assign ) NSInteger sort;

+ (NSArray *)transformsForString:(NSString *)string;
+ (void)performTransform:(IJSVGTransform *)transform
               inContext:(CGContextRef)context;
+ (NSBezierPath *)transformedPath:(IJSVGPath *)path;

@end
