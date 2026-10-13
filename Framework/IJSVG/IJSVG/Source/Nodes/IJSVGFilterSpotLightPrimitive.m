//
//  IJSVGFilterSpotLightPrimitive.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterSpotLightPrimitive.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGFilterSpotLightPrimitive

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeFilterSpotLight;
}

@end

#pragma mark - Parsing

@implementation IJSVGFilterSpotLightPrimitive (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    [attributes setBit:IJSVGNodeAttributeX];
    [attributes setBit:IJSVGNodeAttributeY];
    [attributes setBit:IJSVGNodeAttributeZ];
    [attributes setBit:IJSVGNodeAttributePointsAtX];
    [attributes setBit:IJSVGNodeAttributePointsAtY];
    [attributes setBit:IJSVGNodeAttributePointsAtZ];
    [attributes setBit:IJSVGNodeAttributeSpecularExponent];
    [attributes setBit:IJSVGNodeAttributeLimitingConeAngle];
    [attributes setBit:IJSVGNodeAttributeColorInterpolationFilters];
    IJSVGAddTextStyleAttributes(attributes);
    return attributes;
}

+ (NSSet<NSString*>*)parameterNames
{
    static NSSet<NSString*>* names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = [NSSet setWithArray:@[ IJSVGAttributeX, IJSVGAttributeY, IJSVGAttributeZ, IJSVGAttributePointsAtX, IJSVGAttributePointsAtY, IJSVGAttributePointsAtZ, IJSVGAttributeSpecularExponent, IJSVGAttributeLimitingConeAngle ]];
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
