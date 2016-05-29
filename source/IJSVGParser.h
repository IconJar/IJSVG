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

@class IJSVGParser;

@protocol IJSVGParserDelegate <NSObject>

@optional
- (BOOL)svgParser:(IJSVGParser *)svg
shouldHandleForeignObject:(IJSVGForeignObject *)foreignObject;
- (void)svgParser:(IJSVGParser *)svg
handleForeignObject:(IJSVGForeignObject *)foreignObject
   document:(NSXMLDocument *)document;

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
}

@property ( nonatomic, readonly ) NSRect viewBox;
@property ( nonatomic, readonly ) NSSize proposedViewSize;

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

@end
