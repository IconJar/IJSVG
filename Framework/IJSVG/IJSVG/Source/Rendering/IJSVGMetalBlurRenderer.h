//
//  IJSVGMetalBlurRenderer.h
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// Jobs own their source pixels and completed image; scratch buffers are never exposed.
@interface IJSVGMetalBlurJob : NSObject
@property (nonatomic, readonly) CGImageRef renderedImage;
@end

@interface IJSVGMetalBlurRenderer : NSObject
+ (IJSVGMetalBlurJob*)jobForBitmap:(CGContextRef)bitmap
                          region:(CGRect)region
                         weights:(NSData*)weights
                       linearRGB:(BOOL)linearRGB
                     sourceCrops:(NSUInteger)sourceCrops;
+ (IJSVGMetalBlurJob*)shadowJobForBitmap:(CGContextRef)bitmap
                                region:(CGRect)region
                               weights:(NSData*)weights
                             linearRGB:(BOOL)linearRGB
                                offset:(CGSize)offset
                                 color:(CGColorRef)color;
+ (BOOL)renderJobs:(NSArray<IJSVGMetalBlurJob*>*)jobs;

// NULL leaves the caller on its existing evaluator.
+ (CGImageRef)newImageForBitmap:(CGContextRef)bitmap
                        region:(CGRect)region
                       weights:(NSData*)weights
                     linearRGB:(BOOL)linearRGB
                   sourceCrops:(NSUInteger)sourceCrops CF_RETURNS_RETAINED;
@end
