//
//  IJSVGRadialGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGRadialGradient.h"

@implementation IJSVGRadialGradient

@synthesize cx;
@synthesize cy;
@synthesize fx;
@synthesize fy;
@synthesize radius;

- (void)dealloc
{
    [cx release], cx = nil;
    [cy release], cy = nil;
    [fx release], fx = nil;
    [fy release], fy = nil;
    [radius release], radius = nil;
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGRadialGradient * grad = [super copyWithZone:zone];
    grad.fx = self.fx;
    grad.fy = self.fy;
    grad.cx = self.cx;
    grad.cy = self.cy;
    grad.radius = self.radius;
    grad.startPoint = self.startPoint;
    grad.endPoint = self.endPoint;
    return grad;
}


+ (NSGradient *)parseGradient:(NSXMLElement *)element
                     gradient:(IJSVGRadialGradient *)gradient
                   startPoint:(CGPoint *)startPoint
                     endPoint:(CGPoint *)endPoint
{
    // cx defaults to 50% if not specified
    NSDictionary * kv = @{@"cx":@"cx",
                          @"cy":@"cy",
                          @"r":@"radius"};
    
    for(NSString * key in kv.allKeys) {
        NSString * str = [element attributeForName:key].stringValue;
        IJSVGUnitLength * unit = nil;
        if(str != nil) {
            unit = [IJSVGUnitLength unitWithString:str];
        } else {
            unit = [IJSVGUnitLength unitWithPercentageFloat:.5f];
        }
        [gradient setValue:unit
                    forKey:kv[key]];
    }
  
    if( gradient.gradient != nil ) {
        return nil;
    }
    
    *startPoint = CGPointMake(gradient.cx.valueAsPercentage, gradient.cy.valueAsPercentage);
    *endPoint = CGPointMake(gradient.fx.valueAsPercentage, gradient.fy.valueAsPercentage);
    
    NSArray * colors = nil;
    CGFloat * colorStops = [[self class] computeColorStopsFromString:element colors:&colors];
    NSGradient * ret = [[[NSGradient alloc] initWithColors:colors
                                               atLocations:colorStops
                                                colorSpace:[NSColorSpace genericRGBColorSpace]] autorelease];
    free(colorStops);
    return ret;
}

- (void)drawInContextRef:(CGContextRef)ctx
              parentRect:(NSRect)parentRect
             drawingRect:(NSRect)rect
        absolutePosition:(CGPoint)absolutePosition
                viewPort:(CGRect)viewBox
{
    BOOL inUserSpace = self.units == IJSVGUnitUserSpaceOnUse;
    CGFloat radius = self.radius.value;
    CGPoint startPoint = CGPointZero;
    __block CGPoint gradientPoint = CGPointZero;
    
    // transforms
    CGAffineTransform absTransform = IJSVGAbsoluteTransform(absolutePosition);
    CGAffineTransform selfTransform = IJSVGConcatTransforms(self.transforms);
    
    if(inUserSpace == YES) {
        startPoint = CGPointMake(self.cx.value, self.cy.value);
        CGRect rect = CGRectMake(startPoint.x, startPoint.y,
                                 radius*2.f, radius*2.f);
        rect = CGRectApplyAffineTransform(rect, selfTransform);
        rect = CGRectApplyAffineTransform(rect, absTransform);
        radius = CGRectGetHeight(rect)/2.f;
    } else {
        // compute size based on percentages
        CGFloat x = [self.cx computeValue:CGRectGetWidth(parentRect)];
        CGFloat y = [self.cy computeValue:CGRectGetHeight(parentRect)];
        startPoint = CGPointMake(x, y);
        CGFloat val = MIN(CGRectGetWidth(parentRect),
                          CGRectGetWidth(parentRect));
        radius = [self.radius computeValue:val];
    }
    
    gradientPoint = startPoint;
    
    // make sure we save the context...just incase
    // we screw it up for something else
    CGContextSaveGState(ctx);
    {
        if(inUserSpace == YES) {
            gradientPoint.x -= CGRectGetMinX(parentRect);
            gradientPoint.y -= CGRectGetMinY(parentRect);
            CGContextConcatCTM(ctx, absTransform);
        } else {
            // transform if width or height is not equal
            if(CGRectGetWidth(rect) != CGRectGetHeight(rect)) {
                CGAffineTransform tr = CGAffineTransformMakeTranslation(gradientPoint.x,
                                                                        gradientPoint.y);
                if(CGRectGetWidth(rect) > CGRectGetHeight(rect)) {
                    tr = CGAffineTransformScale(tr, CGRectGetWidth(rect)/CGRectGetHeight(rect), 1);
                } else {
                    tr = CGAffineTransformScale(tr, 1.f, CGRectGetHeight(rect)/CGRectGetWidth(rect));
                }
                tr = CGAffineTransformTranslate(tr, -gradientPoint.x, -gradientPoint.y);
            }
        }

        // transform the context
        CGContextConcatCTM(ctx, selfTransform);
        
        // draw the gradient
        CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation|
            kCGGradientDrawsAfterEndLocation;
        CGContextDrawRadialGradient(ctx, self.CGGradient, gradientPoint, 0, gradientPoint,
                                    radius, options);
    };
    CGContextRestoreGState(ctx);
}

@end
