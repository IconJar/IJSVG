//
//  IJSVGView.m
//  IconJar
//
//  Created by Curtis Hard on 04/04/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGView.h>

@implementation IJSVGView

@synthesize SVG;

- (void)dealloc
{
    // make sure we call this, or block may get called for a view
    // that doesnt exist
    [SVG prepForDrawingInView:nil];
}

+ (IJSVGView*)viewWithSVGNamed:(NSString*)name
{
    IJSVG* anSVG = [IJSVG svgNamed:name];
    return [[self alloc] initWithSVG:anSVG];
}

- (id)initWithSVG:(IJSVG*)anSvg
{
    if ((self = [super init]) != nil) {
        self.SVG = anSvg;
    }
    return self;
}

- (void)awakeFromNib
{
    // image was set via IB
    if (imageName != nil) {
        IJSVG* anSVG = [IJSVG svgNamed:imageName];
        if (tintColor != nil) {
            anSVG.renderingStyle.fillColor = tintColor;
        }
        self.SVG = anSVG;
    }
}

- (void)setSVG:(IJSVG*)anSVG
{
    // memory clean
    SVG = anSVG;

    // redisplay ourself!
    [SVG prepForDrawingInView:self];
    [self setNeedsDisplay:YES];
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // only draw if there is actually an SVG
    if (self.SVG == nil) {
        return;
    }

    // draw the svg
    [self.SVG drawInRect:self.bounds];
}

@end
