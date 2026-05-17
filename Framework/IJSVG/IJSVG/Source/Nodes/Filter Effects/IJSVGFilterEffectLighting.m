//
//  IJSVGFilterEffectLighting.m
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffectLighting.h>
#import <IJSVG/IJSVGFilterGraph.h>

// ---------------------------------------------------------------------------
// SVG feSpecularLighting / feDiffuseLighting implementation.
//
// Reference: https://www.w3.org/TR/SVG11/filters.html#feDiffuseLightingElement
//            https://www.w3.org/TR/SVG11/filters.html#feSpecularLightingElement
//
// Both filters use the alpha channel of the input as a height map, compute
// surface normals via the Sobel operator, then apply Phong lighting.
// ---------------------------------------------------------------------------

// sRGB → linear conversion per IEC 61966-2-1
static CGFloat _sRGBToLinear(CGFloat s)
{
    if (s <= 0.04045) return s / 12.92;
    return pow((s + 0.055) / 1.055, 2.4);
}

static void _parseColor(NSString* colorStr, CGFloat* r, CGFloat* g, CGFloat* b)
{
    *r = 1.0; *g = 1.0; *b = 1.0;
    if (colorStr.length == 0) return;

    NSString* str = [colorStr stringByTrimmingCharactersInSet:
                     NSCharacterSet.whitespaceCharacterSet].lowercaseString;

    if ([str hasPrefix:@"#"]) {
        unsigned int hex = 0;
        NSScanner* scanner = [NSScanner scannerWithString:[str substringFromIndex:1]];
        [scanner scanHexInt:&hex];
        if (str.length == 4) { // #RGB
            *r = ((hex >> 8) & 0xF) / 15.0;
            *g = ((hex >> 4) & 0xF) / 15.0;
            *b = (hex & 0xF) / 15.0;
        } else { // #RRGGBB
            *r = ((hex >> 16) & 0xFF) / 255.0;
            *g = ((hex >> 8) & 0xFF) / 255.0;
            *b = (hex & 0xFF) / 255.0;
        }
    } else if ([str isEqualToString:@"white"]) {
        *r = 1; *g = 1; *b = 1;
    } else if ([str isEqualToString:@"black"]) {
        *r = 0; *g = 0; *b = 0;
    }
    // Add more named colors as needed

    // SVG color-interpolation-filters defaults to linearRGB.
    // Convert parsed sRGB values to linear for filter computations.
    *r = _sRGBToLinear(*r);
    *g = _sRGBToLinear(*g);
    *b = _sRGBToLinear(*b);
}

@implementation IJSVGFilterEffectLighting

- (instancetype)init
{
    self = [super init];
    if (self) {
        _surfaceScale = 1.0;
        _lightColorR = 1.0;
        _lightColorG = 1.0;
        _lightColorB = 1.0;
        _lightType = IJSVGLightTypeDistant;
        _azimuth = 0.0;
        _elevation = 0.0;
        _spotExponent = 1.0;
        _limitingConeAngle = 180.0;
    }
    return self;
}

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    [super parseEffectAttributes:attributes];

    NSString* ss = attributes[@"surfaceScale"];
    if (ss.length > 0) _surfaceScale = ss.doubleValue;

    NSString* lc = attributes[@"lighting-color"];
    if (lc.length > 0) {
        _parseColor(lc, &_lightColorR, &_lightColorG, &_lightColorB);
    }
}

- (void)parseLightSourceFromChildren:(NSArray*)children attributes:(NSDictionary*)attrs
{
    // Light source elements are parsed as child nodes by the IJSVG parser.
    // However, since we receive attributes as a flat dict, the light source
    // attributes may be passed via a secondary mechanism. For now, we handle
    // them via a post-parse step where the parser provides nested element data.
    //
    // This is handled by parseChildElement: below.
}

