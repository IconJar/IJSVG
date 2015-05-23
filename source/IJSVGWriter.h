//
//  IJSVGWriter.h
//  IJSVGExample
//
//  Created by Curtis Hard on 21/05/2015.
//  Copyright (c) 2015 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGPath.h"

@interface IJSVGWriter : NSObject {
    
}

+ (NSString *)SVGDocumentStringForSVGGlyph:(IJSVGPath *)node;
+ (NSString *)SVGDocumentStringForBezierPath:(NSBezierPath *)path;
+ (NSXMLDocument *)SVGDocumentForBezierPath:(NSBezierPath *)path;

@end
