//
//  NSImage+IJSVGAdditions.m
//  IJSVG
//
//  Created by Curtis Hard on 07/06/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#if !TARGET_OS_IOS
#import <IJSVG/IJSVGImageRep.h>
#endif
#import <IJSVG/NSImage+IJSVGAdditions.h>

IJSVG* IJSVGGetFromNSImage(NSImage* image)
{
#if TARGET_OS_IOS
#pragma unused(image)
    return nil;
#else
    for (NSImageRep* rep in image.representations) {
        if([rep isKindOfClass:IJSVGImageRep.class]) {
            return ((IJSVGImageRep*)rep).SVG;
        }
    }
    return nil;
#endif
}

@implementation NSImage (IJSVGAdditions)

+ (NSImage*)SVGImageNamed:(NSString*)imageName
{
#if TARGET_OS_IOS
    IJSVG* svg = [IJSVG SVGNamed:imageName];
    if(svg == nil) {
        return nil;
    }
    CGSize size = svg.size;
    if(size.width <= 0.f || size.height <= 0.f) {
        size = CGSizeMake(24.f, 24.f);
    }
    return [svg imageWithSize:size];
#else
    // find the image
    NSBundle* bundle = NSBundle.mainBundle;
    NSString* str = nil;
    NSString* ext = imageName.pathExtension;
    if(ext == nil || ext.length == 0) {
        ext = @"svg";
    }

    if((str = [bundle pathForResource:imageName.stringByDeletingPathExtension
                                ofType:ext])
        != nil) {

        // work out if we can get the data
        NSData* data = [[NSData alloc] initWithContentsOfFile:str];
        if(data == nil) {
            return nil;
        }

        // grab the image rep
        IJSVGImageRep* rep = [[IJSVGImageRep alloc] initWithData:data];
        NSImage* image = [[NSImage alloc] init];
        [image addRepresentation:rep];
        return image;
    }
    return nil;
#endif
}

@end
