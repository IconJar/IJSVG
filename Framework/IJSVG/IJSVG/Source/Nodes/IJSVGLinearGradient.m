//
//  IJSVGGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGLinearGradient

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags64* storage = [[IJSVGBitFlags64 alloc] init];
    [storage addBits:[super allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeX1];
    [storage setBit:IJSVGNodeAttributeX2];
    [storage setBit:IJSVGNodeAttributeY1];
    [storage setBit:IJSVGNodeAttributeY2];
    return storage;
}

+ (void)parseGradient:(NSXMLElement*)element
             gradient:(IJSVGLinearGradient*)aGradient
{
    // Work out x1, x2, y1, y2
    NSDictionary *dict = @{
      IJSVGAttributeX1: @"0",
      IJSVGAttributeX2: @"100%",
      IJSVGAttributeY1: @"0",
      IJSVGAttributeY2: @"0",
    };
    
    for (NSString* key in dict) {
      NSString *value = [element attributeForName:key].stringValue ?: dict[key];
      IJSVGUnitLength *length = [IJSVGUnitLength unitWithString:value
                                                   fromUnitType:aGradient.units];
      length = length ?: [IJSVGUnitLength unitWithString:dict[key]
                                            fromUnitType:aGradient.units];
      [aGradient setValue:length
                   forKey:key];
    }
  
    // compute the color stops and colours
    NSArray* colors = nil;
    CGFloat* stopsParams = [self.class computeColorStops:aGradient
                                                  colors:&colors];
    aGradient.colors = colors;
    aGradient.locations = stopsParams;
    aGradient.numberOfStops = colors.count;
}

- (void)drawInContextRef:(CGContextRef)ctx
                  bounds:(NSRect)objectRect
               transform:(CGAffineTransform)absoluteTransform
{
    BOOL inUserSpace = self.units == IJSVGUnitUserSpaceOnUse;

    CGPoint gradientStartPoint = CGPointZero;
    CGPoint gradientEndPoint = CGPointZero;
    CGRect boundingBox = objectRect;
    
    // make sure we apply the absolute position to
    // transform us back into the correct space
    CGFloat width = CGRectGetWidth(boundingBox);
    CGFloat height = CGRectGetHeight(boundingBox);
    
    if(inUserSpace == YES) {
        CGContextConcatCTM(ctx, absoluteTransform);
    } else {
        width = 1.f;
        height = 1.f;
        CGContextConcatCTM(ctx, CGAffineTransformMakeScale(boundingBox.size.width,
                                                           boundingBox.size.height));
    }
    
    gradientStartPoint = CGPointMake([self.x1 computeValue:width],
                                     [self.y1 computeValue:height]);
    gradientEndPoint = CGPointMake([self.x2 computeValue:width],
                                     [self.y2 computeValue:height]);
    
    // concat the gradient transform into the context
    IJSVGConcatTransformsCTM(ctx, self.transforms);
    
    // draw the gradient
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;

    CGContextDrawLinearGradient(ctx, self.CGGradient, gradientStartPoint,
        gradientEndPoint, options);
}

@end
