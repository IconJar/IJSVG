//
//  IJSVGParser.h
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGClipPath.h>
#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGColorNode.h>
#import <IJSVG/IJSVGCommand.h>
#import <IJSVG/IJSVGError.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGForeignObject.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGImage.h>
#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGMask.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGPattern.h>
#import <IJSVG/IJSVGRadialGradient.h>
#import <IJSVG/IJSVGStop.h>
#import <IJSVG/IJSVGStyleSheet.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGUtils.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^IJSVGNodeParserPostProcessBlock)(void);

FOUNDATION_EXPORT NSString* const IJSVGStringObjectBoundingBox;
FOUNDATION_EXPORT NSString* const IJSVGStringUserSpaceOnUse;
FOUNDATION_EXPORT NSString* const IJSVGStringNone;
FOUNDATION_EXPORT NSString* const IJSVGStringRound;
FOUNDATION_EXPORT NSString* const IJSVGStringSquare;
FOUNDATION_EXPORT NSString* const IJSVGStringBevel;
FOUNDATION_EXPORT NSString* const IJSVGStringButt;
FOUNDATION_EXPORT NSString* const IJSVGStringMiter;
FOUNDATION_EXPORT NSString* const IJSVGStringInherit;
FOUNDATION_EXPORT NSString* const IJSVGStringEvenOdd;
FOUNDATION_EXPORT NSString* const IJSVGStringAuto;
FOUNDATION_EXPORT NSString* const IJSVGStringStrokeWidth;
FOUNDATION_EXPORT NSString* const IJSVGStringNonScalingStroke;
FOUNDATION_EXPORT NSString* const IJSVGStringDegrees;
FOUNDATION_EXPORT NSString* const IJSVGStringRadians;
FOUNDATION_EXPORT NSString* const IJSVGStringGradians;
FOUNDATION_EXPORT NSString* const IJSVGStringAutoStartReverse;
FOUNDATION_EXPORT NSString* const IJSVGStringContextFill;
FOUNDATION_EXPORT NSString* const IJSVGStringContextStroke;

// SVG filter attribute values and predefined inputs.
FOUNDATION_EXPORT NSString* const IJSVGStringNormal;
FOUNDATION_EXPORT NSString* const IJSVGStringMultiply;
FOUNDATION_EXPORT NSString* const IJSVGStringScreen;
FOUNDATION_EXPORT NSString* const IJSVGStringDarken;
FOUNDATION_EXPORT NSString* const IJSVGStringLighten;
FOUNDATION_EXPORT NSString* const IJSVGStringOverlay;
FOUNDATION_EXPORT NSString* const IJSVGStringColorDodge;
FOUNDATION_EXPORT NSString* const IJSVGStringColorBurn;
FOUNDATION_EXPORT NSString* const IJSVGStringHardLight;
FOUNDATION_EXPORT NSString* const IJSVGStringSoftLight;
FOUNDATION_EXPORT NSString* const IJSVGStringDifference;
FOUNDATION_EXPORT NSString* const IJSVGStringExclusion;
FOUNDATION_EXPORT NSString* const IJSVGStringHue;
FOUNDATION_EXPORT NSString* const IJSVGStringSaturation;
FOUNDATION_EXPORT NSString* const IJSVGStringColor;
FOUNDATION_EXPORT NSString* const IJSVGStringLuminosity;
FOUNDATION_EXPORT NSString* const IJSVGStringMatrix;
FOUNDATION_EXPORT NSString* const IJSVGStringSaturate;
FOUNDATION_EXPORT NSString* const IJSVGStringHueRotate;
FOUNDATION_EXPORT NSString* const IJSVGStringLuminanceToAlpha;
FOUNDATION_EXPORT NSString* const IJSVGStringDilate;
FOUNDATION_EXPORT NSString* const IJSVGStringOver;
FOUNDATION_EXPORT NSString* const IJSVGStringIn;
FOUNDATION_EXPORT NSString* const IJSVGStringOut;
FOUNDATION_EXPORT NSString* const IJSVGStringAtop;
FOUNDATION_EXPORT NSString* const IJSVGStringLighter;
FOUNDATION_EXPORT NSString* const IJSVGStringXor;
FOUNDATION_EXPORT NSString* const IJSVGStringArithmetic;
FOUNDATION_EXPORT NSString* const IJSVGStringIdentity;
FOUNDATION_EXPORT NSString* const IJSVGStringTable;
FOUNDATION_EXPORT NSString* const IJSVGStringDiscrete;
FOUNDATION_EXPORT NSString* const IJSVGStringLinear;
FOUNDATION_EXPORT NSString* const IJSVGStringGamma;
FOUNDATION_EXPORT NSString* const IJSVGStringTrue;
FOUNDATION_EXPORT NSString* const IJSVGStringDuplicate;
FOUNDATION_EXPORT NSString* const IJSVGStringWrap;
FOUNDATION_EXPORT NSString* const IJSVGStringFractalNoise;
FOUNDATION_EXPORT NSString* const IJSVGStringStitch;
FOUNDATION_EXPORT NSString* const IJSVGStringBlack;
FOUNDATION_EXPORT NSString* const IJSVGStringWhite;
FOUNDATION_EXPORT NSString* const IJSVGStringSRGB;
FOUNDATION_EXPORT NSString* const IJSVGStringLinearRGB;
FOUNDATION_EXPORT NSString* const IJSVGStringSourceGraphic;
FOUNDATION_EXPORT NSString* const IJSVGStringSourceAlpha;
FOUNDATION_EXPORT NSString* const IJSVGStringBackgroundImage;
FOUNDATION_EXPORT NSString* const IJSVGStringBackgroundAlpha;
FOUNDATION_EXPORT NSString* const IJSVGStringFillPaint;
FOUNDATION_EXPORT NSString* const IJSVGStringStrokePaint;
FOUNDATION_EXPORT NSString* const IJSVGStringChannelR;
FOUNDATION_EXPORT NSString* const IJSVGStringChannelG;
FOUNDATION_EXPORT NSString* const IJSVGStringChannelB;
FOUNDATION_EXPORT NSString* const IJSVGStringChannelA;

