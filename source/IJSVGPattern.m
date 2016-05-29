//
//  IJSVGPattern.m
//  IJSVGExample
//
//  Created by Curtis Hard on 27/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGPattern.h"

@implementation IJSVGPattern

- (void)drawInContextRef:(CGContextRef)context
                    path:(IJSVGPath *)path
{
    // currently only support images
    for(IJSVGImage * image in self.children) {
        [image drawInContextRef:context
                           path:path];
    }
}

@end
