//
//  IJSVGAnchor.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGAnchor.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGAnchor

- (void)applyPropertiesFromNode:(IJSVGAnchor*)node
{
    [super applyPropertiesFromNode:node];
    self.reference = node.reference;
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeAnchor;
}

@end

@implementation IJSVGAnchor (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeHref];
    [attributes setBit:IJSVGNodeAttributeXLink];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    [super consumeAttributes:context];
    self.reference = context->reference;
}

@end

@implementation IJSVGTextAnchor

- (void)applyPropertiesFromNode:(IJSVGTextAnchor*)node
{
    [super applyPropertiesFromNode:node];
    self.reference = node.reference;
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeAnchor;
}

@end

@implementation IJSVGTextAnchor (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeHref];
    [attributes setBit:IJSVGNodeAttributeXLink];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    [super consumeAttributes:context];
    self.reference = context->reference;
}

@end
