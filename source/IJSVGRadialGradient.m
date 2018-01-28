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
    return grad;
}


+ (NSGradient *)parseGradient:(NSXMLElement *)element
                     gradient:(IJSVGRadialGradient *)gradient
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
    CGPoint gradientPoint = CGPointZero;
    
    // transforms
    CGAffineTransform absTransform = IJSVGAbsoluteTransform(absolutePosition);
    CGAffineTransform selfTransform = IJSVGConcatTransforms(self.transforms);
    
    CGContextSaveGState(ctx);
    {
#pragma mark User Space On Use
        if(inUserSpace == YES) {
            CGFloat rad = radius*2.f;
            startPoint = CGPointMake(self.cx.value, self.cy.value);
            
            // work out the new radius
            CGRect rect = CGRectMake(startPoint.x, startPoint.y, rad, rad);
            rect = CGRectApplyAffineTransform(rect, selfTransform);
            rect = CGRectApplyAffineTransform(rect, absTransform);
            radius = CGRectGetHeight(rect)/2.f;
            
            gradientPoint = startPoint;
            
            // move it back
            gradientPoint.x -= CGRectGetMinX(parentRect);
            gradientPoint.y -= CGRectGetMinY(parentRect);
            
            // apply the absolute position
            CGContextConcatCTM(ctx, absTransform);
        } else {
#pragma mark Object Bounding Box
            // compute size based on percentages
            CGFloat x = [self.cx computeValue:CGRectGetWidth(parentRect)];
            CGFloat y = [self.cy computeValue:CGRectGetHeight(parentRect)];
            startPoint = CGPointMake(x, y);
            CGFloat val = MIN(CGRectGetWidth(parentRect), CGRectGetWidth(parentRect));
            radius = [self.radius computeValue:val];
            
            gradientPoint = startPoint;
            
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

#pragma mark Default drawing
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
