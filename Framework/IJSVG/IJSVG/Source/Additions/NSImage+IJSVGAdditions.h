//
//  NSImage+IJSVGAdditions.h
//  IJSVG
//
//  Created by Curtis Hard on 07/06/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IJSVG;

IJSVG* IJSVGGetFromNSImage(NSImage* image);

@interface NSImage (IJSVGAdditions)

+ (NSImage*)SVGImageNamed:(NSString*)imageName;

@end
