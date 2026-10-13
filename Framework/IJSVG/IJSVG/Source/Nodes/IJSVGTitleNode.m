//
//  IJSVGTitleNode.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

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

+ (void)consumeElement:(NSXMLElement*)element parentNode:(IJSVGNode*)parentNode
{
    parentNode.title = element.stringValue;
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
