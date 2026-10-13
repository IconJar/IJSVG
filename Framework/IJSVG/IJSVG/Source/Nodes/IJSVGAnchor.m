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

#pragma mark - Parsing

@implementation IJSVGAnchor (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeX];
    [attributes setBit:IJSVGNodeAttributeY];
    [attributes setBit:IJSVGNodeAttributeDX];
    [attributes setBit:IJSVGNodeAttributeDY];
    [attributes setBit:IJSVGNodeAttributeRotate];
    [attributes setBit:IJSVGNodeAttributeTextLength];
    [attributes setBit:IJSVGNodeAttributeLengthAdjust];
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
    NSMutableDictionary<NSString*, IJSVGTextAttributeValue*>* positioning = nil;
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeX, IJSVGAttributeX, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeY, IJSVGAttributeY, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeDX, IJSVGAttributeDX, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeDY, IJSVGAttributeDY, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeRotate, IJSVGAttributeRotate, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeTextLength, IJSVGAttributeTextLength, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeLengthAdjust, IJSVGAttributeLengthAdjust, &positioning);
    self.positioning = positioning ?: @{};
    NSString* geometryValue = nil;
    if (IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeX, &geometryValue)) {
        self.x = [IJSVGUnitLength unitWithString:geometryValue];
    }
    if (IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeY, &geometryValue)) {
        self.y = [IJSVGUnitLength unitWithString:geometryValue];
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
