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
    // High image interpolation and full coverage sampling for nested filters.
    kIJSVGRenderQualityFullResolution,

    // Medium image interpolation and local filter sampling for thumbnails.
    kIJSVGRenderQualityOptimized,

    // Low image interpolation without additional filter coverage samples.
    kIJSVGRenderQualityLow
};

FOUNDATION_EXPORT const CGFloat IJSVGDefaultFontSize;

// Independent rendering settings with the standard SVG defaults.
@interface IJSVGRenderingOptions : NSObject <NSCopying>

@property (nonatomic, assign) BOOL filtersEnabled;

// Defaults to full resolution. Applies to image interpolation, filter coverage
// sampling and filter output interpolation. Faster modes can change edge pixels.
@property (nonatomic, assign) IJSVGRenderQuality renderQuality;
@property (nonatomic, assign) BOOL ignoreIntrinsicSize;

// Initial font size in user units, before SVG font size declarations. Defaults
// to 16. Negative and nonfinite values restore the default. Zero is allowed.
@property (nonatomic, assign) CGFloat defaultFontSize;

@end

@interface IJSVGRendering : NSObject

@end
