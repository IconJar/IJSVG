//
//  IJSVGDescriptionNode.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGDescriptionNode.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGDescriptionNode

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeDesc;
}

@end

#pragma mark - Parsing

@implementation IJSVGDescriptionNode (Parsing)

+ (void)consumeElement:(NSXMLElement*)element parentNode:(IJSVGNode*)parentNode
{
    parentNode.desc = element.stringValue;
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
