//
//  IJSVGTransform.h
//  IconJar
//
//  Created by Curtis Hard on 01/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGUtils.h"

@class IJSVGTransform;

typedef CGFloat (^IJSVGTransformParameterModifier)(NSInteger index, CGFloat value);
typedef void (^IJSVGTransformApplyBlock)(IJSVGTransform * transform);

typedef NS_OPTIONS( NSInteger, IJSVGTransformCommand ) {
    IJSVGTransformCommandMatrix,
    IJSVGTransformCommandTranslate,
    IJSVGTransformCommandScale,
    IJSVGTransformCommandRotate,
    IJSVGTransformCommandSkewX,
    IJSVGTransformCommandSkewY,
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

NSString * IJSVGDebugAffineTransform(CGAffineTransform transform);
NSString * IJSVGDebugTransforms(NSArray<IJSVGTransform *> * transforms);
void IJSVGApplyTransform(NSArray<IJSVGTransform *> * transforms,  IJSVGTransformApplyBlock block);
CGAffineTransform IJSVGConcatTransforms(NSArray<IJSVGTransform *> * transforms);

+ (NSArray<IJSVGTransform *> *)transformsFromAffineTransform:(CGAffineTransform)affineTransform;
+ (NSArray *)transformsForString:(NSString *)string;
+ (NSBezierPath *)transformedPath:(IJSVGPath *)path;
+ (NSArray<NSString *> *)affineTransformToSVGTransformAttributeString:(CGAffineTransform)affineTransform;
+ (NSString *)affineTransformToSVGMatrixString:(CGAffineTransform)affineTransform;
- (CGAffineTransform)CGAffineTransform;
- (CGAffineTransform)CGAffineTransformWithModifier:(IJSVGTransformParameterModifier)modifier;
- (CGAffineTransform)stackIdentity:(CGAffineTransform)identity;
- (void)recalculateWithBounds:(CGRect)bounds;
+ (IJSVGTransform *)transformByTranslatingX:(CGFloat)x
                                          y:(CGFloat)y;

@end
