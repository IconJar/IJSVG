//
//  IJSVGRendering.m
//  IJSVG
//
//  Created by Curtis Hard on 14/03/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRendering.h>

const CGFloat IJSVGDefaultFontSize = 16.f;

@implementation IJSVGRenderingOptions

// Preserves the rendering defaults used by existing SVG clients.
- (instancetype)init
{
    if((self = [super init]) != nil) {
        _filtersEnabled = YES;
        _renderQuality = kIJSVGRenderQualityFullResolution;
        _ignoreIntrinsicSize = YES;
        _defaultFontSize = IJSVGDefaultFontSize;
    }
    return self;
}

- (void)setDefaultFontSize:(CGFloat)defaultFontSize
{
    _defaultFontSize = isfinite(defaultFontSize) && defaultFontSize >= 0.f
        ? defaultFontSize : IJSVGDefaultFontSize;
}

// Copies settings so SVG instances never share mutable rendering options.
- (id)copyWithZone:(NSZone*)zone
{
    IJSVGRenderingOptions* options = [[self.class allocWithZone:zone] init];
    options.filtersEnabled = self.filtersEnabled;
    options.renderQuality = self.renderQuality;
    options.ignoreIntrinsicSize = self.ignoreIntrinsicSize;
    options.defaultFontSize = self.defaultFontSize;
    return options;
}

@end

@implementation IJSVGRendering

@end
