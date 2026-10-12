//
//  IJSVGParser.m
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGText.h>
#import <IJSVGSwitch.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVGStyleSheetUtils.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVGParserUtils.h>
#import <IJSVGCSSParser.h>
#import <IJSVGCSSVariables.h>
#import <IJSVGParsedPathCache.h>
#import <IJSVGParserTextUtils.h>
#import <IJSVG/IJSVGFilterPrimitive.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGUnitPoint.h>
#import <IJSVG/IJSVGThreadManager.h>

// Keep absent attributes from causing ARC output parameter writeback.
static BOOL IJSVGParserAttributeHasValue(NSString* __unsafe_unretained const* attributeValues,
                                         IJSVGNodeAttribute attribute, NSString* __strong* value)
{
    NSString* __unsafe_unretained attributeValue = attributeValues[attribute];
    if(attributeValue == nil || attributeValue.length == 0) {
        return NO;
    }
    *value = attributeValue;
    return YES;
}

NSString* const IJSVGStringObjectBoundingBox = @"objectBoundingBox";
NSString* const IJSVGStringUserSpaceOnUse = @"userSpaceOnUse";
NSString* const IJSVGStringNone = @"none";
NSString* const IJSVGStringRound = @"round";
NSString* const IJSVGStringSquare = @"square";
NSString* const IJSVGStringBevel = @"bevel";
NSString* const IJSVGStringButt = @"butt";
NSString* const IJSVGStringMiter = @"miter";
NSString* const IJSVGStringInherit = @"inherit";
NSString* const IJSVGStringEvenOdd = @"evenodd";
NSString* const IJSVGStringAuto = @"auto";
NSString* const IJSVGStringStrokeWidth = @"strokeWidth";
NSString* const IJSVGStringNonScalingStroke = @"non-scaling-stroke";
NSString* const IJSVGStringDegrees = @"deg";
NSString* const IJSVGStringRadians = @"rad";
NSString* const IJSVGStringGradians = @"grad";
NSString* const IJSVGStringAutoStartReverse = @"auto-start-reverse";
NSString* const IJSVGStringContextFill = @"context-fill";
NSString* const IJSVGStringContextStroke = @"context-stroke";

// SVG filter attribute values and predefined inputs.
NSString* const IJSVGStringNormal = @"normal";
NSString* const IJSVGStringMultiply = @"multiply";
NSString* const IJSVGStringScreen = @"screen";
NSString* const IJSVGStringDarken = @"darken";
NSString* const IJSVGStringLighten = @"lighten";
NSString* const IJSVGStringOverlay = @"overlay";
NSString* const IJSVGStringColorDodge = @"color-dodge";
NSString* const IJSVGStringColorBurn = @"color-burn";
NSString* const IJSVGStringHardLight = @"hard-light";
NSString* const IJSVGStringSoftLight = @"soft-light";
NSString* const IJSVGStringDifference = @"difference";
NSString* const IJSVGStringExclusion = @"exclusion";
NSString* const IJSVGStringHue = @"hue";
NSString* const IJSVGStringSaturation = @"saturation";
NSString* const IJSVGStringColor = @"color";
NSString* const IJSVGStringLuminosity = @"luminosity";
NSString* const IJSVGStringMatrix = @"matrix";
NSString* const IJSVGStringSaturate = @"saturate";
NSString* const IJSVGStringHueRotate = @"hueRotate";
NSString* const IJSVGStringLuminanceToAlpha = @"luminanceToAlpha";
NSString* const IJSVGStringDilate = @"dilate";
NSString* const IJSVGStringOver = @"over";
NSString* const IJSVGStringIn = @"in";
NSString* const IJSVGStringOut = @"out";
NSString* const IJSVGStringAtop = @"atop";
NSString* const IJSVGStringLighter = @"lighter";
NSString* const IJSVGStringXor = @"xor";
NSString* const IJSVGStringArithmetic = @"arithmetic";
NSString* const IJSVGStringIdentity = @"identity";
NSString* const IJSVGStringTable = @"table";
NSString* const IJSVGStringDiscrete = @"discrete";
NSString* const IJSVGStringLinear = @"linear";
NSString* const IJSVGStringGamma = @"gamma";
NSString* const IJSVGStringTrue = @"true";
NSString* const IJSVGStringDuplicate = @"duplicate";
NSString* const IJSVGStringWrap = @"wrap";
NSString* const IJSVGStringFractalNoise = @"fractalNoise";
NSString* const IJSVGStringStitch = @"stitch";
NSString* const IJSVGStringBlack = @"black";
NSString* const IJSVGStringWhite = @"white";
NSString* const IJSVGStringSRGB = @"sRGB";
NSString* const IJSVGStringLinearRGB = @"linearRGB";
NSString* const IJSVGStringSourceGraphic = @"SourceGraphic";
NSString* const IJSVGStringSourceAlpha = @"SourceAlpha";
NSString* const IJSVGStringBackgroundImage = @"BackgroundImage";
NSString* const IJSVGStringBackgroundAlpha = @"BackgroundAlpha";
NSString* const IJSVGStringFillPaint = @"FillPaint";
NSString* const IJSVGStringStrokePaint = @"StrokePaint";
NSString* const IJSVGStringChannelR = @"R";
NSString* const IJSVGStringChannelG = @"G";
NSString* const IJSVGStringChannelB = @"B";
NSString* const IJSVGStringChannelA = @"A";

NSString* const IJSVGAttributeVersion = @"version";
NSString* const IJSVGAttributeXMLNS = @"xmlns";
NSString* const IJSVGAttributeXMLNSXlink = @"xmlns:xlink";
NSString* const IJSVGAttributeViewBox = @"viewBox";
NSString* const IJSVGAttributePreserveAspectRatio = @"preserveAspectRatio";
NSString* const IJSVGAttributeID = @"id";
NSString* const IJSVGAttributeClass = @"class";
NSString* const IJSVGAttributeX = @"x";
NSString* const IJSVGAttributeY = @"y";
NSString* const IJSVGAttributeWidth = @"width";
NSString* const IJSVGAttributeHeight = @"height";
NSString* const IJSVGAttributeOpacity = @"opacity";
NSString* const IJSVGAttributeStrokeOpacity = @"stroke-opacity";
NSString* const IJSVGAttributeStrokeWidth = @"stroke-width";
NSString* const IJSVGAttributeStrokeDashOffset = @"stroke-dashoffset";
NSString* const IJSVGAttributeFillOpacity = @"fill-opacity";
NSString* const IJSVGAttributeClipPath = @"clip-path";
NSString* const IJSVGAttributeClipPathUnits = @"clipPathUnits";
NSString* const IJSVGAttributeClipRule = @"clip-rule";
NSString* const IJSVGAttributeMask = @"mask";
NSString* const IJSVGAttributeGradientUnits = @"gradientUnits";
NSString* const IJSVGAttributeSpreadMethod = @"spreadMethod";
NSString* const IJSVGAttributePatternUnits = @"patternUnits";
NSString* const IJSVGAttributePatternContentUnits = @"patternContentUnits";
NSString* const IJSVGAttributePatternTransform = @"patternTransform";
NSString* const IJSVGAttributeMaskType = @"mask-type";
NSString* const IJSVGAttributeMaskUnits = @"maskUnits";
NSString* const IJSVGAttributeMaskContentUnits = @"maskContentUnits";
NSString* const IJSVGAttributeTransform = @"transform";
NSString* const IJSVGAttributeTransformOrigin = @"transform-origin";
NSString* const IJSVGAttributeTransformBox = @"transform-box";
NSString* const IJSVGAttributeRequiredExtensions = @"requiredExtensions";
NSString* const IJSVGAttributeSystemLanguage = @"systemLanguage";
NSString* const IJSVGAttributeGradientTransform = @"gradientTransform";
NSString* const IJSVGAttributeUnicode = @"unicode";
NSString* const IJSVGAttributeStrokeLineCap = @"stroke-linecap";
NSString* const IJSVGAttributeStrokeLineJoin = @"stroke-linejoin";
NSString* const IJSVGAttributeStroke = @"stroke";
NSString* const IJSVGAttributeStrokeDashArray = @"stroke-dasharray";
NSString* const IJSVGAttributeStrokeMiterLimit = @"stroke-miterlimit";
NSString* const IJSVGAttributeFill = @"fill";
NSString* const IJSVGAttributeFillRule = @"fill-rule";
NSString* const IJSVGAttributeBlendMode = @"mix-blend-mode";
NSString* const IJSVGAttributeIsolation = @"isolation";
NSString* const IJSVGAttributePaintOrder = @"paint-order";
NSString* const IJSVGAttributeVectorEffect = @"vector-effect";
NSString* const IJSVGAttributeColor = @"color";
NSString* const IJSVGAttributeVisibility = @"visibility";
NSString* const IJSVGAttributeDisplay = @"display";
NSString* const IJSVGAttributeStyle = @"style";
NSString* const IJSVGAttributeD = @"d";
NSString* const IJSVGAttributeXLink = @"xlink:href";
NSString* const IJSVGAttributeX1 = @"x1";
NSString* const IJSVGAttributeX2 = @"x2";
NSString* const IJSVGAttributeY1 = @"y1";
NSString* const IJSVGAttributeY2 = @"y2";
NSString* const IJSVGAttributeRX = @"rx";
NSString* const IJSVGAttributeRY = @"ry";
NSString* const IJSVGAttributeCX = @"cx";
NSString* const IJSVGAttributeCY = @"cy";
NSString* const IJSVGAttributeR = @"r";
NSString* const IJSVGAttributeFX = @"fx";
NSString* const IJSVGAttributeFY = @"fy";
NSString* const IJSVGAttributeFR = @"fr";
NSString* const IJSVGAttributePoints = @"points";
NSString* const IJSVGAttributeOffset = @"offset";
NSString* const IJSVGAttributeStopColor = @"stop-color";
NSString* const IJSVGAttributeStopOpacity = @"stop-opacity";
NSString* const IJSVGAttributeHref = @"href";
NSString* const IJSVGAttributeOverflow = @"overflow";
NSString* const IJSVGAttributeMarker = @"marker";
NSString* const IJSVGAttributeMarkerStart = @"marker-start";
NSString* const IJSVGAttributeMarkerMid = @"marker-mid";
NSString* const IJSVGAttributeMarkerEnd = @"marker-end";
NSString* const IJSVGAttributeRefX = @"refX";
NSString* const IJSVGAttributeRefY = @"refY";
NSString* const IJSVGAttributeMarkerWidth = @"markerWidth";
NSString* const IJSVGAttributeMarkerHeight = @"markerHeight";
NSString* const IJSVGAttributeMarkerUnits = @"markerUnits";
NSString* const IJSVGAttributeOrient = @"orient";
NSString* const IJSVGAttributeFilter = @"filter";
NSString* const IJSVGAttributeFilterUnits = @"filterUnits";
NSString* const IJSVGAttributePrimitiveUnits = @"primitiveUnits";

NSString* const IJSVGAttributeDX = @"dx";
NSString* const IJSVGAttributeDY = @"dy";
NSString* const IJSVGAttributeStdDeviation = @"stdDeviation";
NSString* const IJSVGAttributeFloodColor = @"flood-color";
NSString* const IJSVGAttributeFloodOpacity = @"flood-opacity";
NSString* const IJSVGAttributeIn = @"in";
NSString* const IJSVGAttributeResult = @"result";
NSString* const IJSVGAttributeIn2 = @"in2";
NSString* const IJSVGAttributeMode = @"mode";
NSString* const IJSVGAttributeType = @"type";
NSString* const IJSVGAttributeValues = @"values";
NSString* const IJSVGAttributeOperator = @"operator";
NSString* const IJSVGAttributeK1 = @"k1";
NSString* const IJSVGAttributeK2 = @"k2";
NSString* const IJSVGAttributeK3 = @"k3";
NSString* const IJSVGAttributeK4 = @"k4";
NSString* const IJSVGAttributeOrder = @"order";
NSString* const IJSVGAttributeKernelMatrix = @"kernelMatrix";
NSString* const IJSVGAttributeDivisor = @"divisor";
NSString* const IJSVGAttributeBias = @"bias";
NSString* const IJSVGAttributeTargetX = @"targetX";
NSString* const IJSVGAttributeTargetY = @"targetY";
NSString* const IJSVGAttributeEdgeMode = @"edgeMode";
NSString* const IJSVGAttributeKernelUnitLength = @"kernelUnitLength";
NSString* const IJSVGAttributePreserveAlpha = @"preserveAlpha";
NSString* const IJSVGAttributeSurfaceScale = @"surfaceScale";
NSString* const IJSVGAttributeDiffuseConstant = @"diffuseConstant";
NSString* const IJSVGAttributeSpecularConstant = @"specularConstant";
NSString* const IJSVGAttributeSpecularExponent = @"specularExponent";
NSString* const IJSVGAttributeLightingColor = @"lighting-color";
NSString* const IJSVGAttributeScale = @"scale";
NSString* const IJSVGAttributeXChannelSelector = @"xChannelSelector";
NSString* const IJSVGAttributeYChannelSelector = @"yChannelSelector";
NSString* const IJSVGAttributeRadius = @"radius";
NSString* const IJSVGAttributeBaseFrequency = @"baseFrequency";
NSString* const IJSVGAttributeNumOctaves = @"numOctaves";
NSString* const IJSVGAttributeSeed = @"seed";
NSString* const IJSVGAttributeStitchTiles = @"stitchTiles";
NSString* const IJSVGAttributeTableValues = @"tableValues";
NSString* const IJSVGAttributeSlope = @"slope";
NSString* const IJSVGAttributeIntercept = @"intercept";
NSString* const IJSVGAttributeAmplitude = @"amplitude";
NSString* const IJSVGAttributeExponent = @"exponent";
NSString* const IJSVGAttributeAzimuth = @"azimuth";
NSString* const IJSVGAttributeElevation = @"elevation";
NSString* const IJSVGAttributeZ = @"z";
NSString* const IJSVGAttributePointsAtX = @"pointsAtX";
NSString* const IJSVGAttributePointsAtY = @"pointsAtY";
NSString* const IJSVGAttributePointsAtZ = @"pointsAtZ";
NSString* const IJSVGAttributeLimitingConeAngle = @"limitingConeAngle";
NSString* const IJSVGAttributeColorInterpolationFilters = @"color-interpolation-filters";
NSString* const IJSVGAttributeEnableBackground = @"enable-background";
NSString* const IJSVGAttributeBackgroundColor = @"background-color";
NSString* const IJSVGAttributeMedia = @"media";

