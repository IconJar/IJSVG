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
    
@private
    id<IJSVGParserDelegate> _delegate;
    NSXMLDocument * _document;
    
}

@property ( nonatomic, readonly ) NSRect viewBox;

- (id)initWithFileURL:(NSURL *)aURL
             delegate:(id<IJSVGParserDelegate>)delegate;
- (id)initWithFileURL:(NSURL *)aURL
             encoding:(NSStringEncoding)encoding
             delegate:(id<IJSVGParserDelegate>)delegate;;
+ (IJSVGParser *)groupForFileURL:(NSURL *)aURL;
+ (IJSVGParser *)groupForFileURL:(NSURL *)aURL
                        delegate:(id<IJSVGParserDelegate>)delegate;
- (NSSize)size;

@end
