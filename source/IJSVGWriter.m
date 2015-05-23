//
//  IJSVGWriter.m
//  IJSVGExample
//
//  Created by Curtis Hard on 21/05/2015.
//  Copyright (c) 2015 Curtis Hard. All rights reserved.
//

#import "IJSVGWriter.h"

@implementation IJSVGWriter

+ (NSString *)SVGDocumentStringForSVGGlyph:(IJSVGPath *)node
{
    NSBezierPath * path = [node path];
    // we need to flip it
    NSAffineTransform * trans = [NSAffineTransform transform];
    [trans scaleXBy:1.f yBy:-1.f];
    [trans translateXBy:0.f yBy:path.controlPointBounds.size.height];
    path = [trans transformBezierPath:path];
    return [[self class] SVGDocumentStringForBezierPath:path];
}

+ (NSString *)SVGDocumentStringForBezierPath:(NSBezierPath *)path
{
    return [[self class] SVGDocumentForBezierPath:path].XMLString;
}

+ (NSXMLDocument *)SVGDocumentForBezierPath:(NSBezierPath *)path
{
    NSXMLElement * root = [[self class] rootElementForPath:path];
    
    // create the path data
    NSXMLElement * p = [[[NSXMLElement alloc] initWithName:@"path"] autorelease];
    
    // add the drawing command
    NSXMLNode * n = [[[NSXMLNode alloc] initWithKind:NSXMLAttributeKind] autorelease];
    [n setName:@"d"];
    [n setStringValue:[[self class] SVGPathStringForBezierPath:path]];
    [p addAttribute:n];
    
    // add the drawing path to the root
    [root addChild:p];
    return [[[NSXMLDocument alloc] initWithRootElement:root] autorelease];
}

+ (NSXMLElement *)rootElementForPath:(NSBezierPath *)path
{
    NSXMLElement * element = [[[NSXMLElement alloc] initWithName:@"svg"] autorelease];
    NSRect bounds = path.controlPointBounds;
    
    // width
    NSXMLNode * att = [[[NSXMLNode alloc] initWithKind:NSXMLAttributeKind] autorelease];
    [att setName:@"width"];
    [att setStringValue:[NSString stringWithFormat:@"%f",bounds.size.width]];
    [element addAttribute:att];
    
    // height
    att = [[[NSXMLNode alloc] initWithKind:NSXMLAttributeKind] autorelease];
    [att setName:@"height"];
    [att setStringValue:[NSString stringWithFormat:@"%f",bounds.size.height]];
    [element addAttribute:att];
    
    // viewbox
    att = [[[NSXMLNode alloc] initWithKind:NSXMLAttributeKind] autorelease];
    [att setName:@"viewBox"];
    [att setStringValue:[NSString stringWithFormat:@"%f %f %f %f",bounds.origin.x,bounds.origin.y,bounds.size.width,bounds.size.height]];
    [element addAttribute:att];
    
    // namespace
    att = [[[NSXMLNode alloc] initWithKind:NSXMLAttributeKind] autorelease];
    [att setName:@"xmlns"];
    [att setStringValue:@"http://www.w3.org/2000/svg"];
    [element addAttribute:att];
    return element;
}

+ (NSString *)SVGPathStringForBezierPath:(NSBezierPath *)path
{
    NSMutableString * str = [[[NSMutableString alloc] init] autorelease];
    for( NSInteger i = 0; i < path.elementCount; i++ )
    {
        NSBezierPathElement element = [path elementAtIndex:i];
        switch( element )
        {
            // move
            case NSMoveToBezierPathElement:
            {
                NSPoint points[1];
                [path elementAtIndex:i associatedPoints:points];
                [str appendFormat:@"M%f %f",points[0].x,points[0].y];
                break;
            }
            // line
            case NSLineToBezierPathElement:
            {
                NSPoint points[1];
                [path elementAtIndex:i associatedPoints:points];
                [str appendFormat:@"L%f %f",points[0].x,points[0].y];
                break;
            }
            // curve
            case NSCurveToBezierPathElement:
            {
                NSPoint points[3];
                [path elementAtIndex:i associatedPoints:points];
                [str appendFormat:@"C%f %f %f %f %f %f",points[0].x,points[0].y,points[1].x,points[1].y,points[2].x,points[2].y];
                break;
            }
            // close
            case NSClosePathBezierPathElement:
            {
                [str appendFormat:@"Z"];
                break;
            }
        }
    }
    return str;
}

@end
