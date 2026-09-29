//
//  IJSVGFilterPrimitive.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterPrimitive.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGParserUtils.h>
#import <IJSVG/IJSVGUtils.h>

@implementation IJSVGFilterPrimitive

+ (NSSet<NSString*>*)filterParameterNames
{
    return [NSSet setWithArray:@[
        IJSVGAttributeIn2, IJSVGAttributeMode, IJSVGAttributeType, IJSVGAttributeValues, IJSVGAttributeOperator,
        IJSVGAttributeK1, IJSVGAttributeK2, IJSVGAttributeK3, IJSVGAttributeK4, IJSVGAttributeOrder,
        IJSVGAttributeKernelMatrix, IJSVGAttributeDivisor, IJSVGAttributeBias, IJSVGAttributeTargetX,
        IJSVGAttributeTargetY, IJSVGAttributeEdgeMode, IJSVGAttributeKernelUnitLength, IJSVGAttributePreserveAlpha,
        IJSVGAttributeSurfaceScale, IJSVGAttributeDiffuseConstant, IJSVGAttributeSpecularConstant,
        IJSVGAttributeSpecularExponent, IJSVGAttributeLightingColor, IJSVGAttributeScale,
        IJSVGAttributeXChannelSelector, IJSVGAttributeYChannelSelector, IJSVGAttributeFloodColor,
        IJSVGAttributeFloodOpacity, IJSVGAttributeStdDeviation, IJSVGAttributeRadius, IJSVGAttributeDX,
        IJSVGAttributeDY, IJSVGAttributeBaseFrequency, IJSVGAttributeNumOctaves, IJSVGAttributeSeed,
        IJSVGAttributeStitchTiles, IJSVGAttributeTableValues, IJSVGAttributeSlope, IJSVGAttributeIntercept,
        IJSVGAttributeAmplitude, IJSVGAttributeExponent, IJSVGAttributeOffset, IJSVGAttributeAzimuth,
        IJSVGAttributeElevation, IJSVGAttributeX, IJSVGAttributeY, IJSVGAttributeZ, IJSVGAttributePointsAtX,
        IJSVGAttributePointsAtY, IJSVGAttributePointsAtZ, IJSVGAttributeLimitingConeAngle, IJSVGAttributeHref,
        IJSVGAttributeXLink, IJSVGAttributePreserveAspectRatio
    ]];
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
    [storage addBits:[IJSVGNode allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeX];
    [storage setBit:IJSVGNodeAttributeY];
    [storage setBit:IJSVGNodeAttributeWidth];
    [storage setBit:IJSVGNodeAttributeHeight];
    [storage setBit:IJSVGNodeAttributeIn];
    [storage setBit:IJSVGNodeAttributeResult];
    [storage setBit:IJSVGNodeAttributePreserveAspectRatio];
    for(NSString* name in self.parameterNames) {
        NSUInteger attribute = IJSVGNodeAttributeForName(name);
        if(attribute != NSNotFound) {
            [storage setBit:(int)attribute];
        }
    }
    return storage;
}

- (void)setDefaults
{
    [super setDefaults];
    self.shouldRender = NO;
}

- (void)applyPropertiesFromNode:(IJSVGNode*)node
{
    [super applyPropertiesFromNode:node];
    if([node isKindOfClass:IJSVGFilterPrimitive.class]) {
        IJSVGFilterPrimitive* primitive = (IJSVGFilterPrimitive*)node;
        self.input = primitive.input;
        self.result = primitive.result;
        self.input2 = primitive.input2;
        self.parameters = primitive.parameters;
        self.imageNode = primitive.imageNode.copy;
        self.image = primitive.image;
    }
}

+ (NSSet<NSString*>*)parameterNames
{
    static NSSet<NSString*>* names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = [self filterParameterNames];
    });
    return names;
}

+ (BOOL)isPrimitiveType:(IJSVGNodeType)type
{
    return type == IJSVGNodeTypeFilterDropShadow
        || (type >= IJSVGNodeTypeFilterBlend && type <= IJSVGNodeTypeFilterTurbulence);
}

+ (BOOL)type:(IJSVGNodeType)parentType
    acceptsChildType:(IJSVGNodeType)childType
{
    if(parentType == IJSVGNodeTypeFilter) {
        return [self isPrimitiveType:childType];
    }
    if(parentType == IJSVGNodeTypeFilterMerge) {
        return childType == IJSVGNodeTypeFilterMergeNode;
    }
    if(parentType == IJSVGNodeTypeFilterComponentTransfer) {
        return childType >= IJSVGNodeTypeFilterFuncR && childType <= IJSVGNodeTypeFilterFuncA;
    }
    if(parentType == IJSVGNodeTypeFilterDiffuseLighting || parentType == IJSVGNodeTypeFilterSpecularLighting) {
        return childType >= IJSVGNodeTypeFilterDistantLight && childType <= IJSVGNodeTypeFilterSpotLight;
    }
    return NO;
}

- (NSArray<NSNumber*>*)numbersForParameter:(NSString*)name
{
    return [IJSVGUtils numbersFromString:self.parameters[name]];
}

- (CGFloat)numberForParameter:(NSString*)name
                 defaultValue:(CGFloat)value
{
    NSArray<NSNumber*>* numbers = [self numbersForParameter:name];
    return numbers.count == 1 ? numbers[0].doubleValue : value;
}

- (CGSize)pairForParameter:(NSString*)name
              defaultValue:(CGSize)value
{
    NSArray<NSNumber*>* numbers = [self numbersForParameter:name];
    if(numbers.count == 1 || numbers.count == 2) {
        return CGSizeMake(numbers[0].doubleValue, numbers.lastObject.doubleValue);
    }
    return value;
}

@end