FOUNDATION_EXPORT NSString* const IJSVGAttributeVersion;
FOUNDATION_EXPORT NSString* const IJSVGAttributeXMLNS;
FOUNDATION_EXPORT NSString* const IJSVGAttributeXMLNSXlink;
FOUNDATION_EXPORT NSString* const IJSVGAttributeViewBox;
FOUNDATION_EXPORT NSString* const IJSVGAttributePreserveAspectRatio;
FOUNDATION_EXPORT NSString* const IJSVGAttributeID;
FOUNDATION_EXPORT NSString* const IJSVGAttributeClass;
FOUNDATION_EXPORT NSString* const IJSVGAttributeX;
FOUNDATION_EXPORT NSString* const IJSVGAttributeY;
FOUNDATION_EXPORT NSString* const IJSVGAttributeWidth;
FOUNDATION_EXPORT NSString* const IJSVGAttributeHeight;
FOUNDATION_EXPORT NSString* const IJSVGAttributeOpacity;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStrokeOpacity;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStrokeWidth;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStrokeDashOffset;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFillOpacity;
FOUNDATION_EXPORT NSString* const IJSVGAttributeClipPath;
FOUNDATION_EXPORT NSString* const IJSVGAttributeClipPathUnits;
FOUNDATION_EXPORT NSString* const IJSVGAttributeClipRule;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMask;
FOUNDATION_EXPORT NSString* const IJSVGAttributeGradientUnits;
FOUNDATION_EXPORT NSString* const IJSVGAttributeSpreadMethod;
FOUNDATION_EXPORT NSString* const IJSVGAttributePatternUnits;
FOUNDATION_EXPORT NSString* const IJSVGAttributePatternContentUnits;
FOUNDATION_EXPORT NSString* const IJSVGAttributePatternTransform;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMaskType;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMaskUnits;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMaskContentUnits;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTransform;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTransformOrigin;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTransformBox;
FOUNDATION_EXPORT NSString* const IJSVGAttributeRequiredExtensions;
FOUNDATION_EXPORT NSString* const IJSVGAttributeSystemLanguage;
FOUNDATION_EXPORT NSString* const IJSVGAttributeGradientTransform;
FOUNDATION_EXPORT NSString* const IJSVGAttributeUnicode;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStrokeLineCap;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStrokeLineJoin;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStroke;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStrokeDashArray;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStrokeMiterLimit;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFill;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFillRule;
FOUNDATION_EXPORT NSString* const IJSVGAttributeBlendMode;
FOUNDATION_EXPORT NSString* const IJSVGAttributeIsolation;
FOUNDATION_EXPORT NSString* const IJSVGAttributePaintOrder;
FOUNDATION_EXPORT NSString* const IJSVGAttributeVectorEffect;
FOUNDATION_EXPORT NSString* const IJSVGAttributeColor;
FOUNDATION_EXPORT NSString* const IJSVGAttributeVisibility;
FOUNDATION_EXPORT NSString* const IJSVGAttributeDisplay;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStyle;
FOUNDATION_EXPORT NSString* const IJSVGAttributeD;
FOUNDATION_EXPORT NSString* const IJSVGAttributeXLink;
FOUNDATION_EXPORT NSString* const IJSVGAttributeX1;
FOUNDATION_EXPORT NSString* const IJSVGAttributeX2;
FOUNDATION_EXPORT NSString* const IJSVGAttributeY1;
FOUNDATION_EXPORT NSString* const IJSVGAttributeY2;
FOUNDATION_EXPORT NSString* const IJSVGAttributeRX;
FOUNDATION_EXPORT NSString* const IJSVGAttributeRY;
FOUNDATION_EXPORT NSString* const IJSVGAttributeCX;
FOUNDATION_EXPORT NSString* const IJSVGAttributeCY;
FOUNDATION_EXPORT NSString* const IJSVGAttributeR;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFR;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFX;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFY;
FOUNDATION_EXPORT NSString* const IJSVGAttributePoints;
FOUNDATION_EXPORT NSString* const IJSVGAttributeOffset;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStopColor;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStopOpacity;
FOUNDATION_EXPORT NSString* const IJSVGAttributeHref;
FOUNDATION_EXPORT NSString* const IJSVGAttributeOverflow;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMarker;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMarkerStart;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMarkerMid;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMarkerEnd;
FOUNDATION_EXPORT NSString* const IJSVGAttributeRefX;
FOUNDATION_EXPORT NSString* const IJSVGAttributeRefY;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMarkerWidth;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMarkerHeight;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMarkerUnits;
FOUNDATION_EXPORT NSString* const IJSVGAttributeOrient;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFilter;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFilterUnits;
FOUNDATION_EXPORT NSString* const IJSVGAttributePrimitiveUnits;
FOUNDATION_EXPORT NSString* const IJSVGAttributeDX;
FOUNDATION_EXPORT NSString* const IJSVGAttributeDY;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStdDeviation;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFloodColor;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFloodOpacity;
FOUNDATION_EXPORT NSString* const IJSVGAttributeIn;
FOUNDATION_EXPORT NSString* const IJSVGAttributeResult;
FOUNDATION_EXPORT NSString* const IJSVGAttributeIn2;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMode;
FOUNDATION_EXPORT NSString* const IJSVGAttributeType;
FOUNDATION_EXPORT NSString* const IJSVGAttributeValues;
FOUNDATION_EXPORT NSString* const IJSVGAttributeOperator;
FOUNDATION_EXPORT NSString* const IJSVGAttributeK1;
FOUNDATION_EXPORT NSString* const IJSVGAttributeK2;
FOUNDATION_EXPORT NSString* const IJSVGAttributeK3;
FOUNDATION_EXPORT NSString* const IJSVGAttributeK4;
FOUNDATION_EXPORT NSString* const IJSVGAttributeOrder;
FOUNDATION_EXPORT NSString* const IJSVGAttributeKernelMatrix;
FOUNDATION_EXPORT NSString* const IJSVGAttributeDivisor;
FOUNDATION_EXPORT NSString* const IJSVGAttributeBias;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTargetX;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTargetY;
FOUNDATION_EXPORT NSString* const IJSVGAttributeEdgeMode;
FOUNDATION_EXPORT NSString* const IJSVGAttributeKernelUnitLength;
FOUNDATION_EXPORT NSString* const IJSVGAttributePreserveAlpha;
FOUNDATION_EXPORT NSString* const IJSVGAttributeSurfaceScale;
FOUNDATION_EXPORT NSString* const IJSVGAttributeDiffuseConstant;
FOUNDATION_EXPORT NSString* const IJSVGAttributeSpecularConstant;
FOUNDATION_EXPORT NSString* const IJSVGAttributeSpecularExponent;
FOUNDATION_EXPORT NSString* const IJSVGAttributeLightingColor;
FOUNDATION_EXPORT NSString* const IJSVGAttributeScale;
FOUNDATION_EXPORT NSString* const IJSVGAttributeXChannelSelector;
FOUNDATION_EXPORT NSString* const IJSVGAttributeYChannelSelector;
FOUNDATION_EXPORT NSString* const IJSVGAttributeRadius;
FOUNDATION_EXPORT NSString* const IJSVGAttributeBaseFrequency;
FOUNDATION_EXPORT NSString* const IJSVGAttributeNumOctaves;
FOUNDATION_EXPORT NSString* const IJSVGAttributeSeed;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStitchTiles;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTableValues;
FOUNDATION_EXPORT NSString* const IJSVGAttributeSlope;
FOUNDATION_EXPORT NSString* const IJSVGAttributeIntercept;
FOUNDATION_EXPORT NSString* const IJSVGAttributeAmplitude;
FOUNDATION_EXPORT NSString* const IJSVGAttributeExponent;
FOUNDATION_EXPORT NSString* const IJSVGAttributeAzimuth;
FOUNDATION_EXPORT NSString* const IJSVGAttributeElevation;
FOUNDATION_EXPORT NSString* const IJSVGAttributeZ;
FOUNDATION_EXPORT NSString* const IJSVGAttributePointsAtX;
FOUNDATION_EXPORT NSString* const IJSVGAttributePointsAtY;
FOUNDATION_EXPORT NSString* const IJSVGAttributePointsAtZ;
FOUNDATION_EXPORT NSString* const IJSVGAttributeLimitingConeAngle;
FOUNDATION_EXPORT NSString* const IJSVGAttributeColorInterpolationFilters;
FOUNDATION_EXPORT NSString* const IJSVGAttributeEnableBackground;
FOUNDATION_EXPORT NSString* const IJSVGAttributeBackgroundColor;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMedia;

