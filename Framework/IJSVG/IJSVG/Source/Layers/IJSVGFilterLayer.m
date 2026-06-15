//
//  IJSVGFilterLayer.m
//  IJSVG
//
//  Created by Curtis Hard on 19/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterLayer.h>
#import <IJSVG/IJSVGTransform.h>

@implementation IJSVGFilterLayer {
    CGRect _filterFrame;
}

- (void)setOwnedImage:(CGImageRef)image
{
    if(_image == image) {
        return;
    }

    _hostingLayer.contents = nil;

    if(_image != NULL) {
        CGImageRelease(_image);
        _image = NULL;
    }

    if(image != NULL) {
        _image = CGImageRetain(image);
    }
}

- (void)dealloc
{
    _hostingLayer.contents = nil;
    if(_image != NULL) {
        CGImageRelease(_image);
        _image = NULL;
    }
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
    CGFloat scale = self.backingScaleFactor;
    if(scale <= 0) scale = 1.0;
    [IJSVGLayer setBackingScaleFactor:scale
                        renderQuality:self.renderQuality
                   recursivelyToLayer:_sublayer];
    _filterFrame = _sublayer.innerBoundingBox;
    CGImageRef image = [self.filter newImageByApplyFilterToLayer:_sublayer
                                                           scale:scale
                                                     outputFrame:&_filterFrame];
    [self setOwnedImage:image];
    if(image != NULL) {
        CGImageRelease(image);
    }
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    if(_image == NULL) {
        [self updateImage];
    }
    CGImageRef image = _image;
    if(image != NULL) {
        CGImageRetain(image);
    }
    if(image != NULL) {
        CGContextDrawImage(ctx, _filterFrame, image);
        CGImageRelease(image);
    }
}

- (void)layoutSublayers
{
    _hostingLayer.frame = _filterFrame;
    _hostingLayer.contents = (__bridge id)_image;
}

- (NSArray<CALayer<IJSVGBasicLayer>*>*)debugLayers
{
    return @[_sublayer];
}

@end
