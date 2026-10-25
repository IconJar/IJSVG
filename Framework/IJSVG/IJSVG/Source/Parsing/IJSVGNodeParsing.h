//
//  IJSVGNodeParsing.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGAnchor.h>
#import <IJSVG/IJSVGCircle.h>
#import <IJSVG/IJSVGDefinitions.h>
#import <IJSVG/IJSVGDescriptionNode.h>
#import <IJSVG/IJSVGEllipse.h>
#import <IJSVG/IJSVGFilterBlendPrimitive.h>
#import <IJSVG/IJSVGFilterColorMatrixPrimitive.h>
#import <IJSVG/IJSVGFilterComponentTransferPrimitive.h>
#import <IJSVG/IJSVGFilterCompositePrimitive.h>
#import <IJSVG/IJSVGFilterConvolveMatrixPrimitive.h>
#import <IJSVG/IJSVGFilterDiffuseLightingPrimitive.h>
#import <IJSVG/IJSVGFilterDisplacementMapPrimitive.h>
#import <IJSVG/IJSVGFilterDistantLightPrimitive.h>
#import <IJSVG/IJSVGFilterDropShadowPrimitive.h>
#import <IJSVG/IJSVGFilterFloodPrimitive.h>
#import <IJSVG/IJSVGFilterFuncAPrimitive.h>
#import <IJSVG/IJSVGFilterFuncBPrimitive.h>
#import <IJSVG/IJSVGFilterFuncGPrimitive.h>
#import <IJSVG/IJSVGFilterFuncRPrimitive.h>
#import <IJSVG/IJSVGFilterGaussianBlurPrimitive.h>
#import <IJSVG/IJSVGFilterImagePrimitive.h>
#import <IJSVG/IJSVGFilterMergeNodePrimitive.h>
#import <IJSVG/IJSVGFilterMergePrimitive.h>
#import <IJSVG/IJSVGFilterMorphologyPrimitive.h>
#import <IJSVG/IJSVGFilterOffsetPrimitive.h>
#import <IJSVG/IJSVGFilterPointLightPrimitive.h>
#import <IJSVG/IJSVGFilterPrimitive.h>
#import <IJSVG/IJSVGFilterSpecularLightingPrimitive.h>
#import <IJSVG/IJSVGFilterSpotLightPrimitive.h>
#import <IJSVG/IJSVGFilterTilePrimitive.h>
#import <IJSVG/IJSVGFilterTurbulencePrimitive.h>
#import <IJSVG/IJSVGFont.h>
#import <IJSVG/IJSVGGlyph.h>
#import <IJSVG/IJSVGLine.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVG/IJSVGPolygon.h>
#import <IJSVG/IJSVGPolyline.h>
#import <IJSVG/IJSVGRect.h>
#import <IJSVG/IJSVGStop.h>
#import <IJSVG/IJSVGStyleNode.h>
#import <IJSVG/IJSVGSymbol.h>
#import <IJSVG/IJSVGText.h>
#import <IJSVG/IJSVGTextPath.h>
#import <IJSVG/IJSVGTextSpan.h>
#import <IJSVG/IJSVGTitleNode.h>
#import <IJSVG/IJSVGUnknownNode.h>
#import <IJSVG/IJSVGUse.h>
#import <IJSVGParserTextUtils.h>
#import <IJSVGParserUtils.h>
#import <IJSVGSwitch.h>
#import <IJSVGXML.h>

// Deferred values remain on the caller stack until the children are parsed.
// Retain resolved strings because the temporary cascade may finish sooner.
typedef struct {
    __strong NSString* mask;
    __strong NSString* clipPath;
    __strong NSString* filter;
    __strong NSString* markerStart;
    __strong NSString* markerMid;
    __strong NSString* markerEnd;
} IJSVGNodeDeferredAttributes;

void IJSVGApplyDeferredAttributes(const IJSVGNodeDeferredAttributes* attributes, IJSVGNode* node, IJSVGParser* parser, IJSVGXMLNode* element);

