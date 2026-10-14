//
//  IJSVGParser.m
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGFilterPrimitive.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGText.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGUnitPoint.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVGCSSParser.h>
#import <IJSVGCSSVariables.h>
#import <IJSVGGradientGeometry.h>
#import <IJSVGGradientStops.h>
#import <IJSVGInheritedElement.h>
#import <IJSVGNodeParsing.h>
#import <IJSVGParsedPathCache.h>
#import <IJSVGParserTextUtils.h>
#import <IJSVGParserUtils.h>
#import <IJSVGStyleSheetUtils.h>
#import <IJSVGSwitch.h>

// Newly created nodes derive canonical names from their type. Only unknown
// elements and noncanonical source spelling need an explicit name override.
static void IJSVGPreserveElementName(IJSVGNode* node, IJSVGXMLNode* element)
{
    const char* canonical = node.name.UTF8String;
    if (canonical == NULL || strcmp(canonical, element->name) != 0) {
        node.name = IJSVGXMLLocalName(element);
    }
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

@interface IJSVGColor (ParserColorCreation)
+ (NSColor*)colorFromHEXInteger:(NSInteger)hex containsAlphaComponent:(BOOL)containsAlphaComponent;
@end

static NSString* IJSVGParserElementIdentifier(IJSVGXMLNode* element)
{
    IJSVGXMLAttributeList elementAttributeIterator = IJSVGXMLAttributes(element);
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&elementAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&elementAttributeIterator)) {
        if (attribute->identifier == IJSVGNodeAttributeID) {
            return IJSVGXMLAttributeValue(attribute);
        }
    }
    return nil;
}

static NSMapTable* IJSVGParserElementMapTable(void)
{
    NSPointerFunctionsOptions options = NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality;
    return [NSMapTable mapTableWithKeyOptions:options valueOptions:NSPointerFunctionsStrongMemory];
}

typedef struct {
    NSUInteger attribute;
    __unsafe_unretained NSString* value;
} IJSVGParserRawAttribute;

// Keep the raw strings alive while cached entries refer to them.
// Resolve inherited values separately because each use can have a different
// parent.
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
    NSMutableDictionary<NSNumber*, IJSVGUnitLength*>* geometryLengths;
    NSMutableDictionary<NSNumber*, NSString*>* geometryValues;
}

- (instancetype)initWithElement:(IJSVGXMLNode*)element;
@end

@implementation IJSVGParserRawAttributes

- (instancetype)initWithElement:(IJSVGXMLNode*)element
{
    if ((self = [super init]) != nil) {
        NSMutableData* data = [[NSMutableData alloc] init];
        NSMutableArray<NSString*>* strings = [[NSMutableArray alloc] init];
        IJSVGXMLAttributeList attributes = IJSVGXMLAttributes(element);
        hasAttributes = attributes.count != 0;
        IJSVGXMLAttributeList attributeIterator = attributes;
        for (IJSVGXMLAttribute* attributeNode = IJSVGXMLFirstAttribute(&attributeIterator); attributeNode != NULL; attributeNode = IJSVGXMLNextAttribute(&attributeIterator)) {
            NSUInteger attribute = NSNotFound;
            NSString* __unsafe_unretained value = nil;
            if (!IJSVGReadXMLAttribute(attributeNode, nil, &attribute, &value, NULL)) {
                continue;
            }
            if (IJSVGAttributeIsGeometryProperty(attribute) && geometryLengths == nil) {
                geometryLengths = [[NSMutableDictionary alloc] init];
                geometryValues = [[NSMutableDictionary alloc] init];
            }
            [strings addObject:value];
            IJSVGParserRawAttribute entry = { attribute, value };
            [data appendBytes:&entry length:sizeof(entry)];
            if (attribute == IJSVGNodeAttributeClass) {
                classNameList = IJSVGClassNameList(value);
            }
        }
        entries = data.copy;
        values = strings.copy;
    }
    return self;
}

@end

