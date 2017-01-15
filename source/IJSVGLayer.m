//
//  IJSVGLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGLayer.h"
#import "IJSVGShapeLayer.h"


@implementation IJSVGLayer

IJSVG_LAYER_DEFAULT_SYNTHESIZE

#ifndef __clang_analyzer__
- (void)dealloc
{
    IJSVG_LAYER_DEFAULT_DEALLOC_INSTRUCTIONS
}
#endif

IJSVG_LAYER_ADD_SUBVIEW_DEFAULT_IMPLEMENTATION

@end
