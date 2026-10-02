//
//  IJSVGRendering.m
//  IJSVG
//
//  Created by Curtis Hard on 14/03/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRendering.h>

@implementation IJSVGRenderingOptions

// Preserves the rendering defaults used by existing SVG clients.
- (instancetype)init
{
    if((self = [super init]) != nil) {
        _filtersEnabled = YES;
        _renderQuality = kIJSVGRenderQualityFullResolution;
        _ignoreIntrinsicSize = YES;
    }
    return self;
}

// Copies settings so SVG instances never share mutable rendering options.
- (id)copyWithZone:(NSZone*)zone
{
    IJSVGRenderingOptions* options = [[self.class allocWithZone:zone] init];
    options.filtersEnabled = self.filtersEnabled;
    options.renderQuality = self.renderQuality;
    options.ignoreIntrinsicSize = self.ignoreIntrinsicSize;
    return options;
}

@end

@implementation IJSVGRendering

@end
