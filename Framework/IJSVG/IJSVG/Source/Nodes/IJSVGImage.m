//
//  IJSVGImage.m
//  IJSVGExample
//
//  Created by Curtis Hard on 28/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGImage.h"
#import "IJSVGPath.h"
#import "IJSVGTransform.h"

@implementation IJSVGImage

- (void)dealloc
{
    (void)(CGImageRelease(CGImage)), CGImage = nil;
    (void)([imagePath release]), imagePath = nil;
    (void)([image release]), image = nil;
    [super dealloc];
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
    NSImage* anImage = [[[NSImage alloc] initWithData:data] autorelease];
    [self setImage:anImage];
}

- (IJSVGPath*)path
{
    if (imagePath == nil) {
        // lazy load the path as it might not be needed
        imagePath = [[IJSVGPath alloc] init];
        CGRect rect = CGRectMake(0.f, 0.f, self.width.value, self.height.value);
        CGPathAddRect(imagePath.path, NULL, rect);
        [imagePath close];
    }
    return imagePath;
}

- (void)setImage:(NSImage*)anImage
{
    if (image != nil) {
        (void)([image release]), image = nil;
    }
    image = [anImage retain];

    if (CGImage != nil) {
        CGImageRelease(CGImage);
        CGImage = nil;
    }

    NSRect rect = NSMakeRect(0.f, 0.f, self.width.value, self.height.value);
    CGImage = [image CGImageForProposedRect:&rect
                                    context:nil
                                      hints:nil];

    // be sure to retain (some reason this is required in Xcode 8 beta 5?)
    CGImageRetain(CGImage);
}

- (CGImageRef)CGImage
{
    return CGImage;
}

- (void)drawInContextRef:(CGContextRef)context
                    path:(IJSVGPath*)path
{
    // run the transforms
    // draw the image
    if (self.width.value == 0.f || self.height.value == 0.f) {
        return;
    }

    // make sure path is set
    if (path == nil) {
        path = [self path];
    }

    CGRect rect = path.pathBoundingBox;
    CGRect bounds = CGRectMake(0.f, 0.f, rect.size.width, rect.size.height);

    // save the state of the context
    CGContextSaveGState(context);
    {
        // flip the coordinates
        CGContextTranslateCTM(context, rect.origin.x, (rect.origin.y) + rect.size.height);
        CGContextScaleCTM(context, 1.f, -1.f);
        CGContextDrawImage(context, bounds, CGImage);
    }
    CGContextRestoreGState(context);
}

@end
