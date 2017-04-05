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

- (IJSVGLayer *)layerForNode:(IJSVGNode *)node;

@end