// SVG text presentation and positioning attributes.
NSString* const IJSVGAttributeFont = @"font";
NSString* const IJSVGAttributeFontFamily = @"font-family";
NSString* const IJSVGAttributeFontSize = @"font-size";
NSString* const IJSVGAttributeFontSizeAdjust = @"font-size-adjust";
NSString* const IJSVGAttributeFontWeight = @"font-weight";
NSString* const IJSVGAttributeFontStyle = @"font-style";
NSString* const IJSVGAttributeFontStretch = @"font-stretch";
NSString* const IJSVGAttributeFontVariant = @"font-variant";
NSString* const IJSVGAttributeFontVariantLigatures = @"font-variant-ligatures";
NSString* const IJSVGAttributeFontFeatureSettings = @"font-feature-settings";
NSString* const IJSVGAttributeFontKerning = @"font-kerning";
NSString* const IJSVGAttributeLetterSpacing = @"letter-spacing";
NSString* const IJSVGAttributeWordSpacing = @"word-spacing";
NSString* const IJSVGAttributeTextAnchor = @"text-anchor";
NSString* const IJSVGAttributeDirection = @"direction";
NSString* const IJSVGAttributeUnicodeBidi = @"unicode-bidi";
NSString* const IJSVGAttributeWritingMode = @"writing-mode";
NSString* const IJSVGAttributeTextOrientation = @"text-orientation";
NSString* const IJSVGAttributeDominantBaseline = @"dominant-baseline";
NSString* const IJSVGAttributeAlignmentBaseline = @"alignment-baseline";
NSString* const IJSVGAttributeBaselineShift = @"baseline-shift";
NSString* const IJSVGAttributeTextDecoration = @"text-decoration";
NSString* const IJSVGAttributeTextDecorationLine = @"text-decoration-line";
NSString* const IJSVGAttributeWhiteSpace = @"white-space";
NSString* const IJSVGAttributeLineHeight = @"line-height";
NSString* const IJSVGAttributeInlineSize = @"inline-size";
NSString* const IJSVGAttributeTextTransform = @"text-transform";
NSString* const IJSVGAttributeTextOverflow = @"text-overflow";
NSString* const IJSVGAttributeXMLSpace = @"xml:space";
NSString* const IJSVGAttributeLang = @"lang";
NSString* const IJSVGAttributeXMLLang = @"xml:lang";
NSString* const IJSVGAttributeTextRendering = @"text-rendering";
NSString* const IJSVGAttributeRotate = @"rotate";
NSString* const IJSVGAttributeTextLength = @"textLength";
NSString* const IJSVGAttributeLengthAdjust = @"lengthAdjust";
NSString* const IJSVGAttributeStartOffset = @"startOffset";
NSString* const IJSVGAttributeMethod = @"method";
NSString* const IJSVGAttributeSpacing = @"spacing";
NSString* const IJSVGAttributeSide = @"side";
NSString* const IJSVGAttributePath = @"path";
NSString* const IJSVGAttributePathLength = @"pathLength";

static NSString* IJSVGParserElementIdentifier(NSXMLElement* element)
{
    for(NSXMLNode* attribute in element.attributes) {
        if([attribute.name isEqualToString:IJSVGAttributeID]) {
            return attribute.stringValue;
        }
    }
    return nil;
}

static NSMapTable* IJSVGParserElementMapTable(void)
{
    NSPointerFunctionsOptions options = NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality;
    return [NSMapTable mapTableWithKeyOptions:options
                                 valueOptions:NSPointerFunctionsStrongMemory];
}

typedef struct {
    NSUInteger attribute;
    __unsafe_unretained NSString* value;
} IJSVGParserRawAttribute;

// Keep the raw strings alive while cached entries refer to them.
// Resolve inherited values separately because each use can have a different parent.
@interface IJSVGParserRawAttributes : NSObject {
@public
    NSData* entries;
    BOOL hasAttributes;
    NSArray<NSString*>* values;
    NSSet<NSString*>* classNameList;
    NSData* filterEntries;
    NSArray<NSString*>* filterValues;
    IJSVGStyleSheetStyle* filterStyle;
    IJSVGStyleSheetStyle* filterInlineStyle;
    NSDictionary<NSString*, NSString*>* filterParameters;
    NSUInteger filterRuleCount;
}
- (instancetype)initWithElement:(NSXMLElement*)element;
@end

@implementation IJSVGParserRawAttributes

- (instancetype)initWithElement:(NSXMLElement*)element
{
    if((self = [super init]) != nil) {
        NSMutableData* data = [[NSMutableData alloc] init];
        NSMutableArray<NSString*>* strings = [[NSMutableArray alloc] init];
        NSArray<NSXMLNode*>* attributes = element.attributes;
        hasAttributes = attributes.count != 0;
        for(NSXMLNode* attributeNode in attributes) {
            NSUInteger attribute = NSNotFound;
            NSString* value = nil;
            if(!IJSVGReadXMLAttribute(attributeNode, nil, &attribute, &value)) {
                continue;
            }
            [strings addObject:value];
            IJSVGParserRawAttribute entry = { attribute, value };
            [data appendBytes:&entry length:sizeof(entry)];
            if(attribute == IJSVGNodeAttributeClass) {
                classNameList = IJSVGClassNameList(value);
            }
        }
        entries = data.copy;
        values = strings.copy;
    }
    return self;
}

@end

static void IJSVGParserCacheFilterAttributes(IJSVGParserRawAttributes* raw,
                                             NSString* __unsafe_unretained const attributes[kIJSVGNodeAttributeStorageLength],
                                             IJSVGStyleSheetStyle* style, IJSVGStyleSheetStyle* inlineStyle, NSUInteger ruleCount)
{
    NSMutableData* data = [[NSMutableData alloc] init];
    NSMutableArray<NSString*>* strings = [[NSMutableArray alloc] init];
    for(NSUInteger index = 0; index < kIJSVGNodeAttributeStorageLength; index++) {
        NSString* value = attributes[index];
        if(value != nil) {
            [strings addObject:value];
            IJSVGParserRawAttribute entry = { index, value };
            [data appendBytes:&entry length:sizeof(entry)];
        }
    }
    raw->filterValues = strings.copy;
    raw->filterEntries = data.copy;
    raw->filterStyle = style;
    raw->filterInlineStyle = inlineStyle;
    raw->filterRuleCount = ruleCount;
    raw->filterParameters = nil;
}

static void IJSVGParserRestoreFilterAttributes(IJSVGParserRawAttributes* raw,
    NSString* __unsafe_unretained attributes[kIJSVGNodeAttributeStorageLength])
{
    memset(attributes, 0, sizeof(*attributes) * kIJSVGNodeAttributeStorageLength);
    const IJSVGParserRawAttribute* entries = raw->filterEntries.bytes;
    NSUInteger count = raw->filterEntries.length / sizeof(*entries);
    for(NSUInteger index = 0; index < count; index++) {
        attributes[entries[index].attribute] = entries[index].value;
    }
}

static NSDictionary<NSString*, NSString*>* IJSVGFilterParametersFromAttributes(
    NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength])
{
    static NSString* names[kIJSVGNodeAttributeStorageLength];
    static IJSVGNodeAttribute attributes[kIJSVGNodeAttributeStorageLength];
    static NSUInteger count;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        for(NSString* name in IJSVGFilterPrimitive.parameterNames) {
            NSUInteger attribute = IJSVGNodeAttributeForName(name);
            if(attribute != NSNotFound) {
                names[count] = name;
                attributes[count++] = (IJSVGNodeAttribute)attribute;
            }
        }
    });

    NSMutableDictionary<NSString*, NSString*>* parameters = [[NSMutableDictionary alloc] init];
    for(NSUInteger index = 0; index < count; index++) {
        NSString* value = nil;
        if(IJSVGParserAttributeHasValue(attributeValues, attributes[index], &value)) {
            parameters[names[index]] = value;
        }
    }
    return parameters;
}

@interface IJSVGParser ()
@property (nonatomic) IJSVGParsedPathCache* parsedPathCache;
@property (nonatomic) NSUInteger inlineStyleCost;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSArray<NSString*>*>* parsedFilterReferences;
@property (nonatomic, strong) NSMutableDictionary<Class, IJSVGBitFlags*>* allowedAttributesByClass;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSColor*>* parsedColors;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSArray<IJSVGTransform*>*>* parsedSVGTransforms;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSArray<IJSVGTransform*>*>* parsedCSSTransforms;
@property (nonatomic, strong) NSMapTable<NSXMLElement*, IJSVGParserRawAttributes*>* rawAttributes;
@property (nonatomic, strong) NSHashTable<NSXMLElement*>* uncachedReferenceElements;
@property (nonatomic, strong) NSXMLElement* lastParsedStyleElement;
@property (nonatomic, strong) NSMutableDictionary<NSString*, IJSVGStyleSheetStyle*>* inlineStyles;
@property (nonatomic, strong) NSMapTable<NSXMLElement*, NSMapTable*>* selectorScopes;
@property (nonatomic, strong) NSMutableSet<NSString*>* activeFilterReferences;
@property (nonatomic, strong) NSMutableSet<NSString*>* activeReferences;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSMutableArray*>* pendingStylePaints;
@property (nonatomic, strong) NSMapTable<NSXMLElement*, IJSVGStyleSheetSelectorRecord*>* selectorNodes;
@property (nonatomic, strong) NSMapTable<NSXMLElement*, IJSVGStyleSheetSelectorRecord*>* selectorScope;
@property (nonatomic, strong) NSMapTable<NSXMLElement*, IJSVGNode*>* styleAncestors;
@property (nonatomic, strong) NSMapTable<IJSVGNode*, NSString*>* inheritedPathData;
@property (nonatomic, strong) NSMapTable<IJSVGNode*, NSDictionary*>* customProperties;
@property (nonatomic, strong) NSMapTable<NSXMLElement*, IJSVGNode*>* definitionStyleParents;
@end

@implementation IJSVGParser

- (void)dealloc
{
    IJSVGParsedPathCacheDestroy(_parsedPathCache);
}

+ (IJSVGParser*)parserForFileURL:(NSURL*)aURL
{
    return [self.class parserForFileURL:aURL
                                  error:nil];
}

+ (IJSVGParser*)parserForFileURL:(NSURL*)aURL
                           error:(NSError**)error
{
    return [[self.class alloc] initWithFileURL:aURL
                                         error:error];
}

- (BOOL)_prepareWithXMLDocument:(NSXMLDocument*)document
                        parseError:(NSError*)parseError
                            fileURL:(NSURL*)aURL
                              error:(NSError**)error
{
    // just some generic value to get it up n running.
    _fileURL = aURL;
    _document = document;

    // error parsing the XML document
    if(parseError != nil || _document == nil) {
        [self _handleErrorWithCode:IJSVGErrorParsingFile
                             error:error];
        return NO;
    }

    // check the actual parsed SVG
    NSError* anError = nil;
    if([self _validateParse:&anError] == NO) {
        if(error != NULL) {
            *error = anError;
        }
        return NO;
    }
    return YES;
}

- (id)initWithSVGString:(NSString*)string
                fileURL:(NSURL*)aURL
                  error:(NSError**)error
{
    if((self = [super init]) != nil) {
        NSError* anError = nil;
        NSXMLDocument* document = nil;
        @try {
            // Keep XML content, but not source-formatting whitespace that is never rendered.
            document = [[NSXMLDocument alloc] initWithXMLString:string
                                                        options:0
                                                          error:&anError];
        }
        @catch (NSException* exception) {
        }

        if([self _prepareWithXMLDocument:document
                              parseError:anError
                                 fileURL:aURL
                                   error:error] == NO) {
            return nil;
        }
    }
    return self;
}

- (id)initWithSVGData:(NSData*)data
              fileURL:(NSURL*)aURL
                error:(NSError**)error
{
    if((self = [super init]) != nil) {
        NSError* anError = nil;
        NSXMLDocument* document = nil;
        @try {
            // Keep XML content, but not source-formatting whitespace that is never rendered.
            document = [[NSXMLDocument alloc] initWithData:data
                                                   options:0
                                                     error:&anError];
        }
        @catch (NSException* exception) {
        }

        if([self _prepareWithXMLDocument:document
                              parseError:anError
                                 fileURL:aURL
                                   error:error] == NO) {
            return nil;
        }
    }
    return self;
}

+ (BOOL)isDataSVG:(NSData*)data
{
    @try {
        NSError* error;
        NSXMLDocument* doc = [[NSXMLDocument alloc] initWithData:data
                                                         options:NSXMLNodePreserveWhitespace
                                                           error:&error];
        return doc != nil && error == nil;
    } @catch (NSException* exception) {
    }
    return NO;
}

