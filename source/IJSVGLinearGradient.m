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
                   startPoint:(CGPoint *)startPoint
                     endPoint:(CGPoint *)endPoint
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
    
    CGPoint startPoint = CGPointZero;
    CGPoint endPoint = CGPointZero;
    
    CGAffineTransform absTransform = IJSVGAbsoluteTransform(absolutePosition);
    CGAffineTransform selfTransform = IJSVGConcatTransforms(self.transforms);
    
    if(inUserSpace == YES) {
        startPoint.x = [self.x1 computeValue:CGRectGetWidth(viewBox)];
        startPoint.y = [self.y1 computeValue:CGRectGetHeight(viewBox)];
    }
    
    CGPoint gradientStartPoint = startPoint;
    
    if(inUserSpace == YES) {
        gradientStartPoint.x = (startPoint.x - CGRectGetMinX(parentRect))/CGRectGetWidth(parentRect);
        gradientStartPoint.y = (startPoint.y - CGRectGetMinY(parentRect))/CGRectGetHeight(parentRect);
    }
    
    if(inUserSpace == YES) {
        endPoint.x = [self.x2 computeValue:CGRectGetWidth(viewBox)];
        endPoint.y = [self.y2 computeValue:CGRectGetHeight(viewBox)];
    }
    
    CGPoint gradientEndPoint = endPoint;
    
    if(inUserSpace == YES) {
        gradientEndPoint.x = ((endPoint.x - CGRectGetMaxX(parentRect))/CGRectGetWidth(parentRect))+1;
        gradientEndPoint.y = ((endPoint.y - CGRectGetMaxY(parentRect))/CGRectGetHeight(parentRect))+1;
    }
    
    CGFloat rotation = atan2(absTransform.b, absTransform.d);
    if(fabs(rotation) > .01) {
        CGAffineTransform tr = CGAffineTransformMakeTranslation(.5f, .5f);
        tr = CGAffineTransformRotate(tr, rotation);
        tr = CGAffineTransformTranslate(tr, -.5f, -5.f);
        gradientStartPoint = CGPointApplyAffineTransform(gradientStartPoint, tr);
        gradientEndPoint = CGPointApplyAffineTransform(gradientEndPoint, tr);
    }
    
    CGContextSaveGState(ctx);
    {
        if(inUserSpace == YES) {
            CGContextConcatCTM(ctx, absTransform);
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