- (void)parseLightSourceElement:(NSString*)elementName
                     attributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    NSString* name = elementName.lowercaseString;

    if ([name isEqualToString:@"fepointlight"]) {
        _lightType = IJSVGLightTypePoint;
        NSString* x = attributes[@"x"];
        NSString* y = attributes[@"y"];
        NSString* z = attributes[@"z"];
        if (x.length > 0) _lightX = x.doubleValue;
        if (y.length > 0) _lightY = y.doubleValue;
        if (z.length > 0) _lightZ = z.doubleValue;
    } else if ([name isEqualToString:@"fedistantlight"]) {
        _lightType = IJSVGLightTypeDistant;
        NSString* az = attributes[@"azimuth"];
        NSString* el = attributes[@"elevation"];
        if (az.length > 0) _azimuth = az.doubleValue;
        if (el.length > 0) _elevation = el.doubleValue;
    } else if ([name isEqualToString:@"fespotlight"]) {
        _lightType = IJSVGLightTypeSpot;
        NSString* x = attributes[@"x"];
        NSString* y = attributes[@"y"];
        NSString* z = attributes[@"z"];
        if (x.length > 0) _lightX = x.doubleValue;
        if (y.length > 0) _lightY = y.doubleValue;
        if (z.length > 0) _lightZ = z.doubleValue;
        NSString* px = attributes[@"pointsAtX"];
        NSString* py = attributes[@"pointsAtY"];
        NSString* pz = attributes[@"pointsAtZ"];
        if (px.length > 0) _pointsAtX = px.doubleValue;
        if (py.length > 0) _pointsAtY = py.doubleValue;
        if (pz.length > 0) _pointsAtZ = pz.doubleValue;
        NSString* se = attributes[@"specularExponent"];
        if (se.length > 0) _spotExponent = se.doubleValue;
        NSString* lca = attributes[@"limitingConeAngle"];
        if (lca.length > 0) _limitingConeAngle = lca.doubleValue;
    }
}

- (uint8_t*)renderInputToBitmapWithGraph:(IJSVGFilterGraph*)graph
                                   width:(NSInteger*)outW
                                  height:(NSInteger*)outH
{
    CIImage* input = [graph imageForInput:self.inputName];
    if (input == nil) {
        *outW = 0; *outH = 0;
        return NULL;
    }

    CGRect bounds = input.extent;
    if (CGRectIsInfinite(bounds)) bounds = graph.sourceBounds;

    NSInteger w = (NSInteger)CGRectGetWidth(bounds);
    NSInteger h = (NSInteger)CGRectGetHeight(bounds);
    if (w <= 0 || h <= 0) {
        *outW = 0; *outH = 0;
        return NULL;
    }

    NSInteger bytesPerRow = w * 4;
    uint8_t* pixels = (uint8_t*)calloc(bytesPerRow * h, 1);
    if (pixels == NULL) {
        *outW = 0; *outH = 0;
        return NULL;
    }

    CIContext* ctx = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceLinearSRGB);
    [ctx render:input toBitmap:pixels rowBytes:bytesPerRow bounds:bounds
         format:kCIFormatRGBA8 colorSpace:cs];
    CGColorSpaceRelease(cs);

    // CIContext renders bottom-up (CG convention). Flip to top-down (SVG convention)
    // so that pixel row 0 corresponds to the top of the image.
    uint8_t* rowBuf = (uint8_t*)malloc(bytesPerRow);
    for (NSInteger top = 0, bot = h - 1; top < bot; top++, bot--) {
        memcpy(rowBuf, pixels + top * bytesPerRow, bytesPerRow);
        memcpy(pixels + top * bytesPerRow, pixels + bot * bytesPerRow, bytesPerRow);
        memcpy(pixels + bot * bytesPerRow, rowBuf, bytesPerRow);
    }
    free(rowBuf);

    *outW = w;
    *outH = h;
    return pixels;
}

