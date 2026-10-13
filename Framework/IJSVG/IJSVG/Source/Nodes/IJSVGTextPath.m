//
//  IJSVGTextPath.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTextPath.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGTextPath

- (void)applyPropertiesFromNode:(IJSVGTextPath*)node
{
    [super applyPropertiesFromNode:node];
    self.reference = node.reference;
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeTextPath;
}

@end

#pragma mark - Parsing

@implementation IJSVGTextPath (Parsing)

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
    [attributes setBit:IJSVGNodeAttributeStartOffset];
    [attributes setBit:IJSVGNodeAttributeMethod];
    [attributes setBit:IJSVGNodeAttributeSpacing];
    [attributes setBit:IJSVGNodeAttributeSide];
    [attributes setBit:IJSVGNodeAttributePath];
    [attributes setBit:IJSVGNodeAttributePathLength];
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
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeStartOffset, IJSVGAttributeStartOffset, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeMethod, IJSVGAttributeMethod, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeSpacing, IJSVGAttributeSpacing, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeSide, IJSVGAttributeSide, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributePath, IJSVGAttributePath, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributePathLength, IJSVGAttributePathLength, &positioning);
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
