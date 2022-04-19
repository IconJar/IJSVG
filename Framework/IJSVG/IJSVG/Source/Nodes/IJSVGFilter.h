//
//  IJSVGFilter.h
//  IJSVG
//
//  Created by Curtis Hard on 18/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGLayer.h>

@interface IJSVGFilter : IJSVGGroup

- (CGImageRef)newImageByApplyFilterToLayer:(CALayer<IJSVGDrawableLayer>*)layer
                                     scale:(CGFloat)scale;

@end
