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
        
        // dont need the dom, so clean it
        [anSVG discardDOM];
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
    
    // make sure we tell the SVG about the scale of the window
    __block IJSVGView * weakSelf = self;
    SVG.renderingBackingScaleHelper = ^CGFloat{
        return weakSelf.window.screen.backingScaleFactor;
    };
    
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
