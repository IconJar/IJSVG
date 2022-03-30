//
//  IJSVGGroupLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGGroupLayer.h"

@implementation IJSVGGroupLayer

- (CGRect)computedFrame
{
    CGRect bounds = CGRectNull;
    for(IJSVGLayer* layer in self.sublayers) {
        if(CGRectIsNull(bounds)) {
            bounds = layer.computedFrame;
        } else {
            bounds = CGRectUnion(bounds, layer.computedFrame);
        }
    }
    return bounds;
}

@end
