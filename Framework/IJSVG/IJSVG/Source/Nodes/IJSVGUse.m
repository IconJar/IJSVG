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

static BOOL IJSVGUseConsumesPaintOnlyAttribute(NSUInteger attribute)
{
    switch (attribute) {
        case IJSVGNodeAttributeID:
        case IJSVGNodeAttributeClass:
        case IJSVGNodeAttributeStyle:
        case IJSVGNodeAttributeHref:
        case IJSVGNodeAttributeXLink:
        case IJSVGNodeAttributeFill:
        case IJSVGNodeAttributeFillOpacity:
        case IJSVGNodeAttributeStroke:
        case IJSVGNodeAttributeStrokeWidth:
        case IJSVGNodeAttributeStrokeLineCap:
        case IJSVGNodeAttributeStrokeLineJoin:
        case IJSVGNodeAttributeFilter:
        case IJSVGNodeAttributeMask:
        case IJSVGNodeAttributeClipPath:
            return YES;
        default:
            return NO;
    }
}

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

    // The cascade has already resolved selectors, variables and inheritance.
    // Common mesh uses contain only paint/effect declarations. Skip unrelated
    // text, geometry and transform consumers without caching resolved styles.
    BOOL paintOnly = context->textAttributes == 0 && !context->style.hasGeometryProperties && !context->inlineStyle.hasGeometryProperties;
    for (NSUInteger index = 0; paintOnly && index < kIJSVGNodeAttributeStorageLength; index++) {
        if (context->values[index] == nil) {
            continue;
        }
        paintOnly = IJSVGUseConsumesPaintOnlyAttribute(index);
    }

    // CSS geometry and transforms can live outside the presentation value array.
    IJSVGStyleSheetStyle* declarations[] = { context->style, context->inlineStyle };
    for (NSUInteger source = 0; paintOnly && source < 2; source++) {
        NSUInteger count = 0;
        const IJSVGStyleSheetAttribute* entries = [declarations[source] attributesWithCount:&count];
        for (NSUInteger index = 0; paintOnly && index < count; index++) {
            paintOnly = IJSVGUseConsumesPaintOnlyAttribute(entries[index].attribute);
        }
    }

    if (paintOnly) {
        IJSVGParsePaintAttributes(self, context);
        IJSVGParseEffectsAttributes(self, context);
        return;
    }
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
