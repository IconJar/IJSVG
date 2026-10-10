//
//  IJSVGFilterContext.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGRendering.h>
#import <CoreImage/CoreImage.h>

@interface IJSVGFilterContext : NSObject

@property (nonatomic, strong) IJSVGFilter* filter;
@property (nonatomic, copy) IJSVGRenderingOptions* renderingOptions;
@property (nonatomic, assign) CGRect boundingBox;
@property (nonatomic, assign) CGRect viewPort;
@property (nonatomic, assign) CGRect extent;
@property (nonatomic, assign) CGAffineTransform imageTransform;
@property (nonatomic, strong) CIContext* context;
@property (nonatomic, assign) BOOL supportsMetalKernels;
@property (nonatomic, assign) BOOL linearRGB;
@property (nonatomic, assign) BOOL inputIsAlphaOnly;
@property (nonatomic, assign) BOOL outputIsAlphaOnly;
@property (nonatomic, copy) CIImage* (^imageProvider)(IJSVGFilterPrimitive* primitive, CGRect region);

- (CGSize)pixelUnits;
- (NSMutableData*)pixelsForImage:(CIImage*)image;
- (CIImage*)imageForPixels:(NSData*)pixels;
- (CIImage*)imageForPixels:(NSData*)pixels
                    bounds:(CGRect)bounds;

// Restrict effects that do not read neighbouring pixels to their output region.
- (CIImage*)mapImage:(CIImage*)image
               other:(CIImage*)other
              region:(CGRect)region
           operation:(void (^)(const float*, const float*, float*, NSInteger, NSInteger))operation;
- (CIImage*)mapImage:(CIImage*)image
               other:(CIImage*)other
           operation:(void (^)(const float*, const float*, float*, NSInteger, NSInteger))operation;
- (CIImage*)imageInPrimitiveColorSpace:(CIImage*)image;
- (CIImage*)imageFromPrimitiveColorSpace:(CIImage*)image;
- (CIImage*)applyFilter:(NSString*)name
                toImage:(CIImage*)image
             parameters:(NSDictionary*)parameters;
- (CIImage*)alphaForImage:(CIImage*)image;
- (CIImage*)offsetImage:(CIImage*)input
                     dx:(CGFloat)dx
                     dy:(CGFloat)dy;
- (CIImage*)floodWithColor:(NSColor*)color
                   opacity:(CGFloat)opacity;

@end

// Load Metal source from the framework. Return nil if it cannot be read.
NSString* IJSVGFilterShaderSource(NSString* name);

void IJSVGFilterApplyRows(NSInteger width, NSInteger height, void (^operation)(NSInteger, NSInteger));

float IJSVGFilterClamp(double value);
BOOL IJSVGFilterValidRect(CGRect rect);
float IJSVGFilterSample(const float* pixels, NSInteger width, NSInteger height,
                        CGFloat x, CGFloat y, NSUInteger channel, CGRect region,
                        IJSVGFilterEdgeMode edgeMode);

typedef struct {
    const float* pixels;
    NSInteger width;
    NSInteger left;
    NSInteger top;
    NSInteger right;
    NSInteger bottom;
    IJSVGFilterEdgeMode edgeMode;
} IJSVGFilterSampler;

IJSVGFilterSampler IJSVGFilterSamplerMake(const float* pixels, NSInteger width, NSInteger height,
    CGRect region, IJSVGFilterEdgeMode edgeMode);
float IJSVGFilterSamplerValue(const IJSVGFilterSampler* sampler, CGFloat x, CGFloat y, NSUInteger channel);
void IJSVGFilterSamplerPixel(const IJSVGFilterSampler* sampler, CGFloat x, CGFloat y, float pixel[4]);
