//
//  IJSVGImageLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGImageLayer.h"

@implementation IJSVGImageLayer

- (void)dealloc
{
    (void)[_image release], _image = nil;
    (void)[_imageLayer release], _imageLayer = nil;
    [super dealloc];
}

- (id)initWithImage:(IJSVGImage*)image
{
    if((self = [super init]) != nil) {
        _image = image.retain;
    }
    return self;
}

- (BOOL)requiresBackingScaleHelp
{
    return YES;
}

- (void)layoutSublayers
{
    [super layoutSublayers];
    [self reloadContent];
    [self setNeedsDisplay];
}

- (void)reloadContent
{
    if(_imageLayer == nil) {
        _imageLayer = [IJSVGBasicLayer layer].retain;
        _imageLayer.contentsGravity = kCAGravityResize;
        _imageLayer.affineTransform = CGAffineTransformMakeScale(1.f, -1.f);
        _imageLayer.contents = (id)_image.CGImage;
        [self addSublayer:_imageLayer];
    }

    _imageLayer.frame = self.bounds;
}

@end