- (id)initWithFileURL:(NSURL*)aURL
                error:(NSError**)error
{
    NSError* anError = nil;
    NSData* data = [NSData dataWithContentsOfURL:aURL
                                         options:NSDataReadingMappedIfSafe
                                           error:&anError];

    // error reading file
    if(data == nil) {
        return [self _handleErrorWithCode:IJSVGErrorReadingFile
                                    error:error];
    }

    return [self initWithSVGData:data
                         fileURL:aURL
                           error:error];
}

- (void*)_handleErrorWithCode:(NSUInteger)code
                        error:(NSError**)error
{
    if(error != nil) {
        *error = [[NSError alloc] initWithDomain:IJSVGErrorDomain
                                            code:code
                                        userInfo:nil];
    }
    return nil;
}

- (BOOL)_validateParse:(NSError**)error
{
    if(_rootNode.viewBox.size.isZeroSize == YES) {
        if(error != NULL) {
            *error = [[NSError alloc] initWithDomain:IJSVGErrorDomain
                                                code:IJSVGErrorParsingSVG
                                            userInfo:nil];
        }
        return NO;
    }
    return YES;
}

- (IJSVGRootNode*)rootNodeWithSize:(CGSize)size
{
  __weak IJSVGParser* weakSelf = self;
  [self beginWithSetup:^{
      IJSVGParser* strongSelf = weakSelf;
      strongSelf->_rootSize = CGSizeEqualToSize(CGSizeZero, size) == YES ?
          IJSVG_SIZE_DEFAULT_CLIENT : size;
  }];
  return _rootNode;
}

- (void)beginWithSetup:(dispatch_block_t __nullable)setup
{
    // setup basics to begin with
    _styleSheet = [[IJSVGStyleSheet alloc] init];
    IJSVGThreadManager* manager = IJSVGThreadManager.currentManager;
    _threadManager = manager;
    _commandDataStream = manager.pathDataStream;
    _detachedReferences = [[NSMutableDictionary alloc] init];
    self.activeReferences = [[NSMutableSet alloc] init];
    self.pendingStylePaints = [[NSMutableDictionary alloc] init];
    self.selectorNodes = nil;
    self.selectorScope = nil;
    self.selectorScopes = nil;
    self.inlineStyles = nil;
    self.parsedColors = nil;
    self.parsedFilterReferences = nil;
    self.allowedAttributesByClass = nil;
    self.parsedSVGTransforms = nil;
    self.parsedCSSTransforms = nil;
    self.rawAttributes = nil;
    self.uncachedReferenceElements = nil;
    self.lastParsedStyleElement = nil;
    self.styleAncestors = IJSVGParserElementMapTable();
    self.inheritedPathData = nil;
    self.customProperties = nil;
    self.definitionStyleParents = IJSVGParserElementMapTable();
    if(setup != nil) {
      setup();
    }
    _rootNode = [[IJSVGRootNode alloc] init];
    _rootNode.clientSize = _rootSize;
    IJSVGNodeParserPostProcessBlock postProcessBlock = nil;
    [self parseSVGElement:_document.rootElement
                 ontoNode:_rootNode
               parentNode:nil
         postProcessBlock:&postProcessBlock
                recursive:YES];
    if(postProcessBlock != nil) {
        postProcessBlock();
    }
    [_rootNode postProcess];
    _rootNode.styleAncestors = self.styleAncestors.objectEnumerator.allObjects;
    self.inlineStyles = nil;
    self.parsedColors = nil;
    self.parsedFilterReferences = nil;
    self.allowedAttributesByClass = nil;
    self.parsedSVGTransforms = nil;
    self.parsedCSSTransforms = nil;
    self.rawAttributes = nil;
    self.uncachedReferenceElements = nil;
    self.lastParsedStyleElement = nil;
    self.selectorScopes = nil;
    _detachedReferences = nil;
}

- (IJSVGRootNode*)rootNode:(BOOL)recursive
{
    IJSVGNodeParserPostProcessBlock postProcessBlock = nil;
    IJSVGRootNode* node = [[IJSVGRootNode alloc] init];
    node.clientSize = _rootSize;
    [self parseSVGElement:_document.rootElement
                 ontoNode:node
               parentNode:nil
         postProcessBlock:&postProcessBlock
                recursive:recursive];
    if(postProcessBlock != nil) {
        postProcessBlock();
    }
    [node postProcess];
    node.styleAncestors = self.styleAncestors.objectEnumerator.allObjects;
    return node;
}

- (void)computeDefsForElement:(NSXMLElement*)element
                   parentNode:(IJSVGNode*)parentNode
{
    if(element.childCount == 0) {
        return;
    }
    for(NSXMLElement* childElement in element.children) {
        IJSVGNodeType type = IJSVGNodeTypeForString(childElement.localName, childElement.kind);
        if(type != IJSVGNodeTypeDef) {
            continue;
        }
        [self parseDefElement:childElement
                   parentNode:_rootNode
                    recursive:YES];
    }
}

- (void)inferDefaultIntrinsicSizeAndViewBoxForRootNode:(IJSVGRootNode*)node {
    if(node.intrinsicSize != nil) {
      return;
    }
  
    IJSVGUnitLength* width = node.width;
    IJSVGUnitLength* height = node.height;
  
    // We already have a width and a height, use those.
    if(width != nil && height != nil) {
        node.intrinsicSize = [IJSVGUnitSize sizeWithWidth:width
                                                   height:height];
        return;
    }
  
    CGSize defaultSize = IJSVG_SIZE_DEFAULT_CLIENT;
    CGFloat ratio = defaultSize.width / defaultSize.height;
  
    if(width != nil && height == nil) {
      height = [IJSVGUnitLength unitWithFloat:width.value*ratio];
    } else if(width == nil && height != nil) {
      width = [IJSVGUnitLength unitWithFloat:height.value*ratio];
    } else {
      width = IJSVGDefaultViewportWidthUnitLength;
      height = IJSVGDefaultViewportHeightUnitLength;
    }
    node.intrinsicSize = [IJSVGUnitSize sizeWithWidth:width
                                               height:height];
    if(node.viewBox == nil) {
        node.viewBox = [IJSVGUnitRect rectWithOrigin:IJSVGUnitPoint.zeroPoint
                                                size:node.intrinsicSize.copy];
        node.viewBoxWasInferred = YES;
    }
}

- (void)computeViewBoxForRootNode:(IJSVGRootNode*)node
{
    if(node.viewBox == nil && (node.width != nil || node.height != nil)) {
        IJSVGUnitLength* width = node.width ?: node.height;
        IJSVGUnitLength* height = node.height ?: node.width;
        IJSVGUnitSize* size = [IJSVGUnitSize sizeWithWidth:width
                                                    height:height];
        node.viewBox = [IJSVGUnitRect rectWithOrigin:IJSVGUnitPoint.zeroPoint
                                                size:size];
        node.viewBoxWasInferred = YES;
    }
  
    if(node.viewBox == nil) {
      return;
    }

    IJSVGIntrinsicDimensions dimensions = IJSVGIntrinsicDimensionNone;
    IJSVGUnitLength* wl = node.viewBox.size.width;
    IJSVGUnitLength* hl = node.viewBox.size.height;
    if(node.width != nil) {
        dimensions|= IJSVGIntrinsicDimensionWidth;
        wl = node.width;
    }
    if(node.height != nil) {
        dimensions |= IJSVGIntrinsicDimensionHeight;
        hl = node.height;
    }
    
    node.intrinsicDimensions = dimensions;
    node.intrinsicSize = [IJSVGUnitSize sizeWithWidth:wl
                                               height:hl];
}

- (IJSVGStyleSheetStyle*)parsedInlineStyleForValue:(NSString*)value
{
    if(_inlineStyles == nil) {
        _inlineStyles = [[NSMutableDictionary alloc] init];
        _inlineStyleCost = 0;
    }
    IJSVGStyleSheetStyle* style = [_inlineStyles objectForKey:value];
    if(style == nil) {
        style = [IJSVGStyleSheetStyle parseStyleString:value];
        NSUInteger cost = value.length * sizeof(unichar);
        if(_inlineStyles.count < 1024 && cost <= 1024 * 1024 - _inlineStyleCost) {
            [_inlineStyles setObject:style forKey:value];
            _inlineStyleCost += cost;
        }
    }
    return style;
}

- (IJSVGBitFlags*)allowedAttributesForNodeClass:(Class)nodeClass
{
    IJSVGBitFlags* attributes = _allowedAttributesByClass[nodeClass];
    if(attributes == nil) {
        attributes = [nodeClass computedAllowedAttributes];
        if(_allowedAttributesByClass == nil) {
            _allowedAttributesByClass = [[NSMutableDictionary alloc] init];
        }
        _allowedAttributesByClass[(id<NSCopying>)nodeClass] = attributes;
    }
    return attributes;
}

// The following method is highly tuned for performance rather than readability.
- (void)applyStopAttributes:(NSString* __unsafe_unretained const*)attributeValues
                     toNode:(IJSVGNode*)node
{
    NSString* value = nil;
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeOffset, &value)) {
        node.offset = [IJSVGUnitLength unitWithString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStopOpacity, &value)) {
        node.fillOpacity = [IJSVGUnitLength unitWithString:value];
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStopColor, &value)) {
        NSColor* color = [value caseInsensitiveCompare:IJSVGColorCurrentColorName] == NSOrderedSame
            ? node.currentColor : [self parsedStopColorForValue:value];
        IJSVGColorNode* colorNode = (IJSVGColorNode*)[IJSVGColorNode colorNodeWithColor:color];
        if(color == nil) {
            colorNode.isNoneOrTransparent = [IJSVGColor isNoneOrTransparent:value];
        } else {
            CGFloat opacity = node.fillOpacity.value;
            if(opacity != 1.f) {
                colorNode.color = [IJSVGColor changeAlphaOnColor:color to:opacity];
            }
        }
        node.fill = colorNode;
    }
}

