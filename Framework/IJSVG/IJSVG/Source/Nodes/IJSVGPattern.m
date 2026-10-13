//
//  IJSVGPattern.m
//  IJSVG
//
//  Created by Curtis Hard on 27/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGPattern.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGPattern

- (void)applyPropertiesFromNode:(IJSVGPattern*)node
{
    [super applyPropertiesFromNode:node];
    self.reference = node.reference;
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypePattern;
}

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        self.viewBox = nil;
        self.viewBoxAlignment = IJSVGViewBoxAlignmentXMidYMid;
        self.viewBoxMeetOrSlice = IJSVGViewBoxMeetOrSliceMeet;
    }
    return self;
}

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds
{
    // as far as I can tell, units are inherited, so we need to go to the root
    // level pattern if there is one (we could be nested) and if so, return those
    // units as the actual units, but the bounds are based on the units of current
    // units defined on this node... wtf?!
    IJSVGGraphicsNode* node = nil;
    IJSVGPattern* parentPattern = [self rootNodeMatchingClass:self.class];
    IJSVGUnitType units = [self contentUnitsWithReferencingNode:&node];
    if (units == IJSVGUnitUserSpaceOnUse) {
        *bounds = node.rootNode.bounds;
    } else {
        *bounds = node.parentNode.bounds;
    }
    return parentPattern ? [parentPattern contentUnitsWithReferencingNode:&node] : units;
}

@end

#pragma mark - Parsing

@implementation IJSVGPattern (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeX];
    [attributes setBit:IJSVGNodeAttributeY];
    [attributes setBit:IJSVGNodeAttributeWidth];
    [attributes setBit:IJSVGNodeAttributeHeight];
    [attributes setBit:IJSVGNodeAttributePatternUnits];
    [attributes setBit:IJSVGNodeAttributePatternContentUnits];
    [attributes setBit:IJSVGNodeAttributePatternTransform];
    [attributes setBit:IJSVGNodeAttributeViewBox];
    [attributes setBit:IJSVGNodeAttributePreserveAspectRatio];
    [attributes setBit:IJSVGNodeAttributeHref];
    [attributes setBit:IJSVGNodeAttributeXLink];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    if (self.reference == nil) {
        self.reference = context->reference;
    }
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
    IJSVGParsePathAttributes(self, context);
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
    IJSVGParseBackgroundAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    IJSVGParsePaintAttributes(self, context);
    IJSVGParseEffectsAttributes(self, context);
    IJSVGParseTransformAttributes(self, context);
    IJSVGParseDisplayAttributes(self, context);
    IJSVGParseOverflowAttributes(self, context);
    IJSVGParseMarkersAttributes(self, context);
    IJSVGParsePatternAttributes(self, context);
    IJSVGParseViewportAttributes(self, context);
}

@end