// Sobel-based surface normal computation from the alpha channel height map.
// The SVG spec uses a specific kernel for interior, edge, and corner pixels.
- (void)computeNormalAtX:(NSInteger)x y:(NSInteger)y
                  pixels:(const uint8_t*)pixels
                   width:(NSInteger)w height:(NSInteger)h
                   scale:(CGFloat)bitmapScale
                      nx:(CGFloat*)nx ny:(CGFloat*)ny nz:(CGFloat*)nz
{
    // Helper to get alpha value at (px, py) clamped to bounds
    #define ALPHA(px, py) ({ \
        NSInteger cx = MAX(0, MIN((px), w - 1)); \
        NSInteger cy = MAX(0, MIN((py), h - 1)); \
        (CGFloat)pixels[(cy * w + cx) * 4 + 3] / 255.0; \
    })

    // SVG spec Sobel kernel factors (in filter pixel space).
    CGFloat f4 = 1.0 / 4.0; // interior
    CGFloat f3 = 1.0 / 3.0; // edge (one direction)
    CGFloat f2 = 1.0 / 2.0; // edge (other direction), divided by 3 below
    CGFloat fc = 2.0 / 3.0; // corner

    CGFloat dx, dy;

    if (x == 0 && y == 0) {
        dx = fc * (ALPHA(1,0) - ALPHA(0,0) + ALPHA(1,1) - ALPHA(0,1));
        dy = fc * (ALPHA(0,1) - ALPHA(0,0) + ALPHA(1,1) - ALPHA(1,0));
    } else if (x == w-1 && y == 0) {
        dx = fc * (ALPHA(w-1,0) - ALPHA(w-2,0) + ALPHA(w-1,1) - ALPHA(w-2,1));
        dy = fc * (ALPHA(w-2,1) - ALPHA(w-2,0) + ALPHA(w-1,1) - ALPHA(w-1,0));
    } else if (x == 0 && y == h-1) {
        dx = fc * (ALPHA(1,h-2) - ALPHA(0,h-2) + ALPHA(1,h-1) - ALPHA(0,h-1));
        dy = fc * (ALPHA(0,h-1) - ALPHA(0,h-2) + ALPHA(1,h-1) - ALPHA(1,h-2));
    } else if (x == w-1 && y == h-1) {
        dx = fc * (ALPHA(w-1,h-2) - ALPHA(w-2,h-2) + ALPHA(w-1,h-1) - ALPHA(w-2,h-1));
        dy = fc * (ALPHA(w-2,h-1) - ALPHA(w-2,h-2) + ALPHA(w-1,h-1) - ALPHA(w-1,h-2));
    } else if (y == 0) {
        dx = f3 * (ALPHA(x+1,0) - ALPHA(x-1,0) + ALPHA(x+1,1) - ALPHA(x-1,1));
        dy = f2 * (ALPHA(x-1,1) - ALPHA(x-1,0) + 2*(ALPHA(x,1) - ALPHA(x,0)) + ALPHA(x+1,1) - ALPHA(x+1,0)) / 3.0;
    } else if (y == h-1) {
        dx = f3 * (ALPHA(x+1,h-2) - ALPHA(x-1,h-2) + ALPHA(x+1,h-1) - ALPHA(x-1,h-1));
        dy = f2 * (ALPHA(x-1,h-1) - ALPHA(x-1,h-2) + 2*(ALPHA(x,h-1) - ALPHA(x,h-2)) + ALPHA(x+1,h-1) - ALPHA(x+1,h-2)) / 3.0;
    } else if (x == 0) {
        dx = f2 * (ALPHA(1,y-1) - ALPHA(0,y-1) + 2*(ALPHA(1,y) - ALPHA(0,y)) + ALPHA(1,y+1) - ALPHA(0,y+1)) / 3.0;
        dy = f3 * (ALPHA(0,y+1) - ALPHA(0,y-1) + ALPHA(1,y+1) - ALPHA(1,y-1));
    } else if (x == w-1) {
        dx = f2 * (ALPHA(w-1,y-1) - ALPHA(w-2,y-1) + 2*(ALPHA(w-1,y) - ALPHA(w-2,y)) + ALPHA(w-1,y+1) - ALPHA(w-2,y+1)) / 3.0;
        dy = f3 * (ALPHA(w-2,y+1) - ALPHA(w-2,y-1) + ALPHA(w-1,y+1) - ALPHA(w-1,y-1));
    } else {
        // Interior pixel — standard Sobel
        dx = f4 * (
            -ALPHA(x-1,y-1) + ALPHA(x+1,y-1)
            -2*ALPHA(x-1,y) + 2*ALPHA(x+1,y)
            -ALPHA(x-1,y+1) + ALPHA(x+1,y+1)
        );
        dy = f4 * (
            -ALPHA(x-1,y-1) - 2*ALPHA(x,y-1) - ALPHA(x+1,y-1)
            +ALPHA(x-1,y+1) + 2*ALPHA(x,y+1) + ALPHA(x+1,y+1)
        );
    }

    #undef ALPHA

    // Normal = (-surfaceScale * dx, -surfaceScale * dy, 1)
    CGFloat ssx = -_surfaceScale * dx;
    CGFloat ssy = -_surfaceScale * dy;
    CGFloat len = sqrt(ssx * ssx + ssy * ssy + 1.0);
    *nx = ssx / len;
    *ny = ssy / len;
    *nz = 1.0 / len;
}

