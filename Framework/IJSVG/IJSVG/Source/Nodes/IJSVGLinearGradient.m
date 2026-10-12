//
//  IJSVGLinearGradient.m
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGParser.h>

static IJSVGUnitLength* IJSVGLinearGradientCoordinate(NSString* value,
                                                      IJSVGUnitType units,
                                                      BOOL endPoint)
{
    IJSVGUnitLength* length = value != nil ?
        [IJSVGUnitLength unitWithString:value
                           fromUnitType:units] : nil;
    if(length == nil) {
        if(endPoint) {
            return IJSVGOnePercentageUnitLength;
        }
        return units == IJSVGUnitObjectBoundingBox ?
            IJSVGZeroBoundingBoxUnitLength :
            IJSVGZeroUnitLength;
    }
    return length;
}

@implementation IJSVGLinearGradient

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeLinearGradient;
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
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
    NSString* values[4] = { nil };
    for(NSXMLNode* attribute in element.attributes) {
        NSString* name = attribute.name;
        if(name.length != 2) {
            continue;
        }
        const char* chars = name.UTF8String;
        if(chars == NULL || (chars[0] != 'x' && chars[0] != 'y') ||
            (chars[1] != '1' && chars[1] != '2')) {
            continue;
        }
        NSUInteger index = (chars[0] == 'y' ? 2 : 0) + (chars[1] - '1');
        values[index] = attribute.stringValue;
    }
    IJSVGUnitType units = aGradient.units;
    aGradient.x1 = IJSVGLinearGradientCoordinate(values[0], units, NO);
    aGradient.x2 = IJSVGLinearGradientCoordinate(values[1], units, YES);
    aGradient.y1 = IJSVGLinearGradientCoordinate(values[2], units, NO);
    aGradient.y2 = IJSVGLinearGradientCoordinate(values[3], units, NO);

    // compute the color stops and colours
    [aGradient parseSpreadMethod:element];
    NSArray<NSColor*>* colors = nil;
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
    
    if([self drawSpreadInContext:ctx
                      startPoint:gradientStartPoint
                        endPoint:gradientEndPoint
                     startRadius:0.f
                       endRadius:0.f
                          radial:NO]) {
        return;
    }
    // draw the gradient
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    CGContextDrawLinearGradient(ctx, self.CGGradient, gradientStartPoint,
                                gradientEndPoint, options);
}

@end