static void IJSVGParserCacheFilterAttributes(IJSVGParserRawAttributes* raw, NSString* __unsafe_unretained const attributes[kIJSVGNodeAttributeStorageLength], IJSVGStyleSheetStyle* style, IJSVGStyleSheetStyle* inlineStyle, NSUInteger ruleCount)
{
    NSMutableData* data = [[NSMutableData alloc] init];
    NSMutableArray<NSString*>* strings = [[NSMutableArray alloc] init];
    for (NSUInteger index = 0; index < kIJSVGNodeAttributeStorageLength; index++) {
        NSString* value = attributes[index];
        if (value != nil) {
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

static uint64_t IJSVGParserRestoreFilterAttributes(IJSVGParserRawAttributes* raw, NSString* __unsafe_unretained attributes[kIJSVGNodeAttributeStorageLength])
{
    uint64_t textAttributes = 0;
    memset(attributes, 0, sizeof(*attributes) * kIJSVGNodeAttributeStorageLength);
    const IJSVGParserRawAttribute* entries = raw->filterEntries.bytes;
    NSUInteger count = raw->filterEntries.length / sizeof(*entries);
    for (NSUInteger index = 0; index < count; index++) {
        attributes[entries[index].attribute] = entries[index].value;
        textAttributes |= IJSVGTextStyleBit(entries[index].attribute);
    }
    return textAttributes;
}

static NSDictionary<NSString*, NSString*>* IJSVGFilterParametersFromAttributes(NSString* __unsafe_unretained const* attributeValues, Class nodeClass)
{
    NSMutableDictionary<NSString*, NSString*>* parameters = [[NSMutableDictionary alloc] init];
    for (NSString* name in [nodeClass parameterNames]) {
        NSUInteger attribute = IJSVGNodeAttributeForName(name);
        NSString* value = nil;
        if (attribute != NSNotFound && IJSVGParserAttributeHasValue(attributeValues, attribute, &value)) {
            parameters[name] = value;
        }
    }
    return parameters;
}

typedef struct IJSVGDefinitionStyleParent {
    IJSVGXMLNode* element;
    __unsafe_unretained IJSVGGraphicsNode* parent;
    struct IJSVGDefinitionStyleParent* previous;
} IJSVGDefinitionStyleParent;

static IJSVGGraphicsNode* IJSVGDefinitionParentForElement(IJSVGDefinitionStyleParent* context, IJSVGXMLNode* element)
{
    for (; context != NULL; context = context->previous) {
        if (context->element == element) {
            return context->parent;
        }
    }
    return nil;
}

@interface IJSVGParser () {
    CFTypeRef* _rawAttributeCache;
    CFTypeRef* _referenceCache;
    IJSVGDefinitionStyleParent* _definitionStyleParent;
}
@property (nonatomic) IJSVGParsedPathCache* parsedPathCache;
@property (nonatomic) NSUInteger inlineStyleCost;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSArray<NSString*>*>* parsedFilterReferences;
@property (nonatomic, strong) NSMutableDictionary<Class, IJSVGBitFlags*>* allowedAttributesByClass;
@property (nonatomic, strong) NSMutableDictionary<id, NSColor*>* parsedColors;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSArray<IJSVGTransform*>*>* parsedSVGTransforms;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSArray<IJSVGTransform*>*>* parsedCSSTransforms;
@property (nonatomic, strong) NSHashTable<id>* plainGradientStopSources;
@property (nonatomic, strong) NSMapTable<id, IJSVGReference*>* references;
@property (nonatomic, strong) NSMutableDictionary<NSString*, IJSVGReference*>* referenceValues;
@property (nonatomic, strong) NSMapTable<id, IJSVGInheritedElement*>* inheritedElements;
@property (nonatomic, strong) IJSVGInheritedElement* attributeInput;
@property (nonatomic, strong) NSMapTable<id, NSMapTable*>* inheritedSelectorScopes;
@property (nonatomic, strong) NSMapTable<id, id>* linearGradientGeometry;
@property (nonatomic, strong) NSMapTable<id, id>* radialGradientGeometry;
@property (nonatomic, strong) NSMapTable<id, IJSVGGradientStops*>* gradientStops;
@property (nonatomic, strong) NSMapTable<id, NSNumber*>* gradientStopStates;
@property (nonatomic) IJSVGXMLNode* lastParsedStyleElement;
@property (nonatomic, strong) NSMutableDictionary<NSString*, IJSVGStyleSheetStyle*>* inlineStyles;
@property (nonatomic, strong) NSMapTable<id, NSMapTable*>* selectorScopes;
@property (nonatomic, strong) NSMutableSet<NSString*>* activeFilterReferences;
@property (nonatomic, strong) NSMutableSet<NSString*>* activeReferences;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSMutableArray<void (^)(IJSVGNode*)>*>* pendingStylePaints;
@property (nonatomic, strong) NSMapTable<id, IJSVGStyleSheetSelectorRecord*>* selectorNodes;
@property (nonatomic, strong) NSMapTable<id, IJSVGStyleSheetSelectorRecord*>* selectorScope;
@property (nonatomic, strong) NSMapTable<id, IJSVGGraphicsNode*>* styleAncestors;
@property (nonatomic, strong) NSMapTable<IJSVGNode*, NSString*>* inheritedPathData;
@property (nonatomic, strong) NSMapTable<IJSVGNode*, NSDictionary<NSString*, id>*>* customProperties;
@end

@implementation IJSVGParser

- (void)clearRawAttributeCache
{
    if (_rawAttributeCache == NULL) {
        return;
    }
    for (uint32_t index = 0; index < _document->nodeCount; index++) {
        CFTypeRef value = _rawAttributeCache[index];
        if (value != NULL && value != kCFNull) {
            CFRelease(value);
        }
    }
    free(_rawAttributeCache);
    _rawAttributeCache = NULL;
}

- (void)clearReferenceCache
{
    if (_referenceCache != NULL) {
        for (uint32_t index = 0; index < _document->nodeCount; index++) {
            if (_referenceCache[index] != NULL) {
                CFRelease(_referenceCache[index]);
            }
        }
        free(_referenceCache);
        _referenceCache = NULL;
    }
    self.references = nil;
}

- (CFTypeRef*)referenceSlotForElement:(IJSVGXMLNode*)element
{
    if (element == NULL || element->document != _document) {
        return NULL;
    }
    if (_referenceCache == NULL) {
        _referenceCache = calloc(_document->nodeCount, sizeof(*_referenceCache));
    }
    return _referenceCache == NULL ? NULL : &_referenceCache[element - _document->nodes];
}

- (void)dealloc
{
    IJSVGParsedPathCacheDestroy(_parsedPathCache);
    [self clearRawAttributeCache];
    [self clearReferenceCache];
    IJSVGXMLDocumentDestroy(_document);
    if (_detachedReferences != NULL) {
        CFRelease(_detachedReferences);
    }
}

+ (IJSVGParser*)parserForFileURL:(NSURL*)aURL
{
    return [self.class parserForFileURL:aURL error:nil];
}

+ (IJSVGParser*)parserForFileURL:(NSURL*)aURL error:(NSError**)error
{
    return [[self.class alloc] initWithFileURL:aURL error:error];
}

- (id)initWithSVGString:(NSString*)string fileURL:(NSURL*)aURL error:(NSError**)error
{
    NSData* data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [self initWithSVGData:data fileURL:aURL error:error];
}

- (id)initWithSVGData:(NSData*)data fileURL:(NSURL*)aURL error:(NSError**)error
{
    if ((self = [super init]) != nil) {
        _fileURL = aURL;
        _document = IJSVGXMLDocumentCreate(data.bytes, data.length);
        if (_document == NULL) {
            [self _handleErrorWithCode:IJSVGErrorParsingFile error:error];
            return nil;
        }
        if (![self _validateParse:error]) {
            return nil;
        }
    }
    return self;
}

+ (BOOL)isDataSVG:(NSData*)data
{
    IJSVGXMLDocument* document = IJSVGXMLDocumentCreate(data.bytes, data.length);
    BOOL valid = document != NULL;
    IJSVGXMLDocumentDestroy(document);
    return valid;
}

- (id)initWithFileURL:(NSURL*)aURL error:(NSError**)error
{
    NSError* anError = nil;
    NSData* data = [NSData dataWithContentsOfURL:aURL options:NSDataReadingMappedIfSafe error:&anError];

    // error reading file
    if (data == nil) {
        return [self _handleErrorWithCode:IJSVGErrorReadingFile error:error];
    }

    return [self initWithSVGData:data fileURL:aURL error:error];
}

- (void*)_handleErrorWithCode:(NSUInteger)code error:(NSError**)error
{
    if (error != nil) {
        *error = [[NSError alloc] initWithDomain:IJSVGErrorDomain code:code userInfo:nil];
    }
    return nil;
}

- (BOOL)_validateParse:(NSError**)error
{
    if (_rootNode.viewBox.size.isZeroSize == YES) {
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:IJSVGErrorDomain code:IJSVGErrorParsingSVG userInfo:nil];
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
        strongSelf->_rootSize = CGSizeEqualToSize(CGSizeZero, size) == YES ? IJSVG_SIZE_DEFAULT_CLIENT : size;
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
    if (_detachedReferences != NULL) {
        CFRelease(_detachedReferences);
    }
    _detachedReferences = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
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
    [self clearRawAttributeCache];
    self.lastParsedStyleElement = nil;
    self.plainGradientStopSources = nil;
    [self clearReferenceCache];
    self.referenceValues = nil;
    self.inheritedElements = nil;
    self.attributeInput = nil;
    self.inheritedSelectorScopes = nil;
    self.linearGradientGeometry = nil;
    self.radialGradientGeometry = nil;
    self.gradientStops = nil;
    self.gradientStopStates = nil;
    self.styleAncestors = IJSVGParserElementMapTable();
    self.inheritedPathData = nil;
    self.customProperties = nil;
    _definitionStyleParent = NULL;
    if (setup != nil) {
        setup();
    }
    _rootNode = [[IJSVGRootNode alloc] init];
    _rootNode.clientSize = _rootSize;
    IJSVGNodeDeferredAttributes deferredAttributes = { 0 };
    [self parseSVGElement:IJSVGXMLRoot(_document) ontoNode:_rootNode parentNode:nil deferredAttributes:&deferredAttributes recursive:YES];
    IJSVGApplyDeferredAttributes(&deferredAttributes, _rootNode, self, IJSVGXMLRoot(_document));
    [_rootNode postProcess];
    _rootNode.styleAncestors = self.styleAncestors.objectEnumerator.allObjects;
    self.inlineStyles = nil;
    self.parsedColors = nil;
    self.parsedFilterReferences = nil;
    self.allowedAttributesByClass = nil;
    self.parsedSVGTransforms = nil;
    self.parsedCSSTransforms = nil;
    [self clearRawAttributeCache];
    self.lastParsedStyleElement = nil;
    self.plainGradientStopSources = nil;
    [self clearReferenceCache];
    self.referenceValues = nil;
    self.inheritedElements = nil;
    self.attributeInput = nil;
    self.inheritedSelectorScopes = nil;
    self.linearGradientGeometry = nil;
    self.radialGradientGeometry = nil;
    self.gradientStops = nil;
    self.gradientStopStates = nil;
    self.selectorScopes = nil;
    if (_detachedReferences != NULL) {
        CFRelease(_detachedReferences);
    }
    _detachedReferences = NULL;
}

- (IJSVGRootNode*)rootNode:(BOOL)recursive
{
    IJSVGNodeDeferredAttributes deferredAttributes = { 0 };
    IJSVGRootNode* node = [[IJSVGRootNode alloc] init];
    node.clientSize = _rootSize;
    [self parseSVGElement:IJSVGXMLRoot(_document) ontoNode:node parentNode:nil deferredAttributes:&deferredAttributes recursive:recursive];
    IJSVGApplyDeferredAttributes(&deferredAttributes, node, self, IJSVGXMLRoot(_document));
    [node postProcess];
    node.styleAncestors = self.styleAncestors.objectEnumerator.allObjects;
    return node;
}

- (void)computeDefsForElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode
{
    if (IJSVGXMLChildCount(element) == 0) {
        return;
    }
    for (IJSVGXMLNode* childElement = IJSVGXMLFirstChild(element); childElement != NULL; childElement = IJSVGXMLNext(childElement)) {
        IJSVGNodeType type = IJSVGXMLType(childElement);
        if (type != IJSVGNodeTypeDef) {
            continue;
        }
        [self parseDefElement:childElement parentNode:_rootNode recursive:YES];
    }
}

- (void)inferDefaultIntrinsicSizeAndViewBoxForRootNode:(IJSVGRootNode*)node
{
    if (node.intrinsicSize != nil) {
        return;
    }

    IJSVGUnitLength* width = node.width;
    IJSVGUnitLength* height = node.height;

    // We already have a width and a height, use those.
    if (width != nil && height != nil) {
        node.intrinsicSize = [IJSVGUnitSize sizeWithWidth:width height:height];
        return;
    }

    CGSize defaultSize = IJSVG_SIZE_DEFAULT_CLIENT;
    CGFloat ratio = defaultSize.width / defaultSize.height;

    if (width != nil && height == nil) {
        height = [IJSVGUnitLength unitWithFloat:width.value * ratio];
    } else if (width == nil && height != nil) {
        width = [IJSVGUnitLength unitWithFloat:height.value * ratio];
    } else {
        width = IJSVGDefaultViewportWidthUnitLength;
        height = IJSVGDefaultViewportHeightUnitLength;
    }
    node.intrinsicSize = [IJSVGUnitSize sizeWithWidth:width height:height];
    if (node.viewBox == nil) {
        node.viewBox = [IJSVGUnitRect rectWithOrigin:IJSVGUnitPoint.zeroPoint size:node.intrinsicSize.copy];
        node.viewBoxWasInferred = YES;
    }
}

- (void)computeViewBoxForRootNode:(IJSVGRootNode*)node
{
    if (node.viewBox == nil && (node.width != nil || node.height != nil)) {
        IJSVGUnitLength* width = node.width ?: node.height;
        IJSVGUnitLength* height = node.height ?: node.width;
        IJSVGUnitSize* size = [IJSVGUnitSize sizeWithWidth:width height:height];
        node.viewBox = [IJSVGUnitRect rectWithOrigin:IJSVGUnitPoint.zeroPoint size:size];
        node.viewBoxWasInferred = YES;
    }

    if (node.viewBox == nil) {
        return;
    }

    IJSVGIntrinsicDimensions dimensions = IJSVGIntrinsicDimensionNone;
    IJSVGUnitLength* wl = node.viewBox.size.width;
    IJSVGUnitLength* hl = node.viewBox.size.height;
    if (node.width != nil) {
        dimensions |= IJSVGIntrinsicDimensionWidth;
        wl = node.width;
    }
    if (node.height != nil) {
        dimensions |= IJSVGIntrinsicDimensionHeight;
        hl = node.height;
    }

    node.intrinsicDimensions = dimensions;
    node.intrinsicSize = [IJSVGUnitSize sizeWithWidth:wl height:hl];
}

- (IJSVGStyleSheetStyle*)parsedInlineStyleForValue:(NSString*)value
{
    if (_inlineStyles == nil) {
        _inlineStyles = [[NSMutableDictionary alloc] init];
        _inlineStyleCost = 0;
    }
    IJSVGStyleSheetStyle* style = [_inlineStyles objectForKey:value];
    if (style == nil) {
        style = [IJSVGStyleSheetStyle parseStyleString:value];
        NSUInteger cost = value.length * sizeof(unichar);
        if (_inlineStyles.count < 1024 && cost <= 1024 * 1024 - _inlineStyleCost) {
            [_inlineStyles setObject:style forKey:value];
            _inlineStyleCost += cost;
        }
    }
    return style;
}

- (IJSVGBitFlags*)allowedAttributesForNodeClass:(Class)nodeClass
{
    IJSVGBitFlags* attributes = _allowedAttributesByClass[nodeClass];
    if (attributes == nil) {
        attributes = [nodeClass computedAllowedAttributes];
        if (_allowedAttributesByClass == nil) {
            _allowedAttributesByClass = [[NSMutableDictionary alloc] init];
        }
        _allowedAttributesByClass[(id<NSCopying>)nodeClass] = attributes;
    }
    return attributes;
}

// The following method is highly tuned for performance rather than readability.
// The common use form has only identity, a reference and an optional fill.
// Validate all attributes before applying anything. CSS and richer uses keep
// the general cascade, including variables and handling of qualified attributes.
- (BOOL)applyPlainUseAttributes:(IJSVGXMLNode*)element toNode:(IJSVGUse*)node
{
    IJSVGXMLAttribute* identifier = NULL;
    IJSVGXMLAttribute* fill = NULL;
    IJSVGXMLAttributeList attributes = IJSVGXMLAttributes(element);
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&attributes); attribute != NULL; attribute = IJSVGXMLNextAttribute(&attributes)) {
        switch (attribute->identifier) {
            case IJSVGNodeAttributeID:
                identifier = attribute;
                break;
            case IJSVGNodeAttributeFill:
                fill = attribute;
                break;
            case IJSVGNodeAttributeHref:
            case IJSVGNodeAttributeXLink:
                break;
            default:
                return NO;
        }
    }
    NSString* fillValue = IJSVGXMLAttributeValue(fill);
    if (IJSVGCSSValueMayContainVariables(fillValue)) {
        return NO;
    }
    NSString* nodeID = IJSVGXMLAttributeValue(identifier);
    if (nodeID.length != 0) {
        node.identifier = nodeID;
        [self detachElement:element withIdentifier:nodeID];
    }
    node.reference = [self referenceForElement:element];
    if (fillValue.length != 0) {
        NSString* paintIdentifier = [IJSVGUtils defURL:fillValue];
        if (paintIdentifier != nil) {
            [self applyPaintReference:paintIdentifier node:node element:element stroke:NO];
        } else {
            node.fill = [self colorPaintForValue:fillValue];
        }
    }
    return YES;
}

- (void)computeAttributesFromElement:(IJSVGXMLNode*)element onNode:(IJSVGNode*)node ignoredAttributes:(IJSVGBitFlags*)ignoringAttributes deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGInheritedElement* input = _attributeInput;
    if (input != nil && input.element != element) {
        input = nil;
    }
    IJSVGGraphicsNode* definitionParent = input.hasReference ? nil : IJSVGDefinitionParentForElement(_definitionStyleParent, element);
    if (definitionParent != nil) {
        node.styleParent = definitionParent;
    }
    if (node.class == IJSVGUse.class && _styleSheet.ruleCount == 0 && ignoringAttributes == nil && input == nil && [self applyPlainUseAttributes:element toNode:(IJSVGUse*)node]) {
        return;
    }
    if (node.class == IJSVGPath.class && _styleSheet.ruleCount == 0 && ignoringAttributes == nil && input == nil) {
        IJSVGXMLAttribute* data = NULL;
        IJSVGXMLAttribute* identifier = NULL;
        BOOL plain = YES;
        IJSVGXMLAttributeList elementAttributeIterator = IJSVGXMLAttributes(element);
        for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&elementAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&elementAttributeIterator)) {
            if (attribute->identifier == IJSVGNodeAttributeD) {
                data = attribute;
            } else if (attribute->identifier == IJSVGNodeAttributeID) {
                identifier = attribute;
            } else {
                plain = NO;
                break;
            }
        }
        if (plain && !IJSVGCSSValueMayContainVariables(IJSVGXMLAttributeValue(data))) {
            NSString* nodeID = IJSVGXMLAttributeValue(identifier);
            if (nodeID.length != 0) {
                node.identifier = nodeID;
                [self detachElement:element withIdentifier:nodeID];
            }
            if (data != NULL && data->value.length != 0) {
                [self applyPathBytes:IJSVGXMLAttributeBytes(data) length:data->value.length toNode:(IJSVGPath*)node];
                ((IJSVGPath*)node).markerPathData = IJSVGXMLAttributeValue(data);
            }
            return;
        }
    }

    // Coordinate only gradients need no style cascade. Their coordinates are
    // resolved by parseGradient after the stop children have been constructed.
    if (node.type == IJSVGNodeTypeLinearGradient && _styleSheet.ruleCount == 0 && ignoringAttributes == nil) {
        IJSVGXMLAttributeList attributes = input != nil ? input.attributes : IJSVGXMLAttributes(element);
        NSString* identifier = nil;
        BOOL plainGradient = YES;
        IJSVGXMLAttributeList attributeIterator = attributes;
        for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&attributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&attributeIterator)) {
            IJSVGNodeAttribute attributeIdentifier = attribute->identifier;
            if (attributeIdentifier == IJSVGNodeAttributeID) {
                identifier = IJSVGXMLAttributeValue(attribute);
            } else if (attributeIdentifier != IJSVGNodeAttributeX1 && attributeIdentifier != IJSVGNodeAttributeX2 && attributeIdentifier != IJSVGNodeAttributeY1 && attributeIdentifier != IJSVGNodeAttributeY2) {
                plainGradient = NO;
                break;
            }
        }
        if (plainGradient) {
            if (identifier.length != 0) {
                node.identifier = identifier;
                [self detachElement:element withIdentifier:identifier];
            }
            return;
        }
    }

    // Plain stops have no cascade to resolve. Avoid allocating reference caches
    // and resolving the general node attribute set for these small leaf nodes.
    if (node.type == IJSVGNodeTypeStop && _styleSheet.ruleCount == 0 && ignoringAttributes == nil) {
        IJSVGXMLAttributeList attributes = input != nil ? input.attributes : IJSVGXMLAttributes(element);
        BOOL plainStop = YES;
        IJSVGXMLAttributeList attributeIterator = attributes;
        for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&attributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&attributeIterator)) {
            IJSVGNodeAttribute identifier = attribute->identifier;
            if (identifier != IJSVGNodeAttributeOffset && identifier != IJSVGNodeAttributeStopColor && identifier != IJSVGNodeAttributeStopOpacity) {
                plainStop = NO;
                break;
            }
        }
        if (plainStop) {
            [(IJSVGStop*)node consumeXMLAttributes:attributes parser:self];
            return;
        }
    }
    __attribute__((objc_precise_lifetime)) IJSVGParserRawAttributes* raw = nil;

    // XML positions provide direct cache slots for repeated references.
    if (input == nil && element->document == _document && (self.activeReferences.count != 0 || self.activeFilterReferences.count != 0)) {
        if (_rawAttributeCache == NULL) {
            _rawAttributeCache = calloc(_document->nodeCount, sizeof(*_rawAttributeCache));
        }
        if (_rawAttributeCache != NULL) {
            CFTypeRef* slot = &_rawAttributeCache[element - _document->nodes];
            if (*slot == kCFNull) {
                raw = [[IJSVGParserRawAttributes alloc] initWithElement:element];
                *slot = CFBridgingRetain(raw);
            } else if (*slot != NULL) {
                raw = (__bridge IJSVGParserRawAttributes*)*slot;
            } else {
                // The first visit needs no allocated attribute record.
                *slot = kCFNull;
            }
        }
    }
    IJSVGXMLAttributeList elementAttributes = raw == nil ? (input != nil ? input.attributes : IJSVGXMLAttributes(element)) : (IJSVGXMLAttributeList) { 0 };
    NSUInteger attributeCount = raw != nil ? raw->entries.length / sizeof(IJSVGParserRawAttribute) : elementAttributes.count;
    BOOL hasStyleSheetRules = _styleSheet.ruleCount != 0;
    BOOL hasAttributes = raw != nil ? raw->hasAttributes : attributeCount != 0;
    if (!hasAttributes && hasStyleSheetRules == NO) {
        return;
    }

    IJSVGBitFlags* activeAttributes = [self allowedAttributesForNodeClass:node.class];
    if (ignoringAttributes != nil) {
        IJSVGBitFlags* attributes = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
        [attributes addBits:activeAttributes];
        for (int i = 0; i < kIJSVGNodeAttributeStorageLength; i++) {
            if ([ignoringAttributes bitIsSet:i] == YES) {
                [attributes unsetBit:i];
            }
        }
        activeAttributes = attributes;
    }

    NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength] = { nil };
    NSUInteger variableAttributes[kIJSVGNodeAttributeStorageLength];
    NSUInteger variableAttributeCount = 0;
    uint64_t textAttributes = 0;
    BOOL plainPath = node.class == IJSVGPath.class && !hasStyleSheetRules && ignoringAttributes == nil;
    BOOL plainUse = node.class == IJSVGUse.class && !hasStyleSheetRules && ignoringAttributes == nil;
    BOOL supportsReference = [activeAttributes bitIsSet:IJSVGNodeAttributeHref];
    CFTypeRef* referenceSlot = supportsReference ? [self referenceSlotForElement:element] : NULL;
    IJSVGReference* reference = nil;
    if (supportsReference) {
        reference = referenceSlot != NULL ? (__bridge IJSVGReference*)*referenceSlot : [_references objectForKey:IJSVGXMLKey(element)];
    }
    IJSVGReferenceAttributes referenceAttributes = { nil, nil, nil };
    IJSVGReferenceAttributes* referenceInput = supportsReference && reference == nil ? &referenceAttributes : NULL;
    if (raw != nil && referenceInput != NULL) {
        reference = [self referenceForElement:element];
        referenceInput = NULL;
    }

    if (raw != nil) {
        const IJSVGParserRawAttribute* entries = raw->entries.bytes;
        const int* allowed = activeAttributes.storage;
        NSUInteger allowedCount = MAX(0, activeAttributes.length);
        for (NSUInteger index = 0; index < attributeCount; index++) {
            NSUInteger attribute = entries[index].attribute;
            if (attribute < allowedCount && allowed[attribute] == 1) {
                attributeValues[attribute] = entries[index].value;
                plainPath &= attribute == IJSVGNodeAttributeID || attribute == IJSVGNodeAttributeD;
                plainUse &= attribute == IJSVGNodeAttributeID || attribute == IJSVGNodeAttributeHref || attribute == IJSVGNodeAttributeXLink || attribute == IJSVGNodeAttributeFill;
                textAttributes |= IJSVGTextStyleBit(attribute);
                if (IJSVGAttributeSupportsVariables(attribute) && IJSVGCSSValueMayContainVariables(entries[index].value)) {
                    variableAttributes[variableAttributeCount++] = attribute;
                }
            }
        }
    } else {
        IJSVGXMLAttributeList elementAttributeIterator = elementAttributes;
        for (IJSVGXMLAttribute* attributeNode = IJSVGXMLFirstAttribute(&elementAttributeIterator); attributeNode != NULL; attributeNode = IJSVGXMLNextAttribute(&elementAttributeIterator)) {
            NSUInteger attribute = NSNotFound;
            NSString* __unsafe_unretained value = nil;
            if (IJSVGReadXMLAttribute(attributeNode, activeAttributes, &attribute, &value, referenceInput)) {
                attributeValues[attribute] = value;
                plainPath &= attribute == IJSVGNodeAttributeID || attribute == IJSVGNodeAttributeD;
                plainUse &= attribute == IJSVGNodeAttributeID || attribute == IJSVGNodeAttributeHref || attribute == IJSVGNodeAttributeXLink || attribute == IJSVGNodeAttributeFill;
                textAttributes |= IJSVGTextStyleBit(attribute);
                if (IJSVGAttributeSupportsVariables(attribute) && IJSVGCSSValueMayContainVariables(value)) {
                    variableAttributes[variableAttributeCount++] = attribute;
                }
            }
        }
    }

    if (referenceInput != NULL) {
        reference = [self referenceFromAttributes:referenceInput];
        if (referenceSlot != NULL) {
            *referenceSlot = CFBridgingRetain(reference);
        } else {
            if (_references == nil) {
                _references = IJSVGParserElementMapTable();
            }
            [_references setObject:reference forKey:IJSVGXMLKey(element)];
        }
    }
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeID, &value)) {
        node.identifier = value;
        [self detachElement:element withIdentifier:value];
    }

    // Bare paths and references with only a fill have no style cascade or
    // other local presentation to resolve. Keep their normal parent links,
    // reference handling and path cache while skipping the empty stages.
    if ((plainPath || plainUse) && variableAttributeCount == 0) {
        if (plainPath) {
            NSString* pathData = IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeD);
            if (pathData != nil) {
                [self applyPathValue:pathData toNode:node css:NO fallback:pathData];
            }
        } else {
            ((IJSVGUse*)node).reference = reference;
            IJSVGNodeParsingContext context = { .deferredAttributes = deferredAttributes, .reference = reference, .parser = self, .element = element, .values = attributeValues };
            IJSVGParsePaintAttributes((IJSVGUse*)node, &context);
        }
        return;
    }

    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeClass, &value)) {
        node.className = value;
        node.classNameList = raw != nil ? raw->classNameList : IJSVGClassNameList(value);
    }

    // Presentation shorthand has lower priority than CSS and explicit longhands.
    for (NSUInteger attribute = IJSVGNodeAttributeMarkerStart; attribute <= IJSVGNodeAttributeMarkerEnd; attribute++) {
        if (attributeValues[attribute] == nil) {
            attributeValues[attribute] = attributeValues[IJSVGNodeAttributeMarker];
        }
    }

    NSString* attributePathData = IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeD);
    BOOL isFilterPrimitive = [node isKindOfClass:IJSVGFilterPrimitive.class];

    // Reuse declarations while resolving inherited values on each new node.
    BOOL cacheFilterAttributes = raw != nil && ignoringAttributes == nil && self.selectorScope == nil && (isFilterPrimitive || node.type == IJSVGNodeTypeFilter);
    NSUInteger styleRuleCount = _styleSheet.ruleCount;
    BOOL reuseFilterAttributes = cacheFilterAttributes && raw->filterEntries != nil && raw->filterRuleCount == styleRuleCount;
    __attribute__((objc_precise_lifetime)) IJSVGStyleSheetStyle* styleSheet = nil;
    __attribute__((objc_precise_lifetime)) IJSVGStyleSheetStyle* nodeStyle = nil;
    if (reuseFilterAttributes) {
        textAttributes = IJSVGParserRestoreFilterAttributes(raw, attributeValues);
        styleSheet = raw->filterStyle;
        nodeStyle = raw->filterInlineStyle;
    } else {
        styleSheet = hasStyleSheetRules == YES ? [_styleSheet styleForNode:(id<IJSVGStyleSheetSelectorNode>)[self selectorNodeForElement:element] ?: node] : nil;

        if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStyle, &value)) {
            nodeStyle = [self parsedInlineStyleForValue:value];
        }

        textAttributes |= IJSVGStoreCascadedStyleAttributes(styleSheet, nodeStyle, activeAttributes, attributeValues);

        if (cacheFilterAttributes) {
            IJSVGParserCacheFilterAttributes(raw, attributeValues, styleSheet, nodeStyle, styleRuleCount);
        }
    }
    NSDictionary<NSString*, id>* customProperties = [self customPropertiesForNode:node style:styleSheet inlineStyle:nodeStyle];
    IJSVGStyleSheetStyle* resolvedStyle = [styleSheet styleByResolvingVariables:customProperties];
    IJSVGStyleSheetStyle* resolvedInline = [nodeStyle styleByResolvingVariables:customProperties];
    BOOL resolvedVariables = resolvedStyle != styleSheet || resolvedInline != nodeStyle;
    if (resolvedVariables) {
        styleSheet = resolvedStyle;
        nodeStyle = resolvedInline;
        textAttributes |= IJSVGStoreCascadedStyleAttributes(styleSheet, nodeStyle, activeAttributes, attributeValues);
    }
    __attribute__((objc_precise_lifetime)) NSMutableArray<NSString*>* resolvedAttributeValues = nil;
    if (variableAttributeCount != 0) {
        resolvedAttributeValues = [[NSMutableArray alloc] initWithCapacity:variableAttributeCount];
        for (NSUInteger index = 0; index < variableAttributeCount; index++) {
            NSUInteger attribute = variableAttributes[index];
            NSString* source = attributeValues[attribute];
            if (!IJSVGCSSValueMayContainVariables(source)) {
                continue;
            }
            NSString* resolved = IJSVGCSSResolveVariables(source, customProperties);
            resolved = IJSVGCSSResolvedPaintValue(resolved, attribute);
            [resolvedAttributeValues addObject:resolved ?: @""];
            attributeValues[attribute] = resolved ?: @"";
        }
    }
    NSDictionary<NSString*, NSString*>* filterParameters = nil;
    if (isFilterPrimitive) {
        BOOL variableParameters = variableAttributeCount != 0 || resolvedVariables;
        filterParameters = reuseFilterAttributes && !variableParameters ? raw->filterParameters : IJSVGFilterParametersFromAttributes(attributeValues, node.class);
    }
    IJSVGNodeParsingContext context = { .deferredAttributes = deferredAttributes, .textAttributes = textAttributes, .reference = reference, .cachedGeometryLengths = raw != nil ? raw->geometryLengths : nil, .cachedGeometryValues = raw != nil ? raw->geometryValues : nil, .parser = self, .element = element, .values = attributeValues, .style = styleSheet, .inlineStyle = nodeStyle, .attributePathData = attributePathData, .filterParameters = filterParameters };
    [node consumeAttributes:&context];
    if (context.geometryLengths != nil) {
        context.geometryOwner.geometryLengths = context.geometryLengths;
    }
    if (isFilterPrimitive && cacheFilterAttributes) {
        raw->filterParameters = ((IJSVGFilterPrimitive*)node).parameters;
    }
}

