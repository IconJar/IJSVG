//
//  IJSVGForeignObject.m
//  IJSVG
//
//  Created by Curtis Hard on 02/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGForeignObject.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGForeignObject

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeForeignObject;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGForeignObject* node = [super copyWithZone:zone];
    node.requiredExtension = _requiredExtension;
    return node;
}

@end

#pragma mark - Parsing

@implementation IJSVGForeignObject (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeWidth];
    [attributes setBit:IJSVGNodeAttributeHeight];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
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
