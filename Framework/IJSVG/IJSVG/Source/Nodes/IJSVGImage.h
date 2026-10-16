//
//  IJSVGImage.h
//  IJSVG
//
//  Created by Curtis Hard on 28/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGViewportNode.h>

#import <IJSVG/IJSVGReference.h>

NS_ASSUME_NONNULL_BEGIN

@class IJSVGPath;
@class IJSVG;

@interface IJSVGImage : IJSVGViewportNode <IJSVGReferenceNode> {
    CGImageRef CGImage;
}

@property (nonatomic, strong, nullable) IJSVGReference* reference;

// Embedded SVG content stays vector based until rendered.
@property (nonatomic, strong, readonly, nullable) IJSVG* embeddedSVG;
@property (nonatomic, readonly) CGSize intrinsicSize;
@property (nonatomic, readonly) CGRect intrinsicBounds;

// Retains the assigned image. Intrinsic size is measured in pixels.
@property (nonatomic, assign, nullable) CGImageRef CGImage;
@property (nonatomic, copy, readonly, nullable) NSData* sourceData;
@property (nonatomic, copy, readonly, nullable) NSString* sourceMIMEType;

- (CGImageRef _Nullable)CGImage CF_RETURNS_NOT_RETAINED;
- (void)loadFromString:(NSString*)encodedString;
- (void)loadFromURL:(NSURL*)aURL;

@end

NS_ASSUME_NONNULL_END
