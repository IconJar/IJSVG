//
//  IJSVGLine.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLine.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGLine

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeLine;
}

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        self.primitiveType = kIJSVGPrimitivePathTypeLine;
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGLine* node = [super copyWithZone:zone];
    node.x1 = _x1.copy;
    node.y1 = _y1.copy;
    node.x2 = _x2.copy;
    node.y2 = _y2.copy;
    return node;
}

- (BOOL)containsRelativeUnits
{
    return _x1.isRelativeUnit || _y1.isRelativeUnit || _x2.isRelativeUnit || _y2.isRelativeUnit || [super containsRelativeUnits];
}

@end

#pragma mark - Parsing

@implementation IJSVGLine (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGGraphicsAttributes();
    [attributes setBit:IJSVGNodeAttributeX1];
    [attributes setBit:IJSVGNodeAttributeY1];
    [attributes setBit:IJSVGNodeAttributeX2];
    [attributes setBit:IJSVGNodeAttributeY2];
    [attributes setBit:IJSVGNodeAttributePathLength];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
    IJSVGParsePathLengthAttributes(self, context);
    IJSVGParseBackgroundAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    IJSVGParsePaintAttributes(self, context);
    IJSVGParseEffectsAttributes(self, context);
    IJSVGParseTransformAttributes(self, context);
    IJSVGParseDisplayAttributes(self, context);
    IJSVGParseMarkersAttributes(self, context);

    self.x1 = [IJSVGUnitLength unitWithString:[context->element attributeForName:IJSVGAttributeX1].stringValue];
    self.y1 = [IJSVGUnitLength unitWithString:[context->element attributeForName:IJSVGAttributeY1].stringValue];
    self.x2 = [IJSVGUnitLength unitWithString:[context->element attributeForName:IJSVGAttributeX2].stringValue];
    self.y2 = [IJSVGUnitLength unitWithString:[context->element attributeForName:IJSVGAttributeY2].stringValue];
}

@end
