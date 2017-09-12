//
//  IJSVGLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGLayer.h"
#import "IJSVGShapeLayer.h"
#import "IJSVGGroupLayer.h"
#import "IJSVG.h"


@implementation IJSVGLayer

IJSVG_LAYER_DEFAULT_SYNTHESIZE

- (void)dealloc
{
    IJSVG_LAYER_DEFAULT_DEALLOC_INSTRUCTIONS
}

IJSVG_LAYER_ADD_SUBVIEW_DEFAULT_IMPLEMENTATION

+ (NSArray *)deepestSublayersOfLayer:(CALayer *)layer
{
    NSMutableArray * arr = [[[NSMutableArray alloc] init] autorelease];
    for(CALayer * subLayer in layer.sublayers) {
        if(subLayer.sublayers.count != 0) {
            NSArray * moreLayers = [self deepestSublayersOfLayer:(IJSVGLayer *)subLayer];
            [arr addObjectsFromArray:moreLayers];
        } else {
            [arr addObject:subLayer];
        }
    }
    return arr;
}

+ (void)recursivelyWalkLayer:(CALayer *)layer
                   withBlock:(void (^)(CALayer * layer))block
{
    // call for layer and mask if there is one
    block(layer);
    
    // do the mask too!
    if(layer.mask != nil) {
        block(layer.mask);
    }
    
    // sublayers!!
    for(CALayer * aLayer in layer.sublayers) {
        [self recursivelyWalkLayer:aLayer
                         withBlock:block];
    }
}

@end
