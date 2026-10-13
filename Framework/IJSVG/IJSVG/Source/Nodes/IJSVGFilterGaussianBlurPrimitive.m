//
//  IJSVGFilterGaussianBlurPrimitive.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterGaussianBlurPrimitive.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGFilterGaussianBlurPrimitive

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeFilterGaussianBlur;
}

@end

#pragma mark - Parsing

@implementation IJSVGFilterGaussianBlurPrimitive (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    [attributes setBit:IJSVGNodeAttributeStdDeviation];
    [attributes setBit:IJSVGNodeAttributeEdgeMode];
    [attributes setBit:IJSVGNodeAttributeX];
    [attributes setBit:IJSVGNodeAttributeY];
    [attributes setBit:IJSVGNodeAttributeWidth];
    [attributes setBit:IJSVGNodeAttributeHeight];
    [attributes setBit:IJSVGNodeAttributeResult];
    [attributes setBit:IJSVGNodeAttributeIn];
    [attributes setBit:IJSVGNodeAttributeColorInterpolationFilters];
    IJSVGAddTextStyleAttributes(attributes);
    return attributes;
}

+ (NSSet<NSString*>*)parameterNames
{
    static NSSet<NSString*>* names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = [NSSet setWithArray:@[ IJSVGAttributeStdDeviation, IJSVGAttributeEdgeMode ]];
    });
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
    self.input = IJSVGAttributeValue(context->values, IJSVGNodeAttributeIn);
    self.result = IJSVGAttributeValue(context->values, IJSVGNodeAttributeResult);
}

@end
