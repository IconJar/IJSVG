//
//  IJSVGViewBox.m
//  IJSVG
//
//  Created by Curtis Hard on 14/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGViewBox.h"
#import "IJSVGStringAdditions.h"

@implementation IJSVGViewBox

+ (IJSVGViewBoxAlignment)alignmentForString:(NSString*)string
                                meetOrSlice:(IJSVGViewBoxMeetOrSlice*)meetOrSlice
{
    NSArray<NSString*>* parts = [string ijsvg_componentsSplitByWhiteSpace];
    if(parts.count == 1) {
        *meetOrSlice = IJSVGViewBoxMeetOrSliceMeet;
        return [self alignmentForString:parts[0]];
    }
    *meetOrSlice = [self meetOrSliceForString:parts[1]];
    return [self alignmentForString:parts[0]];
}

+ (IJSVGViewBoxMeetOrSlice)meetOrSliceForString:(NSString*)string
{
    if(string == nil) {
        return IJSVGViewBoxMeetOrSliceUnknown;
    }
    
    const char* name = string.lowercaseString.UTF8String;
    if(name == NULL) {
        return IJSVGViewBoxMeetOrSliceUnknown;
    }
    if(strcmp(name, "meet") == 0) {
        return IJSVGViewBoxMeetOrSliceMeet;
    }
    if(strcmp(name, "slice") == 0) {
        return IJSVGViewBoxMeetOrSliceSlice;
    }
    return IJSVGViewBoxMeetOrSliceUnknown;
}

+ (IJSVGViewBoxAlignment)alignmentForString:(NSString*)string
{
    if(string == nil) {
        return IJSVGViewBoxAlignmentUnknown;
    }
    
    const char* name = string.lowercaseString.UTF8String;
    if(name == NULL) {
        return IJSVGViewBoxAlignmentUnknown;
    }
    if(strcmp(name, "none") == 0) {
        return IJSVGViewBoxAlignmentNone;
    }
    if(strcmp(name, "xminymin") == 0) {
        return IJSVGViewBoxAlignmentXMinYMin;
    }
    if(strcmp(name, "xmidymin") == 0) {
        return IJSVGViewBoxAlignmentXMidYMin;
    }
    if(strcmp(name, "xmaxymin") == 0) {
        return IJSVGViewBoxAlignmentXMaxYMin;
    }
    if(strcmp(name, "xminymid") == 0) {
        return IJSVGViewBoxAlignmentXMinYMid;
    }
    if(strcmp(name, "xmidymid") == 0) {
        return IJSVGViewBoxAlignmentXMidYMid;
    }
    if(strcmp(name, "xmaxymid") == 0) {
        return IJSVGViewBoxAlignmentXMaxYMid;
    }
    if(strcmp(name, "xminymax") == 0) {
        return IJSVGViewBoxAlignmentXMinYMax;
    }
    if(strcmp(name, "xmidymax") == 0) {
        return IJSVGViewBoxAlignmentXMidYMax;
    }
    if(strcmp(name, "xmaxymax") == 0) {
        return IJSVGViewBoxAlignmentXMaxYMax;
    }
    return IJSVGViewBoxAlignmentUnknown;
}

void IJSVGViewBoxComputeXMidYMid(CGContextRef ctx, CGRect viewBox,
                                 CGRect drawingRect, CGRect contentBounds,
                                 IJSVGViewBoxMeetOrSlice meetOrSlice)
{
//    CGContextClipToRect(ctx, drawingRect);
//    CGFloat width = drawingRect.size.width / contentBounds.size.width;
//    CGFloat height = drawingRect.size.height / contentBounds.size.height;
//    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
//    CGAffineTransform transform = CGAffineTransformIdentity;
//    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
//    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(drawingRect.size.width / 2.f - ((contentBounds.size.width * ratio) / 2.f),
//                                                                                    drawingRect.size.height / 2.f - ((contentBounds.size.height * ratio) / 2.f)));
//    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(-(contentBounds.origin.x * ratio), -(contentBounds.origin.y * ratio)));
//    CGContextConcatCTM(ctx, transform);
//    viewBox = CGRectInset(viewBox, 10, 10);
////    CGContextClipToRect(ctx, viewBox);
//    CGContextSetFillColorWithColor(ctx, NSColor.redColor.CGColor);
//    CGContextFillRect(ctx, viewBox);
}

+ (void)drawViewBox:(CGRect)viewBox
             inRect:(CGRect)drawingRect
      contentBounds:(CGRect)bounds
          alignment:(IJSVGViewBoxAlignment)alignment
        meetOrSlice:(IJSVGViewBoxMeetOrSlice)meetOrSlice
          inContext:(CGContextRef)ctx
       drawingBlock:(dispatch_block_t)block
{
    // this is equal to none, dont do anything fancy
    if(CGRectIsNull(viewBox) == YES ||
       CGRectEqualToRect(viewBox, CGRectZero) == YES) {
        block();
        return;
    }
    
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, drawingRect);
    switch(alignment) {
        default:
        case IJSVGViewBoxAlignmentXMidYMid: {
            IJSVGViewBoxComputeXMidYMid(ctx, viewBox, drawingRect,
                                        bounds, meetOrSlice);
            break;
        }
    }
    block();
    CGContextRestoreGState(ctx);
}

@end