- (void)lightDirectionAtSvgX:(CGFloat)sx svgY:(CGFloat)sy
                    surfaceZ:(CGFloat)sz
                          lx:(CGFloat*)lx ly:(CGFloat*)ly lz:(CGFloat*)lz
{
    switch (_lightType) {
        case IJSVGLightTypeDistant: {
            CGFloat azRad = _azimuth * M_PI / 180.0;
            CGFloat elRad = _elevation * M_PI / 180.0;
            *lx = cos(azRad) * cos(elRad);
            *ly = sin(azRad) * cos(elRad);
            *lz = sin(elRad);
            break;
        }
        case IJSVGLightTypePoint:
        case IJSVGLightTypeSpot: {
            // Both sx,sy and lightX,lightY are in SVG user-space coordinates
            CGFloat dx = _lightX - sx;
            CGFloat dy = _lightY - sy;
            CGFloat dz = _lightZ - sz;
            CGFloat len = sqrt(dx*dx + dy*dy + dz*dz);
            if (len > 0.0) {
                *lx = dx / len;
                *ly = dy / len;
                *lz = dz / len;
            } else {
                *lx = 0; *ly = 0; *lz = 1;
            }
            break;
        }
    }
}

@end

// ---------------------------------------------------------------------------
#pragma mark - feSpecularLighting
// ---------------------------------------------------------------------------

@implementation IJSVGFilterEffectSpecularLighting

