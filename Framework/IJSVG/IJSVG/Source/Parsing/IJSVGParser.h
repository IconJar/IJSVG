//
//  IJSVGParser.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGColor.h"
#import "IJSVGCommand.h"
#import "IJSVGDef.h"
#import "IJSVGError.h"
#import "IJSVGForeignObject.h"
#import "IJSVGGroup.h"
#import "IJSVGImage.h"
#import "IJSVGLinearGradient.h"
#import "IJSVGPath.h"
#import "IJSVGPattern.h"
#import "IJSVGRadialGradient.h"
#import "IJSVGStyleSheet.h"
#import "IJSVGText.h"
#import "IJSVGTransform.h"
#import "IJSVGUnitRect.h"
#import "IJSVGUtils.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

extern NSString* const IJSVGAttributeViewBox;
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
extern NSString* const IJSVGAttributeMask;
extern NSString* const IJSVGAttributeGradientUnits;
extern NSString* const IJSVGAttributeMaskUnits;
extern NSString* const IJSVGAttributeMaskContentUnits;
extern NSString* const IJSVGAttributeTransform;
extern NSString* const IJSVGAttributeGradientTransform;
extern NSString* const IJSVGAttributeUnicode;
extern NSString* const IJSVGAttributeStrokeLineCap;
extern NSString* const IJSVGAttributeLineJoin;
extern NSString* const IJSVGAttributeStroke;
extern NSString* const IJSVGAttributeStrokeDashArray;
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
extern NSString* const IJSVGAttributeFX;
extern NSString* const IJSVGAttributeFY;
extern NSString* const IJSVGAttributePoints;
extern NSString* const IJSVGAttributeOffset;
extern NSString* const IJSVGAttributeStopColor;
extern NSString* const IJSVGAttributeStopOpacity;


@class IJSVGParser;

@protocol IJSVGParserDelegate <NSObject>

@optional
- (BOOL)svgParser:(IJSVGParser*)svg
    shouldHandleForeignObject:(IJSVGForeignObject*)foreignObject;
- (void)svgParser:(IJSVGParser*)svg
    handleForeignObject:(IJSVGForeignObject*)foreignObject
               document:(NSXMLDocument*)document;
- (void)svgParser:(IJSVGParser*)svg
      foundSubSVG:(IJSVG*)subSVG
    withSVGString:(NSString*)string;

@end

@interface IJSVGParser : IJSVGGroup {

@private
    id<IJSVGParserDelegate> _delegate;
    NSXMLDocument* _document;
    NSMutableArray<IJSVGNode*>* _glyphs;
    IJSVGStyleSheet* _styleSheet;
    NSMutableDictionary<NSString*, NSXMLElement*>* _defNodes;
    NSMutableDictionary<NSString*, NSXMLElement*>* _baseDefNodes;
    NSMutableArray<IJSVG*>* _svgs;

    struct {
        unsigned int shouldHandleForeignObject : 1;
        unsigned int handleForeignObject : 1;
        unsigned int handleSubSVG : 1;
    } _respondsTo;

    IJSVGPathDataStream* _commandDataStream;
}

@property (nonatomic, readonly) NSRect viewBox;
@property (nonatomic, readonly) IJSVGUnitSize* intrinsicSize;

+ (BOOL)isDataSVG:(NSData*)data;

- (id)initWithSVGString:(NSString*)string
                  error:(NSError**)error
               delegate:(id<IJSVGParserDelegate>)delegate;

- (id)initWithFileURL:(NSURL*)aURL
                error:(NSError**)error
             delegate:(id<IJSVGParserDelegate>)delegate;
+ (IJSVGParser*)groupForFileURL:(NSURL*)aURL;
+ (IJSVGParser*)groupForFileURL:(NSURL*)aURL
                       delegate:(id<IJSVGParserDelegate>)delegate;
+ (IJSVGParser*)groupForFileURL:(NSURL*)aURL
                          error:(NSError**)error
                       delegate:(id<IJSVGParserDelegate>)delegate;
- (NSSize)size;
- (BOOL)isFont;
- (NSArray*)glyphs;
- (NSArray<IJSVG*>*)subSVGs:(BOOL)recursive;

@end
