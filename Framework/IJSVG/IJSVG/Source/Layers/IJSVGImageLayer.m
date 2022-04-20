//
//  IJSVGImageLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGImageLayer.h>

@implementation IJSVGImageLayer

- (id)initWithImage:(IJSVGImage*)image
{
    if((self = [super init]) != nil) {
        _image = image;
    }
    return self;
}

- (BOOL)requiresBackingScale
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
        _imageLayer = [IJSVGBasicLayer layer];
        _imageLayer.contentsGravity = kCAGravityResize;
        _imageLayer.affineTransform = CGAffineTransformMakeScale(1.f, -1.f);
        _imageLayer.contents = (id)_image.CGImage;
        [self addSublayer:_imageLayer];
    }

    _imageLayer.frame = self.bounds;
}

@end
