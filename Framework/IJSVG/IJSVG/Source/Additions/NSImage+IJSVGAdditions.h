//
//  NSImage+IJSVGAdditions.h
//  IJSVG
//
//  Created by Curtis Hard on 07/06/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>

IJSVG* IJSVGGetFromNSImage(NSImage* image);

@interface NSImage (IJSVGAdditions)

+ (NSImage*)SVGImageNamed:(NSString*)imageName;

@end
