//
//  IJSVGFilterTurbulencePrimitive.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterTurbulencePrimitive.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGFilterTurbulencePrimitive

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeFilterTurbulence;
}

@end

#pragma mark - Parsing

@implementation IJSVGFilterTurbulencePrimitive (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    [attributes setBit:IJSVGNodeAttributeBaseFrequency];
    [attributes setBit:IJSVGNodeAttributeNumOctaves];
    [attributes setBit:IJSVGNodeAttributeSeed];
    [attributes setBit:IJSVGNodeAttributeStitchTiles];
    [attributes setBit:IJSVGNodeAttributeType];
    [attributes setBit:IJSVGNodeAttributeX];
    [attributes setBit:IJSVGNodeAttributeY];
    [attributes setBit:IJSVGNodeAttributeWidth];
    [attributes setBit:IJSVGNodeAttributeHeight];
    [attributes setBit:IJSVGNodeAttributeResult];
    [attributes setBit:IJSVGNodeAttributeColorInterpolationFilters];
    IJSVGAddTextStyleAttributes(attributes);
    return attributes;
}

+ (NSSet<NSString*>*)parameterNames
{
    static NSSet<NSString*>* names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ names = [NSSet setWithArray:@[ IJSVGAttributeBaseFrequency, IJSVGAttributeNumOctaves, IJSVGAttributeSeed, IJSVGAttributeStitchTiles, IJSVGAttributeType ]]; });
    return names;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
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
    IJSVGParseFilterColorInterpolation(self, context);
    self.parameters = context->filterParameters;
    self.result = IJSVGAttributeValue(context->values, IJSVGNodeAttributeResult);
}

@end
