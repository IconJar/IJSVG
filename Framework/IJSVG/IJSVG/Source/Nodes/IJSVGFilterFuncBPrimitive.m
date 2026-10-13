//
//  IJSVGFilterFuncBPrimitive.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterFuncBPrimitive.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGFilterFuncBPrimitive

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeFilterFuncB;
}

@end

#pragma mark - Parsing

@implementation IJSVGFilterFuncBPrimitive (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    [attributes setBit:IJSVGNodeAttributeType];
    [attributes setBit:IJSVGNodeAttributeTableValues];
    [attributes setBit:IJSVGNodeAttributeSlope];
    [attributes setBit:IJSVGNodeAttributeIntercept];
    [attributes setBit:IJSVGNodeAttributeAmplitude];
    [attributes setBit:IJSVGNodeAttributeExponent];
    [attributes setBit:IJSVGNodeAttributeOffset];
    [attributes setBit:IJSVGNodeAttributeColorInterpolationFilters];
    IJSVGAddTextStyleAttributes(attributes);
    return attributes;
}

+ (NSSet<NSString*>*)parameterNames
{
    static NSSet<NSString*>* names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = [NSSet setWithArray:@[ IJSVGAttributeType, IJSVGAttributeTableValues, IJSVGAttributeSlope, IJSVGAttributeIntercept, IJSVGAttributeAmplitude, IJSVGAttributeExponent, IJSVGAttributeOffset ]];
    });
    return names;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    self.parameters = context->filterParameters;
}

@end