- (instancetype)init
{
    self = [super init];
    if (self) {
        _specularConstant = 1.0;
        _specularExponent = 1.0;
    }
    return self;
}

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    [super parseEffectAttributes:attributes];

    NSString* ks = attributes[@"specularConstant"];
    if (ks.length > 0) _specularConstant = ks.doubleValue;

    NSString* se = attributes[@"specularExponent"];
    if (se.length > 0) _specularExponent = se.doubleValue;
}

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    NSInteger w = 0, h = 0;
    uint8_t* inputPixels = [self renderInputToBitmapWithGraph:graph width:&w height:&h];
    if (inputPixels == NULL || w <= 0 || h <= 0) {
        CIImage* empty = [CIImage emptyImage];
        [graph setImage:empty forResult:self.resultName];
        if (inputPixels) free(inputPixels);
        return empty;
    }

    CIImage* input = [graph imageForInput:self.inputName];
    CGRect bounds = input.extent;
    if (CGRectIsInfinite(bounds)) bounds = graph.sourceBounds;

    NSInteger bytesPerRow = w * 4;
    uint8_t* outPixels = (uint8_t*)calloc(bytesPerRow * h, 1);
    if (outPixels == NULL) {
        free(inputPixels);
        CIImage* empty = [CIImage emptyImage];
        [graph setImage:empty forResult:self.resultName];
        return empty;
    }

    // Eye vector (SVG spec: always (0, 0, 1) for infinite viewpoint)
    CGFloat ex = 0, ey = 0, ez = 1;

    // Convert bitmap pixel positions to SVG user-space coordinates.
    // The input CIImage extent may differ from sourceBounds (e.g., blur extends it).
    // CG pixel for flipped bitmap (x, y): (bounds.origin.x + x, bounds.origin.y + h - y)
    // SVG mapping uses the source graphic's CG space as reference:
    //   svgX = svgOrigin.x + (bounds.origin.x + x) / scale
    //   svgY = svgOrigin.y + (sourceBmpH - bounds.origin.y - bounds.size.height + y) / scale
    CGFloat scale = graph.scale;
    CGPoint svgOrigin = graph.elementSVGOrigin;
    CGFloat sourceBmpH = graph.sourceBounds.size.height;
    CGFloat bmpOffX = bounds.origin.x;
    CGFloat bmpOffY = sourceBmpH - bounds.origin.y - bounds.size.height;

    for (NSInteger y = 0; y < h; y++) {
        for (NSInteger x = 0; x < w; x++) {
            CGFloat normalX, normalY, normalZ;
            [self computeNormalAtX:x y:y pixels:inputPixels width:w height:h
                               scale:scale nx:&normalX ny:&normalY nz:&normalZ];

            CGFloat alpha = (CGFloat)inputPixels[(y * w + x) * 4 + 3] / 255.0;
            CGFloat surfZ = self.surfaceScale * alpha;

            CGFloat svgX = svgOrigin.x + (bmpOffX + (CGFloat)x) / scale;
            CGFloat svgY = svgOrigin.y + (bmpOffY + (CGFloat)y) / scale;

            CGFloat lx, ly, lz;
            [self lightDirectionAtSvgX:svgX svgY:svgY
                              surfaceZ:surfZ lx:&lx ly:&ly lz:&lz];

            // Half vector H = normalize(L + E)
            CGFloat hx = lx + ex;
            CGFloat hy = ly + ey;
            CGFloat hz = lz + ez;
            CGFloat hLen = sqrt(hx*hx + hy*hy + hz*hz);
            if (hLen > 0) { hx /= hLen; hy /= hLen; hz /= hLen; }

            // N dot H
            CGFloat nDotH = normalX * hx + normalY * hy + normalZ * hz;
            nDotH = fmax(0.0, nDotH);

            CGFloat spec = _specularConstant * pow(nDotH, _specularExponent);
            spec = fmax(0.0, fmin(1.0, spec));
            NSInteger idx = (y * w + x) * 4;
            // SVG spec: output color = ks * (N dot H)^se * lightColor
            // Output alpha = max(R, G, B)
            CGFloat r = fmin(1.0, spec * self.lightColorR);
            CGFloat g = fmin(1.0, spec * self.lightColorG);
            CGFloat b = fmin(1.0, spec * self.lightColorB);
            CGFloat a = fmax(r, fmax(g, b));

            outPixels[idx + 0] = (uint8_t)(r * 255.0 + 0.5);
            outPixels[idx + 1] = (uint8_t)(g * 255.0 + 0.5);
            outPixels[idx + 2] = (uint8_t)(b * 255.0 + 0.5);
            outPixels[idx + 3] = (uint8_t)(a * 255.0 + 0.5);
        }
    }

    free(inputPixels);

    // Flip output back to CG bottom-up convention for CIImage
    {
        uint8_t* rowBuf = (uint8_t*)malloc(bytesPerRow);
        for (NSInteger top = 0, bot = h - 1; top < bot; top++, bot--) {
            memcpy(rowBuf, outPixels + top * bytesPerRow, bytesPerRow);
            memcpy(outPixels + top * bytesPerRow, outPixels + bot * bytesPerRow, bytesPerRow);
            memcpy(outPixels + bot * bytesPerRow, rowBuf, bytesPerRow);
        }
        free(rowBuf);
    }

    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceLinearSRGB);
    NSData* data = [NSData dataWithBytesNoCopy:outPixels length:bytesPerRow * h freeWhenDone:YES];
    CIImage* output = [CIImage imageWithBitmapData:data bytesPerRow:bytesPerRow
                                              size:CGSizeMake(w, h)
                                            format:kCIFormatRGBA8 colorSpace:cs];
    CGColorSpaceRelease(cs);

    if (bounds.origin.x != 0 || bounds.origin.y != 0) {
        output = [output imageByApplyingTransform:
                  CGAffineTransformMakeTranslation(bounds.origin.x, bounds.origin.y)];
    }

    [graph setImage:output forResult:self.resultName];
    return output;
}

@end

// ---------------------------------------------------------------------------
#pragma mark - feDiffuseLighting
// ---------------------------------------------------------------------------

@implementation IJSVGFilterEffectDiffuseLighting

