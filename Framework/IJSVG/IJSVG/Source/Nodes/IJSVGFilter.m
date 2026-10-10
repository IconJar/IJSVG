//
//  IJSVGFilter.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilter.h>
#import <IJSVGFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGFilter

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeFilter;
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
    [storage addBits:[IJSVGNode allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeX];
    [storage setBit:IJSVGNodeAttributeY];
    [storage setBit:IJSVGNodeAttributeWidth];
    [storage setBit:IJSVGNodeAttributeHeight];
    [storage setBit:IJSVGNodeAttributeFilterUnits];
    [storage setBit:IJSVGNodeAttributePrimitiveUnits];
    return storage;
}

- (void)setDefaults
{
    [super setDefaults];
    self.x = [IJSVGUnitLength unitWithPercentageFloat:-.1f];
    self.y = [IJSVGUnitLength unitWithPercentageFloat:-.1f];
    self.width = [IJSVGUnitLength unitWithPercentageFloat:1.2f];
    self.height = [IJSVGUnitLength unitWithPercentageFloat:1.2f];
    self.units = IJSVGUnitObjectBoundingBox;
    self.contentUnits = IJSVGUnitUserSpaceOnUse;
    self.shouldRender = NO;
}

- (NSArray<IJSVGFilterPrimitive*>*)primitives
{
    NSMutableArray<IJSVGFilterPrimitive*>* primitives = [[NSMutableArray alloc] init];
    for(IJSVGNode* node in self.children) {
        if([node isKindOfClass:IJSVGFilterPrimitive.class]) {
            [primitives addObject:(IJSVGFilterPrimitive*)node];
        }
    }
    return primitives.copy;
}

- (NSSet<NSString*>*)inputNames
{
    NSMutableSet<NSString*>* inputNames = [[NSMutableSet alloc] init];
    for(IJSVGFilterPrimitive* primitive in self.primitives) {
        if(primitive.input != nil) {
            [inputNames addObject:primitive.input];
        }
        if(primitive.input2 != nil) {
            [inputNames addObject:primitive.input2];
        }
        for(IJSVGFilterPrimitive* child in primitive.children) {
            if(child.input != nil) {
                [inputNames addObject:child.input];
            }
        }
    }
    return inputNames.copy;
}

