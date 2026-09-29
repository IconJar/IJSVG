//
//  IJSVGFloodFilterEffect.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGFloodFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGFloodFilterEffect

- (CIImage*)outputImageForPrimitive:(IJSVGFilterPrimitive*)primitive
                             inputs:(NSArray<CIImage*>*)inputs
                             region:(CGRect)region
                            context:(IJSVGFilterContext*)context
{
    NSString* value = [primitive.parameters[IJSVGAttributeFloodOpacity]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString* number = [value hasSuffix:@"%"] ? [value substringToIndex:value.length - 1] : value;
    NSArray<NSNumber*>* numbers = [IJSVGUtils numbersFromString:number];
    CGFloat opacity = numbers.count == 1 ? [IJSVGUtils floatValue:value
                                               fallBackForPercent:1] : 1;
    NSColor* color = [IJSVGColor colorFromString:primitive.parameters[IJSVGAttributeFloodColor] ?: IJSVGStringBlack];
    return [context floodWithColor:color
                           opacity:opacity];
}

@end