- (void)resolveTextPathForNode:(IJSVGTextPath*)node element:(IJSVGXMLNode*)element
{
    NSString* identifier = node.reference.fragmentIdentifier;
    if (identifier != nil) {
        IJSVGXMLNode* definition = [self detachedElementWithIdentifier:identifier];

        // Only geometry is valid here, do not recurse through arbitrary references.
        IJSVGNodeType type = IJSVGXMLType(definition);
        if ([IJSVGNode typeIsPathable:type]) {
            node.textPath = (IJSVGPath*)[self computeDetachedNodeWithIdentifier:identifier referencingNode:nil element:element];
            NSString* length = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(definition, IJSVGNodeAttributePathLength));
            if (length.length != 0) {
                NSMutableDictionary<NSString*, IJSVGTextAttributeValue*>* positioning = [node.positioning mutableCopy];
                positioning[IJSVGAttributePathLength] = IJSVGParseTextAttribute(length, IJSVGNodeAttributePathLength);
                node.positioning = positioning;
            }
        }
    }
    IJSVGTextAttributeValue* path = node.positioning[IJSVGAttributePath];
    if (path != nil) {
        IJSVGPath* geometry = [[IJSVGPath alloc] init];
        [self applyPathData:path.string toNode:geometry];
        node.textPath = geometry;
    }
}

