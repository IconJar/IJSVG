//
//  IJSVGRendering.h
//  IJSVGExample
//
//  Created by Curtis Hard on 14/03/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef CGFloat (^IJSVGRenderingBackingScaleFactorHelper)(void);

typedef NS_ENUM(NSInteger, IJSVGRenderQuality) {
    IJSVGRenderQualityFullResolution, // slowest to render
    IJSVGRenderQualityOptimized, // best of both worlds
    IJSVGRenderQualityLow // fast rendering
};

@interface IJSVGRendering : NSObject

@end
