//
//  IJSVGRootLayer.h
//  IJSVG
//
//  Created by Curtis Hard on 15/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>

@interface IJSVGRootLayer : IJSVGGroupLayer {
    
@private
    BOOL _disableBackingScalePropagation;
    
}

- (void)renderInContext:(CGContextRef)ctx
               viewPort:(CGRect)viewPort
           backingScale:(CGFloat)backingScale
                quality:(IJSVGRenderQuality)quality
    ignoreIntrinsicSize:(BOOL)ignoreIntrinsicSize;

@end
