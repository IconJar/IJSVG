//
//  IJSVGTitleNode.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import <IJSVG/IJSVGTitleNode.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGTitleNode

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeTitle;
}

@end

#pragma mark - Parsing

@implementation IJSVGTitleNode (Parsing)

+ (void)consumeElement:(IJSVGXMLNode*)element parentNode:(IJSVGNode*)parentNode
{
    parentNode.title = IJSVGXMLText(element);
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
