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
                          @"r":@"radius",
                          @"fx":@"fx"};
    
    for(NSString * key in kv.allKeys) {
        NSString * str = [element attributeForName:key].stringValue;
        IJSVGUnitLength * unit = nil;
        if(str != nil) {
            unit = [IJSVGUnitLength unitWithPercentageString:str];
        } else {
            unit = [IJSVGUnitLength unitWithPercentageFloat:50];
        }
        [gradient setValue:unit
                    forKey:kv[key]];
    }
    
    // fy defaults to cy if not specified
    NSString * fy = [element attributeForName:@"fy"].stringValue;
    if(fy != nil) {
        gradient.fy = [IJSVGUnitLength unitWithPercentageString:fy];
    } else {
        gradient.fy = gradient.cy;
    }
    
    if( gradient.gradient != nil )
        return nil;
    
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

- (CGFloat)_handleTransform:(IJSVGTransform *)transform
                     bounds:(CGRect)bounds
                      index:(NSInteger)index
                      value:(CGFloat)value
{
    // rotate transform, assume its based on percentages
    // if lower then 0 is specified for 1 or 2
    CGFloat max = bounds.size.width>bounds.size.height?bounds.size.width:bounds.size.height;
    if( transform.command == IJSVGTransformCommandRotate ) {
        switch(index) {
            case 1:
            case 2: {
                if(value<1.f) {
                    return (max*value);
                }
                break;
            }
        }
    }
    return value;

}

- (void)drawInContextRef:(CGContextRef)ctx
                    rect:(NSRect)rect
{
    CGRect bounds = rect;
    for( IJSVGTransform * transform in self.transforms ) {
        IJSVGTransformParameterModifier modifier = ^CGFloat(NSInteger index, CGFloat value) {
            return [self _handleTransform:transform
                                   bounds:bounds
                                    index:index
                                    value:value];
        };
        CGContextConcatCTM(ctx, [transform CGAffineTransformWithModifier:modifier]);
    }
    
    CGPoint sp = self.startPoint;
    CGPoint ep = self.endPoint;
    
    if( self.startPoint.x == .5f ) {
        sp.x = bounds.size.width*self.startPoint.x;
    }
    
    if(self.startPoint.y == .5f) {
        sp.y = bounds.size.height*self.startPoint.y;
    }
    
    if(self.endPoint.x == .5f) {
        ep.x = bounds.size.width*self.endPoint.x;
    }
    
    if(self.endPoint.y == .5f) {
        ep.y = bounds.size.height*self.endPoint.y;
    }
    
    CGFloat r = self.radius.value;
    if(r == .5f) {
        r = (sp.x>sp.y?sp.x:sp.y);
    }
    
    // actually perform the draw
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation|kCGGradientDrawsAfterEndLocation;
    CGGradientRef grad = self.CGGradient;
    CGContextDrawRadialGradient(ctx, grad, sp, 0.f, ep, r, options);
}

@end
