//
//  IJSVGFloodFilterEffect.m
//  IJSVG
//
//  Created by Curtis Hard on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVGFloodFilterEffect.h>

@implementation IJSVGFloodFilterEffect

+ (NSColor*)colorForPrimitive:(IJSVGFilterPrimitive*)primitive
{
    NSString* value = primitive.parameters[IJSVGAttributeFloodColor] ?: IJSVGStringBlack;
    value = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    // The general parser represents transparent paint as nil.
    // Preserve its alpha before filter callers apply the default colour.
    return [IJSVGColor isNoneOrTransparent:value] ? NSColor.clearColor : [IJSVGColor colorFromString:value];
}

+ (CGFloat)opacityForPrimitive:(IJSVGFilterPrimitive*)primitive
{
    NSString* value = [primitive.parameters[IJSVGAttributeFloodOpacity] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    IJSVGUnitLength* unit = [IJSVGUnitLength unitWithString:value];
    if (unit == nil || (unit.originalType != IJSVGUnitLengthTypeNumber && unit.originalType != IJSVGUnitLengthTypePercentage)) {
        return 1;
    }
    NSString* number = unit.originalType == IJSVGUnitLengthTypePercentage ? [value substringToIndex:value.length - 1] : value;

    // Validate the complete value before using the tolerant unit parser.
    return [IJSVGUtils numbersFromString:number].count == 1 ? [unit computeValue:1] : 1;
}

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive inputs:(NSArray<CIImage*>*)inputs region:(CGRect)region context:(IJSVGFilterContext*)context
{
    // Opacity can be a number or a percentage. Use full opacity if it is invalid.
    CGFloat opacity = [self.class opacityForPrimitive:primitive];
    NSColor* color = [self.class colorForPrimitive:primitive];
    return [context floodWithColor:color opacity:opacity];
}

@end
