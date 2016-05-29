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
    
    // assume its a vertical / horizonal
    aGradient.x1 = IJSVGUnitFromString([[element attributeForName:@"x1"] stringValue]);
    aGradient.x2 = IJSVGUnitFromString([[element attributeForName:@"x2"] stringValue]);
    aGradient.y1 = IJSVGUnitFromString([[element attributeForName:@"y1"] stringValue]);
    aGradient.y2 = IJSVGUnitFromString([[element attributeForName:@"y2"] stringValue]);
//    
//    *startPoint = CGPointMake(x1, y1);
//    *endPoint = CGPointMake(x2, y2);
//    
//    // horizontal
//    if( y1 == y2 && x1 != x2 )
//        aGradient.angle = 0.f;
//    
//    // vertical
//    else if( x1 == x2 && y1 != y2 )
//        aGradient.angle = 270.f;
//    
//    // angles
//    else if( x1 != x2 && y1 != y2 )
//        aGradient.angle = [IJSVGUtils angleBetweenPointA:NSMakePoint( x1, y1 )
//                                                  pointb:NSMakePoint( x2, y2 )];
    
    // compute the color stops and colours
    NSArray * colors = nil;
    CGFloat * stopsParams = [[self class] computeColorStopsFromString:element
                                                               colors:&colors];
    
    // create the gradient with the colours
    NSGradient * grad = [[[NSGradient alloc] initWithColors:colors
                                               atLocations:stopsParams
                                                colorSpace:[NSColorSpace genericRGBColorSpace]] autorelease];
    
    free(stopsParams);
    return grad;
}

- (void)drawInContextRef:(CGContextRef)ctx
                    path:(IJSVGPath *)path
{
    // grab the start and end point
    CGPoint aStartPoint = CGPointMake(IJSVGFloatFromUnit(x1, path, YES), IJSVGFloatFromUnit(y1, path, NO));
    CGPoint aEndPoint = CGPointMake(IJSVGFloatFromUnit(x2, path, YES), IJSVGFloatFromUnit(y2, path, NO));
    
    // convert the nsgradient to a CGGradient
    CGGradientRef gRef = [self CGGradient];
    
    // apply transform for each point
    for( IJSVGTransform * transform in self.transforms ) {
        CGAffineTransform trans = transform.CGAffineTransform;
        aStartPoint = CGPointApplyAffineTransform(aStartPoint, trans);
        aEndPoint = CGPointApplyAffineTransform(aEndPoint, trans);
    }
    
    // we need to move the context into the path coordinate space - so save the state!
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, path.path.bounds.origin.x, path.path.bounds.origin.y);
    
    // draw the gradient
    CGGradientDrawingOptions opt = kCGGradientDrawsBeforeStartLocation|kCGGradientDrawsAfterEndLocation;
    CGContextDrawLinearGradient(ctx, gRef, aStartPoint, aEndPoint, opt);
    
    // restore the state
    CGContextRestoreGState(ctx);
}

@end
