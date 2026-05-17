//
//  IJSVGFilterEffectTurbulence.m
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffectTurbulence.h>
#import <IJSVG/IJSVGFilterGraph.h>

// ---------------------------------------------------------------------------
// SVG feTurbulence — Perlin noise per the SVG 1.1 specification.
// Reference: https://www.w3.org/TR/SVG11/filters.html#feTurbulenceElement
// ---------------------------------------------------------------------------

#define BSIZE 0x100
#define BM    0xff
#define N     0x1000

@implementation IJSVGFilterEffectTurbulence {
    int   _latticeSelector[BSIZE + BSIZE + 2];
    float _gradient[4][BSIZE + BSIZE + 2][2]; // 4 channels, each entry is a 2D gradient (float to match WebKit)
    BOOL  _tablesInitialized;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _baseFrequencyX = 0.0;
        _baseFrequencyY = 0.0;
        _numOctaves = 1;
        _seed = 0.0;
        _turbulenceType = IJSVGTurbulenceTypeTurbulence;
        _tablesInitialized = NO;
    }
    return self;
}

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    [super parseEffectAttributes:attributes];

    NSString* baseFreq = attributes[@"baseFrequency"];
    if (baseFreq.length > 0) {
        NSArray* components = [baseFreq componentsSeparatedByCharactersInSet:
                               [NSCharacterSet characterSetWithCharactersInString:@" ,"]];
        NSMutableArray* values = [NSMutableArray array];
        for (NSString* comp in components) {
            NSString* trimmed = [comp stringByTrimmingCharactersInSet:
                                 NSCharacterSet.whitespaceCharacterSet];
            if (trimmed.length > 0) {
                [values addObject:trimmed];
            }
        }
        if (values.count >= 1) {
            _baseFrequencyX = [values[0] doubleValue];
            _baseFrequencyY = _baseFrequencyX;
        }
        if (values.count >= 2) {
            _baseFrequencyY = [values[1] doubleValue];
        }
    }

    NSString* octaves = attributes[@"numOctaves"];
    if (octaves.length > 0) {
        _numOctaves = octaves.integerValue;
        if (_numOctaves < 1) _numOctaves = 1;
    }

    NSString* seedStr = attributes[@"seed"];
    if (seedStr.length > 0) {
        _seed = seedStr.doubleValue;
    }

    NSString* type = attributes[@"type"];
    if (type.length > 0) {
        if ([type caseInsensitiveCompare:@"fractalNoise"] == NSOrderedSame) {
            _turbulenceType = IJSVGTurbulenceTypeFractalNoise;
        } else {
            _turbulenceType = IJSVGTurbulenceTypeTurbulence;
        }
    }
}

// ---------------------------------------------------------------------------
#pragma mark - SVG spec PRNG and table setup
// ---------------------------------------------------------------------------

// Park-Miller LCG (Lehmer RNG) used by WebKit for feTurbulence.
// Uses Schrage decomposition to avoid overflow: a*seed mod m
// where a=16807, m=2^31-1, q=m/a=127773, r=m%a=2836.
static const long kRandMaximum = 2147483647L;  // 2^31 - 1
static const long kRandAmplitude = 16807L;      // 7^5
static const long kRandQ = 127773L;             // m / a
static const long kRandR = 2836L;               // m % a

static long _svgRandom(long lSeed)
{
    long result = kRandAmplitude * (lSeed % kRandQ) - kRandR * (lSeed / kRandQ);
    if (result <= 0)
        result += kRandMaximum;
    return result;
}

- (void)initializeTables
{
    if (_tablesInitialized) return;
    _tablesInitialized = YES;

    long lSeed = (long)_seed;
    // Clamp seed to [1, 2^31-2] to match WebKit's Park-Miller PRNG range.
    if (lSeed <= 0) lSeed = -(lSeed % (kRandMaximum - 1)) + 1;
    if (lSeed > kRandMaximum - 1) lSeed = kRandMaximum - 1;

    // Initialize gradient vectors for all 4 channels (R, G, B, A).
    // Per the SVG spec, gradients are generated first, then the
    // permutation table is initialized and shuffled once.
    for (int k = 0; k < 4; k++) {
        for (int i = 0; i < BSIZE; i++) {
            lSeed = _svgRandom(lSeed);
            _gradient[k][i][0] = (float)((lSeed % (BSIZE + BSIZE)) - BSIZE) / BSIZE;
            lSeed = _svgRandom(lSeed);
            _gradient[k][i][1] = (float)((lSeed % (BSIZE + BSIZE)) - BSIZE) / BSIZE;
            float s = hypotf(_gradient[k][i][0], _gradient[k][i][1]);
            if (s > 0.0f) {
                _gradient[k][i][0] /= s;
                _gradient[k][i][1] /= s;
            }
        }
    }

    // Initialize and shuffle the permutation table (Fisher-Yates, descending).
    // WebKit calls random() then uses the result: j = random() % BSize.
    for (int i = 0; i < BSIZE; i++) {
        _latticeSelector[i] = i;
    }
    for (int i = BSIZE - 1; i > 0; i--) {
        int k = _latticeSelector[i];
        lSeed = _svgRandom(lSeed);
        int j = (int)(lSeed % BSIZE);
        _latticeSelector[i] = _latticeSelector[j];
        _latticeSelector[j] = k;
    }

    // Duplicate for overflow
    for (int i = 0; i < BSIZE + 2; i++) {
        _latticeSelector[BSIZE + i] = _latticeSelector[i];
        for (int k = 0; k < 4; k++) {
            _gradient[k][BSIZE + i][0] = _gradient[k][i][0];
            _gradient[k][BSIZE + i][1] = _gradient[k][i][1];
        }
    }
}

