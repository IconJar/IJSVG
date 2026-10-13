//
//  IJSVGCircle.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGCircle.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGCircle

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeCircle;
}

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        self.primitiveType = kIJSVGPrimitivePathTypeCircle;
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGCircle* node = [super copyWithZone:zone];
    node.cx = _cx.copy;
    node.cy = _cy.copy;
    node.r = _r.copy;
    return node;
}

- (BOOL)containsRelativeUnits
{
    return _cx.isRelativeUnit || _cy.isRelativeUnit || _r.isRelativeUnit || [super containsRelativeUnits];
}

@end

#pragma mark - Parsing

@implementation IJSVGCircle (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGGraphicsAttributes();
    [attributes setBit:IJSVGNodeAttributeCX];
    [attributes setBit:IJSVGNodeAttributeCY];
    [attributes setBit:IJSVGNodeAttributeR];
    [attributes setBit:IJSVGNodeAttributePathLength];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
    IJSVGUnitLength* geometryLength = nil;
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeCX, &geometryLength)) {
        self.cx = geometryLength;
    }
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeCY, &geometryLength)) {
        self.cy = geometryLength;
    }
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeR, &geometryLength)) {
        self.r = geometryLength;
    }
    IJSVGParsePathLengthAttributes(self, context);
    IJSVGParseBackgroundAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    IJSVGParsePaintAttributes(self, context);
    IJSVGParseEffectsAttributes(self, context);
    IJSVGParseTransformAttributes(self, context);
    IJSVGParseDisplayAttributes(self, context);
    IJSVGParseMarkersAttributes(self, context);
}

@end
