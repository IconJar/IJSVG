//
//  IJSVGImage.m
//  IJSVGExample
//
//  Created by Curtis Hard on 28/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGImage.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGTransform.h>

@implementation IJSVGImage

- (void)dealloc
{
    (void)(CGImageRelease(CGImage)), CGImage = nil;
}

- (void)setDefaults
{
    [super setDefaults];
    self.viewBoxAlignment = IJSVGViewBoxAlignmentXMidYMid;
    self.viewBoxMeetOrSlice = IJSVGViewBoxMeetOrSliceMeet;
}

- (void)loadFromString:(NSString*)encodedString
{
    if ([encodedString hasPrefix:@"data:"]) {
        encodedString = [encodedString stringByReplacingOccurrencesOfString:@"\\s+"
                                                                 withString:@""
                                                                    options:NSRegularExpressionSearch
                                                                      range:NSMakeRange(0, encodedString.length)];
    }
    NSURL* url = [NSURL URLWithString:encodedString];
    if(url != nil) {
        [self loadFromURL:url];
    }
}

- (void)loadFromURL:(NSURL*)aURL
{
    NSData* data = [NSData dataWithContentsOfURL:aURL];

    // no data, just ignore...invalid probably
    if (data == nil) {
        return;
    }

    // set the image against the container
    NSImage* anImage = [[NSImage alloc] initWithData:data];
    [self setImage:anImage];
}

- (void)setImage:(NSImage*)anImage
{
    _image = anImage;
    _intrinsicSize = (CGSize)_image.size;

    if (CGImage != nil) {
        CGImageRelease(CGImage);
        CGImage = nil;
    }

    CGRect rect = CGRectMake(0.f, 0.f,
                             _intrinsicSize.width,
                             _intrinsicSize.height);
    CGImage = [_image CGImageForProposedRect:&rect
                                     context:nil
                                       hints:nil];

    CGImageRetain(CGImage);
}

- (CGImageRef)CGImage
{
    return CGImage;
}

- (CGRect)intrinsicBounds
{
    CGRect rect = CGRectZero;
    rect.size.width = _intrinsicSize.width;
    rect.size.height = _intrinsicSize.height;
    return rect;
}

- (CGRect)bounds
{
    return CGRectMake(0.f, 0.f,
                      self.width.value,
                      self.height.value);
}

@end
