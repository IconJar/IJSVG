//
//  IJSVGStyleList.h
//  IconJar
//
//  Created by Curtis Hard on 09/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColorList.h>
#import <IJSVG/IJSVGNode.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface IJSVGRenderingStyle : NSObject

@property (nonatomic, assign) IJSVGLineCapStyle lineCapStyle;
@property (nonatomic, assign) IJSVGLineJoinStyle lineJoinStyle;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, strong) IJSVGColorList* colorList;
@property (nonatomic, strong) NSColor* fillColor;
@property (nonatomic, strong) NSColor* strokeColor;

+ (NSArray<NSString*>*)observableProperties;

@end
