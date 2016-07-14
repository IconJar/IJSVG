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
    CGImageRelease(CGImage), CGImage = nil;
    [imagePath release], imagePath = nil;
    [image release], image = nil;
    [super dealloc];
}

- (void)loadFromBase64EncodedString:(NSString *)encodedString
{
    NSURL * URL = [NSURL URLWithString:encodedString];
    NSData * data = [NSData dataWithContentsOfURL:URL];
    
    // no data, jsut ignore...invalid probably
    if(data == nil) {
        return;
    }
    
    // set the image against the container
    NSImage * anImage = [[[NSImage alloc] initWithData:data] autorelease];
    [self setImage:anImage];
}

- (IJSVGPath *)path
{
    if(imagePath == nil) {
        // lazy load the path as it might not be needed
        imagePath = [[IJSVGPath alloc] init];
        [imagePath.path appendBezierPathWithRect:NSMakeRect(0.f, 0.f, image.size.width, image.size.height)];
        [imagePath close];
    }
    return imagePath;
}

- (void)setImage:(NSImage *)anImage
{
    if(image != nil) {
        [image release], image = nil;
    }
    image = [anImage retain];
    
    if(CGImage != nil) {
        CGImageRelease(CGImage);
    }
    
    NSRect rect = NSMakeRect( 0.f, 0.f, image.size.width, image.size.height);
    CGImage = [image CGImageForProposedRect:&rect
                                    context:nil
                                      hints:nil];
}

- (void)drawInContextRef:(CGContextRef)context
                    path:(IJSVGPath *)path
{
    // run the transforms
    // draw the image
    if(path == nil) {
        path = [self path];
    }
    
    CGRect rect = path.path.bounds;
    CGRect bounds = CGRectMake( 0.f, 0.f, rect.size.width, rect.size.height);
    
    // save the state of the context
    CGContextSaveGState(context);
    {
        // flip the coordinates
        CGContextTranslateCTM(context, rect.origin.x, (rect.origin.y)+rect.size.height);
        CGContextScaleCTM(context, 1.f, -1.f);
        CGContextDrawImage( context, bounds, CGImage);
    }
    CGContextRestoreGState(context);
}

@end
