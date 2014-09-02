//
//  IJSVGParser.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGGroup.h"
#import "IJSVGPath.h"
#import "IJSVGUtils.h"
#import "IJSVGCommand.h"
#import "IJSVGColor.h"
#import "IJSVGTransform.h"

@interface IJSVGParser : IJSVGGroup {
    
    NSRect viewBox;
    
@private
    NSXMLDocument * _document;
    
}

@property ( nonatomic, readonly ) NSRect viewBox;

- (id)initWithFileURL:(NSURL *)aURL;
- (id)initWithFileURL:(NSURL *)aURL
             encoding:(NSStringEncoding)encoding;
+ (IJSVGParser *)groupForFileURL:(NSURL *)aURL;
- (NSSize)size;

@end
