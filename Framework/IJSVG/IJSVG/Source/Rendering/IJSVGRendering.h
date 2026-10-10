//
//  IJSVGRendering.h
//  IJSVG
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

FOUNDATION_EXPORT const CGFloat IJSVGDefaultFontSize;

// Independent rendering settings with the standard SVG defaults.
@interface IJSVGRenderingOptions : NSObject <NSCopying>

@property (nonatomic, assign) BOOL filtersEnabled;
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, assign) BOOL ignoreIntrinsicSize;

// Initial font size in user units, before SVG font-size declarations. Defaults to 16.
// Negative and non-finite values restore the default; zero is allowed.
@property (nonatomic, assign) CGFloat defaultFontSize;

@end

@interface IJSVGRendering : NSObject

@end