- (IJSVGText*)parseTextElement:(IJSVGXMLNode*)element type:(IJSVGNodeType)type parentNode:(IJSVGGraphicsNode*)parentNode
{
    IJSVGText* node = [[IJSVGNodeClassForType(type) alloc] init];
    node.type = type;
    IJSVGPreserveElementName(node, element);
    node.isTextPath = type == IJSVGNodeTypeTextPath;
    if ([parentNode isKindOfClass:IJSVGGroup.class]) {
        [(IJSVGGroup*)parentNode addChild:node];
    }
    IJSVGNodeDeferredAttributes deferredAttributes = { 0 };
    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:&deferredAttributes];

    // These are text positions, not a group translation.
    node.x = nil;
    node.y = nil;
    IJSVGXMLNode* children = IJSVGXMLFirstChild(element);
    NSMutableArray<id>* content = [[NSMutableArray alloc] initWithCapacity:IJSVGXMLChildCount(element)];
    for (IJSVGXMLNode* child = children; child != NULL; child = IJSVGXMLNext(child)) {
        if (IJSVGXMLKind(child) == NSXMLTextKind) {
            [content addObject:IJSVGXMLText(child) ?: @""];
        } else {
            IJSVGNodeType childType = IJSVGXMLType(child);
            if (childType == IJSVGNodeTypeTextSpan || childType == IJSVGNodeTypeTextPath || childType == IJSVGNodeTypeAnchor) {
                IJSVGText* span = [self parseTextElement:(IJSVGXMLNode*)child type:childType parentNode:node];
                [content addObject:span];
            }
        }
    }
    node.textContent = content;
    if (node.isTextPath) {
        [self resolveTextPathForNode:(IJSVGTextPath*)node element:element];
    }
    IJSVGApplyDeferredAttributes(&deferredAttributes, node, self, element);
    [node postProcess];
    return node;
}

- (IJSVGMarker*)markerForValue:(NSString*)value referencingNode:(IJSVGGraphicsNode*)node element:(IJSVGXMLNode*)element
{
    NSArray<NSString*>* identifiers = [IJSVGUtils defURLs:value];
    NSString* identifier = identifiers.count == 1 ? identifiers.firstObject : nil;
    IJSVGNode* definition = identifier == nil ? nil : [self computeDetachedNodeWithIdentifier:identifier referencingNode:node element:element];

    // An empty marker overrides inheritance for none and invalid references.
    return [definition isKindOfClass:IJSVGMarker.class] ? (IJSVGMarker*)definition : [[IJSVGMarker alloc] init];
}

- (void)applyMarkerStart:(NSString*)start mid:(NSString*)mid end:(NSString*)end toNode:(IJSVGGraphicsNode*)node element:(IJSVGXMLNode*)element
{
    if (start != nil && ![start isEqualToString:IJSVGStringInherit]) {
        node.markerStart = [self markerForValue:start referencingNode:node element:element];
    }
    if (mid != nil && ![mid isEqualToString:IJSVGStringInherit]) {
        node.markerMid = [self markerForValue:mid referencingNode:node element:element];
    }
    if (end != nil && ![end isEqualToString:IJSVGStringInherit]) {
        node.markerEnd = [self markerForValue:end referencingNode:node element:element];
    }
}

- (NSArray<IJSVGTransform*>*)parsedTransformsForValue:(NSString*)value allowCSSUnits:(BOOL)allowCSSUnits
{
    NSMutableDictionary<NSString*, NSArray<IJSVGTransform*>*>* cache = allowCSSUnits ? _parsedCSSTransforms : _parsedSVGTransforms;
    NSArray<IJSVGTransform*>* transforms = cache[value];
    if (transforms != nil) {
        return [[NSArray alloc] initWithArray:transforms copyItems:YES];
    }
    transforms = [IJSVGTransform transformsForString:value allowCSSUnits:allowCSSUnits];
    if (value.length <= 1024 && cache.count < 128) {
        if (cache == nil) {
            cache = [[NSMutableDictionary alloc] init];
            if (allowCSSUnits) {
                _parsedCSSTransforms = cache;
            } else {
                _parsedSVGTransforms = cache;
            }
        }
        cache[value] = [[NSArray alloc] initWithArray:transforms copyItems:YES];
    }
    return transforms;
}

- (NSColor*)parsedStopColorForAttribute:(IJSVGXMLAttribute*)attribute
{
    uint32_t rgba = 0;
    if (!IJSVGParseHexColorBytes(IJSVGXMLAttributeBytes(attribute), attribute->value.length, &rgba)) {
        return [self parsedStopColorForValue:IJSVGXMLAttributeValue(attribute)];
    }
    NSNumber* key = @(rgba);
    NSColor* color = _parsedColors[key];
    if (color == nil) {
        color = [IJSVGColor colorFromHEXInteger:rgba containsAlphaComponent:YES];
        if (color != nil && _parsedColors.count < 256) {
            if (_parsedColors == nil) {
                _parsedColors = [[NSMutableDictionary alloc] init];
            }
            _parsedColors[key] = color;
        }
    }
    return color;
}

