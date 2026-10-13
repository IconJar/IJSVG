//
//  IJSVGFilterPointLightPrimitive.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterPointLightPrimitive.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGFilterPointLightPrimitive

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeFilterPointLight;
}

@end

#pragma mark - Parsing

@implementation IJSVGFilterPointLightPrimitive (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    [attributes setBit:IJSVGNodeAttributeX];
    [attributes setBit:IJSVGNodeAttributeY];
    [attributes setBit:IJSVGNodeAttributeZ];
    [attributes setBit:IJSVGNodeAttributeColorInterpolationFilters];
    IJSVGAddTextStyleAttributes(attributes);
    return attributes;
}

+ (NSSet<NSString*>*)parameterNames
{
    static NSSet<NSString*>* names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ names = [NSSet setWithArray:@[ IJSVGAttributeX, IJSVGAttributeY, IJSVGAttributeZ ]]; });
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