// ---------------------------------------------------------------------------
#pragma mark - Noise evaluation (SVG spec algorithm)
// ---------------------------------------------------------------------------

static float _sCurve(float t) { return t * t * (3.0f - 2.0f * t); }
static float _lerp(float t, float a, float b) { return a + t * (b - a); }

- (float)noise2ForChannel:(int)channel x:(float)x y:(float)y
{
    float t = x + N;
    int bx0 = ((int)t) & BM;
    int bx1 = (bx0 + 1) & BM;
    float rx0 = t - (int)t;
    float rx1 = rx0 - 1.0f;

    t = y + N;
    int by0 = ((int)t) & BM;
    int by1 = (by0 + 1) & BM;
    float ry0 = t - (int)t;
    float ry1 = ry0 - 1.0f;

    int i = _latticeSelector[bx0];
    int j = _latticeSelector[bx1];

    int b00 = _latticeSelector[i + by0];
    int b10 = _latticeSelector[j + by0];
    int b01 = _latticeSelector[i + by1];
    int b11 = _latticeSelector[j + by1];

    float sx = _sCurve(rx0);
    float sy = _sCurve(ry0);

    float u, v;

    u = rx0 * _gradient[channel][b00][0] + ry0 * _gradient[channel][b00][1];
    v = rx1 * _gradient[channel][b10][0] + ry0 * _gradient[channel][b10][1];
    float a = _lerp(sx, u, v);

    u = rx0 * _gradient[channel][b01][0] + ry1 * _gradient[channel][b01][1];
    v = rx1 * _gradient[channel][b11][0] + ry1 * _gradient[channel][b11][1];
    float b = _lerp(sx, u, v);

    return _lerp(sy, a, b);
}

- (void)turbulenceAtX:(float)x y:(float)y result:(float[4])result
{
    BOOL isFractalNoise = (_turbulenceType == IJSVGTurbulenceTypeFractalNoise);

    for (int ch = 0; ch < 4; ch++) {
        result[ch] = 0.0f;
    }

    float ratio = 1.0f;
    for (NSInteger oct = 0; oct < _numOctaves; oct++) {
        for (int ch = 0; ch < 4; ch++) {
            float n = [self noise2ForChannel:ch
                                           x:x * (float)_baseFrequencyX * ratio
                                           y:y * (float)_baseFrequencyY * ratio];
            if (isFractalNoise) {
                result[ch] += n / ratio;
            } else {
                result[ch] += fabsf(n) / ratio;
            }
        }
        ratio *= 2.0f;
    }

    // Clamp to [0, 1]
    for (int ch = 0; ch < 4; ch++) {
        if (isFractalNoise) {
            result[ch] = (result[ch] + 1.0f) / 2.0f;
        }
        result[ch] = fmaxf(0.0f, fminf(1.0f, result[ch]));
    }
}

// ---------------------------------------------------------------------------
#pragma mark - Rendering
// ---------------------------------------------------------------------------

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    [self initializeTables];

    CGRect bounds = graph.sourceBounds;
    CGFloat scale = graph.scale;

    // sourceBounds is the CIImage extent in pixels — use directly without
    // multiplying by scale (the bitmap is already at device pixel resolution).
    NSInteger w = (NSInteger)CGRectGetWidth(bounds);
    NSInteger h = (NSInteger)CGRectGetHeight(bounds);
    if (w <= 0 || h <= 0) {
        CIImage* empty = [CIImage emptyImage];
        [graph setImage:empty forResult:self.resultName];
        return empty;
    }

    NSInteger bytesPerRow = w * 4;
    uint8_t* pixels = (uint8_t*)calloc(bytesPerRow * h, 1);
    if (pixels == NULL) {
        CIImage* empty = [CIImage emptyImage];
        [graph setImage:empty forResult:self.resultName];
        return empty;
    }

    // Map pixel coordinates to absolute SVG user-space using the element offset.
    // CIImage bitmaps are bottom-up (row 0 = bottom), so flip Y to match SVG's
    // top-down coordinate system.
    CGPoint svgOrigin = graph.elementSVGOrigin;
    for (NSInteger py = 0; py < h; py++) {
        for (NSInteger px = 0; px < w; px++) {
            float svgX = (float)(svgOrigin.x + (bounds.origin.x + (double)px) / scale);
            float svgY = (float)(svgOrigin.y + (bounds.origin.y + (double)(h - 1 - py)) / scale);

            float result[4];
            [self turbulenceAtX:svgX y:svgY result:result];

            NSInteger idx = (py * w + px) * 4;
            pixels[idx + 0] = (uint8_t)(result[0] * 255.0f + 0.5f);
            pixels[idx + 1] = (uint8_t)(result[1] * 255.0f + 0.5f);
            pixels[idx + 2] = (uint8_t)(result[2] * 255.0f + 0.5f);
            pixels[idx + 3] = (uint8_t)(result[3] * 255.0f + 0.5f);
        }
    }

    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    NSData* data = [NSData dataWithBytesNoCopy:pixels length:bytesPerRow * h freeWhenDone:YES];
    CIImage* output = [CIImage imageWithBitmapData:data
                                       bytesPerRow:bytesPerRow
                                              size:CGSizeMake(w, h)
                                            format:kCIFormatRGBA8
                                        colorSpace:cs];
    CGColorSpaceRelease(cs);

    // The bitmap is already in CG pixel space (same size as sourceBounds).
    // No scaling needed — the noise was sampled at SVG coordinates but stored
    // at pixel resolution to match other CIImages in the filter pipeline.

    [graph setImage:output forResult:self.resultName];
    return output;
}

@end
