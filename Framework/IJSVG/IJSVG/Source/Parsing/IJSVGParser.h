//
//  IJSVGParser.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGCommand.h>
#import <IJSVG/IJSVGDef.h>
#import <IJSVG/IJSVGError.h>
#import <IJSVG/IJSVGForeignObject.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGColorNode.h>
#import <IJSVG/IJSVGImage.h>
#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGPattern.h>
#import <IJSVG/IJSVGRadialGradient.h>
#import <IJSVG/IJSVGStyleSheet.h>
#import <IJSVG/IJSVGText.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGUtils.h>
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
extern NSString* const IJSVGAttributePatternContentUnits;
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
extern NSString* const IJSVGAttributeHref;
extern NSString* const IJSVGAttributeOverflow;


@class IJSVGParser;

@protocol IJSVGParserDelegate <NSObject>

@optional
- (void)svgParser:(IJSVGParser*)svg
      foundSubSVG:(IJSVG*)subSVG
    withSVGString:(NSString*)string;

@end

@interface IJSVGParser : NSObject {

@private
    id<IJSVGParserDelegate> _delegate;
    NSXMLDocument* _document;

    struct {
        unsigned int handleSubSVG : 1;
    } _respondsTo;

    IJSVGPathDataStream* _commandDataStream;
    IJSVGStyleSheet* _styleSheet;
    NSMapTable<IJSVGNode*, NSMutableDictionary<NSString*, NSXMLElement*>*>* _detachedElements;
}

@property (nonatomic, retain, readonly) IJSVGRootNode* rootNode;

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

@end
