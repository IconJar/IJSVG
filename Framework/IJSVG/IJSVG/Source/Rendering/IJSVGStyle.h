//
//  IJSVGStyleList.h
//  IconJar
//
//  Created by Curtis Hard on 09/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTraitedColorStorage.h>
#import <IJSVG/IJSVGNode.h>
#import <objc/runtime.h>
#import <IJSVG/IJSVGPlatform.h>

@interface IJSVGStyle : NSObject

@property (nonatomic, assign) IJSVGLineCapStyle lineCapStyle;
@property (nonatomic, assign) IJSVGLineJoinStyle lineJoinStyle;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) CGFloat miterLimit;
@property (nonatomic, strong) IJSVGTraitedColorStorage* colors;
@property (nonatomic, strong) NSColor* fillColor;
@property (nonatomic, strong) NSColor* strokeColor;

@end
