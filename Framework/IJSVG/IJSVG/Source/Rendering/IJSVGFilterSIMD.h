// CPU filter kernels for renderer-owned RGBA8 sRGB bitmaps.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class IJSVGFilter;
@class IJSVGFilterGraph;

BOOL IJSVGFilterSIMDUsesBackdropAddition(IJSVGFilter* filter);

// Both contexts must be renderer-owned RGBA8 sRGB bitmaps. Returns NULL when
// the graph or pixel mapping requires the general evaluator. The caller owns
// the returned image; neither input bitmap is modified.
CGImageRef IJSVGFilterSIMDNewComposite(CGContextRef source,
                                     CGContextRef backdrop,
                                     IJSVGFilterGraph* graph,
                                     CGRect region) CF_RETURNS_RETAINED;

// Fused three-box kernel for RGBA float buffers. Each side is odd and <=501.
// Transparent borders are retained through all passes. Buffers must be
// separate and 16-byte aligned, as with renderer-owned NSMutableData storage.
BOOL IJSVGFilterSIMDThreeBoxBlur(const float* source, float* output,
                                NSUInteger width, NSUInteger height,
                                const NSUInteger sides[3]);

// Interleaved float CPU blur. Source and output are separate, equally sized
// buffers with one or four channels; weights describe an odd symmetric kernel.
BOOL IJSVGFilterSIMDBlur(const float* source, float* output,
                        NSUInteger width, NSUInteger height,
                        NSUInteger channels, NSData* weights);
