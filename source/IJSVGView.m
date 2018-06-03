//
//  IJSVGView.m
//  IconJar
//
//  Created by Curtis Hard on 04/04/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGView.h"

@implementation IJSVGView

@synthesize SVG;

- (void)dealloc
{
    // make sure we call this, or block may get called for a view
    // that doesnt exist
    [SVG prepForDrawingInView:nil];
    [imageName release], imageName = nil;
    [SVG release], SVG = nil;
    [super dealloc];
}

+ (IJSVGView *)viewWithSVGNamed:(NSString *)name
{
    IJSVG * anSVG = [IJSVG svgNamed:name];
    return [[[self alloc] initWithSVG:anSVG] autorelease];
}

- (id)initWithSVG:(IJSVG *)anSvg
{
    if((self = [super init]) != nil) {
        self.SVG = anSvg;
    }
    return self;
}

- (void)awakeFromNib
{
    // image was set via IB
    if(imageName != nil) {
        IJSVG * anSVG = [IJSVG svgNamed:imageName];
        self.SVG = anSVG;
    }
}

- (void)setSVG:(IJSVG *)anSVG
{
    // memory clean
    if(SVG != nil) {
        [SVG release], SVG = nil;
    }
    SVG = [anSVG retain];
    
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
    if(self.SVG == nil) {
        return;
    }
    
    // draw the svg
    [self.SVG drawInRect:self.bounds];
}

@end
