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
        [self setNeedsDisplay];
    }
    return self;
}

- (BOOL)requiresBackingScale
{
    return YES;
}

- (void)drawInContext:(CGContextRef)ctx
{
    CGImageRef image = _image.CGImage;
    CGRect imageDrawRect = _image.intrinsicBounds;
    CGRect currentBounds = self.bounds;
    IJSVGViewBoxDrawingBlock drawBlock = ^(CGSize scale) {
        // image will be upside down, so just translate it back on itself
        CGContextConcatCTM(ctx, CGAffineTransformMakeScale(1.f, -1.f));
        CGContextTranslateCTM(ctx, 0.f, -CGRectGetHeight(imageDrawRect));
        CGContextDrawImage(ctx, imageDrawRect, image);
    };
    IJSVGContextDrawViewBox(ctx, _image.intrinsicBounds, currentBounds,
                     _image.viewBoxAlignment, _image.viewBoxMeetOrSlice,
                     drawBlock);
}

@end
