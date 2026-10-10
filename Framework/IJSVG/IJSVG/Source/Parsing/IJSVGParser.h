//
//  IJSVGParser.h
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGCommand.h>
#import <IJSVG/IJSVGError.h>
#import <IJSVG/IJSVGForeignObject.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGColorNode.h>
#import <IJSVG/IJSVGStop.h>
#import <IJSVG/IJSVGImage.h>
#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGPattern.h>
#import <IJSVG/IJSVGMask.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGClipPath.h>
#import <IJSVG/IJSVGRadialGradient.h>
#import <IJSVG/IJSVGStyleSheet.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGUtils.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^IJSVGNodeParserPostProcessBlock)(void);

extern NSString* const IJSVGStringObjectBoundingBox;
extern NSString* const IJSVGStringUserSpaceOnUse;
extern NSString* const IJSVGStringNone;
extern NSString* const IJSVGStringRound;
extern NSString* const IJSVGStringSquare;
extern NSString* const IJSVGStringBevel;
extern NSString* const IJSVGStringButt;
extern NSString* const IJSVGStringMiter;
extern NSString* const IJSVGStringInherit;
extern NSString* const IJSVGStringEvenOdd;
extern NSString* const IJSVGStringAuto;
extern NSString* const IJSVGStringStrokeWidth;
extern NSString* const IJSVGStringNonScalingStroke;
extern NSString* const IJSVGStringDegrees;
extern NSString* const IJSVGStringRadians;
extern NSString* const IJSVGStringGradians;
extern NSString* const IJSVGStringAutoStartReverse;
extern NSString* const IJSVGStringContextFill;
extern NSString* const IJSVGStringContextStroke;

// SVG filter attribute values and predefined inputs.
extern NSString* const IJSVGStringNormal;
extern NSString* const IJSVGStringMultiply;
extern NSString* const IJSVGStringScreen;
extern NSString* const IJSVGStringDarken;
extern NSString* const IJSVGStringLighten;
extern NSString* const IJSVGStringOverlay;
extern NSString* const IJSVGStringColorDodge;
extern NSString* const IJSVGStringColorBurn;
extern NSString* const IJSVGStringHardLight;
extern NSString* const IJSVGStringSoftLight;
extern NSString* const IJSVGStringDifference;
extern NSString* const IJSVGStringExclusion;
extern NSString* const IJSVGStringHue;
extern NSString* const IJSVGStringSaturation;
extern NSString* const IJSVGStringColor;
extern NSString* const IJSVGStringLuminosity;
extern NSString* const IJSVGStringMatrix;
extern NSString* const IJSVGStringSaturate;
extern NSString* const IJSVGStringHueRotate;
extern NSString* const IJSVGStringLuminanceToAlpha;
extern NSString* const IJSVGStringDilate;
extern NSString* const IJSVGStringOver;
extern NSString* const IJSVGStringIn;
extern NSString* const IJSVGStringOut;
extern NSString* const IJSVGStringAtop;
extern NSString* const IJSVGStringLighter;
extern NSString* const IJSVGStringXor;
extern NSString* const IJSVGStringArithmetic;
extern NSString* const IJSVGStringIdentity;
extern NSString* const IJSVGStringTable;
extern NSString* const IJSVGStringDiscrete;
extern NSString* const IJSVGStringLinear;
extern NSString* const IJSVGStringGamma;
extern NSString* const IJSVGStringTrue;
extern NSString* const IJSVGStringDuplicate;
extern NSString* const IJSVGStringWrap;
extern NSString* const IJSVGStringFractalNoise;
extern NSString* const IJSVGStringStitch;
extern NSString* const IJSVGStringBlack;
extern NSString* const IJSVGStringWhite;
extern NSString* const IJSVGStringSRGB;
extern NSString* const IJSVGStringLinearRGB;
extern NSString* const IJSVGStringSourceGraphic;
extern NSString* const IJSVGStringSourceAlpha;
extern NSString* const IJSVGStringBackgroundImage;
extern NSString* const IJSVGStringBackgroundAlpha;
extern NSString* const IJSVGStringFillPaint;
extern NSString* const IJSVGStringStrokePaint;
extern NSString* const IJSVGStringChannelR;
extern NSString* const IJSVGStringChannelG;
extern NSString* const IJSVGStringChannelB;
extern NSString* const IJSVGStringChannelA;

