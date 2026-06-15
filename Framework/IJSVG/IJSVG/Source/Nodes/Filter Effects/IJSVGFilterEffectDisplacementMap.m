//
//  IJSVGFilterEffectDisplacementMap.m
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffectDisplacementMap.h>
#import <IJSVG/IJSVGFilterGraph.h>

@implementation IJSVGFilterEffectDisplacementMap

- (instancetype)init
{
    self = [super init];
    if (self) {
        _scale = 0.0;
        _xChannelSelector = IJSVGChannelSelectorA;
        _yChannelSelector = IJSVGChannelSelectorA;
    }
    return self;
}

+ (IJSVGChannelSelector)channelSelectorForString:(NSString*)string
{
    if (string.length == 0) return IJSVGChannelSelectorA;
    NSString* lower = string.lowercaseString;
    if ([lower isEqualToString:@"r"]) return IJSVGChannelSelectorR;
    if ([lower isEqualToString:@"g"]) return IJSVGChannelSelectorG;
    if ([lower isEqualToString:@"b"]) return IJSVGChannelSelectorB;
    if ([lower isEqualToString:@"a"]) return IJSVGChannelSelectorA;
    return IJSVGChannelSelectorA;
}

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    [super parseEffectAttributes:attributes];

    NSString* scaleStr = attributes[@"scale"];
    if (scaleStr.length > 0) {
        _scale = scaleStr.doubleValue;
    }

    NSString* xChan = attributes[@"xChannelSelector"];
    if (xChan.length > 0) {
        _xChannelSelector = [IJSVGFilterEffectDisplacementMap channelSelectorForString:xChan];
    }

    NSString* yChan = attributes[@"yChannelSelector"];
    if (yChan.length > 0) {
        _yChannelSelector = [IJSVGFilterEffectDisplacementMap channelSelectorForString:yChan];
    }
}

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    CIImage* inputImage = [graph imageForInput:self.inputName];
    CIImage* displacementImage = [graph imageForInput:self.inputName2];

    if (inputImage == nil || displacementImage == nil || _scale == 0.0) {
        CIImage* result = inputImage ?: [CIImage emptyImage];
        [graph setImage:result forResult:self.resultName];
        return result;
    }

    CGFloat scaledAmount = _scale * graph.scale;

    // The filter region is the area we operate over. Use the displacement
    // map extent (which comes from the turbulence covering the full filter
    // region) intersected with an expanded source bounds.
    CGRect filterRegion = displacementImage.extent;
    if (CGRectIsInfinite(filterRegion)) {
        filterRegion = graph.sourceBounds;
    }

    CIImage* output = [self applyDisplacementToImage:inputImage
                                     displacementMap:displacementImage
                                               scale:scaledAmount
                                        filterRegion:filterRegion];

    [graph setImage:output forResult:self.resultName];
    return output;
}