- (IJSVGNodeParserPostProcessBlock)computeAttributesFromElement:(NSXMLElement*)element
                                                         onNode:(IJSVGNode*)node
                                              ignoredAttributes:(IJSVGBitFlags*)ignoringAttributes
{
    IJSVGNode* definitionParent = [self.definitionStyleParents objectForKey:element];
    if(definitionParent != nil) {
        node.styleParent = definitionParent;
    }
    // Coordinate-only gradients need no style cascade. Their coordinates are
    // resolved by parseGradient after the stop children have been constructed.
    if(node.type == IJSVGNodeTypeLinearGradient && _styleSheet.ruleCount == 0 &&
        ignoringAttributes == nil) {
        NSArray<NSXMLNode*>* attributes = element.attributes;
        NSString* identifier = nil;
        BOOL plainGradient = YES;
        for(NSXMLNode* attribute in attributes) {
            NSString* name = attribute.name;
            if([name isEqualToString:IJSVGAttributeID]) {
                identifier = attribute.stringValue;
            } else if(![name isEqualToString:IJSVGAttributeX1] &&
                      ![name isEqualToString:IJSVGAttributeX2] &&
                      ![name isEqualToString:IJSVGAttributeY1] &&
                      ![name isEqualToString:IJSVGAttributeY2]) {
                plainGradient = NO;
                break;
            }
        }
        if(plainGradient) {
            if(identifier.length != 0) {
                node.identifier = identifier;
                [self detachElement:element withIdentifier:identifier];
            }
            return nil;
        }
    }
    // Plain stops have no cascade to resolve. Avoid allocating reference caches
    // and resolving the general node attribute set for these small leaf nodes.
    if(node.type == IJSVGNodeTypeStop && _styleSheet.ruleCount == 0 && ignoringAttributes == nil) {
        NSString* __unsafe_unretained values[kIJSVGNodeAttributeStorageLength] = { nil };
        NSArray<NSXMLNode*>* attributes = element.attributes;
        BOOL plainStop = YES;
        for(NSXMLNode* attribute in attributes) {
            NSString* name = attribute.name;
            NSUInteger index;
            if([name isEqualToString:IJSVGAttributeOffset]) {
                index = IJSVGNodeAttributeOffset;
            } else if([name isEqualToString:IJSVGAttributeStopColor]) {
                index = IJSVGNodeAttributeStopColor;
            } else if([name isEqualToString:IJSVGAttributeStopOpacity]) {
                index = IJSVGNodeAttributeStopOpacity;
            } else {
                plainStop = NO;
                break;
            }
            values[index] = attribute.stringValue;
        }
        if(plainStop) {
            [self applyStopAttributes:values toNode:node];
            return nil;
        }
    }
    __attribute__((objc_precise_lifetime)) IJSVGParserRawAttributes* raw = nil;
    // Cache attributes for referenced elements because they may be parsed again.
    if(self.activeReferences.count != 0 || self.activeFilterReferences.count != 0) {
        raw = [self.rawAttributes objectForKey:element];
        if(raw == nil) {
            if([self.uncachedReferenceElements containsObject:element]) {
                raw = [[IJSVGParserRawAttributes alloc] initWithElement:element];
                if(self.rawAttributes == nil) {
                    self.rawAttributes = IJSVGParserElementMapTable();
                }
                [self.rawAttributes setObject:raw forKey:element];
                [self.uncachedReferenceElements removeObject:element];
            } else {
                // Wait until the element is referenced again before caching its attributes.
                if(self.uncachedReferenceElements == nil) {
                    self.uncachedReferenceElements = [NSHashTable hashTableWithOptions:
                        NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
                }
                [self.uncachedReferenceElements addObject:element];
            }
        }
    }
    NSArray<NSXMLNode*>* elementAttributes = raw == nil ? element.attributes : nil;
    NSUInteger attributeCount = raw != nil ? raw->entries.length / sizeof(IJSVGParserRawAttribute) :
        elementAttributes.count;
    BOOL hasStyleSheetRules = _styleSheet.ruleCount != 0;
    BOOL hasAttributes = raw != nil ? raw->hasAttributes : attributeCount != 0;
    if(!hasAttributes && hasStyleSheetRules == NO) {
        return nil;
    }

    IJSVGBitFlags* activeAttributes = [self allowedAttributesForNodeClass:node.class];
    if(ignoringAttributes != nil) {
        IJSVGBitFlags* attributes = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
        [attributes addBits:activeAttributes];
        for(int i = 0; i < kIJSVGNodeAttributeStorageLength; i++) {
            if([ignoringAttributes bitIsSet:i] == YES) {
                [attributes unsetBit:i];
            }
        }
        activeAttributes = attributes;
    }
    
    NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength] = { nil };
    NSUInteger variableAttributes[kIJSVGNodeAttributeStorageLength];
    NSUInteger variableAttributeCount = 0;
  
    if(raw != nil) {
        const IJSVGParserRawAttribute* entries = raw->entries.bytes;
        const int* allowed = activeAttributes.storage;
        NSUInteger allowedCount = MAX(0, activeAttributes.length);
        for(NSUInteger index = 0; index < attributeCount; index++) {
            NSUInteger attribute = entries[index].attribute;
            if(attribute < allowedCount && allowed[attribute] == 1) {
                attributeValues[attribute] = entries[index].value;
                if(IJSVGAttributeSupportsVariables(attribute) &&
                   IJSVGCSSValueMayContainVariables(entries[index].value)) {
                    variableAttributes[variableAttributeCount++] = attribute;
                }
            }
        }
    } else {
        for(NSXMLNode* attributeNode in elementAttributes) {
            NSUInteger attribute = NSNotFound;
            NSString* value = nil;
            if(IJSVGReadXMLAttribute(attributeNode, activeAttributes, &attribute, &value)) {
                attributeValues[attribute] = value;
                if(IJSVGAttributeSupportsVariables(attribute) && IJSVGCSSValueMayContainVariables(value)) {
                    variableAttributes[variableAttributeCount++] = attribute;
                }
            }
        }
    }

    NSString* value = nil;
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeID, &value)) {
        node.identifier = value;
        [self detachElement:element
             withIdentifier:value];
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeClass, &value)) {
        node.className = value;
        node.classNameList = raw != nil ? raw->classNameList : IJSVGClassNameList(value);
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeUnicode, &value)) {
        node.unicode = value;
    }

    // Presentation shorthand has lower priority than CSS and explicit longhands.
    for(NSUInteger attribute = IJSVGNodeAttributeMarkerStart; attribute <= IJSVGNodeAttributeMarkerEnd; attribute++) {
        if(attributeValues[attribute] == nil) {
            attributeValues[attribute] = attributeValues[IJSVGNodeAttributeMarker];
        }
    }

    NSString* attributePathData = IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeD);
    BOOL isFilterPrimitive = [node isKindOfClass:IJSVGFilterPrimitive.class];
    // Reuse declarations while resolving inherited values on each new node.
    BOOL cacheFilterAttributes = raw != nil && ignoringAttributes == nil &&
        self.selectorScope == nil && (isFilterPrimitive || node.type == IJSVGNodeTypeFilter);
    NSUInteger styleRuleCount = _styleSheet.ruleCount;
    BOOL reuseFilterAttributes = cacheFilterAttributes && raw->filterEntries != nil &&
        raw->filterRuleCount == styleRuleCount;
    __attribute__((objc_precise_lifetime)) IJSVGStyleSheetStyle* styleSheet = nil;
    __attribute__((objc_precise_lifetime)) IJSVGStyleSheetStyle* nodeStyle = nil;
    if(reuseFilterAttributes) {
        IJSVGParserRestoreFilterAttributes(raw, attributeValues);
        styleSheet = raw->filterStyle;
        nodeStyle = raw->filterInlineStyle;
    } else {
        styleSheet = hasStyleSheetRules == YES ?
            [_styleSheet styleForNode:(id<IJSVGStyleSheetSelectorNode>)[self selectorNodeForElement:element] ?: node] :
            nil;

        if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStyle, &value)) {
            nodeStyle = [self parsedInlineStyleForValue:value];
        }

        IJSVGStoreCascadedStyleAttributes(styleSheet, nodeStyle, activeAttributes,
            attributeValues);

        if(cacheFilterAttributes) {
            IJSVGParserCacheFilterAttributes(raw, attributeValues, styleSheet,
                nodeStyle, styleRuleCount);
        }
    }
    NSDictionary* customProperties = [self customPropertiesForNode:node
                                                             style:styleSheet
                                                       inlineStyle:nodeStyle];
    IJSVGStyleSheetStyle* resolvedStyle = [styleSheet styleByResolvingVariables:customProperties];
    IJSVGStyleSheetStyle* resolvedInline = [nodeStyle styleByResolvingVariables:customProperties];
    BOOL resolvedVariables = resolvedStyle != styleSheet || resolvedInline != nodeStyle;
    if(resolvedVariables) {
        styleSheet = resolvedStyle;
        nodeStyle = resolvedInline;
        IJSVGStoreCascadedStyleAttributes(styleSheet, nodeStyle, activeAttributes, attributeValues);
    }
    __attribute__((objc_precise_lifetime)) NSMutableArray* resolvedAttributeValues = nil;
    if(variableAttributeCount != 0) {
        resolvedAttributeValues = [[NSMutableArray alloc] initWithCapacity:variableAttributeCount];
        for(NSUInteger index = 0; index < variableAttributeCount; index++) {
            NSUInteger attribute = variableAttributes[index];
            NSString* source = attributeValues[attribute];
            if(!IJSVGCSSValueMayContainVariables(source)) {
                continue;
            }
            NSString* resolved = IJSVGCSSResolveVariables(source, customProperties);
            resolved = IJSVGCSSResolvedPaintValue(resolved, attribute);
            [resolvedAttributeValues addObject:resolved ?: @""];
            attributeValues[attribute] = resolved ?: @"";
        }
    }
    BOOL variableFilterParameters = variableAttributeCount != 0 || resolvedVariables;
    NSString* pathValue = IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeD);
    if(pathValue != nil) {
        BOOL cssPath = [nodeStyle property:IJSVGAttributeD] != nil ||
            [styleSheet property:IJSVGAttributeD] != nil;
        [self applyPathValue:pathValue
                      toNode:node
                         css:cssPath
                    fallback:attributePathData];
    }
    IJSVGApplyTextAttributes(node, attributeValues);

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePathLength, &value) &&
        [node isKindOfClass:IJSVGPath.class]) {
        NSArray<IJSVGUnitLength*>* lengths = IJSVGUnitLengthsFromString(value);
        if(lengths.count == 1 && lengths.firstObject.originalType == IJSVGUnitLengthTypeNumber) {
            ((IJSVGPath*)node).pathLength = @(lengths.firstObject.value);
        }
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeEnableBackground, &value)) {
        IJSVGApplyBackgroundAttribute(node, value);
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeColorInterpolationFilters, &value)) {
        node.filterColorInterpolation = IJSVGColorInterpolationForString(value);
    }
    if(isFilterPrimitive) {
        NSDictionary<NSString*, NSString*>* parameters = reuseFilterAttributes && !variableFilterParameters ?
            raw->filterParameters :
            IJSVGFilterParametersFromAttributes(attributeValues);
        IJSVGFilterPrimitive* primitive = (IJSVGFilterPrimitive*)node;
        primitive.parameters = parameters;
        if(cacheFilterAttributes) {
            raw->filterParameters = primitive.parameters;
        }
        primitive.input2 = parameters[IJSVGAttributeIn2];
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeX, &value) &&
        !IJSVGGeometryPropertyAppliesToNode(IJSVGNodeAttributeX, node)) {
        node.x = [IJSVGUnitLength unitWithString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeY, &value) &&
        !IJSVGGeometryPropertyAppliesToNode(IJSVGNodeAttributeY, node)) {
        node.y = [IJSVGUnitLength unitWithString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeWidth, &value) &&
        !IJSVGGeometryPropertyAppliesToNode(IJSVGNodeAttributeWidth, node)) {
        IJSVGUnitLength* width = IJSVGDimensionFromString(value, node.type);
        if(width != nil) {
            node.width = width;
        }
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeHeight, &value) &&
        !IJSVGGeometryPropertyAppliesToNode(IJSVGNodeAttributeHeight, node)) {
        IJSVGUnitLength* height = IJSVGDimensionFromString(value, node.type);
        if(height != nil) {
            node.height = height;
        }
    }
    IJSVGApplyGeometryAttributes(node, attributeValues, styleSheet, nodeStyle);

    if(node.type == IJSVGNodeTypeSymbol) {
        IJSVGRootNode* symbol = (IJSVGRootNode*)node;
        symbol.refX = IJSVGSymbolReferenceFromString(IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeRefX),
                                                     IJSVGNodeAttributeRefX);
        symbol.refY = IJSVGSymbolReferenceFromString(IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeRefY),
                                                     IJSVGNodeAttributeRefY);
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeOpacity, &value)) {
        node.opacity = [IJSVGUnitLength unitWithString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeOpacity, &value)) {
        node.strokeOpacity = [IJSVGUnitLength unitWithString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeWidth, &value)) {
        node.strokeWidth = IJSVGLengthFromString(value, NO);
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeDashOffset, &value)) {
        node.strokeDashOffset = IJSVGLengthFromString(value, YES);
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeMiterLimit, &value)) {
        node.strokeMiterLimit = [IJSVGUnitLength unitWithString:value];
    }

    IJSVGNodeParserPostProcessBlock postProcessBlock = nil;
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeMask, &value)) {
        NSString* maskValue = value;
        postProcessBlock = ^{
            NSString* identifier = [IJSVGUtils defURL:maskValue];
            if(identifier != nil) {
                node.mask = (id)[self computeDetachedNodeWithIdentifier:identifier
                                                        referencingNode:node
                                                                element:element];
            }
        };
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeClipPath, &value)) {
        NSString* clipPathValue = value;
        IJSVGNodeParserPostProcessBlock previousPostProcessBlock = postProcessBlock;
        postProcessBlock = ^{
            if(previousPostProcessBlock != nil) {
                previousPostProcessBlock();
            }
            NSString* identifier = [IJSVGUtils defURL:clipPathValue];
            if(identifier != nil) {
                node.clipPath = (id)[self computeDetachedNodeWithIdentifier:identifier
                                                            referencingNode:node
                                                                    element:element];
            } else {
                node.clipPath = [IJSVGClipPath clipPathWithBasicShape:clipPathValue];
            }
        };
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeFilter, &value)) {
        NSString* filterValue = value;
        IJSVGNodeParserPostProcessBlock previousPostProcessBlock = postProcessBlock;
        postProcessBlock = ^{
            if(previousPostProcessBlock != nil) {
                previousPostProcessBlock();
            }
            node.filters = [self filtersForValue:filterValue
                                 referencingNode:node
                                         element:element];
        };
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeFilterUnits, &value)) {
        node.units = [IJSVGUtils unitTypeForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePrimitiveUnits, &value)) {
        node.contentUnits = [IJSVGUtils unitTypeForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeGradientUnits, &value)) {
        node.units = [IJSVGUtils unitTypeForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeMaskType, &value) && [node isKindOfClass:IJSVGMask.class]) {
        ((IJSVGMask*)node).maskType = [value caseInsensitiveCompare:@"alpha"] == NSOrderedSame
            ? IJSVGMaskTypeAlpha : IJSVGMaskTypeLuminance;
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeMaskUnits, &value)) {
        node.units = [IJSVGUtils unitTypeForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePatternUnits, &value)) {
        node.units = [IJSVGUtils unitTypeForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeMaskContentUnits, &value)) {
        node.contentUnits = [IJSVGUtils unitTypeForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePatternContentUnits, &value)) {
        node.contentUnits = [IJSVGUtils unitTypeForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeClipPathUnits, &value)) {
        node.contentUnits = [IJSVGUtils unitTypeForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeTransformOrigin, &value)) {
        if([value isEqualToString:@"inherit"]) {
            node.transformOrigin = node.styleParent.transformOrigin;
        } else {
            node.transformOrigin = IJSVGTransformOriginFromString(
                ([@[@"initial", @"unset"] containsObject:value.lowercaseString]) ? @"center" : value);
        }
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeTransformBox, &value)) {
        node.transformBox = [value isEqualToString:@"inherit"] ? node.styleParent.transformBox : value;
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeTransform, &value)) {
        BOOL css = [nodeStyle property:IJSVGAttributeTransform] != nil ||
            [styleSheet property:IJSVGAttributeTransform] != nil;
        IJSVGApplyParsedTransforms(node, [self parsedTransformsForValue:value allowCSSUnits:css]);
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeGradientTransform, &value)) {
        IJSVGApplyParsedTransforms(node, [self parsedTransformsForValue:value allowCSSUnits:NO]);
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePatternTransform, &value)) {
        IJSVGApplyParsedTransforms(node, [self parsedTransformsForValue:value allowCSSUnits:NO]);
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeLineCap, &value)) {
        node.lineCapStyle = [IJSVGUtils lineCapStyleForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeLineJoin, &value)) {
        node.lineJoinStyle = [IJSVGUtils lineJoinStyleForString:value];
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStroke, &value)) {
        NSString* fillIdentifier = [IJSVGUtils defURL:value];
        if(fillIdentifier != nil) {
            [self applyPaintReference:fillIdentifier node:node element:element stroke:YES];
        } else {
            IJSVGColorNode* colorNode = [self colorPaintForValue:value];
            node.stroke = colorNode;
        }
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeDashArray, &value)) {
        if([value isEqualToString:IJSVGStringNone]) {
            node.strokeDashArrayCount = 0;
            node.strokeDashLengths = nil;
        } else {
            NSArray<IJSVGUnitLength*>* lengths = IJSVGUnitLengthsFromString(value);
            if(lengths != nil) {
                CGFloat* params = malloc(lengths.count * sizeof(CGFloat));
                for(NSUInteger index = 0; index < lengths.count; index++) {
                    params[index] = lengths[index].value;
                }
                node.strokeDashArray = params;
                node.strokeDashArrayCount = lengths.count;
                node.strokeDashLengths = lengths;
            }
        }
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeColor, &value)) {
        NSString* keyword = value.lowercaseString;
        if([keyword isEqualToString:@"initial"]) {
            node.currentColor = NSColor.blackColor;
        } else if([keyword isEqualToString:@"currentcolor"] ||
                  [keyword isEqualToString:@"inherit"] ||
                  [keyword isEqualToString:@"unset"]) {
            node.currentColor = nil;
        } else if([keyword isEqualToString:@"transparent"]) {
            node.currentColor = NSColor.clearColor;
        } else {
            node.currentColor = [IJSVGColor colorFromString:value];
        }
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeBackgroundColor, &value) &&
        [node isKindOfClass:IJSVGRootNode.class]) {
        ((IJSVGRootNode*)node).backgroundColor = [value caseInsensitiveCompare:@"currentColor"] == NSOrderedSame
            ? node.currentColor : [IJSVGColor colorFromString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeFill, &value)) {
        NSString* fillIdentifier = [IJSVGUtils defURL:value];
        if(fillIdentifier != nil) {
            [self applyPaintReference:fillIdentifier node:node element:element stroke:NO];
        } else {
            IJSVGColorNode* colorNode = [self colorPaintForValue:value];
            node.fill = colorNode;
        }
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeFillOpacity, &value)) {
        node.fillOpacity = [IJSVGUnitLength unitWithString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeVectorEffect, &value)) {
        node.vectorEffect = [IJSVGUtils vectorEffectForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePaintOrder, &value)) {
        node.paintOrder = IJSVGPaintOrderFromString(value);
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeIsolation, &value)) {
        node.isolated = IJSVGIsolationFromString(value, node.parentNode.isolated);
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeBlendMode, &value)) {
        node.blendMode = [IJSVGUtils blendModeForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeFillRule, &value)) {
        node.windingRule = [IJSVGUtils windingRuleForString:value];
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeClipRule, &value)) {
        node.clipRule = [IJSVGUtils windingRuleForString:value];
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeVisibility, &value)) {
        NSString* keyword = value.lowercaseString;
        if([keyword isEqualToString:@"hidden"] || [keyword isEqualToString:@"collapse"]) {
            node.visibility = IJSVGVisibilityHidden;
        } else if([keyword isEqualToString:@"visible"] || [keyword isEqualToString:@"initial"]) {
            node.visibility = IJSVGVisibilityVisible;
        } else {
            node.visibility = IJSVGVisibilityInherit;
        }
    }
    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeDisplay, &value)) {
        if([value caseInsensitiveCompare:IJSVGStringNone] == NSOrderedSame) {
            node.shouldRender = NO;
        }
    }

    [self applyStopAttributes:attributeValues toNode:node];

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeOverflow, &value)) {
        if([value caseInsensitiveCompare:@"hidden"] == NSOrderedSame ||
           [value caseInsensitiveCompare:@"scroll"] == NSOrderedSame ||
           [value caseInsensitiveCompare:@"clip"] == NSOrderedSame) {
            node.overflowVisibility = IJSVGOverflowVisibilityHidden;
        } else if([value caseInsensitiveCompare:@"visible"] == NSOrderedSame ||
                  [value caseInsensitiveCompare:IJSVGStringAuto] == NSOrderedSame ||
                  [value caseInsensitiveCompare:@"initial"] == NSOrderedSame ||
                  [value caseInsensitiveCompare:@"unset"] == NSOrderedSame) {
            node.overflowVisibility = IJSVGOverflowVisibilityVisible;
        } else if([value caseInsensitiveCompare:@"inherit"] == NSOrderedSame) {
            node.overflowVisibility = node.parentNode != nil ? node.parentNode.overflowVisibility
                                                              : IJSVGOverflowVisibilityVisible;
        }
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeViewBox, &value)) {
        CGFloat* floats = [IJSVGUtils parseViewBox:value];
        node.viewBox = [IJSVGUnitRect rectWithX:floats[0]
                                              y:floats[1]
                                          width:floats[2]
                                         height:floats[3]];
        ((void)free(floats)), floats = NULL;
    }

    if(IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePreserveAspectRatio, &value)) {
        IJSVGViewBoxMeetOrSlice meetOrSlice;
        IJSVGViewBoxAlignment alignment = [IJSVGViewBox alignmentForString:value
                                                               meetOrSlice:&meetOrSlice];
        node.viewBoxAlignment = alignment;
        node.viewBoxMeetOrSlice = meetOrSlice;
    }

    if([node isKindOfClass:IJSVGFilterPrimitive.class]) {
        IJSVGFilterPrimitive* primitive = (IJSVGFilterPrimitive*)node;
        primitive.input = IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeIn);
        primitive.result = IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeResult);
    }

    NSString* markerStart = attributeValues[IJSVGNodeAttributeMarkerStart];
    NSString* markerMid = attributeValues[IJSVGNodeAttributeMarkerMid];
    NSString* markerEnd = attributeValues[IJSVGNodeAttributeMarkerEnd];
    if(markerStart != nil || markerMid != nil || markerEnd != nil) {
        IJSVGNodeParserPostProcessBlock previous = postProcessBlock;
        postProcessBlock = ^{
            if(previous != nil) {
                previous();
            }
            [self applyMarkerStart:markerStart
                               mid:markerMid
                               end:markerEnd
                            toNode:node
                           element:element];
        };
    }
    return postProcessBlock;
}

