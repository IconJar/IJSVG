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
                                                 scale:1.f];
}

- (void)layoutSublayers
{
    CGFloat width = CGImageGetWidth(_image);
    CGFloat height = CGImageGetHeight(_image);
    CGRect frame = _sublayer.innerBoundingBox;
    _hostingLayer.frame = CGRectMake(frame.origin.x + (frame.size.width / 2.f - width / 2.f),
                                     frame.origin.y + (frame.size.height / 2.f - height / 2.f),
                                     width, height);
    _hostingLayer.contents = (__bridge id)_image;
}

- (NSArray<CALayer<IJSVGBasicLayer>*>*)debugLayers
{
    return @[_sublayer];
}

@end