// SVG text presentation and positioning attributes.
FOUNDATION_EXPORT NSString* const IJSVGAttributeFont;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFontFamily;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFontSize;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFontSizeAdjust;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFontWeight;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFontStyle;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFontStretch;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFontVariant;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFontVariantLigatures;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFontFeatureSettings;
FOUNDATION_EXPORT NSString* const IJSVGAttributeFontKerning;
FOUNDATION_EXPORT NSString* const IJSVGAttributeLetterSpacing;
FOUNDATION_EXPORT NSString* const IJSVGAttributeWordSpacing;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTextAnchor;
FOUNDATION_EXPORT NSString* const IJSVGAttributeDirection;
FOUNDATION_EXPORT NSString* const IJSVGAttributeUnicodeBidi;
FOUNDATION_EXPORT NSString* const IJSVGAttributeWritingMode;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTextOrientation;
FOUNDATION_EXPORT NSString* const IJSVGAttributeDominantBaseline;
FOUNDATION_EXPORT NSString* const IJSVGAttributeAlignmentBaseline;
FOUNDATION_EXPORT NSString* const IJSVGAttributeBaselineShift;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTextDecoration;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTextDecorationLine;
FOUNDATION_EXPORT NSString* const IJSVGAttributeWhiteSpace;
FOUNDATION_EXPORT NSString* const IJSVGAttributeLineHeight;
FOUNDATION_EXPORT NSString* const IJSVGAttributeInlineSize;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTextTransform;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTextOverflow;
FOUNDATION_EXPORT NSString* const IJSVGAttributeXMLSpace;
FOUNDATION_EXPORT NSString* const IJSVGAttributeLang;
FOUNDATION_EXPORT NSString* const IJSVGAttributeXMLLang;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTextRendering;
FOUNDATION_EXPORT NSString* const IJSVGAttributeRotate;
FOUNDATION_EXPORT NSString* const IJSVGAttributeTextLength;
FOUNDATION_EXPORT NSString* const IJSVGAttributeLengthAdjust;
FOUNDATION_EXPORT NSString* const IJSVGAttributeStartOffset;
FOUNDATION_EXPORT NSString* const IJSVGAttributeMethod;
FOUNDATION_EXPORT NSString* const IJSVGAttributeSpacing;
FOUNDATION_EXPORT NSString* const IJSVGAttributeSide;
FOUNDATION_EXPORT NSString* const IJSVGAttributePath;
FOUNDATION_EXPORT NSString* const IJSVGAttributePathLength;

