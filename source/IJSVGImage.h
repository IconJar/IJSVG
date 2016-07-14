//
//  IJSVGImage.h
//  IJSVGExample
//
//  Created by Curtis Hard on 28/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGNode.h"

@class IJSVGPath;

@interface IJSVGImage : IJSVGNode {
    
    NSImage * image;
    CGImageRef CGImage;
    IJSVGPath * imagePath;
    
}

- (void)drawInContextRef:(CGContextRef)context
                    path:(IJSVGPath *)path;
- (void)loadFromBase64EncodedString:(NSString *)encodedString;

@end
