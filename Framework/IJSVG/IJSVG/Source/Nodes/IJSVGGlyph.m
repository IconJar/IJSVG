//
//  IJSVGGlyph.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGlyph.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGGlyph

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeGlyph;
}

- (void)applyPropertiesFromNode:(IJSVGNode*)source
{
    [super applyPropertiesFromNode:source];
    if ([source isKindOfClass:IJSVGGlyph.class]) {
        self.unicode = ((IJSVGGlyph*)source).unicode.copy;
    }
}

@end

#pragma mark - Parsing

@implementation IJSVGGlyph (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeUnicode];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    self.unicode = IJSVGAttributeValue(context->values, IJSVGNodeAttributeUnicode);
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
    IJSVGParsePathAttributes(self, context);
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