@class IJSVGParser;
@class IJSVGThreadManager;

@interface IJSVGParser : NSObject {
@private
    NSXMLDocument* _document;
    IJSVGPathDataStream* _commandDataStream;
    IJSVGStyleSheet* _styleSheet;
    NSMutableDictionary<NSString*, NSXMLElement*>* _detachedReferences;
    IJSVGThreadManager* _threadManager;
    CGSize _rootSize;
    IJSVGRootNode* _rootNode;
    NSURL* _fileURL;
}

+ (BOOL)isDataSVG:(NSData*)data;

- (nullable instancetype)initWithSVGString:(NSString*)string fileURL:(NSURL* _Nullable)fileURL error:(NSError* _Nullable* _Nullable)error;
- (nullable instancetype)initWithSVGData:(NSData*)data fileURL:(NSURL* _Nullable)fileURL error:(NSError* _Nullable* _Nullable)error;

- (nullable instancetype)initWithFileURL:(NSURL*)aURL error:(NSError* _Nullable* _Nullable)error;
+ (nullable IJSVGParser*)parserForFileURL:(NSURL*)aURL;
+ (nullable IJSVGParser*)parserForFileURL:(NSURL*)aURL error:(NSError* _Nullable* _Nullable)error;

- (IJSVGRootNode*)rootNodeWithSize:(CGSize)size;

@end

NS_ASSUME_NONNULL_END