- (NSColor*)parsedStopColorForValue:(NSString*)value
{
    if (value.length == 0 || [value characterAtIndex:0] != '#') {
        return [IJSVGColor colorFromString:value];
    }
    NSColor* color = _parsedColors[value];
    if (color == nil) {
        color = [IJSVGColor colorFromString:value];
        if (color != nil && _parsedColors.count < 256) {
            if (_parsedColors == nil) {
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
    if (colorNode.contextPaint != IJSVGContextPaintNone) {
        // A context paint outside an instantiated marker paints nothing.
        colorNode.isNoneOrTransparent = YES;
    } else if (color == nil) {
        colorNode.isNoneOrTransparent = [IJSVGColor isNoneOrTransparent:value];
    }
    return colorNode;
}

- (IJSVGMarker*)parseMarkerElement:(IJSVGXMLNode*)element deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    // Definitions are instantiated only through a marker reference.
    NSString* identifier = IJSVGParserElementIdentifier(element);
    if (identifier == nil || ![self.activeReferences containsObject:identifier]) {
        return nil;
    }
    IJSVGMarker* marker = [[IJSVGMarker alloc] init];
    IJSVGPreserveElementName(marker, element);
    marker.styleParent = [self styleAncestorForElement:IJSVGXMLParent(element)];
    [self computeAttributesFromElement:element onNode:marker ignoredAttributes:nil deferredAttributes:deferredAttributes];
    [self computeElement:element parentNode:marker];
    return marker;
}

- (IJSVGNode*)parseElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)node
{
    IJSVGNodeType nodeType = IJSVGXMLType(element);

    [self parseDefElement:element parentNode:node recursive:NO];

    IJSVGNodeDeferredAttributes deferredAttributes = { 0 };
    IJSVGNode* computedNode = nil;
    switch (nodeType) {
        case IJSVGNodeTypeText:
            return [self parseTextElement:element type:nodeType parentNode:node];
        case IJSVGNodeTypeSymbol:

            // Symbols are instantiated only as the direct target of a use.
            break;
        case IJSVGNodeTypeTextPath:
        case IJSVGNodeTypeTextSpan:

            // A standalone tspan is not rendered.
            break;
        case IJSVGNodeTypeMarker: {
            computedNode = [self parseMarkerElement:element deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeForeignObject: {
            // do nothing for foreign objects, we dont support them
            break;
        }

        case IJSVGNodeTypeStyle: {
            [self parseStyleElement:element parentNode:node];
            break;
        }

        // we can treat unkown element as groups, as some people
        // thought it was a good idea to stick HTML within the markup
        case IJSVGNodeTypeFont:
        case IJSVGNodeTypeGlyph:
        case IJSVGNodeTypeUnknown:
        case IJSVGNodeTypeSwitch:
        case IJSVGNodeTypeGroup: {
            computedNode = [self parseGroupElement:element parentNode:node nodeType:nodeType deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeSVG: {
            computedNode = [self parseSVGElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypePath: {
            computedNode = [self parsePathElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeCircle: {
            computedNode = [self parseCircleElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeEllipse: {
            computedNode = [self parseEllipseElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeRect: {
            computedNode = [self parseRectElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypePolygon: {
            computedNode = [self parsePolygonElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypePolyline: {
            computedNode = [self parsePolyLineElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeLine: {
            computedNode = [self parseLineElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeImage: {
            computedNode = [self parseImageElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypePattern: {
            computedNode = [self parsePatternElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeClipPath: {
            computedNode = [self parseClipPathElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeFilter: {
            computedNode = [self parseFilterElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeMask: {
            computedNode = [self parseMaskElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeUse: {
            computedNode = [self parseUseElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeLinearGradient: {
            computedNode = [self parseLinearGradientElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeRadialGradient: {
            computedNode = [self parseRadialGradientElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeStop: {
            computedNode = [self parseStopElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeTitle: {
            [self parseTitleElement:element parentNode:node deferredAttributes:&deferredAttributes];
            break;
        }
        case IJSVGNodeTypeDesc: {
            [self parseDescElement:element parentNode:node deferredAttributes:&deferredAttributes];
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
    IJSVGApplyDeferredAttributes(&deferredAttributes, computedNode, self, element);

    // perform any post processing
    [computedNode postProcess];

    return computedNode;
}

- (void)computeElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)node
{
    if (IJSVGXMLChildCount(element) == 0) {
        return;
    }
    [self computeDefsForElement:element parentNode:node];
    BOOL isSwitch = [node isKindOfClass:IJSVGSwitch.class];
    IJSVGXMLNode* selectedChild = isSwitch ? [IJSVGSwitch selectedChildInXML:element preferredLanguages:NSLocale.preferredLanguages] : nil;
    for (IJSVGXMLNode* childNode = IJSVGXMLFirstChild(element); childNode != NULL; childNode = IJSVGXMLNext(childNode)) {
        if (IJSVGXMLKind(childNode) != NSXMLElementKind) {
            continue;
        }
        IJSVGXMLNode* child = (IJSVGXMLNode*)childNode;
        if (isSwitch && child != selectedChild && IJSVGXMLType(child) != IJSVGNodeTypeStyle) {
            continue;
        }
        [self parseElement:child parentNode:node];
    }
}

#pragma mark Detaching nodes

- (void)detachElement:(IJSVGXMLNode*)element withIdentifier:(NSString*)identifier
{
    // we can just store the reference for later, we used to copy at this point
    // but realised there can be a lot of elements with IDs that dont actually
    // ever get used, so just store reference and let the usage deal with copy and
    // detach
    if (_detachedReferences != NULL && identifier != nil && element != NULL) {
        CFDictionarySetValue(_detachedReferences, (__bridge CFStringRef)identifier, element);
    }
}

- (IJSVGXMLNode*)detachedElementWithIdentifier:(NSString*)identifier
{
    return _detachedReferences == NULL || identifier == nil ? NULL : (IJSVGXMLNode*)CFDictionaryGetValue(_detachedReferences, (__bridge CFStringRef)identifier);
}

- (IJSVGStyleSheetSelectorRecord*)buildSelectorTreeForElement:(IJSVGXMLNode*)element nodes:(NSMapTable<id, IJSVGStyleSheetSelectorRecord*>*)nodes
{
    IJSVGStyleSheetSelectorRecord* node = [[IJSVGStyleSheetSelectorRecord alloc] init];
    node.name = IJSVGXMLLocalName(element);
    node.identifier = IJSVGParserElementIdentifier(element);
    NSString* className = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributeClass));
    node.classNameList = IJSVGClassNameList(className);
    [nodes setObject:node forKey:IJSVGXMLKey(element)];
    IJSVGStyleSheetSelectorRecord* previous = nil;
    for (IJSVGXMLNode* child = IJSVGXMLFirstChild(element); child != NULL; child = IJSVGXMLNext(child)) {
        if (IJSVGXMLKind(child) == NSXMLElementKind) {
            IJSVGStyleSheetSelectorRecord* record = [self buildSelectorTreeForElement:(IJSVGXMLNode*)child nodes:nodes];
            record.selectorParent = node;
            record.selectorPreviousSibling = previous;
            previous = record;
        }
    }
    return node;
}

- (IJSVGStyleSheetSelectorRecord*)selectorNodeForElement:(IJSVGXMLNode*)element
{
    if (!_styleSheet.requiresSelectorTree) {
        return nil;
    }
    IJSVGStyleSheetSelectorRecord* scoped = [self.selectorScope objectForKey:IJSVGXMLKey(element)];
    if (scoped != nil) {
        return scoped;
    }
    if (self.selectorNodes == nil) {
        // Look up records by the XML object address.
        // Hashing XML contents becomes expensive when an element has many siblings.
        self.selectorNodes = IJSVGParserElementMapTable();
        [self buildSelectorTreeForElement:IJSVGXMLRoot(_document) nodes:self.selectorNodes];
    }
    return [self.selectorNodes objectForKey:IJSVGXMLKey(element)];
}

- (IJSVGGraphicsNode*)styleAncestorForElement:(IJSVGXMLNode*)element
{
    if (IJSVGXMLKind(element) != NSXMLElementKind) {
        return nil;
    }
    IJSVGXMLNode* source = (IJSVGXMLNode*)element;
    IJSVGGraphicsNode* ancestor = [self.styleAncestors objectForKey:IJSVGXMLKey(source)];
    if (ancestor != nil) {
        return ancestor;
    }
    ancestor = [[IJSVGGroup alloc] init];
    IJSVGPreserveElementName(ancestor, source);
    [self.styleAncestors setObject:ancestor forKey:IJSVGXMLKey(source)];
    ancestor.styleParent = [self styleAncestorForElement:IJSVGXMLParent(source)];

    // Reuse normal attribute parsing without rendering ancestor effects.
    IJSVGNodeDeferredAttributes deferredAttributes = { 0 };
    [self computeAttributesFromElement:source onNode:ancestor ignoredAttributes:nil deferredAttributes:&deferredAttributes];
    return ancestor;
}

- (void)applyPaintReference:(NSString*)identifier node:(IJSVGGraphicsNode*)node element:(IJSVGXMLNode*)element stroke:(BOOL)stroke
{
    if ([self.styleAncestors objectForKey:IJSVGXMLKey(element)] == node && [self.activeReferences containsObject:identifier]) {
        void (^apply)(IJSVGNode*) = ^(IJSVGNode* paint) {
            if (stroke) {
                node.stroke = paint;
            } else {
                node.fill = paint;
            }
        };
        NSMutableArray<void (^)(IJSVGNode*)>* pending = self.pendingStylePaints[identifier];
        if (pending == nil) {
            pending = [[NSMutableArray alloc] init];
            self.pendingStylePaints[identifier] = pending;
        }
        [pending addObject:apply];
        return;
    }
    IJSVGNode* paint = [self computeDetachedNodeWithIdentifier:identifier referencingNode:node element:element];
    if (stroke) {
        node.stroke = paint;
    } else {
        node.fill = paint;
    }
}

- (IJSVGNode*)computeDetachedNodeWithIdentifier:(NSString*)identifier referencingNode:(IJSVGGraphicsNode*)node element:(IJSVGXMLNode*)element
{
    IJSVGXMLNode* source = [self detachedElementWithIdentifier:identifier];
    if (source == nil || [self.activeReferences containsObject:identifier]) {
        return nil;
    }
    if ([self isElement:element decedentOf:source]) {
        [self recursionDetectedOn:element decendentOf:source identifier:identifier];
        return nil;
    }
    [self.activeReferences addObject:identifier];
    NSMapTable* previousScope = self.selectorScope;
    self.selectorScope = nil;
    IJSVGDefinitionStyleParent context = { .element = source, .previous = _definitionStyleParent };
    @try {
        __attribute__((objc_precise_lifetime)) IJSVGGraphicsNode* parent = [self styleAncestorForElement:IJSVGXMLParent(source)];
        context.parent = parent;
        _definitionStyleParent = &context;
        IJSVGNode* detached = [self parseElement:source parentNode:node].detach;
        detached.styleParent = parent;
        for (void (^apply)(IJSVGNode*) in self.pendingStylePaints[identifier]) {
            apply(detached);
        }
        return detached;
    } @finally {
        [self.pendingStylePaints removeObjectForKey:identifier];
        _definitionStyleParent = context.previous;
        [self.activeReferences removeObject:identifier];
        self.selectorScope = previousScope;
    }
}

- (void)recursionDetectedOn:(IJSVGXMLNode*)element decendentOf:(IJSVGXMLNode*)parent identifier:(NSString*)identifier
{
    // For now, we only want to log these for debug builds whilst we fix any
    // SVGs that are problematic.
#if DEBUG
    NSLog(@"<%@> Recursion detected in file: \"%@\", with identifer: \"%@\"", self.className, _fileURL ?: @"Unknown", identifier);
#endif
}

- (BOOL)isElement:(IJSVGXMLNode*)element decedentOf:(IJSVGXMLNode*)parentElement
{
    IJSVGXMLNode* parent = (IJSVGXMLNode*)IJSVGXMLParent(element);
    while (parent != nil) {
        if (parentElement == parent) {
            return YES;
        }
        parent = (IJSVGXMLNode*)IJSVGXMLParent(parent);
    }
    return NO;
}

- (IJSVGInheritedElement*)inheritedElementForElement:(IJSVGXMLNode*)element visiting:(NSHashTable<id>*)visiting
{
    IJSVGInheritedElement* input = [_inheritedElements objectForKey:IJSVGXMLKey(element)];
    if (input != nil) {
        return input;
    }
    if (visiting == nil) {
        visiting = [NSHashTable hashTableWithOptions:NSPointerFunctionsOpaquePersonality | NSPointerFunctionsOpaqueMemory];
    }
    if ([visiting containsObject:IJSVGXMLKey(element)]) {
        return nil;
    }
    [visiting addObject:IJSVGXMLKey(element)];
    NSString* identifier = [self referenceForElement:element].fragmentIdentifier;
    IJSVGXMLNode* source = identifier == nil ? nil : [self detachedElementWithIdentifier:identifier];
    IJSVGInheritedElement* fallback = source == nil ? nil : [self inheritedElementForElement:source visiting:visiting];
    input = [[IJSVGInheritedElement alloc] initWithElement:element fallback:fallback];
    [visiting removeObject:IJSVGXMLKey(element)];
    if (_inheritedElements == nil) {
        _inheritedElements = IJSVGParserElementMapTable();
    }
    [_inheritedElements setObject:input forKey:IJSVGXMLKey(element)];
    return input;
}

- (NSMapTable*)selectorScopeForInheritedElement:(IJSVGInheritedElement*)input
{
    if (!_styleSheet.requiresSelectorTree) {
        return nil;
    }
    NSMapTable* scope = [_inheritedSelectorScopes objectForKey:IJSVGXMLKey(input.element)];
    if (scope != nil) {
        return scope;
    }
    scope = IJSVGParserElementMapTable();
    IJSVGStyleSheetSelectorRecord* root = [[IJSVGStyleSheetSelectorRecord alloc] init];
    root.name = IJSVGXMLLocalName(input.element);
    IJSVGXMLAttributeList inputAttributeIterator = input.attributes;
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&inputAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&inputAttributeIterator)) {
        if (attribute->identifier == IJSVGNodeAttributeID) {
            root.identifier = IJSVGXMLAttributeValue(attribute);
        } else if (attribute->identifier == IJSVGNodeAttributeClass) {
            root.classNameList = IJSVGClassNameList(IJSVGXMLAttributeValue(attribute));
        }
    }
    [scope setObject:root forKey:IJSVGXMLKey(input.element)];
    IJSVGStyleSheetSelectorRecord* previous = nil;
    for (IJSVGXMLNode* child = IJSVGXMLFirstChild(input.childrenElement); child != NULL; child = IJSVGXMLNext(child)) {
        if (IJSVGXMLKind(child) != NSXMLElementKind) {
            continue;
        }
        IJSVGStyleSheetSelectorRecord* record = [self buildSelectorTreeForElement:(IJSVGXMLNode*)child nodes:scope];
        record.selectorParent = root;
        record.selectorPreviousSibling = previous;
        previous = record;
    }
    if (_inheritedSelectorScopes == nil) {
        _inheritedSelectorScopes = IJSVGParserElementMapTable();
    }
    [_inheritedSelectorScopes setObject:scope forKey:IJSVGXMLKey(input.element)];
    return scope;
}

- (void)computeAttributesFromElement:(IJSVGXMLNode*)element onNode:(IJSVGNode*)node input:(IJSVGInheritedElement*)input deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGInheritedElement* previous = _attributeInput;
    _attributeInput = input;
    @try {
        [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];
    } @finally {
        _attributeInput = previous;
    }
}

- (void)populateGradient:(IJSVGGradient*)gradient fromElement:(IJSVGXMLNode*)element
{
    BOOL cacheable = _styleSheet.ruleCount == 0;
    IJSVGGradientStops* data = cacheable ? [_gradientStops objectForKey:IJSVGXMLKey(element)] : nil;
    if (data != nil && data.inheritedOpacity == gradient.fillOpacity.value) {
        [data applyToGradient:gradient];
        return;
    }
    if (!cacheable || !IJSVGPopulatePlainGradientStops(gradient, element, self)) {
        [self computeElement:element parentNode:gradient];
    }
    [gradient parseColorStops];
    if (!cacheable || _styleSheet.ruleCount != 0) {
        return;
    }
    NSNumber* state = [_gradientStopStates objectForKey:IJSVGXMLKey(element)];
    if (state == nil) {
        if (_gradientStopStates == nil) {
            _gradientStopStates = IJSVGParserElementMapTable();
        }
        [_gradientStopStates setObject:@YES forKey:IJSVGXMLKey(element)];
    } else if (state.boolValue) {
        if ([IJSVGGradientStops canCacheElement:element]) {
            data = [[IJSVGGradientStops alloc] initWithGradient:gradient element:element];
            if (_gradientStops == nil) {
                _gradientStops = IJSVGParserElementMapTable();
            }
            [_gradientStops setObject:data forKey:IJSVGXMLKey(element)];
        } else {
            [_gradientStopStates setObject:@NO forKey:IJSVGXMLKey(element)];
        }
    }
}

- (void)parseLinearGeometry:(IJSVGLinearGradient*)gradient element:(IJSVGXMLNode*)element attributes:(IJSVGXMLAttributeList)attributes
{
    IJSVGGradientGeometry* data = [_linearGradientGeometry objectForKey:IJSVGXMLKey(element)];
    if (data != nil && (id)data != NSNull.null && data.units == gradient.units) {
        [data applyToLinearGradient:gradient];
    } else {
        [IJSVGLinearGradient parseGeometryFromAttributes:attributes gradient:gradient];
        if (_linearGradientGeometry == nil) {
            _linearGradientGeometry = IJSVGParserElementMapTable();
        }

        // Most definitions are used once. Keep only a shared marker until
        // a second use justifies allocating an immutable geometry snapshot.
        id snapshot = data == nil ? NSNull.null : [[IJSVGGradientGeometry alloc] initWithLinearGradient:gradient];
        [_linearGradientGeometry setObject:snapshot forKey:IJSVGXMLKey(element)];
    }
}

- (void)parseRadialGeometry:(IJSVGRadialGradient*)gradient element:(IJSVGXMLNode*)element attributes:(IJSVGXMLAttributeList)attributes
{
    IJSVGGradientGeometry* data = [_radialGradientGeometry objectForKey:IJSVGXMLKey(element)];
    if (data != nil && (id)data != NSNull.null && data.units == gradient.units) {
        [data applyToRadialGradient:gradient];
    } else {
        [IJSVGRadialGradient parseGeometryFromAttributes:attributes gradient:gradient];
        if (_radialGradientGeometry == nil) {
            _radialGradientGeometry = IJSVGParserElementMapTable();
        }

        // Most definitions are used once. Keep only a shared marker until
        // a second use justifies allocating an immutable geometry snapshot.
        id snapshot = data == nil ? NSNull.null : [[IJSVGGradientGeometry alloc] initWithRadialGradient:gradient];
        [_radialGradientGeometry setObject:snapshot forKey:IJSVGXMLKey(element)];
    }
}

#pragma mark Node Types

- (void)parseStyleElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode
{
    // Repeating the latest style block cannot change the cascade.
    // Keep registrations separated by other blocks in their existing order.
    if (_lastParsedStyleElement == element) {
        return;
    }
    if ([IJSVGStyleNode consumeElement:element rootElement:IJSVGXMLRoot(_document) viewport:_rootSize styleSheet:_styleSheet]) {
        _lastParsedStyleElement = element;
    }
}

// Coordinate only references can read plain stops without copying an XML tree.
// Restrict this to the same simple leaf syntax handled by applyStopAttributes.
- (BOOL)canReadGradientStopsFromElement:(IJSVGXMLNode*)reference forElement:(IJSVGXMLNode*)element
{
    if (_styleSheet.ruleCount != 0 || IJSVGXMLChildCount(element) != 0 || ![IJSVGXMLLocalName(reference) isEqualToString:@"linearGradient"]) {
        return NO;
    }
    BOOL hasIdentifier = NO;
    IJSVGXMLAttributeList elementAttributeIterator = IJSVGXMLAttributes(element);
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&elementAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&elementAttributeIterator)) {
        IJSVGNodeAttribute attributeIdentifier = attribute->identifier;
        if (attributeIdentifier == IJSVGNodeAttributeID) {
            hasIdentifier = attribute->value.length != 0;
        } else if (attributeIdentifier != IJSVGNodeAttributeX1 && attributeIdentifier != IJSVGNodeAttributeX2 && attributeIdentifier != IJSVGNodeAttributeY1 && attributeIdentifier != IJSVGNodeAttributeY2 && attributeIdentifier != IJSVGNodeAttributeHref && attributeIdentifier != IJSVGNodeAttributeXLink) {
            return NO;
        }
    }
    if (!hasIdentifier) {
        return NO;
    }
    if ([_plainGradientStopSources containsObject:IJSVGXMLKey(reference)]) {
        return YES;
    }
    IJSVGXMLAttributeList referenceAttributeIterator = IJSVGXMLAttributes(reference);
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&referenceAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&referenceAttributeIterator)) {
        if (attribute->identifier != IJSVGNodeAttributeID) {
            return NO;
        }
    }
    for (IJSVGXMLNode* child = IJSVGXMLFirstChild(reference); child != NULL; child = IJSVGXMLNext(child)) {
        if (IJSVGXMLKind(child) != NSXMLElementKind || ![IJSVGXMLLocalName(child) isEqualToString:@"stop"]) {
            return NO;
        }
        IJSVGXMLNode* stop = (IJSVGXMLNode*)child;
        if (IJSVGXMLChildCount(stop) != 0) {
            return NO;
        }
        IJSVGXMLAttributeList stopAttributeIterator = IJSVGXMLAttributes(stop);
        for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&stopAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&stopAttributeIterator)) {
            IJSVGNodeAttribute attributeIdentifier = attribute->identifier;
            if (attributeIdentifier != IJSVGNodeAttributeOffset && attributeIdentifier != IJSVGNodeAttributeStopColor && attributeIdentifier != IJSVGNodeAttributeStopOpacity) {
                return NO;
            }
        }
    }

    // The source syntax is stable for this parse, but each use still creates its
    // own stops.
    if (_plainGradientStopSources == nil) {
        _plainGradientStopSources = [NSHashTable hashTableWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality];
    }
    [_plainGradientStopSources addObject:IJSVGXMLKey(reference)];
    return YES;
}

- (IJSVGNode*)parseLinearGradientElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGLinearGradient* node = [[IJSVGLinearGradient alloc] init];
    node.units = IJSVGUnitObjectBoundingBox;
    IJSVGPreserveElementName(node, element);
    [node addTraits:IJSVGNodeTraitPaintable];
    node.reference = [self referenceForElement:element];
    NSString* identifier = node.reference.fragmentIdentifier;
    if (identifier != nil) {
        IJSVGXMLNode* source = [self detachedElementWithIdentifier:identifier];
        if ([self canReadGradientStopsFromElement:source forElement:element]) {
            node.identifier = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributeID));
            [self parseLinearGeometry:node element:element attributes:IJSVGXMLAttributes(element)];
            [self populateGradient:node fromElement:source];
            return node;
        }
    }
    IJSVGInheritedElement* input = identifier == nil ? nil : [self inheritedElementForElement:element visiting:nil];
    NSMapTable* previousScope = self.selectorScope;
    if (input.hasReference) {
        self.selectorScope = [self selectorScopeForInheritedElement:input];
    }
    @try {
        [self computeAttributesFromElement:element onNode:node input:input deferredAttributes:deferredAttributes];
        [self parseLinearGeometry:node element:element attributes:input != nil ? input.attributes : IJSVGXMLAttributes(element)];
        [self populateGradient:node fromElement:input != nil ? input.childrenElement : element];
    } @finally {
        self.selectorScope = previousScope;
    }
    return node;
}

- (IJSVGNode*)parseRadialGradientElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGRadialGradient* node = [[IJSVGRadialGradient alloc] init];
    node.units = IJSVGUnitObjectBoundingBox;
    IJSVGPreserveElementName(node, element);
    [node addTraits:IJSVGNodeTraitPaintable];
    node.reference = [self referenceForElement:element];
    IJSVGInheritedElement* input = node.reference.fragmentIdentifier == nil ? nil : [self inheritedElementForElement:element visiting:nil];
    NSMapTable* previousScope = self.selectorScope;
    if (input.hasReference) {
        self.selectorScope = [self selectorScopeForInheritedElement:input];
    }
    @try {
        [self computeAttributesFromElement:element onNode:node input:input deferredAttributes:deferredAttributes];
        [self parseRadialGeometry:node element:element attributes:input != nil ? input.attributes : IJSVGXMLAttributes(element)];
        [self populateGradient:node fromElement:input != nil ? input.childrenElement : element];
    } @finally {
        self.selectorScope = previousScope;
    }
    return node;
}

- (IJSVGNode*)parseStopElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGStop* node = [[IJSVGStop alloc] init];
    IJSVGPreserveElementName(node, element);

    if ([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];
    return node;
}

- (NSDictionary<NSString*, id>*)customPropertiesForNode:(IJSVGNode*)node style:(IJSVGStyleSheetStyle*)style inlineStyle:(IJSVGStyleSheetStyle*)inlineStyle
{
    NSDictionary<NSString*, id>* inherited = nil;
    if (self.customProperties != nil) {
        for (IJSVGNode* parent = node.styleParent; parent != nil; parent = parent.styleParent) {
            inherited = [self.customProperties objectForKey:parent];
            if (inherited != nil) {
                break;
            }
        }
    }
    if (!style.hasCustomProperties && !inlineStyle.hasCustomProperties) {
        return inherited;
    }
    NSMutableDictionary<NSString*, NSString*>* declarations = [[NSMutableDictionary alloc] init];
    IJSVGStyleSheetStyle* __unsafe_unretained sources[] = { style, inlineStyle };
    for (NSUInteger index = 0; index < 2; index++) {
        IJSVGStyleSheetStyle* source = sources[index];
        if (!source.hasCustomProperties) {
            continue;
        }
        for (NSString* property in source.properties) {
            if (![property hasPrefix:@"--"]) {
                continue;
            }
            if (source == inlineStyle && [style isPropertyImportant:property] && ![inlineStyle isPropertyImportant:property]) {
                continue;
            }
            declarations[property] = [source property:property];
        }
    }
    NSDictionary<NSString*, id>* result = IJSVGCSSResolveCustomProperties(declarations, inherited);
    if (self.customProperties == nil) {
        self.customProperties = [NSMapTable weakToStrongObjectsMapTable];
    }
    [self.customProperties setObject:result forKey:node];
    return result;
}

- (void)applyPathValue:(NSString*)value toNode:(IJSVGNode*)node css:(BOOL)css fallback:(NSString*)fallback
{
    if (!css && node.type != IJSVGNodeTypePath) {
        return;
    }
    NSString* pathData = value;
    if (css) {
        switch (IJSVGCSSWideKeywordFromString(value)) {
            case IJSVGCSSWideKeywordInherit: {
                IJSVGNode* parent = node.styleParent;
                pathData = parent.type == IJSVGNodeTypePath ? ((IJSVGPath*)parent).markerPathData : [self.inheritedPathData objectForKey:parent];
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
    if (node.type != IJSVGNodeTypePath) {
        if (pathData != nil) {
            if (self.inheritedPathData == nil) {
                self.inheritedPathData = [NSMapTable weakToStrongObjectsMapTable];
            }
            [self.inheritedPathData setObject:pathData forKey:node];
        } else {
            [self.inheritedPathData removeObjectForKey:node];
        }
    } else {
        IJSVGPath* path = (IJSVGPath*)node;
        [path resetPathForParsing];
        [self applyPathData:pathData toNode:path];
        path.markerPathData = pathData;
    }
}

- (void)applyPathData:(NSString*)pathData toNode:(IJSVGPath*)node
{
    [self applyPathBytes:pathData.UTF8String length:[pathData lengthOfBytesUsingEncoding:NSUTF8StringEncoding] toNode:node];
}

- (void)applyPathBytes:(const char*)characters length:(NSUInteger)length toNode:(IJSVGPath*)node
{
    if (characters == NULL) {
        return;
    }
    if (_parsedPathCache == NULL) {
        _parsedPathCache = IJSVGParsedPathCacheCreate();
    }
    CGPathRef cachedPath = IJSVGParsedPathCacheCopyBytes(_parsedPathCache, characters, length, IJSVGParsedPathData);
    if (cachedPath != NULL) {
        node.path = (CGMutablePathRef)cachedPath;
        CGPathRelease(cachedPath);
        return;
    }
    BOOL mayHavePointSubpaths = IJSVGAppendPathDataCheckingPointSubpaths(node.path, characters, length, _commandDataStream);
    CGPathRef cached = CGPathCreateCopy(node.path);
    if (!mayHavePointSubpaths) {
        [node cachePointSubpaths:NO forPath:cached];
    }
    IJSVGParsedPathCacheStoreBytes(_parsedPathCache, characters, length, IJSVGParsedPathData, cached);
    CGPathRelease(cached);
}

- (IJSVGNode*)parsePathElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    IJSVGPreserveElementName(node, element);
    if ([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];
    return node;
}

- (IJSVGNode*)parseLineElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGPath* node = [[IJSVGLine alloc] init];
    IJSVGPreserveElementName(node, element);

    if ([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];

    return node;
}

- (IJSVGNode*)parsePolyLineElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGPath* node = [[IJSVGPolyline alloc] init];
    IJSVGPreserveElementName(node, element);
    if ([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];

    return node;
}

- (IJSVGNode*)parsePolygonElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGPath* node = [[IJSVGPolygon alloc] init];
    IJSVGPreserveElementName(node, element);
    if ([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];

    return node;
}

- (IJSVGNode*)parseEllipseElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGPath* node = [[IJSVGEllipse alloc] init];
    IJSVGPreserveElementName(node, element);

    if ([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];

    return node;
}

- (IJSVGNode*)parseCircleElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGPath* node = [[IJSVGCircle alloc] init];
    IJSVGPreserveElementName(node, element);

    if ([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];

    return node;
}

- (IJSVGNode*)parseGroupElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode nodeType:(IJSVGNodeType)nodeType deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGGroup* node = [[IJSVGNodeClassForType(nodeType) alloc] init];
    node.type = nodeType;
    IJSVGPreserveElementName(node, element);
    if ([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];

    // recursively compute children
    [self computeElement:element parentNode:node];
    return node;
}

- (void)parseSVGElement:(IJSVGXMLNode*)element ontoNode:(IJSVGRootNode*)node parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes recursive:(BOOL)recursive
{
    node.name = nil;
    IJSVGPreserveElementName(node, element);
    if ([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }

    [self parseDefElement:element parentNode:node recursive:NO];

    if (parentNode != nil) {
        node.overflowVisibility = IJSVGOverflowVisibilityHidden;
    }

    // if we are the root node and not a nested SVG, disable transforms
    IJSVGBitFlags* ignored = nil;
    if (parentNode == nil) {
        ignored = [[IJSVGBitFlags64 alloc] init];
        [ignored setBit:IJSVGNodeAttributeTransform];
    }

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:ignored deferredAttributes:deferredAttributes];

    // Only the outer document needs intrinsic size inference. A nested SVG
    // defaults to the containing viewport and may have no viewBox at all.
    if (parentNode == nil) {
        [self computeViewBoxForRootNode:node];
        [self inferDefaultIntrinsicSizeAndViewBoxForRootNode:node];
    }

    // recursively compute children
    if (recursive == YES) {
        [self computeElement:element parentNode:node];
    }
}

- (IJSVGNode*)parseSVGElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGRootNode* node = [[IJSVGRootNode alloc] init];
    [self parseSVGElement:element ontoNode:node parentNode:parentNode deferredAttributes:deferredAttributes recursive:YES];
    return node;
}

- (IJSVGNode*)parseRectElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGPath* node = [[IJSVGRect alloc] init];
    IJSVGPreserveElementName(node, element);

    if ([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];

    return node;
}

- (IJSVGNode*)parseImageElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGImage* node = [[IJSVGImage alloc] init];
    IJSVGPreserveElementName(node, element);
    if ([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];

    [node loadFromString:node.reference.href];
    return node;
}

- (IJSVGNode*)parseSymbolElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode
{
    IJSVGRootNode* node = [[IJSVGSymbol alloc] init];
    node.type = IJSVGNodeTypeSymbol;
    IJSVGPreserveElementName(node, element);
    node.parentNode = parentNode;
    node.overflowVisibility = IJSVGOverflowVisibilityHidden;

    // Symbols inherit presentation properties from their use element.
    node.lineCapStyle = IJSVGLineCapStyleInherit;
    node.lineJoinStyle = IJSVGLineJoinStyleInherit;
    node.strokeMiterLimit = [node.strokeMiterLimit lengthWithInheritance:YES];
    node.strokeDashArrayCount = IJSVGInheritedIntegerValue;
    IJSVGNodeDeferredAttributes deferredAttributes = { 0 };
    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:&deferredAttributes];
    node.width = parentNode.width ?: node.width ?
                                                : IJSVGOnePercentageUnitLength;
    node.height = parentNode.height ?: node.height ?
                                                   : IJSVGOnePercentageUnitLength;
    node.shouldRender = YES;
    [self computeElement:element parentNode:node];
    IJSVGApplyDeferredAttributes(&deferredAttributes, node, self, element);
    [node postProcess];
    return node;
}

- (IJSVGNode*)parseUseElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGUse* node = [[IJSVGUse alloc] init];
    IJSVGPreserveElementName(node, element);
    IJSVGGroup* parentGroup = [parentNode isKindOfClass:IJSVGGroup.class] ? (IJSVGGroup*)parentNode : nil;
    [parentGroup addChild:node];
    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];
    NSString* xlinkID = node.reference.fragmentIdentifier;
    IJSVGXMLNode* detachedElement = xlinkID == nil ? nil : [self detachedElementWithIdentifier:xlinkID];
    if (xlinkID != nil && [self isElement:element decedentOf:detachedElement]) {
        [self recursionDetectedOn:element decendentOf:detachedElement identifier:xlinkID];
        [parentGroup removeChild:node];
        *deferredAttributes = (IJSVGNodeDeferredAttributes) { 0 };
        return nil;
    }
    [self computeElement:element parentNode:node];
    if (xlinkID == nil) {
        return node;
    }

    if (detachedElement == nil || [self.activeReferences containsObject:xlinkID]) {
        return node;
    }
    NSMapTable* previousScope = self.selectorScope;
    self.selectorScope = nil;
    if (_styleSheet.requiresSelectorTree) {
        self.selectorScope = [self.selectorScopes objectForKey:IJSVGXMLKey(detachedElement)];
        if (self.selectorScope == nil) {
            self.selectorScope = IJSVGParserElementMapTable();
            [self buildSelectorTreeForElement:detachedElement nodes:self.selectorScope];
            if (self.selectorScopes == nil) {
                self.selectorScopes = IJSVGParserElementMapTable();
            }
            [self.selectorScopes setObject:self.selectorScope forKey:IJSVGXMLKey(detachedElement)];
        }
    }
    [self.activeReferences addObject:xlinkID];
    @try {
        IJSVGNodeType type = IJSVGXMLType(detachedElement);
        IJSVGNode* shadowNode = type == IJSVGNodeTypeSymbol ? [self parseSymbolElement:detachedElement parentNode:node] : [self parseElement:detachedElement parentNode:node];
        if (shadowNode != nil) {
            [node addChild:shadowNode];
        }
    } @finally {
        [self.activeReferences removeObject:xlinkID];
        self.selectorScope = previousScope;
    }
    return node;
}

- (IJSVGNode*)parsePatternElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGPattern* node = [[IJSVGPattern alloc] init];
    IJSVGPreserveElementName(node, element);
    node.parentNode = parentNode;
    node.units = IJSVGUnitObjectBoundingBox;
    node.contentUnits = IJSVGUnitUserSpaceOnUse;
    [node addTraits:IJSVGNodeTraitPaintable];
    node.reference = [self referenceForElement:element];
    IJSVGInheritedElement* input = node.reference.fragmentIdentifier == nil ? nil : [self inheritedElementForElement:element visiting:nil];
    NSMapTable* previousScope = self.selectorScope;
    if (input.hasReference) {
        self.selectorScope = [self selectorScopeForInheritedElement:input];
    }
    @try {
        [self computeAttributesFromElement:element onNode:node input:input deferredAttributes:deferredAttributes];
        [self computeElement:input != nil ? input.childrenElement : element parentNode:node];
    } @finally {
        self.selectorScope = previousScope;
    }
    return node;
}

- (IJSVGNode*)parseClipPathElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGClipPath* node = [[IJSVGClipPath alloc] init];
    IJSVGPreserveElementName(node, element);
    node.parentNode = parentNode;

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];

    [self computeElement:element parentNode:node];

    return node;
}

- (void)parseFilterChildren:(IJSVGXMLNode*)element parentNode:(IJSVGGroup*)node
{
    for (IJSVGXMLNode* child = IJSVGXMLFirstChild(element); child != NULL; child = IJSVGXMLNext(child)) {
        IJSVGNodeType type = IJSVGXMLType(child);
        if ([IJSVGFilterPrimitive type:node.type acceptsChildType:type]) {
            [self parseFilterPrimitiveElement:(IJSVGXMLNode*)child parentNode:node];
        }
    }
}

- (IJSVGNode*)filterReferenceWithIdentifier:(NSString*)identifier referencingNode:(IJSVGGraphicsNode*)node element:(IJSVGXMLNode*)element
{
    if (self.activeFilterReferences == nil) {
        self.activeFilterReferences = [[NSMutableSet alloc] init];
    }
    if ([self.activeFilterReferences containsObject:identifier]) {
        return nil;
    }
    [self.activeFilterReferences addObject:identifier];
    @try {
        return [self computeDetachedNodeWithIdentifier:identifier referencingNode:node element:element];
    } @finally {
        [self.activeFilterReferences removeObject:identifier];
    }
}

- (NSArray<NSString*>*)filterIdentifiersForValue:(NSString*)value
{
    NSArray<NSString*>* identifiers = _parsedFilterReferences[value];
    if (identifiers == nil) {
        identifiers = [IJSVGUtils defURLs:value];
        if (value.length <= 4096 && _parsedFilterReferences.count < 128) {
            if (_parsedFilterReferences == nil) {
                _parsedFilterReferences = [[NSMutableDictionary alloc] init];
            }
            _parsedFilterReferences[value] = identifiers.copy;
        }
    }
    return identifiers;
}

- (NSArray<IJSVGFilter*>*)filtersForValue:(NSString*)value referencingNode:(IJSVGGraphicsNode*)node element:(IJSVGXMLNode*)element
{
    NSArray<NSString*>* identifiers = [self filterIdentifiersForValue:value];
    NSMutableArray<IJSVGFilter*>* filters = [[NSMutableArray alloc] init];
    for (NSString* identifier in identifiers) {
        IJSVGXMLNode* definition = [self detachedElementWithIdentifier:identifier];
        if (IJSVGXMLType(definition) != IJSVGNodeTypeFilter) {
            return @[];
        }
        IJSVGFilter* filter = (IJSVGFilter*)[self filterReferenceWithIdentifier:identifier referencingNode:node element:element];
        if (filter == nil) {
            return @[];
        }
        [filters addObject:filter];
    }
    return filters;
}

- (IJSVGFilterPrimitive*)parseFilterPrimitiveElement:(IJSVGXMLNode*)element parentNode:(IJSVGGroup*)parentNode
{
    IJSVGNodeType type = IJSVGXMLType(element);
    IJSVGFilterPrimitive* node = [[IJSVGNodeClassForType(type) alloc] init];
    node.type = type;
    IJSVGPreserveElementName(node, element);
    [parentNode addChild:node];

    IJSVGNodeDeferredAttributes deferredAttributes = { 0 };
    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:&deferredAttributes];
    IJSVGApplyDeferredAttributes(&deferredAttributes, node, self, element);

    [self parseFilterChildren:element parentNode:node];
    if (node.type == IJSVGNodeTypeFilterImage) {
        IJSVGFilterImagePrimitive* imagePrimitive = (IJSVGFilterImagePrimitive*)node;
        NSString* href = imagePrimitive.reference.href;
        NSString* identifier = imagePrimitive.reference.fragmentIdentifier;
        if (href != nil) {
            NSMutableDictionary<NSString*, NSString*>* parameters = node.parameters.mutableCopy;
            parameters[IJSVGAttributeHref] = href;
            [parameters removeObjectForKey:IJSVGAttributeXLink];
            node.parameters = parameters;
        }
        if (identifier != nil) {
            node.imageNode = [self filterReferenceWithIdentifier:identifier referencingNode:node element:element];
            [node removeChild:node.imageNode];
        } else if (href.length != 0) {
            IJSVGImage* image = [[IJSVGImage alloc] init];
            if ([href hasPrefix:@"data:"]) {
                [image loadFromString:href];
            } else {
                [image loadFromURL:[NSURL URLWithString:href relativeToURL:_fileURL]];
            }
            node.image = image.image;
        }
    }
    return node;
}

- (IJSVGNode*)parseFilterElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGFilter* node = [[IJSVGFilter alloc] init];
    IJSVGPreserveElementName(node, element);
    node.parentNode = parentNode;

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];

    NSString* identifier = node.reference.fragmentIdentifier;
    if (identifier != nil) {
        IJSVGNode* inherited = [self filterReferenceWithIdentifier:identifier referencingNode:node element:element];
        if ([inherited isKindOfClass:IJSVGFilter.class]) {
            IJSVGFilter* template = (IJSVGFilter*)inherited;
            if (IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributeX) == nil) {
                node.x = template.x;
            }
            if (IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributeY) == nil) {
                node.y = template.y;
            }
            if (IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributeWidth) == nil) {
                node.width = template.width;
            }
            if (IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributeHeight) == nil) {
                node.height = template.height;
            }
            if (IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributeFilterUnits) == nil) {
                node.units = template.units;
            }
            if (IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributePrimitiveUnits) == nil) {
                node.contentUnits = template.contentUnits;
            }
            if (node.filterColorInterpolation == IJSVGColorInterpolationUnspecified) {
                node.filterColorInterpolation = template.filterColorInterpolation;
            }
            [self parseFilterChildren:element parentNode:node];
            if (node.children.count == 0) {
                for (IJSVGFilterPrimitive* primitive in template.primitives) {
                    IJSVGFilterPrimitive* copy = primitive.copy;
                    copy.parentNode = nil;
                    [node addChild:copy];
                }
            }
            return node;
        }
    }
    [self parseFilterChildren:element parentNode:node];
    return node;
}

- (IJSVGNode*)parseMaskElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    IJSVGMask* node = [[IJSVGMask alloc] init];
    IJSVGPreserveElementName(node, element);
    node.parentNode = parentNode;

    [self computeAttributesFromElement:element onNode:node ignoredAttributes:nil deferredAttributes:deferredAttributes];

    [self computeElement:element parentNode:node];
    return node;
}

- (void)parseDefElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode recursive:(BOOL)recursive
{
    [IJSVGDefinitions consumeElement:element parser:self parentNode:parentNode recursive:recursive];
}

- (void)parseTitleElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    [IJSVGTitleNode consumeElement:element parentNode:parentNode];
}

- (void)parseDescElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode deferredAttributes:(IJSVGNodeDeferredAttributes*)deferredAttributes
{
    [IJSVGDescriptionNode consumeElement:element parentNode:parentNode];
}

#pragma mark References

- (IJSVGReference*)referenceFromAttributes:(const IJSVGReferenceAttributes*)attributes
{
    IJSVGXMLAttribute* attribute = attributes->href ?: attributes->namespacedHref ?
                                                                                  : attributes->legacyHref;
    NSString* href = IJSVGXMLAttributeValue(attribute);
    if (href == nil) {
        return IJSVGEmptyReference();
    }
    IJSVGReference* reference = _referenceValues[href];
    if (reference == nil) {
        reference = [[IJSVGReference alloc] initWithHref:href];
        if (_referenceValues == nil) {
            _referenceValues = [[NSMutableDictionary alloc] init];
        }
        _referenceValues[href] = reference;
    }
    return reference;
}

- (IJSVGReference*)referenceForElement:(IJSVGXMLNode*)element
{
    if (element == nil) {
        return nil;
    }
    CFTypeRef* referenceSlot = [self referenceSlotForElement:element];
    IJSVGReference* reference = referenceSlot != NULL ? (__bridge IJSVGReference*)*referenceSlot : [_references objectForKey:IJSVGXMLKey(element)];
    if (reference == nil) {
        IJSVGReferenceAttributes attributes = { nil, nil, nil };
        IJSVGXMLAttributeList elementAttributes = IJSVGXMLAttributes(element);
        IJSVGXMLAttributeList elementAttributeIterator = elementAttributes;
        for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&elementAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&elementAttributeIterator)) {
            if (strcmp(attribute->name, "href") != 0) {
                continue;
            }
            IJSVGReadReferenceAttribute(attribute, &attributes);
            if (attributes.href != nil) {
                break;
            }
        }
        reference = [self referenceFromAttributes:&attributes];
        if (referenceSlot != NULL) {
            *referenceSlot = CFBridgingRetain(reference);
        } else {
            if (_references == nil) {
                _references = IJSVGParserElementMapTable();
            }
            [_references setObject:reference forKey:IJSVGXMLKey(element)];
        }
    }
    return reference;
}

#pragma mark Command Parsing

- (void)parsePolyPoints:(NSString*)points intoPath:(IJSVGPath*)path closePath:(BOOL)closePath
{
    [self parsePolyBytes:points.UTF8String length:[points lengthOfBytesUsingEncoding:NSUTF8StringEncoding] intoPath:path closePath:closePath];
}

- (void)parsePolyBytes:(const char*)characters length:(NSUInteger)length intoPath:(IJSVGPath*)path closePath:(BOOL)closePath
{
    BOOL cacheable = characters != NULL && CGPathIsEmpty(path.path);
    if (cacheable && _parsedPathCache == NULL) {
        _parsedPathCache = IJSVGParsedPathCacheCreate();
    }
    IJSVGParsedPathKind kind = closePath ? IJSVGParsedPathPolygon : IJSVGParsedPathPolyline;
    CGPathRef cached = cacheable ? IJSVGParsedPathCacheCopyBytes(_parsedPathCache, characters, length, kind) : NULL;
    BOOL parsed = cached != NULL;
    if (parsed) {
        path.path = (CGMutablePathRef)cached;
        CGPathRelease(cached);
    } else {
        parsed = IJSVGAppendPolyPoints(path.path, characters, length, closePath, _commandDataStream);
        if (parsed && cacheable) {
            IJSVGParsedPathCacheStoreBytes(_parsedPathCache, characters, length, kind, path.path);
        }
    }
    if (parsed) {
        IJSVGGraphicsNode* referencingNode = nil;
        path.pathUnits = [path contentUnitsWithReferencingNode:&referencingNode];
    }
}

@end
