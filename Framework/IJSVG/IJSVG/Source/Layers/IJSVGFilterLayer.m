//
//  IJSVGFilterLayer.m
//  IJSVG
//
//  Created by Curtis Hard on 19/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterLayer.h>
#import <IJSVG/IJSVGTransform.h>

@implementation IJSVGFilterLayer

- (void)dealloc
{
    (void)CGImageRelease(_image), _image = nil;
}

- (instancetype)init
{
    if((self = [super init]) != nil) {
        _hostingLayer = [IJSVGBasicLayer layer];
        [self addSublayer:_hostingLayer];
    }
    return self;
}

- (BOOL)requiresBackingScale
{
    return YES;
}

- (void)setBackingScaleFactor:(CGFloat)backingScaleFactor
{
    // we are responsible for recursively calling the sublayer
    // with the new backing scale factor
    [IJSVGLayer setBackingScaleFactor:backingScaleFactor
                        renderQuality:self.renderQuality
                   recursivelyToLayer:_sublayer];
    
    BOOL needsChange = self.backingScaleFactor != backingScaleFactor;
    [super setBackingScaleFactor:backingScaleFactor];
    if(needsChange == YES) {
        [self updateImage];
    }
}

- (void)updateImage
{
    if(_image != nil) {
        (void)CGImageRelease(_image), _image = nil;
    }
    _image = [self.filter newImageByApplyFilterToLayer:_sublayer
                                                 scale:self.backingScaleFactor];
}

- (void)layoutSublayers
{
    CGRect frame = _sublayer.innerBoundingBox;
    _hostingLayer.frame = frame;
    _hostingLayer.contents = (__bridge id)_image;
}

- (NSArray<CALayer<IJSVGBasicLayer>*>*)debugLayers
{
    return @[_sublayer];
}

@end
