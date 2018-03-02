//
//  IJSVGParser.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGForeignObject.h"
#import "IJSVGGroup.h"
#import "IJSVGPath.h"
#import "IJSVGUtils.h"
#import "IJSVGCommand.h"
#import "IJSVGColor.h"
#import "IJSVGTransform.h"
#import "IJSVGDef.h"
#import "IJSVGLinearGradient.h"
#import "IJSVGRadialGradient.h"
#import "IJSVGError.h"
#import "IJSVGStyleSheet.h"
#import "IJSVGPattern.h"
#import "IJSVGImage.h"
#import "IJSVGText.h"

static NSString const * IJSVGAttributeViewBox = @"viewBox";
static NSString const * IJSVGAttributeID = @"id";
static NSString const * IJSVGAttributeClass = @"class";
static NSString const * IJSVGAttributeX = @"x";
static NSString const * IJSVGAttributeY = @"y";
static NSString const * IJSVGAttributeWidth = @"width";
static NSString const * IJSVGAttributeHeight = @"height";
static NSString const * IJSVGAttributeOpacity = @"opacity";
static NSString const * IJSVGAttributeStrokeOpacity = @"stroke-opacity";
static NSString const * IJSVGAttributeStrokeWidth = @"stroke-width";
static NSString const * IJSVGAttributeStrokeDashOffset = @"stroke-dashoffset";
static NSString const * IJSVGAttributeFillOpacity = @"fill-opacity";
static NSString const * IJSVGAttributeClipPath = @"clip-path";
static NSString const * IJSVGAttributeMask = @"mask";
static NSString const * IJSVGAttributeGradientUnits = @"gradientUnits";
static NSString const * IJSVGAttributeMaskUnits = @"maskUnits";
static NSString const * IJSVGAttributeMaskContentUnits = @"maskContentUnits";
static NSString const * IJSVGAttributeTransform = @"transform";
static NSString const * IJSVGAttributeGradientTransform = @"gradientTransform";
static NSString const * IJSVGAttributeUnicode = @"unicode";
static NSString const * IJSVGAttributeStrokeLineCap = @"stroke-linecap";
static NSString const * IJSVGAttributeLineJoin = @"stroke-linejoin";
static NSString const * IJSVGAttributeStroke = @"stroke";
static NSString const * IJSVGAttributeStrokeDashArray = @"stroke-dasharray";
static NSString const * IJSVGAttributeFill = @"fill";
static NSString const * IJSVGAttributeFillRule = @"fill-rule";
static NSString const * IJSVGAttributeBlendMode = @"mix-blend-mode";
static NSString const * IJSVGAttributeDisplay = @"display";
static NSString const * IJSVGAttributeStyle = @"style";
static NSString const * IJSVGAttributeD = @"d";
static NSString const * IJSVGAttributeXLink = @"xlink:href";
static NSString const * IJSVGAttributeX1 = @"x1";
static NSString const * IJSVGAttributeX2 = @"x2";
static NSString const * IJSVGAttributeY1 = @"y1";
static NSString const * IJSVGAttributeY2 = @"y2";
static NSString const * IJSVGAttributeRX = @"rx";
static NSString const * IJSVGAttributeRY = @"ry";
static NSString const * IJSVGAttributeCX = @"cx";
static NSString const * IJSVGAttributeCY = @"cy";
static NSString const * IJSVGAttributeR = @"r";
static NSString const * IJSVGAttributePoints = @"points";

@class IJSVGParser;

@protocol IJSVGParserDelegate <NSObject>

@optional
- (BOOL)svgParser:(IJSVGParser *)svg
shouldHandleForeignObject:(IJSVGForeignObject *)foreignObject;
- (void)svgParser:(IJSVGParser *)svg
handleForeignObject:(IJSVGForeignObject *)foreignObject
   document:(NSXMLDocument *)document;
- (void)svgParser:(IJSVGParser *)svg
      foundSubSVG:(IJSVG *)subSVG
    withSVGString:(NSString *)string;

@end

@interface IJSVGParser : IJSVGGroup {
    
    NSRect viewBox;
    NSSize proposedViewSize;
    
@private
    id<IJSVGParserDelegate> _delegate;
    NSXMLDocument * _document;
    NSMutableArray * _glyphs;
    IJSVGStyleSheet * _styleSheet;
    NSMutableArray * _parsedNodes;
    NSMutableDictionary * _defNodes;
    NSMutableDictionary * _baseDefNodes;
    NSMutableArray<IJSVG *> * _svgs;
    NSMutableArray * _definedGroups;
    
    struct {
        unsigned int shouldHandleForeignObject: 1;
        unsigned int handleForeignObject: 1;
        unsigned int handleSubSVG: 1;
    } _respondsTo;
}

@property ( nonatomic, readonly ) NSRect viewBox;
@property ( nonatomic, readonly ) NSSize proposedViewSize;

- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error
               delegate:(id<IJSVGParserDelegate>)delegate;

- (id)initWithFileURL:(NSURL *)aURL
                error:(NSError **)error
             delegate:(id<IJSVGParserDelegate>)delegate;
+ (IJSVGParser *)groupForFileURL:(NSURL *)aURL;
+ (IJSVGParser *)groupForFileURL:(NSURL *)aURL
                        delegate:(id<IJSVGParserDelegate>)delegate;
+ (IJSVGParser *)groupForFileURL:(NSURL *)aURL
                           error:(NSError **)error
                        delegate:(id<IJSVGParserDelegate>)delegate;
- (NSSize)size;
- (BOOL)isFont;
- (NSArray *)glyphs;
- (NSArray<IJSVG *> *)subSVGs:(BOOL)recursive;

@end