- (void)resolveTextPathForNode:(IJSVGText*)node
                       element:(NSXMLElement*)element
{
    NSString* identifier = [self resolveXLinkAttributeStringForElement:element];
    if(identifier != nil) {
        NSXMLElement* definition = [self detachedElementWithIdentifier:identifier];
        // Only geometry is valid here; do not recurse through arbitrary references.
        IJSVGNodeType type = IJSVGNodeTypeForString(definition.localName, definition.kind);
        if([IJSVGNode typeIsPathable:type]) {
            node.textPath = (IJSVGPath*)[self computeDetachedNodeWithIdentifier:identifier
                                                                referencingNode:nil
                                                                        element:element];
            NSString* length = [definition attributeForName:IJSVGAttributePathLength].stringValue;
            if(length.length != 0) {
                NSMutableDictionary* positioning = [node.positioning mutableCopy];
                positioning[IJSVGAttributePathLength] = IJSVGParseTextAttribute(length,
                                                                                IJSVGNodeAttributePathLength);
                node.positioning = positioning;
            }
        }
    }
    IJSVGTextAttributeValue* path = node.positioning[IJSVGAttributePath];
    if(path != nil) {
        IJSVGPath* geometry = [[IJSVGPath alloc] init];
        geometry.name = IJSVGAttributePath;
        [self applyPathData:path.string toNode:geometry];
        node.textPath = geometry;
    }
}

- (IJSVGText*)parseTextElement:(NSXMLElement*)element
                         type:(IJSVGNodeType)type
                   parentNode:(IJSVGNode*)parentNode
{
    IJSVGText* node = [[IJSVGText alloc] init];
    node.name = element.localName;
    node.type = type;
    node.isTextPath = type == IJSVGNodeTypeTextPath;
    if([parentNode isKindOfClass:IJSVGGroup.class]) {
        [(IJSVGGroup*)parentNode addChild:node];
    }
    IJSVGNodeParserPostProcessBlock postProcess = [self computeAttributesFromElement:element
                                                                              onNode:node
                                                                   ignoredAttributes:nil];

    // These are text positions, not a group translation.
    node.x = nil;
    node.y = nil;
    NSArray<NSXMLNode*>* children = element.children;
    NSMutableArray* content = [[NSMutableArray alloc] initWithCapacity:children.count];
    for(NSXMLNode* child in children) {
        if(child.kind == NSXMLTextKind) {
            [content addObject:child.stringValue ?: @""];
        } else {
            IJSVGNodeType childType = IJSVGNodeTypeForString(child.localName,
                                                             child.kind);
            if(childType == IJSVGNodeTypeTextSpan || childType == IJSVGNodeTypeTextPath ||
               childType == IJSVGNodeTypeAnchor) {
                IJSVGText* span = [self parseTextElement:(NSXMLElement*)child
                                                    type:childType
                                              parentNode:node];
                [content addObject:span];
            }
        }
    }
    node.textContent = content;
    if(node.isTextPath) {
        [self resolveTextPathForNode:node
                             element:element];
    }
    if(postProcess) {
        postProcess();
    }
    [node postProcess];
    return node;
}

- (IJSVGMarker*)markerForValue:(NSString*)value
               referencingNode:(IJSVGNode*)node
                       element:(NSXMLElement*)element
{
    NSArray<NSString*>* identifiers = [IJSVGUtils defURLs:value];
    NSString* identifier = identifiers.count == 1 ? identifiers.firstObject : nil;
    IJSVGNode* definition = identifier == nil ? nil : [self computeDetachedNodeWithIdentifier:identifier
                                                                              referencingNode:node
                                                                                      element:element];
    // An empty marker overrides inheritance for none and invalid references.
    return [definition isKindOfClass:IJSVGMarker.class] ?
        (IJSVGMarker*)definition : [[IJSVGMarker alloc] init];
}

- (void)applyMarkerStart:(NSString*)start
                     mid:(NSString*)mid
                     end:(NSString*)end
                  toNode:(IJSVGNode*)node
                 element:(NSXMLElement*)element
{
    if(start != nil && ![start isEqualToString:IJSVGStringInherit]) {
        node.markerStart = [self markerForValue:start
                                referencingNode:node
                                        element:element];
    }
    if(mid != nil && ![mid isEqualToString:IJSVGStringInherit]) {
        node.markerMid = [self markerForValue:mid
                              referencingNode:node
                                      element:element];
    }
    if(end != nil && ![end isEqualToString:IJSVGStringInherit]) {
        node.markerEnd = [self markerForValue:end
                              referencingNode:node
                                      element:element];
    }
}

- (NSArray<IJSVGTransform*>*)parsedTransformsForValue:(NSString*)value
                                        allowCSSUnits:(BOOL)allowCSSUnits
{
    NSMutableDictionary<NSString*, NSArray<IJSVGTransform*>*>* cache = allowCSSUnits
        ? _parsedCSSTransforms : _parsedSVGTransforms;
    NSArray<IJSVGTransform*>* transforms = cache[value];
    if(transforms != nil) {
        return [[NSArray alloc] initWithArray:transforms
                                    copyItems:YES];
    }
    transforms = [IJSVGTransform transformsForString:value
                                       allowCSSUnits:allowCSSUnits];
    if(value.length <= 1024 && cache.count < 128) {
        if(cache == nil) {
            cache = [[NSMutableDictionary alloc] init];
            if(allowCSSUnits) {
                _parsedCSSTransforms = cache;
            } else {
                _parsedSVGTransforms = cache;
            }
        }
        cache[value] = [[NSArray alloc] initWithArray:transforms
                                            copyItems:YES];
    }
    return transforms;
}

- (NSColor*)parsedStopColorForValue:(NSString*)value
{
    if(value.length == 0 || [value characterAtIndex:0] != '#') {
        return [IJSVGColor colorFromString:value];
    }
    NSColor* color = _parsedColors[value];
    if(color == nil) {
        color = [IJSVGColor colorFromString:value];
        if(color != nil && _parsedColors.count < 256) {
            if(_parsedColors == nil) {
                _parsedColors = [[NSMutableDictionary alloc] init];
            }
            _parsedColors[value] = color;
        }
    }
    return color;
}

- (IJSVGColorNode*)colorPaintForValue:(NSString*)value
{
    NSColor* color = [IJSVGColor colorFromString:value];
    IJSVGColorNode* colorNode = (IJSVGColorNode*)[IJSVGColorNode colorNodeWithColor:color];
    colorNode.usesCurrentColor = [value caseInsensitiveCompare:IJSVGColorCurrentColorName] == NSOrderedSame;
    colorNode.contextPaint = [IJSVGUtils contextPaintForString:value];
    if(colorNode.contextPaint != IJSVGContextPaintNone) {
        // A context paint outside an instantiated marker paints nothing.
        colorNode.isNoneOrTransparent = YES;
    } else if(color == nil) {
        colorNode.isNoneOrTransparent = [IJSVGColor isNoneOrTransparent:value];
    }
    return colorNode;
}

- (IJSVGUnitLength*)markerLengthFromElement:(NSXMLElement*)element
                                  attribute:(NSString*)attribute
                               defaultValue:(IJSVGUnitLength*)defaultValue
{
    NSString* value = [element attributeForName:attribute].stringValue;
    return value != nil ? [IJSVGUnitLength unitWithString:value] : defaultValue;
}

- (void)applyMarkerOrientation:(NSString*)orient toMarker:(IJSVGMarker*)marker
{
    marker.orientType = [IJSVGUtils markerOrientTypeForString:orient];
    marker.orientAngle = [IJSVGUtils angleForString:orient];
}

