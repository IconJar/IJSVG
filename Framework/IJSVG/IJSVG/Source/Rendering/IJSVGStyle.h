//
//  IJSVGStyle.h
//  IJSVG
//
//  Created by Curtis Hard on 09/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <IJSVG/IJSVGNode.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGStyle : NSObject

@property (nonatomic, assign) IJSVGLineCapStyle lineCapStyle;
@property (nonatomic, assign) IJSVGLineJoinStyle lineJoinStyle;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) CGFloat miterLimit;
@property (nonatomic, strong, null_resettable) IJSVGTraitedColorStorage* colors;
@property (nonatomic, strong, nullable) NSColor* fillColor;
@property (nonatomic, strong, nullable) NSColor* strokeColor;

@end

NS_ASSUME_NONNULL_END
