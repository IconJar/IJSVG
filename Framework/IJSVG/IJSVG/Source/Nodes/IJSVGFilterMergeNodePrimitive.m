//
//  IJSVGFilterMergeNodePrimitive.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterMergeNodePrimitive.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGFilterMergeNodePrimitive

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeFilterMergeNode;
}

@end

#pragma mark - Parsing

@implementation IJSVGFilterMergeNodePrimitive (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
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
        names = [NSSet setWithArray:@[]];
    });
    return names;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    self.parameters = context->filterParameters;
    self.input = IJSVGAttributeValue(context->values, IJSVGNodeAttributeIn);
}

@end
