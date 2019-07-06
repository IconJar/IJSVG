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
            unit = [IJSVGUnitLength unitWithString:str
                                      fromUnitType:gradient.units];
        } else {
            // spec says to say 50% for missing property default
            unit = [IJSVGUnitLength unitWithPercentageFloat:.5f];
        }
        [gradient setValue:unit
                    forKey:kv[key]];
    }
    
    // fx and fy are the same unless specified otherwise
    gradient.fx = gradient.cx;
    gradient.fy = gradient.cy;
    
    // needs fixing
    NSString * fx = [element attributeForName:@"fx"].stringValue;
    if(fx != nil) {
        gradient.fx = [IJSVGUnitLength unitWithString:fx
                                         fromUnitType:gradient.units];
    }
    
    NSString * fy = [element attributeForName:@"fy"].stringValue;
    if(fx != nil) {
        gradient.fy = [IJSVGUnitLength unitWithString:fy
                                         fromUnitType:gradient.units];
    }
  
    if( gradient.gradient != nil ) {
        return nil;
    }
    
    NSArray * colors = nil;
    CGFloat * colorStops = [self.class computeColorStopsFromString:element colors:&colors];
    NSGradient * ret = [[[NSGradient alloc] initWithColors:colors
                                               atLocations:colorStops
                                                colorSpace:IJSVGColor.defaultColorSpace] autorelease];
    free(colorStops);
    return ret;
}

- (void)drawInContextRef:(CGContextRef)ctx
              objectRect:(NSRect)objectRect
       absoluteTransform:(CGAffineTransform)absoluteTransform
                viewPort:(CGRect)viewBox
{
    BOOL inUserSpace = self.units == IJSVGUnitUserSpaceOnUse;
    CGFloat radius = 0.f;
    CGPoint startPoint = CGPointZero;
    CGPoint gradientStartPoint = CGPointZero;
    CGPoint gradientEndPoint = CGPointZero;
    
    // transforms
    CGAffineTransform selfTransform = IJSVGConcatTransforms(self.transforms);
    
    CGRect boundingBox = inUserSpace ? viewBox : objectRect;
    
    // make sure we apply the absolute position to
    // transform us back into the correct space
    if(inUserSpace == YES) {
        CGContextConcatCTM(ctx, absoluteTransform);
    }
    
    
    // compute size based on percentages
    CGFloat x = [self.cx computeValue:CGRectGetWidth(boundingBox)];
    CGFloat y = [self.cy computeValue:CGRectGetHeight(boundingBox)];
    startPoint = CGPointMake(x, y);
    CGFloat val = MIN(CGRectGetWidth(boundingBox),
                      CGRectGetHeight(boundingBox));
    radius = [self.radius computeValue:val];
    
    CGFloat ex = [self.fx computeValue:CGRectGetWidth(boundingBox)];
    CGFloat ey = [self.fy computeValue:CGRectGetHeight(boundingBox)];
    
    gradientEndPoint = CGPointMake(ex, ey);
    gradientStartPoint = startPoint;
    
    // transform if width or height is not equal - this can only
    // be done if we are using objectBoundingBox
    if(inUserSpace == NO && CGRectGetWidth(boundingBox) != CGRectGetHeight(boundingBox)) {
        CGAffineTransform tr = CGAffineTransformMakeTranslation(gradientStartPoint.x,
                                                                gradientStartPoint.y);
        if(CGRectGetWidth(boundingBox) > CGRectGetHeight(boundingBox)) {
            tr = CGAffineTransformScale(tr, CGRectGetWidth(boundingBox)/CGRectGetHeight(boundingBox), 1);
        } else {
            tr = CGAffineTransformScale(tr, 1.f, CGRectGetHeight(boundingBox)/CGRectGetWidth(boundingBox));
        }
        tr = CGAffineTransformTranslate(tr, -gradientStartPoint.x, -gradientStartPoint.y);
        selfTransform = CGAffineTransformConcat(tr, selfTransform);
    }

    // transform the context
    CGContextConcatCTM(ctx, selfTransform);

    // draw the gradient
    CGGradientDrawingOptions options =
        kCGGradientDrawsBeforeStartLocation|
        kCGGradientDrawsAfterEndLocation;
    CGContextDrawRadialGradient(ctx, self.CGGradient,
                                gradientEndPoint, 0,
                                gradientStartPoint,
                                radius, options);
    
#ifdef IJSVG_DEBUG_GRADIENTS
    [self _debugStart:gradientStartPoint
                  end:gradientEndPoint
              context:ctx];
#endif
}

@end
