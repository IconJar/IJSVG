//
//  IJSVGPatternLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGPatternLayer.h"

@implementation IJSVGPatternLayer

- (void)dealloc
{
    (void)([_pattern release]), _pattern = nil;
    (void)([_patternNode release]), _patternNode = nil;
    [super dealloc];
}

- (id)init
{
    if ((self = [super init]) != nil) {
        self.requiresBackingScaleHelp = YES;
        self.shouldRasterize = YES;
    }
    return self;
}

void IJSVGPatternDrawingCallBack(void* info, CGContextRef ctx)
{
    // reassign the layer
    IJSVGPatternLayer* layer = (IJSVGPatternLayer*)info;
    [layer.pattern renderInContext:ctx];
};

- (void)drawInContext:(CGContextRef)ctx
{
    // holder for callback
    static const CGPatternCallbacks callbacks = { 0, &IJSVGPatternDrawingCallBack, NULL };
    BOOL inUserSpace = self.patternNode.contentUnits == IJSVGUnitUserSpaceOnUse;

    // create base pattern space
    CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern(NULL);
    CGContextSetFillColorSpace(ctx, patternSpace);
    CGColorSpaceRelease(patternSpace);
    
    CGRect rect = self.bounds;
    CGRect boundingBox = inUserSpace ? _viewBox : _objectRect;
    
    IJSVGUnitLength* wLength = [IJSVGUnitLength unitWithFloat:_patternNode.width.value
                                                         type:IJSVGUnitLengthTypePercentage];
    IJSVGUnitLength* hLength = [IJSVGUnitLength unitWithFloat:_patternNode.height.value
                                                         type:IJSVGUnitLengthTypePercentage];
    
    CGFloat width = [wLength computeValue:rect.size.width];
    CGFloat height = [hLength computeValue:rect.size.height];

    // make sure we apply the absolute position to
    // transform us back into the correct space
    if (inUserSpace == YES) {
        CGContextConcatCTM(ctx, _absoluteTransform);
    }

    // create the pattern
    CGPatternRef ref = CGPatternCreate((void*)self, rect,
        CGAffineTransformIdentity,
        width,
        height,
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
