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
    if( [element attributeForName:@"cx"] )
        gradient.cx = [[[element attributeForName:@"cx"] stringValue] floatValue]/100;
    else
        gradient.cx = .5f;
    
    // cy defaults to 50% is not specified
    if([element attributeForName:@"cy"])
        gradient.cy = [[[element attributeForName:@"cy"] stringValue] floatValue]/100;
    else
        gradient.cy = .5f;
    
    if( [element attributeForName:@"r"] )
        gradient.radius = [[[element attributeForName:@"r"] stringValue] floatValue]/100;
    else
        gradient.radius = .5f;
    
    // fx defaults to cx if not specified
    if( [element attributeForName:@"fx"] != nil )
        gradient.fx = [[[element attributeForName:@"fx"] stringValue] floatValue]/100;
    else
        gradient.fx = gradient.cx;
    
    // fy defaults to cy if not specified
    if( [element attributeForName:@"fy"] != nil )
        gradient.fy = [[[element attributeForName:@"fx"] stringValue] floatValue]/100;
    else
        gradient.fy = gradient.cy;
    
    if( gradient.gradient != nil )
        return nil;
    
    *startPoint = CGPointMake(gradient.cx, gradient.cy);
    *endPoint = CGPointMake(gradient.fx, gradient.fy);
    
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
    if( transform.command == IJSVGTransformCommandRotate )
    {
        switch(index)
        {
            case 1: {
                if(value<1.f)
                    return max*value;
                break;
            }
                
            case 2: {
                if(value<1.f)
                    return max*value;
                break;
            }
        }
    }
    return value;

}

- (void)drawInContextRef:(CGContextRef)ctx
                    path:(IJSVGPath *)path
{
    CGRect bounds = path.path.bounds;
    for( IJSVGTransform * transform in self.transforms )
    {
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
    
    if( self.startPoint.x == .5f )
        sp.x = bounds.size.width*self.startPoint.x;
    if(startPoint.y == .5f)
        sp.y = bounds.size.height*self.startPoint.y;
    
    if(self.endPoint.x == .5f)
        ep.x = bounds.size.width*self.endPoint.x;
    if(self.endPoint.y == .5f)
        ep.y = bounds.size.height*self.endPoint.y;
    
    CGFloat r = self.radius;
    if(r == .5f)
        r = (sp.x>sp.y?sp.x:sp.y);
    
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation|kCGGradientDrawsAfterEndLocation;
    CGGradientRef grad = self.CGGradient;
    CGContextDrawRadialGradient(ctx, grad, sp, 0.f, ep, r, options);
}

@end
