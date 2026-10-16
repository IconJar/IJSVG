//
//  IJSVGStyle.h
//  IJSVG
//
//  Created by Curtis Hard on 09/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGStyle : NSObject

@property (nonatomic, assign) IJSVGLineCapStyle lineCapStyle;
@property (nonatomic, assign) IJSVGLineJoinStyle lineJoinStyle;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) CGFloat miterLimit;
@property (nonatomic, strong, null_resettable) IJSVGTraitedColorStorage* colors;
@property (nonatomic, assign, nullable) CGColorRef fillColor;
@property (nonatomic, assign, nullable) CGColorRef strokeColor;

@end

NS_ASSUME_NONNULL_END
