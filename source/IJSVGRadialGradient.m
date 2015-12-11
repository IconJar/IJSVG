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
    // assume its a vertical / horizonal
    gradient.cx = [[[element attributeForName:@"cx"] stringValue] floatValue]/100;
    gradient.cy = [[[element attributeForName:@"cy"] stringValue] floatValue]/100;
    gradient.radius = [[[element attributeForName:@"r"] stringValue] floatValue]/100;
    gradient.fx = [[[element attributeForName:@"fx"] stringValue] floatValue]/100;
    gradient.fy = [[[element attributeForName:@"fy"] stringValue] floatValue]/100;
    
    // nothing has been specified, make it 50% for everything
    if( gradient.cx == 0.f && gradient.cy == 0.f
       && gradient.fx == 0.f && gradient.fy == 0.f
       && gradient.radius == 0.f )
    {
        gradient.cx = .5;
        gradient.cy = .5;
        gradient.radius = .5;
        gradient.fx = .5;
        gradient.fy = .5;
    }
    
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

- (void)drawInContextRef:(CGContextRef)ctx
                    path:(IJSVGPath *)path
{
    // apply any transforms to the current context
    CGRect bounds = path.path.bounds;
    CGContextTranslateCTM( ctx, bounds.origin.x, bounds.origin.y );
    
    for( IJSVGTransform * transform in self.transforms )
    {
        transform = [[transform copy] autorelease];
        [transform recalculateWithBounds:bounds];
        CGAffineTransform trans = transform.CGAffineTransform;
        CGContextConcatCTM(ctx, trans);
    }

    CGPoint sp = CGPointMake( bounds.size.width*self.cx, bounds.size.height*self.cy);
    CGPoint ep = CGPointMake( bounds.size.width*self.fx, bounds.size.height*self.fy);
    
    // draw the gradient
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation|kCGGradientDrawsAfterEndLocation;
    CGGradientRef grad = self.CGGradient;
    CGContextDrawRadialGradient(ctx, grad, sp, 0.f, ep, bounds.size.height*self.radius, options);
}

@end
