//
//  IJSVGStyleList.h
//  IconJar
//
//  Created by Curtis Hard on 09/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGNode.h"
#import "IJSVGColorList.h"

@interface IJSVGRenderingStyle : NSObject

@property (nonatomic, assign) IJSVGLineCapStyle lineCapStyle;
@property (nonatomic, assign) IJSVGLineJoinStyle lineJoinStyle;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, retain) IJSVGColorList * colorList;
@property (nonatomic, retain) NSColor * fillColor;
@property (nonatomic, retain) NSColor * strokeColor;

+ (NSArray<NSString *> *)observableProperties;

@end