- (IJSVGMarker*)parseMarkerElement:(NSXMLElement*)element
                  postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    // Definitions are instantiated only through a marker reference.
    NSString* identifier = IJSVGParserElementIdentifier(element);
    if(identifier == nil || ![self.activeReferences containsObject:identifier]) {
        return nil;
    }
    IJSVGMarker* marker = [[IJSVGMarker alloc] init];
    marker.name = element.localName;
    marker.styleParent = [self styleAncestorForElement:element.parent];
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:marker
                                         ignoredAttributes:nil];
    marker.refX = [self markerLengthFromElement:element
                                      attribute:IJSVGAttributeRefX
                                   defaultValue:marker.refX];
    marker.refY = [self markerLengthFromElement:element
                                      attribute:IJSVGAttributeRefY
                                   defaultValue:marker.refY];
    marker.markerWidth = [self markerLengthFromElement:element
                                             attribute:IJSVGAttributeMarkerWidth
                                          defaultValue:marker.markerWidth];
    marker.markerHeight = [self markerLengthFromElement:element
                                              attribute:IJSVGAttributeMarkerHeight
                                           defaultValue:marker.markerHeight];
    NSString* units = [element attributeForName:IJSVGAttributeMarkerUnits].stringValue;
    marker.markerUnits = [IJSVGUtils markerUnitsForString:units];
    NSString* orientation = [element attributeForName:IJSVGAttributeOrient].stringValue;
    [self applyMarkerOrientation:orientation
                        toMarker:marker];
    marker.shouldRender = YES; // SVG 1.1: display does not apply to marker.
    [self computeElement:element
              parentNode:marker];
    return marker;
}

