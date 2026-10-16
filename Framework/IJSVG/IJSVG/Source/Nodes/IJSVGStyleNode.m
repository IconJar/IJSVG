//
//  IJSVGStyleNode.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
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

+ (BOOL)consumeElement:(IJSVGXMLNode*)element rootElement:(IJSVGXMLNode*)rootElement viewport:(CGSize)viewport styleSheet:(IJSVGStyleSheet*)styleSheet
{
    NSString* media = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(element, IJSVGNodeAttributeMedia));
    NSString* width = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(rootElement, IJSVGNodeAttributeWidth));
    NSString* height = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(rootElement, IJSVGNodeAttributeHeight));
    if (width != nil) {
        viewport.width = [[IJSVGUnitLength unitWithString:width] computeValue:viewport.width];
    }
    if (height != nil) {
        viewport.height = [[IJSVGUnitLength unitWithString:height] computeValue:viewport.height];
    }
    if (media.length != 0) {
        IJSVGMediaEnvironment environment = { viewport, IJSVGMediaTypeScreen };
        IJSVGMediaQuery* query = IJSVGMediaQueryCreate(media);
        BOOL matches = IJSVGMediaQueryMatches(query, environment);
        IJSVGMediaQueryRelease(query);
        if (!matches) {
            return NO;
        }
    }
    [styleSheet parseStyleBlock:IJSVGXMLText(element) viewport:viewport];
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