- (CIImage*)applyDisplacementToImage:(CIImage*)input
                     displacementMap:(CIImage*)dispMap
                               scale:(CGFloat)scale
                        filterRegion:(CGRect)filterRegion
{
    CIContext* ctx = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];

    // Work over the filter region (not just the input extent).
    // This ensures we process all pixels where displacement can move
    // source pixels to, including areas outside the source bounds.
    NSInteger w = (NSInteger)CGRectGetWidth(filterRegion);
    NSInteger h = (NSInteger)CGRectGetHeight(filterRegion);
    if (w <= 0 || h <= 0) return input;

    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

    // Render displacement map over the filter region
    NSInteger bytesPerRow = w * 4;
    uint8_t* dispPixels = (uint8_t*)calloc(bytesPerRow * h, 1);
    if (dispPixels == NULL) {
        CGColorSpaceRelease(cs);
        return input;
    }

    CIImage* croppedDisp = [dispMap imageByCroppingToRect:filterRegion];
    [ctx render:croppedDisp
       toBitmap:dispPixels
       rowBytes:bytesPerRow
         bounds:filterRegion
         format:kCIFormatRGBA8
     colorSpace:cs];

    // Render the source image over an expanded region (filter region + scale padding)
    // so we can sample source pixels that are offset by displacement.
    // Do NOT clamp — pixels outside the source graphic must be transparent (RGBA=0).
    CGFloat absScale = fabs(scale);
    NSInteger padW = (NSInteger)(w + absScale * 2 + 2);
    NSInteger padH = (NSInteger)(h + absScale * 2 + 2);
    NSInteger padBytesPerRow = padW * 4;
    uint8_t* srcPixels = (uint8_t*)calloc(padBytesPerRow * padH, 1);
    if (srcPixels == NULL) {
        free(dispPixels);
        CGColorSpaceRelease(cs);
        return input;
    }

    CGFloat padOffX = absScale + 1;
    CGFloat padOffY = absScale + 1;
    CGRect srcRenderBounds = CGRectMake(filterRegion.origin.x - padOffX,
                                         filterRegion.origin.y - padOffY,
                                         padW, padH);

    // Crop the input to its own extent first — this ensures pixels outside
    // the source graphic remain zero (transparent), not clamped edge pixels.
    CIImage* croppedInput = [input imageByCroppingToRect:input.extent];
    [ctx render:croppedInput
       toBitmap:srcPixels
       rowBytes:padBytesPerRow
         bounds:srcRenderBounds
         format:kCIFormatRGBA8
     colorSpace:cs];

    // Create output bitmap
    uint8_t* outPixels = (uint8_t*)calloc(bytesPerRow * h, 1);
    if (outPixels == NULL) {
        free(dispPixels);
        free(srcPixels);
        CGColorSpaceRelease(cs);
        return input;
    }

    // Apply displacement per pixel.
    // SVG spec: P'(x,y) = P(x + scale*(XC(x,y) - 0.5), y + scale*(YC(x,y) - 0.5))
    for (NSInteger y = 0; y < h; y++) {
        for (NSInteger x = 0; x < w; x++) {
            NSInteger dispIdx = (y * w + x) * 4;

            CGFloat xChanVal = (CGFloat)dispPixels[dispIdx + _xChannelSelector] / 255.0;
            CGFloat yChanVal = (CGFloat)dispPixels[dispIdx + _yChannelSelector] / 255.0;

            CGFloat dx = scale * (xChanVal - 0.5);
            CGFloat dy = scale * (yChanVal - 0.5);

            // Map to padded source buffer coordinates
            CGFloat srcX = x + padOffX + dx;
            CGFloat srcY = y + padOffY + dy;

            // Bilinear interpolation
            NSInteger sx0 = (NSInteger)floor(srcX);
            NSInteger sy0 = (NSInteger)floor(srcY);
            NSInteger sx1 = sx0 + 1;
            NSInteger sy1 = sy0 + 1;
            CGFloat fx = srcX - sx0;
            CGFloat fy = srcY - sy0;

            NSInteger outIdx = (y * w + x) * 4;

            // If completely outside padded buffer, output transparent
            if (sx1 < 0 || sx0 >= padW || sy1 < 0 || sy0 >= padH) {
                outPixels[outIdx + 0] = 0;
                outPixels[outIdx + 1] = 0;
                outPixels[outIdx + 2] = 0;
                outPixels[outIdx + 3] = 0;
                continue;
            }

            // Clamp to padded buffer (edges are transparent from calloc)
            sx0 = MAX(0, MIN(sx0, padW - 1));
            sy0 = MAX(0, MIN(sy0, padH - 1));
            sx1 = MAX(0, MIN(sx1, padW - 1));
            sy1 = MAX(0, MIN(sy1, padH - 1));

            for (int c = 0; c < 4; c++) {
                CGFloat v00 = srcPixels[(sy0 * padW + sx0) * 4 + c];
                CGFloat v10 = srcPixels[(sy0 * padW + sx1) * 4 + c];
                CGFloat v01 = srcPixels[(sy1 * padW + sx0) * 4 + c];
                CGFloat v11 = srcPixels[(sy1 * padW + sx1) * 4 + c];
                CGFloat top = v00 + fx * (v10 - v00);
                CGFloat bot = v01 + fx * (v11 - v01);
                CGFloat val = top + fy * (bot - top);
                outPixels[outIdx + c] = (uint8_t)MAX(0, MIN(255, (int)round(val)));
            }
        }
    }

    NSData* outData = [NSData dataWithBytesNoCopy:outPixels
                                           length:bytesPerRow * h
                                     freeWhenDone:YES];
    CIImage* result = [CIImage imageWithBitmapData:outData
                                       bytesPerRow:bytesPerRow
                                              size:CGSizeMake(w, h)
                                            format:kCIFormatRGBA8
                                        colorSpace:cs];

    // Offset to match filter region origin
    if (filterRegion.origin.x != 0 || filterRegion.origin.y != 0) {
        result = [result imageByApplyingTransform:
                  CGAffineTransformMakeTranslation(filterRegion.origin.x, filterRegion.origin.y)];
    }

    free(dispPixels);
    free(srcPixels);
    CGColorSpaceRelease(cs);

    return result;
}

@end
