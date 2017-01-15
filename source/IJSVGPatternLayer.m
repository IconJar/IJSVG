//
//  IJSVGPatternLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGPatternLayer.h"

@implementation IJSVGPatternLayer

@synthesize pattern;
@synthesize patternNode;

- (void)dealloc
{
    [pattern release], pattern = nil;
    [patternNode release], patternNode = nil;
    [super dealloc];
}

- (id)init
{
    if((self = [super init]) != nil) {
        self.requiresBackingScaleHelp = YES;
    }
    return self;
}

void IJSVGPatternDrawingCallBack(void * info, CGContextRef ctx) {
    // reassign the layer
    IJSVGPatternLayer * layer = (IJSVGPatternLayer *)info;
    [layer.pattern renderInContext:ctx];
};

- (void)drawInContext:(CGContextRef)ctx
{
    // holder for callback
    static const CGPatternCallbacks callbacks = {0, &IJSVGPatternDrawingCallBack, NULL};
    
    // create base pattern space
    CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern(NULL);
    CGContextSetFillColorSpace(ctx, patternSpace);
    CGColorSpaceRelease(patternSpace);
    
    // create the pattern
    CGRect rect = self.bounds;
    CGPatternRef ref = CGPatternCreate( (void *)self, self.bounds,
                                       CGAffineTransformIdentity,
                                       roundf(rect.size.width*self.patternNode.width.value),
                                       roundf(rect.size.height*self.patternNode.height.value),
                                       kCGPatternTilingConstantSpacing,
                                       true, &callbacks);
    
    // set the pattern then release it
    CGFloat alpha = 1.f;
    CGContextSetFillPattern(ctx, ref, &alpha);
    CGPatternRelease(ref);
    
    // fill it
    CGContextFillRect(ctx, rect);
}

@end