- (instancetype)init
{
    self = [super init];
    if (self) {
        _diffuseConstant = 1.0;
    }
    return self;
}

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    [super parseEffectAttributes:attributes];

    NSString* kd = attributes[@"diffuseConstant"];
    if (kd.length > 0) _diffuseConstant = kd.doubleValue;
}

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    NSInteger w = 0, h = 0;
    uint8_t* inputPixels = [self renderInputToBitmapWithGraph:graph width:&w height:&h];
    if (inputPixels == NULL || w <= 0 || h <= 0) {
        CIImage* empty = [CIImage emptyImage];
        [graph setImage:empty forResult:self.resultName];
        if (inputPixels) free(inputPixels);
        return empty;
    }

    CIImage* input = [graph imageForInput:self.inputName];
    CGRect bounds = input.extent;
    if (CGRectIsInfinite(bounds)) bounds = graph.sourceBounds;

    NSInteger bytesPerRow = w * 4;
    uint8_t* outPixels = (uint8_t*)calloc(bytesPerRow * h, 1);
    if (outPixels == NULL) {
        free(inputPixels);
        CIImage* empty = [CIImage emptyImage];
        [graph setImage:empty forResult:self.resultName];
        return empty;
    }

    CGFloat scale = graph.scale;
    CGPoint svgOrigin = graph.elementSVGOrigin;
    CGFloat sourceBmpH_d = graph.sourceBounds.size.height;
    CGFloat bmpOffX_d = bounds.origin.x;
    CGFloat bmpOffY_d = sourceBmpH_d - bounds.origin.y - bounds.size.height;

    for (NSInteger y = 0; y < h; y++) {
        for (NSInteger x = 0; x < w; x++) {
            CGFloat normalX, normalY, normalZ;
            [self computeNormalAtX:x y:y pixels:inputPixels width:w height:h
                               scale:scale nx:&normalX ny:&normalY nz:&normalZ];

            CGFloat alpha = (CGFloat)inputPixels[(y * w + x) * 4 + 3] / 255.0;
            CGFloat surfZ = self.surfaceScale * alpha;

            CGFloat svgX = svgOrigin.x + (bmpOffX_d + (CGFloat)x) / scale;
            CGFloat svgY = svgOrigin.y + (bmpOffY_d + (CGFloat)y) / scale;

            CGFloat lx, ly, lz;
            [self lightDirectionAtSvgX:svgX svgY:svgY
                           surfaceZ:surfZ lx:&lx ly:&ly lz:&lz];

            // N dot L
            CGFloat nDotL = normalX * lx + normalY * ly + normalZ * lz;
            nDotL = fmax(0.0, nDotL);

            CGFloat diff = _diffuseConstant * nDotL;
            diff = fmax(0.0, fmin(1.0, diff));

            NSInteger idx = (y * w + x) * 4;
            // SVG spec: output = kd * (N dot L) * lightColor, alpha = 1
            CGFloat r = fmin(1.0, diff * self.lightColorR);
            CGFloat g = fmin(1.0, diff * self.lightColorG);
            CGFloat b = fmin(1.0, diff * self.lightColorB);

            outPixels[idx + 0] = (uint8_t)(r * 255.0 + 0.5);
            outPixels[idx + 1] = (uint8_t)(g * 255.0 + 0.5);
            outPixels[idx + 2] = (uint8_t)(b * 255.0 + 0.5);
            outPixels[idx + 3] = 255; // diffuse always opaque
        }
    }

    free(inputPixels);

    // Flip output back to CG bottom-up convention for CIImage
    {
        uint8_t* rowBuf = (uint8_t*)malloc(bytesPerRow);
        for (NSInteger top = 0, bot = h - 1; top < bot; top++, bot--) {
            memcpy(rowBuf, outPixels + top * bytesPerRow, bytesPerRow);
            memcpy(outPixels + top * bytesPerRow, outPixels + bot * bytesPerRow, bytesPerRow);
            memcpy(outPixels + bot * bytesPerRow, rowBuf, bytesPerRow);
        }
        free(rowBuf);
    }

    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceLinearSRGB);
    NSData* data = [NSData dataWithBytesNoCopy:outPixels length:bytesPerRow * h freeWhenDone:YES];
    CIImage* output = [CIImage imageWithBitmapData:data bytesPerRow:bytesPerRow
                                              size:CGSizeMake(w, h)
                                            format:kCIFormatRGBA8 colorSpace:cs];
    CGColorSpaceRelease(cs);

    if (bounds.origin.x != 0 || bounds.origin.y != 0) {
        output = [output imageByApplyingTransform:
                  CGAffineTransformMakeTranslation(bounds.origin.x, bounds.origin.y)];
    }

    [graph setImage:output forResult:self.resultName];
    return output;
}

@end
