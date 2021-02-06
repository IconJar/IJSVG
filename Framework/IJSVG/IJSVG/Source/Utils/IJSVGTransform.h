//
//  IJSVGTransform.h
//  IconJar
//
//  Created by Curtis Hard on 01/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGUtils.h"
#import <Foundation/Foundation.h>

@class IJSVGTransform;

typedef CGFloat (^IJSVGTransformParameterModifier)(NSInteger index, CGFloat value);
typedef void (^IJSVGTransformApplyBlock)(IJSVGTransform* transform);

typedef NS_OPTIONS(NSInteger, IJSVGTransformCommand) {
    IJSVGTransformCommandMatrix,
    IJSVGTransformCommandTranslate,
    IJSVGTransformCommandTranslateX,
    IJSVGTransformCommandTranslateY,
    IJSVGTransformCommandScale,
    IJSVGTransformCommandRotate,
    IJSVGTransformCommandSkewX,
    IJSVGTransformCommandSkewY,
    IJSVGTransformCommandNotImplemented
};

@interface IJSVGTransform : NSObject {
}

@property (nonatomic, assign) IJSVGTransformCommand command;
@property (nonatomic, assign) CGFloat* parameters;
@property (nonatomic, assign) NSInteger parameterCount;
@property (nonatomic, assign) NSInteger sort;

void IJSVGApplyTransform(NSArray<IJSVGTransform*>* transforms, IJSVGTransformApplyBlock block);
CGAffineTransform IJSVGConcatTransforms(NSArray<IJSVGTransform*>* transforms);
NSString* IJSVGTransformAttributeString(CGAffineTransform transform);

+ (NSArray<NSDictionary*>*)affineTransformToSVGTransformComponents:(CGAffineTransform)transform;
+ (NSString*)affineTransformToSVGTransformComponentString:(CGAffineTransform)transform
                                     floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
+ (NSString*)affineTransformToSVGTransformComponentString:(CGAffineTransform)transform;
+ (NSArray<IJSVGTransform*>*)transformsFromAffineTransform:(CGAffineTransform)affineTransform;
+ (NSArray<IJSVGTransform*>*)transformsForString:(NSString*)string;
+ (NSString*)affineTransformToSVGMatrixString:(CGAffineTransform)affineTransform;
+ (NSString*)affineTransformToSVGMatrixString:(CGAffineTransform)transform
                         floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
- (CGAffineTransform)CGAffineTransform;
- (CGAffineTransform)CGAffineTransformWithModifier:(IJSVGTransformParameterModifier)modifier;
- (CGAffineTransform)stackIdentity:(CGAffineTransform)identity;
- (void)recalculateWithBounds:(CGRect)bounds;
+ (IJSVGTransform*)transformByTranslatingX:(CGFloat)x
                                         y:(CGFloat)y;
+ (IJSVGTransform*)transformByScaleX:(CGFloat)x
                                   y:(CGFloat)y;

@end
