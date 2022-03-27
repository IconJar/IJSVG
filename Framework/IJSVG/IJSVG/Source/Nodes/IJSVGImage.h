//
//  IJSVGImage.h
//  IJSVGExample
//
//  Created by Curtis Hard on 28/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <Foundation/Foundation.h>

@class IJSVGPath;

@interface IJSVGImage : IJSVGNode {

    NSImage* image;
    CGImageRef CGImage;
    IJSVGPath* imagePath;
}

@property (nonatomic, readonly) CGSize intrinsicSize;
@property (nonatomic, readonly) CGRect intrinsicBounds;
@property (nonatomic, readonly) CGAffineTransform intrinsicTransform;

- (CGImageRef)CGImage;
- (void)loadFromString:(NSString*)encodedString;
- (void)loadFromURL:(NSURL*)aURL;

@end
