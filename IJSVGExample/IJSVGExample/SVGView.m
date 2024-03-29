//
//  SVGView.m
//  IJSVGExample
//
//  Created by Curtis Hard on 02/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "SVGView.h"

@implementation SVGView

- (id)initWithFrame:(NSRect)frameRect
{
    if( ( self = [super initWithFrame:frameRect] ) != nil ) {
        svg = [self svg];
        svg.renderQuality = kIJSVGRenderQualityFullResolution;
        svg.ignoreIntrinsicSize = YES;
        svg.renderingBackingScaleHelper = ^CGFloat {
            return NSScreen.mainScreen.backingScaleFactor;
        };
    }
    return self;
}

- (IJSVG *)svg
{
    return [IJSVG SVGNamed:@"Toucan in the Shade"];
}

- (void)drawRect:(NSRect)dirtyRect
{
    CGContextRef ref = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(ref);
    CGContextTranslateCTM( ref, 0, self.bounds.size.height);
    CGContextScaleCTM( ref, 1, -1 );
    [svg drawInRect:self.bounds];
    CGContextRestoreGState(ref);
}

@end
