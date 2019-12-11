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
    kIJSVGRenderQualityFullResolution, // slowest to render
    kIJSVGRenderQualityOptimized, // best of both worlds
    kIJSVGRenderQualityLow // fast rendering
};

@interface IJSVGRendering : NSObject

@end
