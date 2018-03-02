//
//  IJSVGLayerTree.h
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "IJSVGNode.h"

@class IJSVGLayer;

@interface IJSVGLayerTree : NSObject {
    
}

@property (nonatomic, assign) CGRect viewBox;
@property (nonatomic, retain) NSColor * fillColor;
@property (nonatomic, retain) NSColor * strokeColor;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, assign) IJSVGLineJoinStyle lineJoinStyle;
@property (nonatomic, assign) IJSVGLineCapStyle lineCapStyle;
@property (nonatomic, retain) NSDictionary<NSColor *, NSColor *> * replacementColors;

- (IJSVGLayer *)layerForNode:(IJSVGNode *)node;

@end