extern NSString* const IJSVGAttributeVersion;
extern NSString* const IJSVGAttributeXMLNS;
extern NSString* const IJSVGAttributeXMLNSXlink;
extern NSString* const IJSVGAttributeViewBox;
extern NSString* const IJSVGAttributePreserveAspectRatio;
extern NSString* const IJSVGAttributeID;
extern NSString* const IJSVGAttributeClass;
extern NSString* const IJSVGAttributeX;
extern NSString* const IJSVGAttributeY;
extern NSString* const IJSVGAttributeWidth;
extern NSString* const IJSVGAttributeHeight;
extern NSString* const IJSVGAttributeOpacity;
extern NSString* const IJSVGAttributeStrokeOpacity;
extern NSString* const IJSVGAttributeStrokeWidth;
extern NSString* const IJSVGAttributeStrokeDashOffset;
extern NSString* const IJSVGAttributeFillOpacity;
extern NSString* const IJSVGAttributeClipPath;
extern NSString* const IJSVGAttributeClipPathUnits;
extern NSString* const IJSVGAttributeClipRule;
extern NSString* const IJSVGAttributeMask;
extern NSString* const IJSVGAttributeGradientUnits;
extern NSString* const IJSVGAttributeSpreadMethod;
extern NSString* const IJSVGAttributePatternUnits;
extern NSString* const IJSVGAttributePatternContentUnits;
extern NSString* const IJSVGAttributePatternTransform;
extern NSString* const IJSVGAttributeMaskType;
extern NSString* const IJSVGAttributeMaskUnits;
extern NSString* const IJSVGAttributeMaskContentUnits;
extern NSString* const IJSVGAttributeTransform;
extern NSString* const IJSVGAttributeTransformOrigin;
extern NSString* const IJSVGAttributeTransformBox;
extern NSString* const IJSVGAttributeRequiredExtensions;
extern NSString* const IJSVGAttributeSystemLanguage;
extern NSString* const IJSVGAttributeGradientTransform;
extern NSString* const IJSVGAttributeUnicode;
extern NSString* const IJSVGAttributeStrokeLineCap;
extern NSString* const IJSVGAttributeStrokeLineJoin;
extern NSString* const IJSVGAttributeStroke;
extern NSString* const IJSVGAttributeStrokeDashArray;
extern NSString* const IJSVGAttributeStrokeMiterLimit;
extern NSString* const IJSVGAttributeFill;
extern NSString* const IJSVGAttributeFillRule;
extern NSString* const IJSVGAttributeBlendMode;
extern NSString* const IJSVGAttributeIsolation;
extern NSString* const IJSVGAttributePaintOrder;
extern NSString* const IJSVGAttributeVectorEffect;
extern NSString* const IJSVGAttributeColor;
extern NSString* const IJSVGAttributeVisibility;
extern NSString* const IJSVGAttributeDisplay;
extern NSString* const IJSVGAttributeStyle;
extern NSString* const IJSVGAttributeD;
extern NSString* const IJSVGAttributeXLink;
extern NSString* const IJSVGAttributeX1;
extern NSString* const IJSVGAttributeX2;
extern NSString* const IJSVGAttributeY1;
extern NSString* const IJSVGAttributeY2;
extern NSString* const IJSVGAttributeRX;
extern NSString* const IJSVGAttributeRY;
extern NSString* const IJSVGAttributeCX;
extern NSString* const IJSVGAttributeCY;
extern NSString* const IJSVGAttributeR;
extern NSString* const IJSVGAttributeFR;
extern NSString* const IJSVGAttributeFX;
extern NSString* const IJSVGAttributeFY;
extern NSString* const IJSVGAttributePoints;
extern NSString* const IJSVGAttributeOffset;
extern NSString* const IJSVGAttributeStopColor;
extern NSString* const IJSVGAttributeStopOpacity;
extern NSString* const IJSVGAttributeHref;
extern NSString* const IJSVGAttributeOverflow;
extern NSString* const IJSVGAttributeMarker;
extern NSString* const IJSVGAttributeMarkerStart;
extern NSString* const IJSVGAttributeMarkerMid;
extern NSString* const IJSVGAttributeMarkerEnd;
extern NSString* const IJSVGAttributeRefX;
extern NSString* const IJSVGAttributeRefY;
extern NSString* const IJSVGAttributeMarkerWidth;
extern NSString* const IJSVGAttributeMarkerHeight;
extern NSString* const IJSVGAttributeMarkerUnits;
extern NSString* const IJSVGAttributeOrient;
extern NSString* const IJSVGAttributeFilter;
extern NSString* const IJSVGAttributeFilterUnits;
extern NSString* const IJSVGAttributePrimitiveUnits;
extern NSString* const IJSVGAttributeDX;
extern NSString* const IJSVGAttributeDY;
extern NSString* const IJSVGAttributeStdDeviation;
extern NSString* const IJSVGAttributeFloodColor;
extern NSString* const IJSVGAttributeFloodOpacity;
extern NSString* const IJSVGAttributeIn;
extern NSString* const IJSVGAttributeResult;
extern NSString* const IJSVGAttributeIn2;
extern NSString* const IJSVGAttributeMode;
extern NSString* const IJSVGAttributeType;
extern NSString* const IJSVGAttributeValues;
extern NSString* const IJSVGAttributeOperator;
extern NSString* const IJSVGAttributeK1;
extern NSString* const IJSVGAttributeK2;
extern NSString* const IJSVGAttributeK3;
extern NSString* const IJSVGAttributeK4;
extern NSString* const IJSVGAttributeOrder;
extern NSString* const IJSVGAttributeKernelMatrix;
extern NSString* const IJSVGAttributeDivisor;
extern NSString* const IJSVGAttributeBias;
extern NSString* const IJSVGAttributeTargetX;
extern NSString* const IJSVGAttributeTargetY;
extern NSString* const IJSVGAttributeEdgeMode;
extern NSString* const IJSVGAttributeKernelUnitLength;
extern NSString* const IJSVGAttributePreserveAlpha;
extern NSString* const IJSVGAttributeSurfaceScale;
extern NSString* const IJSVGAttributeDiffuseConstant;
extern NSString* const IJSVGAttributeSpecularConstant;
extern NSString* const IJSVGAttributeSpecularExponent;
extern NSString* const IJSVGAttributeLightingColor;
extern NSString* const IJSVGAttributeScale;
extern NSString* const IJSVGAttributeXChannelSelector;
extern NSString* const IJSVGAttributeYChannelSelector;
extern NSString* const IJSVGAttributeRadius;
extern NSString* const IJSVGAttributeBaseFrequency;
extern NSString* const IJSVGAttributeNumOctaves;
extern NSString* const IJSVGAttributeSeed;
extern NSString* const IJSVGAttributeStitchTiles;
extern NSString* const IJSVGAttributeTableValues;
extern NSString* const IJSVGAttributeSlope;
extern NSString* const IJSVGAttributeIntercept;
extern NSString* const IJSVGAttributeAmplitude;
extern NSString* const IJSVGAttributeExponent;
extern NSString* const IJSVGAttributeAzimuth;
extern NSString* const IJSVGAttributeElevation;
extern NSString* const IJSVGAttributeZ;
extern NSString* const IJSVGAttributePointsAtX;
extern NSString* const IJSVGAttributePointsAtY;
extern NSString* const IJSVGAttributePointsAtZ;
extern NSString* const IJSVGAttributeLimitingConeAngle;
extern NSString* const IJSVGAttributeColorInterpolationFilters;
extern NSString* const IJSVGAttributeEnableBackground;