// Resolved values live on the parser stack for the duration of consumption.
// Nodes retain only the values they use.
typedef struct {
    uint64_t textAttributes;
    __unsafe_unretained IJSVGReference* reference;
    __unsafe_unretained NSMutableDictionary<NSNumber*, IJSVGUnitLength*>* cachedGeometryLengths;
    __unsafe_unretained NSMutableDictionary<NSNumber*, NSString*>* cachedGeometryValues;
    __unsafe_unretained IJSVGGraphicsNode* geometryOwner;
    __strong NSMutableDictionary<NSNumber*, IJSVGUnitLength*>* geometryLengths;
    __unsafe_unretained IJSVGParser* parser;
    IJSVGXMLNode* element;
    NSString* __unsafe_unretained* values;
    __unsafe_unretained IJSVGStyleSheetStyle* style;
    __unsafe_unretained IJSVGStyleSheetStyle* inlineStyle;
    __unsafe_unretained NSString* attributePathData;
    __unsafe_unretained NSDictionary<NSString*, NSString*>* filterParameters;
    IJSVGNodeDeferredAttributes* deferredAttributes;
} IJSVGNodeParsingContext;

@interface IJSVGPath (DataParsing)
- (void)resetPathForParsing;
@end

@interface IJSVGGradient (DataParsing)
- (void)parseSpreadMethodFromAttributes:(IJSVGXMLAttributeList)attributes;
- (void)parseColorStops;
@end

@interface IJSVGLinearGradient (DataParsing)
+ (void)parseGeometryFromAttributes:(IJSVGXMLAttributeList)attributes gradient:(IJSVGLinearGradient*)gradient;
@end

@interface IJSVGRadialGradient (DataParsing)
+ (void)parseGeometryFromAttributes:(IJSVGXMLAttributeList)attributes gradient:(IJSVGRadialGradient*)gradient;
@end

@interface IJSVGNode (Parsing)
- (void)consumeAttributes:(IJSVGNodeParsingContext*)context;
@end

@interface IJSVGStop (Parsing)
- (void)consumeXMLAttributes:(IJSVGXMLAttributeList)attributes parser:(IJSVGParser*)parser;
- (void)consumeOffset:(NSString*)offset color:(NSString*)color opacity:(NSString*)opacity parser:(IJSVGParser*)parser;
@end

// Shared services do not decide which attributes an element supports.
@interface IJSVGParser (NodeParsingServices)
- (IJSVGStyleSheetStyle*)parsedInlineStyleForValue:(NSString*)value;
- (void)parsePolyBytes:(const char*)bytes length:(NSUInteger)length intoPath:(IJSVGPath*)path closePath:(BOOL)close;
- (void)parsePolyPoints:(NSString*)points intoPath:(IJSVGPath*)path closePath:(BOOL)close;
- (void)detachElement:(IJSVGXMLNode*)element withIdentifier:(NSString*)identifier;
- (void)parseStyleElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode;
- (void)parseDefElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode recursive:(BOOL)recursive;
- (void)applyPathValue:(NSString*)value toNode:(IJSVGNode*)node css:(BOOL)css fallback:(NSString*)fallback;
- (IJSVGNode*)computeDetachedNodeWithIdentifier:(NSString*)identifier referencingNode:(IJSVGGraphicsNode*)node element:(IJSVGXMLNode*)element;
- (NSArray<IJSVGFilter*>*)filtersForValue:(NSString*)value referencingNode:(IJSVGGraphicsNode*)node element:(IJSVGXMLNode*)element;
- (NSArray<IJSVGTransform*>*)parsedTransformsForValue:(NSString*)value allowCSSUnits:(BOOL)allowCSSUnits;
- (void)applyPaintValue:(NSString*)value node:(IJSVGGraphicsNode*)node element:(IJSVGXMLNode*)element stroke:(BOOL)stroke;
- (IJSVGColorNode*)colorPaintForValue:(NSString*)value;
- (CGColorRef)parsedStopColorForValue:(NSString*)value;
- (CGColorRef)parsedStopColorForAttribute:(IJSVGXMLAttribute*)attribute;
- (void)applyMarkerStart:(NSString*)start mid:(NSString*)mid end:(NSString*)end toNode:(IJSVGGraphicsNode*)node element:(IJSVGXMLNode*)element;
@end

