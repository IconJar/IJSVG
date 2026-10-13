//
//  IJSVGFilterDistantLightPrimitive.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterDistantLightPrimitive.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGFilterDistantLightPrimitive

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeFilterDistantLight;
}

@end

#pragma mark - Parsing

@implementation IJSVGFilterDistantLightPrimitive (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    [attributes setBit:IJSVGNodeAttributeAzimuth];
    [attributes setBit:IJSVGNodeAttributeElevation];
    [attributes setBit:IJSVGNodeAttributeColorInterpolationFilters];
    IJSVGAddTextStyleAttributes(attributes);
    return attributes;
}

+ (NSSet<NSString*>*)parameterNames
{
    static NSSet<NSString*>* names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ names = [NSSet setWithArray:@[ IJSVGAttributeAzimuth, IJSVGAttributeElevation ]]; });
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
