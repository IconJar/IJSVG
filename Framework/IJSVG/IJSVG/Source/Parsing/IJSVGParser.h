//
//  IJSVGParser.h
//  IconJar
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
#import <IJSVG/IJSVGClipPath.h>
#import <IJSVG/IJSVGRadialGradient.h>
#import <IJSVG/IJSVGStyleSheet.h>
#import <IJSVG/IJSVGText.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGFilterEffect.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

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
extern NSString* const IJSVGAttributePatternUnits;
extern NSString* const IJSVGAttributePatternContentUnits;
extern NSString* const IJSVGAttributePatternTransform;
extern NSString* const IJSVGAttributeMaskUnits;
extern NSString* const IJSVGAttributeMaskContentUnits;
extern NSString* const IJSVGAttributeTransform;
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
extern NSString* const IJSVGAttributeFilter;
extern NSString* const IJSVGAttributeStdDeviation;
extern NSString* const IJSVGAttributeIn;
extern NSString* const IJSVGAttributeEdgeMode;
extern NSString* const IJSVGAttributeMarker;


@class IJSVGParser;
@class IJSVGThreadManager;

typedef struct {
    char* nodeType;
} IJSVGParserMallocBuffers;

IJSVGParserMallocBuffers* IJSVGParserMallocBuffersCreate(void);
void IJSVGParserMallocBuffersFree(IJSVGParserMallocBuffers* buffers);

@interface IJSVGParser : NSObject {

@private
    NSXMLDocument* _document;
    IJSVGPathDataStream* _commandDataStream;
    IJSVGStyleSheet* _styleSheet;
    NSMutableDictionary<NSString*, NSXMLElement*>* _detachedReferences;
    IJSVGThreadManager* _threadManager;
    CGSize _rootSize;
    IJSVGRootNode* _rootNode;
}

@property (nonatomic, assign) CGSize defaultSize;

+ (BOOL)isDataSVG:(NSData*)data;

- (id)initWithSVGString:(NSString*)string
                  error:(NSError**)error;

- (id)initWithFileURL:(NSURL*)aURL
                error:(NSError**)error;
+ (IJSVGParser*)parserForFileURL:(NSURL*)aURL;
+ (IJSVGParser*)parserForFileURL:(NSURL*)aURL
                           error:(NSError**)error;

- (IJSVGRootNode*)rootNodeWithSize:(CGSize)size;

@end