BOOL IJSVGParserAttributeHasValue(NSString* __unsafe_unretained const* values, IJSVGNodeAttribute attribute, NSString* __strong* value);

IJSVGBitFlags* IJSVGCommonAttributes(void);
IJSVGBitFlags* IJSVGGraphicsAttributes(void);
IJSVGBitFlags* IJSVGContainerAttributes(void);
void IJSVGAddTextStyleAttributes(IJSVGBitFlags* attributes);
Class IJSVGNodeClassForType(IJSVGNodeType type);
void IJSVGParseColorAttributes(IJSVGNode* node, IJSVGNodeParsingContext* context);
void IJSVGParseDisplayAttributes(IJSVGNode* node, IJSVGNodeParsingContext* context);
void IJSVGParseTextStyleAttributes(IJSVGNode* node, IJSVGNodeParsingContext* context);
void IJSVGParseGeometryInheritance(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context);
BOOL IJSVGReadGeometryLength(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context, IJSVGNodeAttribute attribute, IJSVGUnitLength* __strong* usedLength);
void IJSVGParsePathAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context);
void IJSVGParsePathLengthAttributes(IJSVGPath* node, IJSVGNodeParsingContext* context);
void IJSVGParseBackgroundAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context);
void IJSVGParsePaintAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context);
void IJSVGParseEffectsAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context);
void IJSVGParseTransformAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context);
void IJSVGParseViewportAttributes(IJSVGViewportNode* node, IJSVGNodeParsingContext* context);
void IJSVGParseAspectRatioAttributes(IJSVGViewportNode* node, IJSVGNodeParsingContext* context);
void IJSVGParseOverflowAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context);
void IJSVGParseGradientAttributes(IJSVGGradient* node, IJSVGNodeParsingContext* context);
void IJSVGParseMaskAttributes(IJSVGMask* node, IJSVGNodeParsingContext* context);
void IJSVGParsePatternAttributes(IJSVGPattern* node, IJSVGNodeParsingContext* context);
void IJSVGParseClipAttributes(IJSVGClipPath* node, IJSVGNodeParsingContext* context);
void IJSVGParseFilterAttributes(IJSVGFilter* node, IJSVGNodeParsingContext* context);
void IJSVGParseRootAttributes(IJSVGRootNode* node, IJSVGNodeParsingContext* context);
void IJSVGParseSymbolAttributes(IJSVGSymbol* node, IJSVGNodeParsingContext* context);
void IJSVGParseFilterColorInterpolation(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context);
void IJSVGParseMarkersAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context);

@interface IJSVGDefinitions (Parsing)
+ (void)consumeElement:(IJSVGXMLNode*)element parser:(IJSVGParser*)parser parentNode:(IJSVGGraphicsNode*)parentNode recursive:(BOOL)recursive;
@end

@interface IJSVGTitleNode (Parsing)
+ (void)consumeElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode;
@end

@interface IJSVGDescriptionNode (Parsing)
+ (void)consumeElement:(IJSVGXMLNode*)element parentNode:(IJSVGGraphicsNode*)parentNode;
@end

@interface IJSVGStyleNode (Parsing)
+ (BOOL)consumeElement:(IJSVGXMLNode*)element rootElement:(IJSVGXMLNode*)rootElement viewport:(CGSize)viewport styleSheet:(IJSVGStyleSheet*)styleSheet;
@end

@interface IJSVGSwitch (XMLParsing)
+ (IJSVGXMLNode*)selectedChildInXML:(IJSVGXMLNode*)element preferredLanguages:(NSArray<NSString*>*)preferredLanguages;
@end

@interface IJSVGFilterPrimitive (ParameterTemplate)
- (instancetype)initWithParameterStateFromPrimitive:(IJSVGFilterPrimitive*)source;
@end

// Advances whenever a style parent link, a parent link or an inherited color
// interpolation value may have changed, including when a node is freed.
// Readers may cache inherited values while the generation is unchanged.
uint64_t IJSVGNodeInheritanceGeneration(void);
void IJSVGNodeInvalidateInheritance(void);
