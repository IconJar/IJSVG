//
//  IJSVGImage.h
//  IJSVG
//
//  Created by Curtis Hard on 28/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class IJSVGPath;

@interface IJSVGImage : IJSVGNode {
    CGImageRef CGImage;
}

@property (nonatomic, readonly) CGSize intrinsicSize;
@property (nonatomic, readonly) CGRect intrinsicBounds;
@property (nonatomic, strong, nullable) XImage* image;
@property (nonatomic, copy, readonly, nullable) NSData* sourceData;
@property (nonatomic, copy, readonly, nullable) NSString* sourceMIMEType;

- (CGImageRef _Nullable)CGImage CF_RETURNS_NOT_RETAINED;
- (void)loadFromString:(NSString*)encodedString;
- (void)loadFromURL:(NSURL*)aURL;

@end

NS_ASSUME_NONNULL_END
