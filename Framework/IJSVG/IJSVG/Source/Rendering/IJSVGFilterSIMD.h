//
//  IJSVGFilterSIMD.h
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

// CPU filters for RGBA8 sRGB bitmaps owned by the renderer.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class IJSVGFilter;
@class IJSVGFilterGraph;

BOOL IJSVGFilterSIMDUsesBackdropAddition(IJSVGFilter* filter);

// Finite premultiplied linear component: 0 <= component <= alpha <= 1,
// with final crop coverage in [0, 1]. Returns the encoded sRGB output byte.
uint8_t IJSVGFilterSIMDEncodeLinearComponent(float component, float alpha,
                                             float coverage);

// Both contexts must be RGBA8 sRGB bitmaps owned by the renderer.
// Return NULL if the graph or pixel positions need the general calculation.
// The caller owns the returned image. Both input bitmaps stay unchanged.
CGImageRef IJSVGFilterSIMDNewComposite(CGContextRef source, CGContextRef backdrop,
                                       IJSVGFilterGraph* graph, CGRect region) CF_RETURNS_RETAINED;

// Small standalone matrices and sRGB composites of local inputs.
// Returns NULL when the general evaluator is required; source stays unchanged.
CGImageRef IJSVGFilterSIMDNewLocalFilter(CGContextRef source, IJSVGFilterGraph* graph,
                                         CGRect region) CF_RETURNS_RETAINED;

// Apply three box blurs to RGBA float buffers. Each size must be odd and at most 501.
// Keep transparent borders through every pass. Use separate buffers whose
// addresses are multiples of 16, like the NSMutableData buffers used by the renderer.
BOOL IJSVGFilterSIMDThreeBoxBlur(const float* source, float* output,
                                 NSUInteger width, NSUInteger height,
                                 const NSUInteger sides[3]);

// Interleaved float CPU blur. Source and output are separate, equally sized
// buffers with one or four channels; weights describe an odd symmetric kernel.
BOOL IJSVGFilterSIMDBlur(const float* source, float* output, NSUInteger width,
                         NSUInteger height, NSUInteger channels, NSData* weights);
