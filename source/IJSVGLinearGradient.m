//
//  IJSVGGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGLinearGradient.h"
#import "IJSVGUtils.h"

@implementation IJSVGLinearGradient

+ (NSGradient *)parseGradient:(NSXMLElement *)element
                     gradient:(IJSVGLinearGradient *)aGradient
{
    
    CGFloat px1 = [[element attributeForName:@"x1"] stringValue].floatValue;
    CGFloat px2 = [[element attributeForName:@"x2"] stringValue].floatValue;
    CGFloat py1 = [[element attributeForName:@"y1"] stringValue].floatValue;
    CGFloat py2 = [[element attributeForName:@"y2"] stringValue].floatValue;
    
    // work out each coord, and work out if its a % or not
    // annoyingly we need to check them all against each other -_-
    BOOL isPercent = NO;
    if(px1 <= 1.f && px2 <= 1.f && py1 <= 1.f && py2 <= 1.f) {
        isPercent = YES;
    } else if((px1 >= 0.f && px1 <= 1.f) && (px2 >= 0.f && px2 <= 1.f) &&
              (py1 >= 0.f && py1 <= 1.f) && (py2 >= 0.f && py2 <= 1.f)) {
        isPercent = YES;
    }
    
    // assume its a vertical / horizonal
    if(isPercent == NO) {
        // just ask unit for the value
        aGradient.x1 = [IJSVGGradientUnitLength unitWithString:[[element attributeForName:@"x1"] stringValue] ?: @"0"];
        aGradient.x2 = [IJSVGGradientUnitLength unitWithString:[[element attributeForName:@"x2"] stringValue] ?: @"100"];
        aGradient.y1 = [IJSVGGradientUnitLength unitWithString:[[element attributeForName:@"y1"] stringValue] ?: @"0"];
        aGradient.y2 = [IJSVGGradientUnitLength unitWithString:[[element attributeForName:@"y2"] stringValue] ?: @"0"];
    } else {
        // make sure its a percent!
        aGradient.x1 = [IJSVGGradientUnitLength unitWithPercentageString:[[element attributeForName:@"x1"] stringValue] ?: @"0"];
        aGradient.x2 = [IJSVGGradientUnitLength unitWithPercentageString:[[element attributeForName:@"x2"] stringValue] ?: @"1"];
        aGradient.y1 = [IJSVGGradientUnitLength unitWithPercentageString:[[element attributeForName:@"y1"] stringValue] ?: @"0"];
        aGradient.y2 = [IJSVGGradientUnitLength unitWithPercentageString:[[element attributeForName:@"y2"] stringValue] ?: @"0"];
    }

    // compute the color stops and colours
    NSArray * colors = nil;
    CGFloat * stopsParams = [[self class] computeColorStopsFromString:element
                                                               colors:&colors];
    
    // create the gradient with the colours
    NSGradient * grad = [[NSGradient alloc] initWithColors:colors
                                               atLocations:stopsParams
                                                colorSpace:[NSColorSpace genericRGBColorSpace]];
    
    free(stopsParams);
    return [grad autorelease];
}

- (void)drawInContextRef:(CGContextRef)ctx
              parentRect:(NSRect)parentRect
             drawingRect:(NSRect)rect
        absolutePosition:(CGPoint)absolutePosition
                viewPort:(CGRect)viewBox
{
    BOOL inUserSpace = self.units == IJSVGUnitUserSpaceOnUse;
    
    CGPoint gradientStartPoint = CGPointZero;
    CGPoint gradientEndPoint = CGPointZero;
    CGAffineTransform absTransform = IJSVGAbsoluteTransform(absolutePosition);
    CGAffineTransform selfTransform = IJSVGConcatTransforms(self.transforms);
    
#pragma mark User Space On Use
    CGContextSaveGState(ctx);
    {
        if(inUserSpace == YES) {
            gradientStartPoint = CGPointMake([self.x1 computeValue:CGRectGetWidth(viewBox)],
                                             [self.y1 computeValue:CGRectGetHeight(viewBox)]);
            gradientEndPoint = CGPointMake([self.x2 computeValue:CGRectGetWidth(viewBox)],
                                           [self.y2 computeValue:CGRectGetHeight(viewBox)]);
            
            
            // transform absolute - due to user space
            CGContextConcatCTM(ctx, absTransform);
        } else {
#pragma mark Object Bounding Box
            gradientStartPoint = CGPointMake([self.x1 computeValue:CGRectGetWidth(parentRect)],
                                             [self.y1 computeValue:CGRectGetHeight(parentRect)]);
            gradientEndPoint = CGPointMake([self.x2 computeValue:CGRectGetWidth(parentRect)],
                                           [self.y2 computeValue:CGRectGetHeight(parentRect)]);
        }
        
        // check rotation
        CGFloat rotation = atan2(absTransform.b, absTransform.d);
        if(fabs(rotation) > .01) {
            CGAffineTransform tr = CGAffineTransformMakeTranslation(.5f, .5f);
            tr = CGAffineTransformRotate(tr, rotation);
            tr = CGAffineTransformTranslate(tr, -.5f, -.5f);
            gradientStartPoint = CGPointApplyAffineTransform(gradientStartPoint, tr);
            gradientEndPoint = CGPointApplyAffineTransform(gradientEndPoint, tr);
        }
        
    
        // transform the context
        CGContextConcatCTM(ctx, selfTransform);
        
        // draw the gradient
        CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation|
            kCGGradientDrawsAfterEndLocation;
        
        CGContextDrawLinearGradient(ctx, self.CGGradient, gradientStartPoint,
                                    gradientEndPoint, options);
    };
    CGContextRestoreGState(ctx);
}

@end
