//
//  IJSVGGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGColor.h>
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
    // just ask unit for the value
    NSString* x1 = ([element attributeForName:IJSVGAttributeX1].stringValue ?: @"0");
    NSString* x2 = ([element attributeForName:IJSVGAttributeX2].stringValue ?: @"100%");
    NSString* y1 = ([element attributeForName:IJSVGAttributeY1].stringValue ?: @"0");
    NSString* y2 = ([element attributeForName:IJSVGAttributeY2].stringValue ?: @"0");
    aGradient.x1 = [IJSVGGradientUnitLength unitWithString:x1 fromUnitType:aGradient.units];
    aGradient.x2 = [IJSVGGradientUnitLength unitWithString:x2 fromUnitType:aGradient.units];
    aGradient.y1 = [IJSVGGradientUnitLength unitWithString:y1 fromUnitType:aGradient.units];
    aGradient.y2 = [IJSVGGradientUnitLength unitWithString:y2 fromUnitType:aGradient.units];
    
    // parse spreadMethod
    NSString* spreadMethod = [element attributeForName:@"spreadMethod"].stringValue;
    if([spreadMethod isEqualToString:@"reflect"]) {
        aGradient.spreadMethod = IJSVGSpreadMethodReflect;
    } else if([spreadMethod isEqualToString:@"repeat"]) {
        aGradient.spreadMethod = IJSVGSpreadMethodRepeat;
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
    if(self.spreadMethod == IJSVGSpreadMethodPad) {
        // Default: extend with last color before/after
        CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
        CGContextDrawLinearGradient(ctx, self.CGGradient, gradientStartPoint,
            gradientEndPoint, options);
    } else {
        // Reflect or Repeat: tile the gradient by drawing it multiple times
        // with reflected/repeated start/end points
        CGFloat dx = gradientEndPoint.x - gradientStartPoint.x;
        CGFloat dy = gradientEndPoint.y - gradientStartPoint.y;
        CGFloat gradLen = sqrt(dx * dx + dy * dy);
        if(gradLen < 0.001) {
            CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
            CGContextDrawLinearGradient(ctx, self.CGGradient, gradientStartPoint,
                gradientEndPoint, options);
        } else {
            // Determine how many tiles we need to cover the clip bounds
            CGRect clipBounds = CGContextGetClipBoundingBox(ctx);
            CGFloat maxDim = MAX(CGRectGetWidth(clipBounds), CGRectGetHeight(clipBounds));
            int tiles = (int)(maxDim / gradLen) + 2;

            CGGradientRef grad = self.CGGradient;
            CGGradientRef reversedGrad = NULL;

            if(self.spreadMethod == IJSVGSpreadMethodReflect) {
                // Create a reversed gradient for alternating tiles
                NSUInteger nStops = self.numberOfStops;
                CGFloat* revLocations = (CGFloat*)malloc(nStops * sizeof(CGFloat));
                CGFloat* revComponents = (CGFloat*)malloc(nStops * 4 * sizeof(CGFloat));
                for(NSUInteger i = 0; i < nStops; i++) {
                    revLocations[i] = 1.0 - self.locations[nStops - 1 - i];
                    NSColor* color = [IJSVGColor computeColorSpace:self.colors[nStops - 1 - i]];
                    CGFloat r = 0.f;
                    CGFloat g = 0.f;
                    CGFloat b = 0.f;
                    CGFloat a = 0.f;
                    IJSVGColorGetRGBAComponents(color, &r, &g, &b, &a);
                    revComponents[i * 4 + 0] = r;
                    revComponents[i * 4 + 1] = g;
                    revComponents[i * 4 + 2] = b;
                    revComponents[i * 4 + 3] = a;
                }
                CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
                reversedGrad = CGGradientCreateWithColorComponents(cs, revComponents, revLocations, nStops);
                CGColorSpaceRelease(cs);
                free(revLocations);
                free(revComponents);
            }

            for(int t = -tiles; t <= tiles; t++) {
                CGPoint tileStart = CGPointMake(gradientStartPoint.x + dx * t,
                                                gradientStartPoint.y + dy * t);
                CGPoint tileEnd = CGPointMake(gradientStartPoint.x + dx * (t + 1),
                                              gradientStartPoint.y + dy * (t + 1));

                BOOL useReverse = (self.spreadMethod == IJSVGSpreadMethodReflect) && (abs(t) % 2 == 1);
                CGGradientRef tileGrad = useReverse ? reversedGrad : grad;

                CGContextDrawLinearGradient(ctx, tileGrad, tileStart, tileEnd, 0);
            }

            if(reversedGrad != NULL) {
                CGGradientRelease(reversedGrad);
            }
        }
    }
}

@end
