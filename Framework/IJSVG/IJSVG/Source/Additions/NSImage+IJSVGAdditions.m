//
//  NSImage+IJSVGAdditions.m
//  IJSVG
//
//  Created by Curtis Hard on 07/06/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGImageRep.h>
#import <IJSVG/NSImage+IJSVGAdditions.h>

IJSVG* IJSVGGetFromNSImage(NSImage* image)
{
    for (NSImageRep* rep in image.representations) {
        if([rep isKindOfClass:IJSVGImageRep.class]) {
            return ((IJSVGImageRep*)rep).SVG;
        }
    }
    return nil;
}

@implementation NSImage (IJSVGAdditions)

+ (NSImage*)SVGImageNamed:(NSString*)imageName
{
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
}

@end
