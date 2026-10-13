//
//  IJSVGMask.m
//  IJSVG
//
//  Created by Curtis Hard on 28/05/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGMask.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGMask

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeMask;
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
    [storage addBits:[super allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeX];
    [storage setBit:IJSVGNodeAttributeY];
    [storage setBit:IJSVGNodeAttributeWidth];
    [storage setBit:IJSVGNodeAttributeHeight];
    [storage setBit:IJSVGNodeAttributeMaskType];
    [storage setBit:IJSVGNodeAttributeMaskUnits];
    [storage setBit:IJSVGNodeAttributeMaskContentUnits];
    return storage;
}

// Sets the SVG mask region and coordinate system defaults.
- (void)setDefaults
{
    [super setDefaults];
    self.x = IJSVGNegativeTenPercentageUnitLength;
    self.y = IJSVGNegativeTenPercentageUnitLength;
    self.width = IJSVGOneHundredTwentyPercentageUnitLength;
    self.height = IJSVGOneHundredTwentyPercentageUnitLength;
    self.units = IJSVGUnitObjectBoundingBox;
    self.contentUnits = IJSVGUnitUserSpaceOnUse;
    self.overflowVisibility = IJSVGOverflowVisibilityHidden;
}

- (void)applyPropertiesFromNode:(IJSVGNode*)node
{
    [super applyPropertiesFromNode:node];
    if ([node isKindOfClass:IJSVGMask.class]) {
        self.maskType = ((IJSVGMask*)node).maskType;
    }
}

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds
{
    IJSVGGraphicsNode* node = nil;
    IJSVGUnitType units = [self contentUnitsWithReferencingNode:&node];
    if (units == IJSVGUnitUserSpaceOnUse) {
        *bounds = node.rootNode.bounds;
    } else {
        *bounds = node.parentNode.bounds;
    }
    return units;
}

@end

#pragma mark - Parsing

@implementation IJSVGMask (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeX];
    [attributes setBit:IJSVGNodeAttributeY];
    [attributes setBit:IJSVGNodeAttributeWidth];
    [attributes setBit:IJSVGNodeAttributeHeight];
    [attributes setBit:IJSVGNodeAttributeMaskType];
    [attributes setBit:IJSVGNodeAttributeMaskUnits];
    [attributes setBit:IJSVGNodeAttributeMaskContentUnits];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
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
    if (IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeWidth, &geometryValue)) {
        IJSVGUnitLength* length = IJSVGDimensionFromString(geometryValue, self.type);
        if (length != nil) {
            self.width = length;
        }
    }
    if (IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeHeight, &geometryValue)) {
        IJSVGUnitLength* length = IJSVGDimensionFromString(geometryValue, self.type);
        if (length != nil) {
            self.height = length;
        }
    }
    IJSVGParseBackgroundAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    IJSVGParsePaintAttributes(self, context);
    IJSVGParseEffectsAttributes(self, context);
    IJSVGParseTransformAttributes(self, context);
    IJSVGParseDisplayAttributes(self, context);
    IJSVGParseOverflowAttributes(self, context);
    IJSVGParseMarkersAttributes(self, context);
    IJSVGParseMaskAttributes(self, context);
}

@end
