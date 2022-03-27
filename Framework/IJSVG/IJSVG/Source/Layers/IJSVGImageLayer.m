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

- (id)initWithImage:(IJSVGImage *)image
{
    if((self = [super init]) != nil) {
        _image = image.retain;
        self.requiresBackingScaleHelp = YES;
        self.shouldRasterize = YES;
        self.backgroundColor = NSColor.blueColor.CGColor;
        [self reloadContent];
    }
    return self;
}

- (void)reloadContent
{
    if(_imageLayer == nil) {
        _imageLayer = [[IJSVGLayer layer] retain];
        _imageLayer.backgroundColor = NSColor.redColor.CGColor;
        CGRect bounds = _image.intrinsicBounds;
        _imageLayer.frame = bounds;
//        _imageLayer.anchorPoint = CGPointMake(0.f, 0.f);
        [self addSublayer:_imageLayer];
    }

    _imageLayer.contents = (id)_image.CGImage;
    [self setNeedsDisplay];
}

//- (id)initWithImage:(NSImage*)image
//{
//    NSRect rect = (NSRect){
//        .origin = NSZeroPoint,
//        .size = image.size
//    };
//    CGImageRef ref = [image CGImageForProposedRect:&rect
//                                           context:nil
//                                             hints:nil];
//    return [self initWithCGImage:ref];
//}
//
//- (id)initWithCGImage:(CGImageRef)imageRef
//{
//    if ((self = [super init]) != nil) {
//        // set the contents
//        self.contents = (id)imageRef;
//
//        // make sure we say we need help
//        self.requiresBackingScaleHelp = YES;
//        self.shouldRasterize = YES;
//
//        // set the frame, simple stuff
//        self.frame = (CGRect){
//            .origin = CGPointZero,
//            .size = CGSizeMake(CGImageGetWidth(imageRef),
//                CGImageGetHeight(imageRef))
//        };
//    }
//    return self;
//}
//
//- (void)setNeedsDisplay
//{
//    // swap the content around on call
//    // because set needs display discards previous
//    // content - yolo!
//    id oldContent = self.contents;
//    [super setNeedsDisplay];
//    self.contents = oldContent;
//}

@end
