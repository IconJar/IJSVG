//
//  IJSVGGradientLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGGradientLayer.h"

@implementation IJSVGGradientLayer

- (void)dealloc
{
    (void)([_gradient release]), _gradient = nil;
    [super dealloc];
}

- (id)init
{
    if ((self = [super init]) != nil) {
        self.requiresBackingScaleHelp = YES;
//        self.shouldRasterize = YES;
    }
    return self;
}

- (void)setGradient:(IJSVGGradient*)newGradient
{
    if (_gradient != nil) {
        (void)([_gradient release]), _gradient = nil;
    }
    _gradient = [newGradient retain];

    // lets check its alpha properties on the colors
    BOOL hasAlphaChannel = NO;
    NSInteger stops = _gradient.gradient.numberOfColorStops;
    for (NSInteger i = 0; i < stops; i++) {
        NSColor* color = nil;
        [_gradient.gradient getColor:&color
                           location:NULL
                            atIndex:i];
        if (color.alphaComponent != 1.f) {
            hasAlphaChannel = YES;
            break;
        }
    }
    self.opaque = hasAlphaChannel == NO;
}

- (void)setOpacity:(float)opacity
{
    if (opacity != 1.f) {
        self.opaque = NO;
    }
    [super setOpacity:opacity];
}

- (void)setBackingScaleFactor:(CGFloat)backingScaleFactor
{
    switch (self.renderQuality) {
    case kIJSVGRenderQualityOptimized: {
        backingScaleFactor = (backingScaleFactor * .35f);
        break;
    }
    case kIJSVGRenderQualityLow: {
        backingScaleFactor = (backingScaleFactor * .05f);
        break;
    }
    default: {
        break;
    }
    }
    [super setBackingScaleFactor:backingScaleFactor];
}

- (void)drawInContext:(CGContextRef)ctx
{
    [super drawInContext:ctx];

    // nothing to do :(
    if (self.gradient == nil) {
        return;
    }

    // draw the gradient
    CGAffineTransform trans = CGAffineTransformMakeTranslation(-CGRectGetMinX(_objectRect),
                                                               -CGRectGetMinY(_objectRect));
    CGAffineTransform transform = CGAffineTransformConcat(_absoluteTransform, trans);
    CGContextSaveGState(ctx);
    [self.gradient drawInContextRef:ctx
                         objectRect:_objectRect
                  absoluteTransform:transform
                           viewPort:self.viewBox];
    CGContextRestoreGState(ctx);
}

@end
