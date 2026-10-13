//
//  IJSVGPolyline.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGPolyline.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGPolyline

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypePolyline;
}

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        self.primitiveType = kIJSVGPrimitivePathTypePolyLine;
    }
    return self;
}

@end

#pragma mark - Parsing

@implementation IJSVGPolyline (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGGraphicsAttributes();
    [attributes setBit:IJSVGNodeAttributePoints];
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
    NSString* pointsString = [context->element attributeForName:IJSVGAttributePoints].stringValue;
    [context->parser parsePolyPoints:pointsString intoPath:self closePath:NO];
}

@end