- (BOOL)containsOnlyInnerShadows:(NSArray<IJSVGFilterPrimitive*>*)primitives
{
    // Recognise the complete exported inner shadow graph, not just an alpha
    // matrix. Keep its SourceGraphic and final blend at destination resolution:
    // supersampling the whole graph softens the otherwise crisp foreground.
    if(primitives.count < 8 || (primitives.count - 2) % 6 != 0) {
        return NO;
    }
    for(IJSVGFilterPrimitive* primitive in primitives) {
        if(primitive.x != nil || primitive.y != nil || primitive.width != nil ||
            primitive.height != nil || primitive.children.count != 0) {
            return NO;
        }
    }
    IJSVGFilterPrimitive* flood = primitives[0];
    IJSVGFilterPrimitive* shape = primitives[1];
    if(flood.type != IJSVGNodeTypeFilterFlood ||
        [flood numberForParameter:IJSVGAttributeFloodOpacity defaultValue:1] != 0 ||
        flood.result.length == 0 || shape.result.length == 0 ||
        shape.type != IJSVGNodeTypeFilterBlend ||
        ![shape.input isEqualToString:IJSVGStringSourceGraphic] ||
        ![shape.input2 isEqualToString:flood.result] ||
        shape.filterBlendMode != IJSVGBlendModeNormal) {
        return NO;
    }

    // Named sources take precedence over results. Reject collisions rather than
    // incorrectly identifying a different graph as an inner shadow.
    NSSet<NSString*>* sources = [NSSet setWithArray:@[
        IJSVGStringSourceGraphic, IJSVGStringSourceAlpha,
        IJSVGStringBackgroundImage, IJSVGStringBackgroundAlpha,
        IJSVGStringFillPaint, IJSVGStringStrokePaint
    ]];
    if([sources containsObject:flood.result] || [sources containsObject:shape.result] ||
        [flood.result isEqualToString:shape.result]) {
        return NO;
    }
    NSString* previousShape = shape.result;
    for(NSUInteger index = 2; index < primitives.count; index += 6) {
        IJSVGFilterPrimitive* hardAlpha = primitives[index];
        IJSVGFilterPrimitive* offset = primitives[index + 1];
        IJSVGFilterPrimitive* blur = primitives[index + 2];
        IJSVGFilterPrimitive* subtract = primitives[index + 3];
        IJSVGFilterPrimitive* color = primitives[index + 4];
        IJSVGFilterPrimitive* blend = primitives[index + 5];
        if(hardAlpha.type != IJSVGNodeTypeFilterColorMatrix ||
            ![hardAlpha.input isEqualToString:IJSVGStringSourceAlpha] ||
            hardAlpha.result.length == 0 || [sources containsObject:hardAlpha.result] ||
            [hardAlpha.result isEqualToString:previousShape] ||
            offset.type != IJSVGNodeTypeFilterOffset ||
            blur.type != IJSVGNodeTypeFilterGaussianBlur ||
            subtract.type != IJSVGNodeTypeFilterComposite ||
            color.type != IJSVGNodeTypeFilterColorMatrix ||
            blend.type != IJSVGNodeTypeFilterBlend) {
            return NO;
        }
        // Only implicit chaining is recognised here. Unfamiliar named branches
        // continue through the existing supersampling fallback.
        for(IJSVGFilterPrimitive* stage in @[offset, blur, subtract, color]) {
            if(stage.input.length != 0 || stage.result.length != 0) {
                return NO;
            }
        }
        if(![subtract.input2 isEqualToString:hardAlpha.result] ||
            subtract.compositeOperator != IJSVGFilterCompositeOperatorArithmetic ||
            [subtract numberForParameter:IJSVGAttributeK1 defaultValue:0] != 0 ||
            [subtract numberForParameter:IJSVGAttributeK2 defaultValue:0] != -1 ||
            [subtract numberForParameter:IJSVGAttributeK3 defaultValue:0] != 1 ||
            [subtract numberForParameter:IJSVGAttributeK4 defaultValue:0] != 0 ||
            blend.input.length != 0 || ![blend.input2 isEqualToString:previousShape] ||
            blend.filterBlendMode != IJSVGBlendModeNormal ||
            (blend.result.length != 0 && [sources containsObject:blend.result])) {
            return NO;
        }
        NSArray<NSNumber*>* alphaValues = [hardAlpha numbersForParameter:IJSVGAttributeValues];
        NSArray<NSNumber*>* colorValues = [color numbersForParameter:IJSVGAttributeValues];
        if(hardAlpha.colorMatrixType != IJSVGFilterColorMatrixTypeMatrix ||
            color.colorMatrixType != IJSVGFilterColorMatrixTypeMatrix ||
            alphaValues.count != 20 || colorValues.count != 20) {
            return NO;
        }
        for(NSUInteger component = 0; component < 20; component++) {
            double alpha = alphaValues[component].doubleValue;
            double tint = colorValues[component].doubleValue;
            if(!isfinite(alpha) || !isfinite(tint) ||
                (component == 18 ? alpha <= 1 : alpha != 0)) {
                return NO;
            }
            if(component == 4 || component == 9 || component == 14) {
                if(tint < 0 || tint > 1) {
                    return NO;
                }
            } else if(tint != (component == 18 ? 1 : 0)) {
                return NO;
            }
        }
        previousShape = blend.result;
        if(index + 6 < primitives.count && previousShape.length == 0) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)preservesInnerShadowCoverage
{
    return [self containsOnlyInnerShadows:self.primitives];
}

- (BOOL)requiresSupersampling
{
    NSArray<IJSVGFilterPrimitive*>* primitives = self.primitives;
    if([self containsOnlyInnerShadows:primitives]) {
        return NO;
    }
    for(IJSVGFilterPrimitive* primitive in primitives) {
        IJSVGFilterEffect* effect = [IJSVGFilterEffect effectForType:primitive.type];
        if([effect requiresSupersamplingForPrimitive:primitive]) {
            return YES;
        }
    }
    return NO;
}

@end
