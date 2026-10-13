//
//  IJSVGTextSpan.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTextSpan.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGTextSpan

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeTextSpan;
}

@end

#pragma mark - Parsing

@implementation IJSVGTextSpan (Parsing)

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
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
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
