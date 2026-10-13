//
//  IJSVGUse.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUse.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGUse

- (void)applyPropertiesFromNode:(IJSVGUse*)node
{
    [super applyPropertiesFromNode:node];
    self.reference = node.reference;
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeUse;
}

@end

#pragma mark - Parsing

@implementation IJSVGUse (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeWidth];
    [attributes setBit:IJSVGNodeAttributeHeight];
    [attributes setBit:IJSVGNodeAttributeHref];
    [attributes setBit:IJSVGNodeAttributeXLink];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    self.reference = context->reference;
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
    IJSVGParsePathAttributes(self, context);
    IJSVGUnitLength* geometryLength = nil;
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeX, &geometryLength)) {
        self.x = geometryLength;
    }
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeY, &geometryLength)) {
        self.y = geometryLength;
    }
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeWidth, &geometryLength)) {
        self.width = geometryLength;
    }
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeHeight, &geometryLength)) {
        self.height = geometryLength;
    }
    IJSVGParseBackgroundAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    IJSVGParsePaintAttributes(self, context);
    IJSVGParseEffectsAttributes(self, context);
    IJSVGParseTransformAttributes(self, context);
    IJSVGParseDisplayAttributes(self, context);
    IJSVGParseOverflowAttributes(self, context);
    IJSVGParseMarkersAttributes(self, context);
}

@end
