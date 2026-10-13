//
//  IJSVGStyleNode.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleNode.h>
#import <IJSVGNodeParsing.h>
#import <IJSVGStyleSheetUtils.h>

@implementation IJSVGStyleNode

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeStyle;
}

@end

#pragma mark - Parsing

@implementation IJSVGStyleNode (Parsing)

+ (BOOL)consumeElement:(NSXMLElement*)element rootElement:(NSXMLElement*)rootElement viewport:(CGSize)viewport styleSheet:(IJSVGStyleSheet*)styleSheet
{
    NSString* media = [element attributeForName:IJSVGAttributeMedia].stringValue;
    if (media.length != 0) {
        NSString* width = [rootElement attributeForName:IJSVGAttributeWidth].stringValue;
        NSString* height = [rootElement attributeForName:IJSVGAttributeHeight].stringValue;
        if (width != nil) {
            viewport.width = [[IJSVGUnitLength unitWithString:width] computeValue:viewport.width];
        }
        if (height != nil) {
            viewport.height = [[IJSVGUnitLength unitWithString:height] computeValue:viewport.height];
        }
        IJSVGMediaEnvironment environment = { viewport, IJSVGMediaTypeScreen };
        IJSVGMediaQuery* query = IJSVGMediaQueryCreate(media);
        BOOL matches = IJSVGMediaQueryMatches(query, environment);
        IJSVGMediaQueryRelease(query);
        if (!matches) {
            return NO;
        }
    }
    [styleSheet parseStyleBlock:element.stringValue];
    return YES;
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
}

@end