- (IJSVGNode*)parseElement:(NSXMLElement*)element
                parentNode:(IJSVGNode*)node
{
    NSString* name = element.localName;
    NSXMLNodeKind nodeKind = element.kind;
    IJSVGNodeType nodeType = IJSVGNodeTypeForString(name, nodeKind);
        
    [self parseDefElement:element
               parentNode:node
                recursive:NO];
    
    IJSVGNodeParserPostProcessBlock postProcessBlock = nil;
    IJSVGNode* computedNode = nil;
    switch(nodeType) {
        case IJSVGNodeTypeText:
            return [self parseTextElement:element
                                     type:nodeType
                               parentNode:node];
        case IJSVGNodeTypeSymbol:
            // Symbols are instantiated only as the direct target of a use.
            break;
        case IJSVGNodeTypeTextPath:
        case IJSVGNodeTypeTextSpan:
            // A standalone tspan is not rendered.
            break;
        case IJSVGNodeTypeMarker: {
            computedNode = [self parseMarkerElement:element
                                   postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeForeignObject: {
            // do nothing for foreign objects, we dont support them
            break;
        }
            
        case IJSVGNodeTypeStyle: {
            [self parseStyleElement:element
                         parentNode:node];
            break;
        }
            
        // we can treat unkown element as groups, as some people
        // thought it was a good idea to stick HTML within the markup
        case IJSVGNodeTypeUnknown:
        case IJSVGNodeTypeSwitch:
        case IJSVGNodeTypeGroup: {
            computedNode = [self parseGroupElement:element
                                        parentNode:node
                                          nodeType:nodeType
                                  postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeSVG: {
            computedNode = [self parseSVGElement:element
                                      parentNode:node
                                postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypePath: {
            computedNode = [self parsePathElement:element
                                       parentNode:node
                                 postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeCircle: {
            computedNode = [self parseCircleElement:element
                                         parentNode:node
                                   postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeEllipse: {
            computedNode = [self parseEllipseElement:element
                                          parentNode:node
                                    postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeRect: {
            computedNode = [self parseRectElement:element
                                       parentNode:node
                                 postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypePolygon: {
            computedNode = [self parsePolygonElement:element
                                          parentNode:node
                                    postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypePolyline: {
            computedNode = [self parsePolyLineElement:element
                                           parentNode:node
                                     postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeLine: {
            computedNode = [self parseLineElement:element
                                       parentNode:node
                                 postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeImage: {
            computedNode = [self parseImageElement:element
                                        parentNode:node
                                  postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypePattern: {
            computedNode = [self parsePatternElement:element
                                          parentNode:node
                                    postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeClipPath: {
            computedNode = [self parseClipPathElement:element
                                           parentNode:node
                                     postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeFilter: {
            computedNode = [self parseFilterElement:element parentNode:node postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeMask: {
            computedNode = [self parseMaskElement:element
                                       parentNode:node
                                 postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeUse: {
            computedNode = [self parseUseElement:element
                                      parentNode:node
                                postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeLinearGradient: {
            computedNode = [self parseLinearGradientElement:element
                                                 parentNode:node
                                           postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeRadialGradient: {
            computedNode = [self parseRadialGradientElement:element
                                                 parentNode:node
                                           postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeStop: {
            computedNode = [self parseStopElement:element
                                       parentNode:node
                                 postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeTitle: {
            [self parseTitleElement:element
                         parentNode:node
                   postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeDesc: {
            [self parseDescElement:element
                        parentNode:node
                  postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeDef: {
            // defs have already been handled by the parseDefElement
            // call further up
            break;
        }
        default:
            break;
    }
    
    // some nodes require post processing once their tree has been worked out
    if(postProcessBlock != nil) {
        postProcessBlock();
    }
    
    // perform any post processing
    [computedNode postProcess];
    
    return computedNode;
}

- (void)computeElement:(NSXMLElement*)element
            parentNode:(IJSVGNode*)node
{
    if(element.childCount == 0) {
        return;
    }
    [self computeDefsForElement:element
                     parentNode:node];
    BOOL isSwitch = [node isKindOfClass:IJSVGSwitch.class];
    NSXMLElement* selectedChild = isSwitch ?
        [IJSVGSwitch selectedChildInElement:element preferredLanguages:NSLocale.preferredLanguages] : nil;
    for(NSXMLNode* childNode in element.children) {
        if(childNode.kind != NSXMLElementKind) {
            continue;
        }
        NSXMLElement* child = (NSXMLElement*)childNode;
        if(isSwitch && child != selectedChild &&
           IJSVGNodeTypeForString(child.localName, child.kind) != IJSVGNodeTypeStyle) {
            continue;
        }
        [self parseElement:child
                parentNode:node];
    }
}

#pragma mark Detaching nodes
- (void)detachElement:(NSXMLElement*)element
       withIdentifier:(NSString*)identifier
{
    // we can just store the reference for later, we used to copy at this point
    // but realised there can be a lot of elements with IDs that dont actually ever
    // get used, so just store reference and let the usage deal with copy and detach
    _detachedReferences[identifier] = element;
}

- (NSXMLElement*)detachedElementWithIdentifier:(NSString*)identifier
{
    return _detachedReferences[identifier];
}

- (IJSVGStyleSheetSelectorRecord*)buildSelectorTreeForElement:(NSXMLElement*)element
                                     nodes:(NSMapTable<NSXMLElement*, IJSVGStyleSheetSelectorRecord*>*)nodes
{
    IJSVGStyleSheetSelectorRecord* node = [[IJSVGStyleSheetSelectorRecord alloc] init];
    node.name = element.localName;
    node.identifier = IJSVGParserElementIdentifier(element);
    NSString* className = [element attributeForName:IJSVGAttributeClass].stringValue;
    node.classNameList = IJSVGClassNameList(className);
    [nodes setObject:node forKey:element];
    IJSVGStyleSheetSelectorRecord* previous = nil;
    for(NSXMLNode* child in element.children) {
        if(child.kind == NSXMLElementKind) {
            IJSVGStyleSheetSelectorRecord* record =
                [self buildSelectorTreeForElement:(NSXMLElement*)child nodes:nodes];
            record.selectorParent = node;
            record.selectorPreviousSibling = previous;
            previous = record;
        }
    }
    return node;
}

- (IJSVGStyleSheetSelectorRecord*)selectorNodeForElement:(NSXMLElement*)element
{
    if(!_styleSheet.requiresSelectorTree) {
        return nil;
    }
    IJSVGStyleSheetSelectorRecord* scoped = [self.selectorScope objectForKey:element];
    if(scoped != nil) {
        return scoped;
    }
    if(self.selectorNodes == nil) {
        // Look up records by the XML object address.
        // Hashing XML contents becomes expensive when an element has many siblings.
        self.selectorNodes = IJSVGParserElementMapTable();
        [self buildSelectorTreeForElement:_document.rootElement
                                    nodes:self.selectorNodes];
    }
    return [self.selectorNodes objectForKey:element];
}

- (IJSVGNode*)styleAncestorForElement:(NSXMLNode*)element
{
    if(element.kind != NSXMLElementKind) {
        return nil;
    }
    NSXMLElement* source = (NSXMLElement*)element;
    IJSVGNode* ancestor = [self.styleAncestors objectForKey:source];
    if(ancestor != nil) {
        return ancestor;
    }
    ancestor = [[IJSVGGroup alloc] init];
    ancestor.name = source.localName;
    [self.styleAncestors setObject:ancestor forKey:source];
    ancestor.styleParent = [self styleAncestorForElement:source.parent];
    // Reuse normal attribute parsing without rendering ancestor effects.
    [self computeAttributesFromElement:source
                                onNode:ancestor
                     ignoredAttributes:nil];
    return ancestor;
}

- (void)applyPaintReference:(NSString*)identifier
                       node:(IJSVGNode*)node
                    element:(NSXMLElement*)element
                     stroke:(BOOL)stroke
{
    void (^apply)(IJSVGNode*) = ^(IJSVGNode* paint) {
        if(stroke) {
            node.stroke = paint;
        } else {
            node.fill = paint;
        }
    };
    if([self.styleAncestors objectForKey:element] == node &&
       [self.activeReferences containsObject:identifier]) {
        NSMutableArray* pending = self.pendingStylePaints[identifier];
        if(pending == nil) {
            pending = [[NSMutableArray alloc] init];
            self.pendingStylePaints[identifier] = pending;
        }
        [pending addObject:apply];
        return;
    }
    apply([self computeDetachedNodeWithIdentifier:identifier
                                  referencingNode:node
                                          element:element]);
}

- (IJSVGNode*)computeDetachedNodeWithIdentifier:(NSString*)identifier
                                referencingNode:(IJSVGNode*)node
                                        element:(NSXMLElement*)element
{
    NSXMLElement* source = [self detachedElementWithIdentifier:identifier];
    if(source == nil || [self.activeReferences containsObject:identifier]) {
        return nil;
    }
    if([self isElement:element
            decedentOf:source]) {
        [self recursionDetectedOn:element
                      decendentOf:source
                       identifier:identifier];
        return nil;
    }
    [self.activeReferences addObject:identifier];
    NSMapTable* previousScope = self.selectorScope;
    self.selectorScope = nil;
    @try {
        IJSVGNode* parent = [self styleAncestorForElement:source.parent];
        if(parent != nil) {
            [self.definitionStyleParents setObject:parent
                                            forKey:source];
        }
        IJSVGNode* detached = [self parseElement:source
                                      parentNode:node].detach;
        detached.styleParent = parent;
        for(void (^apply)(IJSVGNode*) in self.pendingStylePaints[identifier]) {
            apply(detached);
        }
        return detached;
    } @finally {
        [self.pendingStylePaints removeObjectForKey:identifier];
        [self.definitionStyleParents removeObjectForKey:source];
        [self.activeReferences removeObject:identifier];
        self.selectorScope = previousScope;
    }
}

- (void)recursionDetectedOn:(NSXMLElement*)element
                decendentOf:(NSXMLElement*)parent
                 identifier:(NSString*)identifier
{
  // For now, we only want to log these for debug builds whilst we fix any
  // SVGs that are problematic.
#if DEBUG
  NSLog(@"<%@> Recursion detected in file: \"%@\", with identifer: \"%@\"",
        self.className, _fileURL ?: @"Unknown", identifier);
#endif
}

- (BOOL)isElement:(NSXMLElement*)element
       decedentOf:(NSXMLElement*)parentElement {
    NSXMLElement* parent = (NSXMLElement*)element.parent;
    while(parent != nil) {
      if(parentElement == parent) {
        return YES;
      }
      parent = (NSXMLElement*)parent.parent;
    }
    return NO;
}

- (NSXMLElement*)mergedElement:(NSXMLElement*)element
          withReferenceElement:(NSXMLElement*)reference
{
    NSXMLElement* copy = reference.copy;
    for (__strong NSXMLNode* attribute in element.attributes) {
        [copy removeAttributeForName:attribute.name];
        attribute = attribute.copy;
        [copy addAttribute:attribute];
    }
  
    // if we merge an element, we need to also maintain its children, if the
    // reference element has children and the referencing element does not,
    // use those else use the referencing element children.
    if (element.childCount != 0) {
      // remove any old children, iterate back to front so we do not mutate
      // the collection we are enumerating (removing by index whilst fast
      // enumerating shifts indexes and is undefined behaviour)
      for(NSUInteger i = copy.childCount; i > 0; i--) {
        [copy removeChildAtIndex:i - 1];
      }

      // add the new ones from the copy
      for(__strong NSXMLElement* child in element.children) {
        [copy addChild:child.copy];
      }
    }
    return copy;
}

#pragma mark Node Types

- (void)parseStyleElement:(NSXMLElement*)element
               parentNode:(IJSVGNode*)parentNode
{
    // Repeating the latest style block cannot change the cascade.
    // Keep registrations separated by other blocks in their existing order.
    if(_lastParsedStyleElement == element) {
        return;
    }
    NSString* media = [element attributeForName:IJSVGAttributeMedia].stringValue;
    if(media.length != 0) {
        CGSize viewport = _rootSize;
        NSString* width = [_document.rootElement attributeForName:IJSVGAttributeWidth].stringValue;
        NSString* height = [_document.rootElement attributeForName:IJSVGAttributeHeight].stringValue;
        if(width != nil) {
            viewport.width = [[IJSVGUnitLength unitWithString:width] computeValue:viewport.width];
        }
        if(height != nil) {
            viewport.height = [[IJSVGUnitLength unitWithString:height] computeValue:viewport.height];
        }
        IJSVGMediaEnvironment environment = { viewport, IJSVGMediaTypeScreen };
        IJSVGMediaQuery* query = IJSVGMediaQueryCreate(media);
        BOOL matches = IJSVGMediaQueryMatches(query, environment);
        IJSVGMediaQueryRelease(query);
        if(!matches) {
            return;
        }
    }
    _lastParsedStyleElement = element;
    [_styleSheet parseStyleBlock:element.stringValue];
}

- (IJSVGNode*)parseLinearGradientElement:(NSXMLElement*)element
                              parentNode:(IJSVGNode*)parentNode
                        postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGLinearGradient* node = [[IJSVGLinearGradient alloc] init];
    node.units = IJSVGUnitObjectBoundingBox;
    node.name = element.localName;
    [node addTraits:IJSVGNodeTraitPaintable];
    
    NSString* xLinkID = [self resolveXLinkAttributeStringForElement:element];
    if(xLinkID != nil) {
        NSXMLElement* detachedElement = [self detachedElementWithIdentifier:xLinkID];
        element = [self mergedElement:element
                 withReferenceElement:detachedElement];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    [self computeElement:element
              parentNode:node];
    [IJSVGLinearGradient parseGradient:element
                              gradient:node];
    return node;
}

- (IJSVGNode*)parseRadialGradientElement:(NSXMLElement*)element
                              parentNode:(IJSVGNode*)parentNode
                        postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGRadialGradient* node = [[IJSVGRadialGradient alloc] init];
    node.units = IJSVGUnitObjectBoundingBox;
    node.name = element.localName;
    [node addTraits:IJSVGNodeTraitPaintable];
    
    NSString* xLinkID = [self resolveXLinkAttributeStringForElement:element];
    if(xLinkID != nil) {
        NSXMLElement* detachedElement = [self detachedElementWithIdentifier:xLinkID];
        element = [self mergedElement:element
                 withReferenceElement:detachedElement];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    [self computeElement:element
              parentNode:node];
    [IJSVGRadialGradient parseGradient:element
                              gradient:node];
    return node;
}

- (IJSVGNode*)parseStopElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
              postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGStop* node = [[IJSVGStop alloc] init];
    node.name = element.localName;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    return node;
}

- (NSDictionary*)customPropertiesForNode:(IJSVGNode*)node
                                   style:(IJSVGStyleSheetStyle*)style
                             inlineStyle:(IJSVGStyleSheetStyle*)inlineStyle
{
    NSDictionary* inherited = nil;
    if(self.customProperties != nil) {
        for(IJSVGNode* parent = node.styleParent; parent != nil; parent = parent.styleParent) {
            inherited = [self.customProperties objectForKey:parent];
            if(inherited != nil) {
                break;
            }
        }
    }
    if(!style.hasCustomProperties && !inlineStyle.hasCustomProperties) {
        return inherited;
    }
    NSMutableDictionary* declarations = [[NSMutableDictionary alloc] init];
    IJSVGStyleSheetStyle* __unsafe_unretained sources[] = { style, inlineStyle };
    for(NSUInteger index = 0; index < 2; index++) {
        IJSVGStyleSheetStyle* source = sources[index];
        if(!source.hasCustomProperties) {
            continue;
        }
        for(NSString* property in source.properties) {
            if(![property hasPrefix:@"--"]) {
                continue;
            }
            if(source == inlineStyle && [style isPropertyImportant:property] &&
               ![inlineStyle isPropertyImportant:property]) {
                continue;
            }
            declarations[property] = [source property:property];
        }
    }
    NSDictionary* result = IJSVGCSSResolveCustomProperties(declarations, inherited);
    if(self.customProperties == nil) {
        self.customProperties = [NSMapTable weakToStrongObjectsMapTable];
    }
    [self.customProperties setObject:result
                              forKey:node];
    return result;
}

- (void)applyPathValue:(NSString*)value
                toNode:(IJSVGNode*)node
                   css:(BOOL)css
              fallback:(NSString*)fallback
{
    if(!css && node.type != IJSVGNodeTypePath) {
        return;
    }
    NSString* pathData = value;
    if(css) {
        switch(IJSVGCSSWideKeywordFromString(value)) {
            case IJSVGCSSWideKeywordInherit: {
                IJSVGNode* parent = node.styleParent;
                pathData = parent.type == IJSVGNodeTypePath
                    ? ((IJSVGPath*)parent).markerPathData
                    : [self.inheritedPathData objectForKey:parent];
                break;
            }
            case IJSVGCSSWideKeywordInitial:
            case IJSVGCSSWideKeywordUnset: {
                pathData = nil;
                break;
            }
            case IJSVGCSSWideKeywordRevert:
            case IJSVGCSSWideKeywordRevertLayer: {
                pathData = fallback;
                break;
            }
            case IJSVGCSSWideKeywordUnknown: {
                pathData = IJSVGCSSPathDataFromString(value);
                break;
            }
        }
    }
    if(node.type != IJSVGNodeTypePath) {
        if(pathData != nil) {
            if(self.inheritedPathData == nil) {
                self.inheritedPathData = [NSMapTable weakToStrongObjectsMapTable];
            }
            [self.inheritedPathData setObject:pathData
                                       forKey:node];
        } else {
            [self.inheritedPathData removeObjectForKey:node];
        }
    } else {
        IJSVGPath* path = (IJSVGPath*)node;
        if(!CGPathIsEmpty(path.path)) {
            CGMutablePathRef empty = CGPathCreateMutable();
            path.path = empty;
            CGPathRelease(empty);
        }
        [self applyPathData:pathData
                     toNode:path];
        path.markerPathData = pathData;
    }
}

- (void)applyPathData:(NSString*)pathData
               toNode:(IJSVGPath*)node
{
    if(pathData == nil) {
        return;
    }
    if(_parsedPathCache == NULL) {
        _parsedPathCache = IJSVGParsedPathCacheCreate();
    }
    CGPathRef cachedPath = IJSVGParsedPathCacheCopy(_parsedPathCache, pathData,
                                                    IJSVGParsedPathData);
    if(cachedPath != NULL) {
        node.path = (CGMutablePathRef)cachedPath;
        CGPathRelease(cachedPath);
        return;
    }
    const char* characters = pathData.UTF8String;
    NSUInteger length = characters != NULL ? strlen(characters) : 0;
    BOOL mayHavePointSubpaths = IJSVGAppendPathDataCheckingPointSubpaths(node.path, characters,
                                                                         length, _commandDataStream);
    CGPathRef cached = CGPathCreateCopy(node.path);
    if(!mayHavePointSubpaths) {
        [node cachePointSubpaths:NO
                         forPath:cached];
    }
    IJSVGParsedPathCacheStore(_parsedPathCache, pathData, IJSVGParsedPathData,
                              cached);
    CGPathRelease(cached);
}

- (IJSVGNode*)parsePathElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
              postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.name = element.localName;
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    return node;
}

- (IJSVGNode*)parseLineElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
              postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.type = IJSVGNodeTypeLine;
    node.primitiveType = kIJSVGPrimitivePathTypeLine;
    node.name = element.localName;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    node.x1 = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeX1].stringValue];
    node.y1 = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeY1].stringValue];
    node.x2 = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeX2].stringValue];
    node.y2 = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeY2].stringValue];
    return node;
}

- (IJSVGNode*)parsePolyLineElement:(NSXMLElement*)element
                        parentNode:(IJSVGNode*)parentNode
                  postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.type = IJSVGNodeTypePolyline;
    node.name = element.localName;
    node.primitiveType = kIJSVGPrimitivePathTypePolyLine;
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    NSString* pointsString = [element attributeForName:IJSVGAttributePoints].stringValue;
    [self parsePolyPoints:pointsString
                 intoPath:node
                closePath:NO];
    
    return node;
}

- (IJSVGNode*)parsePolygonElement:(NSXMLElement*)element
                       parentNode:(IJSVGNode*)parentNode
                 postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.type = IJSVGNodeTypePolygon;
    node.name = element.localName;
    node.primitiveType = kIJSVGPrimitivePathTypePolygon;
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    NSString* pointsString = [element attributeForName:IJSVGAttributePoints].stringValue;
    [self parsePolyPoints:pointsString
                 intoPath:node
                closePath:YES];
    
    return node;
}

- (IJSVGNode*)parseEllipseElement:(NSXMLElement*)element
                       parentNode:(IJSVGNode*)parentNode
                 postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.name = element.localName;
    node.primitiveType = kIJSVGPrimitivePathTypeEllipse;
    node.type = IJSVGNodeTypeEllipse;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    return node;
}

- (IJSVGNode*)parseCircleElement:(NSXMLElement*)element
                      parentNode:(IJSVGNode*)parentNode
                postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.name = element.localName;
    node.primitiveType = kIJSVGPrimitivePathTypeCircle;
    node.type = IJSVGNodeTypeCircle;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    return node;
}

- (IJSVGNode*)parseGroupElement:(NSXMLElement*)element
                     parentNode:(IJSVGNode*)parentNode
                       nodeType:(IJSVGNodeType)nodeType
               postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGGroup* node = nodeType == IJSVGNodeTypeSwitch ? [[IJSVGSwitch alloc] init] : [[IJSVGGroup alloc] init];
    node.type = nodeType;
    node.name = element.localName;
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    // recursively compute children
    [self computeElement:element
              parentNode:node];
    return node;
}

- (void)parseSVGElement:(NSXMLElement*)element
               ontoNode:(IJSVGRootNode*)node
             parentNode:(IJSVGNode*)parentNode
       postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
              recursive:(BOOL)recursive
{
    node.name = element.localName;
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    [self parseDefElement:element
               parentNode:node
                recursive:NO];
    
    if(parentNode != nil) {
        node.overflowVisibility = IJSVGOverflowVisibilityHidden;
    }

    // if we are the root node and not a nested SVG, disable transforms
    IJSVGBitFlags* ignored = nil;
    if(parentNode == nil) {
        ignored = [[IJSVGBitFlags64 alloc] init];
        [ignored setBit:IJSVGNodeAttributeTransform];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:ignored];
  
    // Only the outer document needs intrinsic size inference. A nested SVG
    // defaults to the containing viewport and may have no viewBox at all.
    if(parentNode == nil) {
        [self computeViewBoxForRootNode:node];
        [self inferDefaultIntrinsicSizeAndViewBoxForRootNode:node];
    }
    
    // recursively compute children
    if(recursive == YES) {
      [self computeElement:element
                parentNode:node];
    }
  
}

- (IJSVGNode*)parseSVGElement:(NSXMLElement*)element
                   parentNode:(IJSVGNode*)parentNode
             postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGRootNode* node = [[IJSVGRootNode alloc] init];
    [self parseSVGElement:element
                 ontoNode:node
               parentNode:parentNode
         postProcessBlock:postProcessBlock
                recursive:YES];
    return node;
}

- (IJSVGNode*)parseRectElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
              postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.type = IJSVGNodeTypeRect;
    node.primitiveType = kIJSVGPrimitivePathTypeRect;
    node.name = element.localName;
  
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    return node;
}

- (IJSVGNode*)parseImageElement:(NSXMLElement*)element
                     parentNode:(IJSVGNode*)parentNode
               postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGImage* node = [[IJSVGImage alloc] init];
    node.name = element.localName;
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    // load image from base64
    NSXMLNode* dataNode = [self resolveXLinkAttributeForElement:element];
    
    [node loadFromString:dataNode.stringValue];
    return node;
}

- (IJSVGNode*)parseSymbolElement:(NSXMLElement*)element
                      parentNode:(IJSVGGroup*)parentNode
{
    IJSVGRootNode* node = [[IJSVGRootNode alloc] init];
    node.type = IJSVGNodeTypeSymbol;
    node.name = element.localName;
    node.parentNode = parentNode;
    node.overflowVisibility = IJSVGOverflowVisibilityHidden;

    // Symbols inherit presentation properties from their use element.
    node.lineCapStyle = IJSVGLineCapStyleInherit;
    node.lineJoinStyle = IJSVGLineJoinStyleInherit;
    node.strokeMiterLimit = [node.strokeMiterLimit lengthWithInheritance:YES];
    node.strokeDashArrayCount = IJSVGInheritedIntegerValue;
    IJSVGNodeParserPostProcessBlock postProcessBlock = [self computeAttributesFromElement:element
                                                                                   onNode:node
                                                                        ignoredAttributes:nil];
    node.width = parentNode.width ?: node.width ?: IJSVGOnePercentageUnitLength;
    node.height = parentNode.height ?: node.height ?: IJSVGOnePercentageUnitLength;
    node.shouldRender = YES;
    [self computeElement:element
              parentNode:node];
    if(postProcessBlock != nil) {
        postProcessBlock();
    }
    [node postProcess];
    return node;
}

- (IJSVGNode*)parseUseElement:(NSXMLElement*)element
                   parentNode:(IJSVGNode*)parentNode
             postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    NSString* xlinkID = [self resolveXLinkAttributeStringForElement:element];
    if(xlinkID == nil) {
        // An empty use can still produce pixels through a filter in user space.
        return [self parseGroupElement:element
                            parentNode:parentNode
                              nodeType:IJSVGNodeTypeUse
                      postProcessBlock:postProcessBlock];
    }
  
    // its important that we remove the xlink attribute or hell breaks loose
    NSXMLElement* detachedElement = [self detachedElementWithIdentifier:xlinkID];
  
    // We are trying to use an element that is a decedent of itself.
    if([self isElement:element decedentOf:detachedElement]) {
      [self recursionDetectedOn:element
                    decendentOf:detachedElement
                     identifier:xlinkID];
      return nil;
    }

    IJSVGGroup* node = (IJSVGGroup*)[self parseGroupElement:element
                                                 parentNode:parentNode
                                                   nodeType:IJSVGNodeTypeUse
                                           postProcessBlock:postProcessBlock];
        
    if(detachedElement == nil || [self.activeReferences containsObject:xlinkID]) {
        return node;
    }
    NSMapTable* previousScope = self.selectorScope;
    self.selectorScope = nil;
    if(_styleSheet.requiresSelectorTree) {
        self.selectorScope = [self.selectorScopes objectForKey:detachedElement];
        if(self.selectorScope == nil) {
            self.selectorScope = IJSVGParserElementMapTable();
            [self buildSelectorTreeForElement:detachedElement
                                        nodes:self.selectorScope];
            if(self.selectorScopes == nil) {
                self.selectorScopes = IJSVGParserElementMapTable();
            }
            [self.selectorScopes setObject:self.selectorScope
                                    forKey:detachedElement];
        }
    }
    [self.activeReferences addObject:xlinkID];
    @try {
        IJSVGNodeType type = IJSVGNodeTypeForString(detachedElement.localName,
                                                    detachedElement.kind);
        IJSVGNode* shadowNode = type == IJSVGNodeTypeSymbol
            ? [self parseSymbolElement:detachedElement parentNode:node]
            : [self parseElement:detachedElement parentNode:node];
        if(shadowNode != nil) {
            [node addChild:shadowNode];
        }
    } @finally {
        [self.activeReferences removeObject:xlinkID];
        self.selectorScope = previousScope;
    }
    return node;
}

- (void)replaceAttributes:(NSArray<NSString*>*)attributes
                onElement:(NSXMLElement*)onElement
              fromElement:(NSXMLElement*)fromElement
{
    [self.rawAttributes removeObjectForKey:onElement];
    [self.rawAttributes removeObjectForKey:fromElement];
    for(NSString* collpaseAttribute in attributes) {
        NSXMLNode* attribute = nil;
        if((attribute = [fromElement attributeForName:collpaseAttribute]) != nil &&
           [onElement attributeForName:collpaseAttribute] != nil) {
            [attribute detach];
            [onElement removeAttributeForName:collpaseAttribute];
            [onElement addAttribute:attribute];
        }
    }
}

- (IJSVGNode*)parsePatternElement:(NSXMLElement*)element
                       parentNode:(IJSVGNode*)parentNode
                 postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPattern* node = [[IJSVGPattern alloc] init];
    node.name = element.localName;
    node.parentNode = parentNode;
    node.units = IJSVGUnitObjectBoundingBox;
    node.contentUnits = IJSVGUnitUserSpaceOnUse;
    [node addTraits:IJSVGNodeTraitPaintable];
    NSString* xLinkID = [self resolveXLinkAttributeStringForElement:element];
    if(xLinkID != nil) {
        NSXMLElement* detachedElement = [self detachedElementWithIdentifier:xLinkID];
        element = [self mergedElement:element
                 withReferenceElement:detachedElement];
    }
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    [self computeElement:element
              parentNode:node];
    return node;
}

- (IJSVGNode*)parseClipPathElement:(NSXMLElement*)element
                        parentNode:(IJSVGNode*)parentNode
                  postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGClipPath* node = [[IJSVGClipPath alloc] init];
    node.name = element.localName;
    node.parentNode = parentNode;
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    [self computeElement:element
              parentNode:node];
    
    return node;
}

- (void)parseFilterChildren:(NSXMLElement*)element parentNode:(IJSVGGroup*)node
{
    for(NSXMLNode* child in element.children) {
        IJSVGNodeType type = IJSVGNodeTypeForString(child.localName, child.kind);
        if([IJSVGFilterPrimitive type:node.type acceptsChildType:type]) {
            [self parseFilterPrimitiveElement:(NSXMLElement*)child parentNode:node];
        }
    }
}

- (IJSVGNode*)filterReferenceWithIdentifier:(NSString*)identifier
                            referencingNode:(IJSVGNode*)node
                                    element:(NSXMLElement*)element
{
    if(self.activeFilterReferences == nil) {
        self.activeFilterReferences = [[NSMutableSet alloc] init];
    }
    if([self.activeFilterReferences containsObject:identifier]) {
        return nil;
    }
    [self.activeFilterReferences addObject:identifier];
    @try {
        return [self computeDetachedNodeWithIdentifier:identifier
                                       referencingNode:node
                                               element:element];
    } @finally {
        [self.activeFilterReferences removeObject:identifier];
    }
}

- (NSArray<NSString*>*)filterIdentifiersForValue:(NSString*)value
{
    NSArray<NSString*>* identifiers = _parsedFilterReferences[value];
    if(identifiers == nil) {
        identifiers = [IJSVGUtils defURLs:value];
        if(value.length <= 4096 && _parsedFilterReferences.count < 128) {
            if(_parsedFilterReferences == nil) {
                _parsedFilterReferences = [[NSMutableDictionary alloc] init];
            }
            _parsedFilterReferences[value] = identifiers.copy;
        }
    }
    return identifiers;
}

- (NSArray<IJSVGFilter*>*)filtersForValue:(NSString*)value
                          referencingNode:(IJSVGNode*)node
                                  element:(NSXMLElement*)element
{
    NSArray<NSString*>* identifiers = [self filterIdentifiersForValue:value];
    NSMutableArray<IJSVGFilter*>* filters = [[NSMutableArray alloc] init];
    for(NSString* identifier in identifiers) {
        NSXMLElement* definition = [self detachedElementWithIdentifier:identifier];
        if(IJSVGNodeTypeForString(definition.localName, definition.kind) != IJSVGNodeTypeFilter) {
            return @[];
        }
        IJSVGFilter* filter = (IJSVGFilter*)[self filterReferenceWithIdentifier:identifier
                                                                referencingNode:node
                                                                        element:element];
        if(filter == nil) {
            return @[];
        }
        [filters addObject:filter];
    }
    return filters;
}

- (IJSVGFilterPrimitive*)parseFilterPrimitiveElement:(NSXMLElement*)element
                                          parentNode:(IJSVGGroup*)parentNode
{
    IJSVGNodeType type = IJSVGNodeTypeForString(element.localName, element.kind);
    IJSVGFilterPrimitive* node = [[IJSVGFilterPrimitive alloc] init];
    node.type = type;
    node.name = element.localName;
    [parentNode addChild:node];

    IJSVGNodeParserPostProcessBlock postProcessBlock = [self computeAttributesFromElement:element
                                                                                   onNode:node
                                                                        ignoredAttributes:nil];
    if(postProcessBlock != nil) {
        postProcessBlock();
    }

    [self parseFilterChildren:element parentNode:node];
    if(node.type == IJSVGNodeTypeFilterImage) {
        NSString* href = [self resolveXLinkAttributeForElement:element].stringValue;
        NSString* identifier = [self resolveXLinkAttributeStringForElement:element];
        if(href != nil) {
            NSMutableDictionary* parameters = node.parameters.mutableCopy;
            parameters[IJSVGAttributeHref] = href;
            [parameters removeObjectForKey:IJSVGAttributeXLink];
            node.parameters = parameters;
        }
        if(identifier != nil) {
            node.imageNode = [self filterReferenceWithIdentifier:identifier
                                                 referencingNode:node
                                                         element:element];
            [node removeChild:node.imageNode];
        } else if(href.length != 0) {
            IJSVGImage* image = [[IJSVGImage alloc] init];
            if([href hasPrefix:@"data:"]) {
                [image loadFromString:href];
            } else {
                [image loadFromURL:[NSURL URLWithString:href
                                          relativeToURL:_fileURL]];
            }
            node.image = image.image;
        }
    }
    return node;
}

- (IJSVGNode*)parseFilterElement:(NSXMLElement*)element
                      parentNode:(IJSVGNode*)parentNode
                postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGFilter* node = [[IJSVGFilter alloc] init];
    node.name = element.localName;
    node.parentNode = parentNode;

    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];

    NSString* identifier = [self resolveXLinkAttributeStringForElement:element];
    if(identifier != nil) {
        IJSVGNode* inherited = [self filterReferenceWithIdentifier:identifier
                                                   referencingNode:node
                                                           element:element];
        if([inherited isKindOfClass:IJSVGFilter.class]) {
            IJSVGFilter* template = (IJSVGFilter*)inherited;
            if([element attributeForName:IJSVGAttributeX] == nil) {
                node.x = template.x;
            }
            if([element attributeForName:IJSVGAttributeY] == nil) {
                node.y = template.y;
            }
            if([element attributeForName:IJSVGAttributeWidth] == nil) {
                node.width = template.width;
            }
            if([element attributeForName:IJSVGAttributeHeight] == nil) {
                node.height = template.height;
            }
            if([element attributeForName:IJSVGAttributeFilterUnits] == nil) {
                node.units = template.units;
            }
            if([element attributeForName:IJSVGAttributePrimitiveUnits] == nil) {
                node.contentUnits = template.contentUnits;
            }
            if(node.filterColorInterpolation == IJSVGColorInterpolationUnspecified) {
                node.filterColorInterpolation = template.filterColorInterpolation;
            }
            [self parseFilterChildren:element parentNode:node];
            if(node.children.count == 0) {
                for(IJSVGFilterPrimitive* primitive in template.primitives) {
                    IJSVGFilterPrimitive* copy = primitive.copy;
                    copy.parentNode = nil;
                    [node addChild:copy];
                }
            }
            return node;
        }
    }
    [self parseFilterChildren:element
                   parentNode:node];
    return node;
}

- (IJSVGNode*)parseMaskElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
              postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGMask* node = [[IJSVGMask alloc] init];
    node.name = element.localName;
    node.parentNode = parentNode;
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    [self computeElement:element
              parentNode:node];
    return node;
}

- (void)parseDefElement:(NSXMLElement*)element
             parentNode:(IJSVGNode*)parentNode
              recursive:(BOOL)recursive
{
    if(element.childCount == 0) {
        return;
    }
    for(NSXMLElement* childElement in element.children) {
        IJSVGNodeType type = IJSVGNodeTypeForString(childElement.localName,
                                                    childElement.kind);
        
        // we can exit early, not a node we know of
        if(type == IJSVGNodeTypeNotFound) {
            continue;
        }
        
        // we always want style elements to be passed
        NSString* identifier = IJSVGParserElementIdentifier(childElement);
        if(identifier != nil) {
            [self detachElement:childElement
                 withIdentifier:identifier];
        }
        
        if(type == IJSVGNodeTypeStyle) {
            [self parseStyleElement:childElement
                         parentNode:parentNode];
        } else {
            // only run this if recursive or it can be slow or incorrect
            // when parsing the tree with ids that are the same
            if(recursive == YES && childElement.childCount != 0) {
                [self parseDefElement:childElement
                           parentNode:parentNode
                            recursive:recursive];
            }
        }
    }
}

- (void)parseTitleElement:(NSXMLElement*)element
               parentNode:(IJSVGNode*)parentNode
         postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    parentNode.title = element.stringValue;
}

- (void)parseDescElement:(NSXMLElement*)element
              parentNode:(IJSVGNode*)parentNode
        postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    parentNode.desc = element.stringValue;
}

#pragma mark XLink

- (NSXMLNode*)resolveXLinkAttributeForElement:(NSXMLElement*)element
{
    NSXMLNode* legacyAttribute = nil;
    BOOL hasQualifiedHref = NO;
    for(NSXMLNode* attribute in element.attributes) {
        NSString* name = attribute.name;
        if([name isEqualToString:IJSVGAttributeHref]) {
            return attribute;
        }
        if([name hasSuffix:@":href"]) {
            hasQualifiedHref = YES;
            if([name isEqualToString:IJSVGAttributeXLink]) {
                legacyAttribute = attribute;
            }
        }
    }
    if(!hasQualifiedHref) {
        return nil;
    }
    return [element attributeForLocalName:IJSVGAttributeHref
                                     URI:@"http://www.w3.org/1999/xlink"] ?: legacyAttribute;
}

- (NSString*)resolveXLinkAttributeStringForElement:(NSXMLElement*)element
{
    NSString* value = [self resolveXLinkAttributeForElement:element].stringValue;
    if([value hasPrefix:@"#"] && value.length > 1) {
        return [value substringFromIndex:1];
    }
    return nil;
}

#pragma mark Command Parsing

- (void)parsePolyPoints:(NSString*)points
               intoPath:(IJSVGPath*)path
              closePath:(BOOL)closePath
{
    BOOL cacheable = points != nil && CGPathIsEmpty(path.path);
    if(cacheable && _parsedPathCache == NULL) {
        _parsedPathCache = IJSVGParsedPathCacheCreate();
    }
    IJSVGParsedPathKind kind = closePath ? IJSVGParsedPathPolygon : IJSVGParsedPathPolyline;
    CGPathRef cached = cacheable ? IJSVGParsedPathCacheCopy(_parsedPathCache, points, kind) : NULL;
    BOOL parsed = cached != NULL;
    if(parsed) {
        path.path = (CGMutablePathRef)cached;
        CGPathRelease(cached);
    } else {
        const char* characters = points.UTF8String;
        NSUInteger length = characters != NULL ? strlen(characters) : 0;
        parsed = IJSVGAppendPolyPoints(path.path, characters, length, closePath, _commandDataStream);
        if(parsed && cacheable) {
            IJSVGParsedPathCacheStore(_parsedPathCache, points, kind, path.path);
        }
    }
    if(parsed) {
        IJSVGNode* referencingNode = nil;
        path.pathUnits = [path contentUnitsWithReferencingNode:&referencingNode];
    }
}

@end