// SVG text presentation and positioning attributes.
extern NSString* const IJSVGAttributeFont;
extern NSString* const IJSVGAttributeFontFamily;
extern NSString* const IJSVGAttributeFontSize;
extern NSString* const IJSVGAttributeFontSizeAdjust;
extern NSString* const IJSVGAttributeFontWeight;
extern NSString* const IJSVGAttributeFontStyle;
extern NSString* const IJSVGAttributeFontStretch;
extern NSString* const IJSVGAttributeFontVariant;
extern NSString* const IJSVGAttributeFontVariantLigatures;
extern NSString* const IJSVGAttributeFontFeatureSettings;
extern NSString* const IJSVGAttributeFontKerning;
extern NSString* const IJSVGAttributeLetterSpacing;
extern NSString* const IJSVGAttributeWordSpacing;
extern NSString* const IJSVGAttributeTextAnchor;
extern NSString* const IJSVGAttributeDirection;
extern NSString* const IJSVGAttributeUnicodeBidi;
extern NSString* const IJSVGAttributeWritingMode;
extern NSString* const IJSVGAttributeTextOrientation;
extern NSString* const IJSVGAttributeDominantBaseline;
extern NSString* const IJSVGAttributeAlignmentBaseline;
extern NSString* const IJSVGAttributeBaselineShift;
extern NSString* const IJSVGAttributeTextDecoration;
extern NSString* const IJSVGAttributeTextDecorationLine;
extern NSString* const IJSVGAttributeWhiteSpace;
extern NSString* const IJSVGAttributeLineHeight;
extern NSString* const IJSVGAttributeInlineSize;
extern NSString* const IJSVGAttributeTextTransform;
extern NSString* const IJSVGAttributeTextOverflow;
extern NSString* const IJSVGAttributeXMLSpace;
extern NSString* const IJSVGAttributeLang;
extern NSString* const IJSVGAttributeXMLLang;
extern NSString* const IJSVGAttributeTextRendering;
extern NSString* const IJSVGAttributeRotate;
extern NSString* const IJSVGAttributeTextLength;
extern NSString* const IJSVGAttributeLengthAdjust;
extern NSString* const IJSVGAttributeStartOffset;
extern NSString* const IJSVGAttributeMethod;
extern NSString* const IJSVGAttributeSpacing;
extern NSString* const IJSVGAttributeSide;
extern NSString* const IJSVGAttributePath;
extern NSString* const IJSVGAttributePathLength;

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

- (nullable instancetype)initWithSVGString:(NSString*)string
                fileURL:(NSURL* _Nullable)fileURL
                  error:(NSError* _Nullable * _Nullable)error;
- (nullable instancetype)initWithSVGData:(NSData*)data
              fileURL:(NSURL* _Nullable)fileURL
                error:(NSError* _Nullable * _Nullable)error;

- (nullable instancetype)initWithFileURL:(NSURL*)aURL
                error:(NSError* _Nullable * _Nullable)error;
+ (nullable IJSVGParser*)parserForFileURL:(NSURL*)aURL;
+ (nullable IJSVGParser*)parserForFileURL:(NSURL*)aURL
                           error:(NSError* _Nullable * _Nullable)error;

- (IJSVGRootNode*)rootNodeWithSize:(CGSize)size;

@end

NS_ASSUME_NONNULL_END
