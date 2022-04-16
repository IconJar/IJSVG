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
                                 CGRect drawingRect, IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(drawingRect.size.width / 2.f - (viewBox.size.width * ratio) / 2.f,
                                                                   drawingRect.size.height / 2.f - (viewBox.size.height * ratio) / 2.f);
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    CGContextConcatCTM(ctx, transform);
}

void IJSVGViewBoxComputeXMinYMid(CGContextRef ctx, CGRect viewBox,
                                 CGRect drawingRect, IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(0.f,
                                                                   drawingRect.size.height / 2.f - ((viewBox.size.height * ratio)) / 2.f);
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    CGContextConcatCTM(ctx, transform);
}

void IJSVGViewBoxComputeXMaxYMid(CGContextRef ctx, CGRect viewBox,
                                 CGRect drawingRect, IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(drawingRect.size.width - (viewBox.size.width * ratio),
                                                                   drawingRect.size.height / 2.f - ((viewBox.size.height * ratio)) / 2.f);
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    CGContextConcatCTM(ctx, transform);
}

void IJSVGViewBoxComputeXMidYMin(CGContextRef ctx, CGRect viewBox,
                                 CGRect drawingRect, IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(drawingRect.size.width / 2.f - ((viewBox.size.width * ratio)) / 2.f,
                                                                   0.f);
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    CGContextConcatCTM(ctx, transform);
}

void IJSVGViewBoxComputeXMinYMin(CGContextRef ctx, CGRect viewBox,
                                 CGRect drawingRect, IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(0.f, 0.f);
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    CGContextConcatCTM(ctx, transform);
}

void IJSVGViewBoxComputeXMidYMax(CGContextRef ctx, CGRect viewBox,
                                 CGRect drawingRect, IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(drawingRect.size.width / 2.f - ((viewBox.size.width * ratio)) / 2.f,
                                                                   drawingRect.size.height - (viewBox.size.height * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    CGContextConcatCTM(ctx, transform);
}

void IJSVGViewBoxComputeXMaxYMin(CGContextRef ctx, CGRect viewBox,
                                 CGRect drawingRect, IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(drawingRect.size.width - viewBox.size.width,
                                                                   0.f);
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    CGContextConcatCTM(ctx, transform);
}

void IJSVGViewBoxComputeXMinYMax(CGContextRef ctx, CGRect viewBox,
                                 CGRect drawingRect, IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(0.f,
                                                                   drawingRect.size.height - viewBox.size.height);
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    CGContextConcatCTM(ctx, transform);
}

void IJSVGViewBoxComputeXMaxYMax(CGContextRef ctx, CGRect viewBox,
                                 CGRect drawingRect, IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(drawingRect.size.width - viewBox.size.width,
                                                                   drawingRect.size.height - viewBox.size.height);
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    CGContextConcatCTM(ctx, transform);
}

void IJSVGViewBoxComputeNone(CGContextRef ctx, CGRect viewBox,
                             CGRect drawingRect, IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(width, height));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(drawingRect.size.width / 2.f - ((viewBox.size.width * width)) / 2.f,
                                                                   drawingRect.size.height - (viewBox.size.height * height));
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * width),
                                                 -(viewBox.origin.y * height));
    transform = CGAffineTransformConcat(transform, translate);
    CGContextConcatCTM(ctx, transform);
}

+ (void)drawViewBox:(CGRect)viewBox
             inRect:(CGRect)drawingRect
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
    if(meetOrSlice == IJSVGViewBoxMeetOrSliceSlice) {
        CGContextClipToRect(ctx, drawingRect);
    }
    switch(alignment) {
        case IJSVGViewBoxAlignmentNone: {
            IJSVGViewBoxComputeNone(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentUnknown:
        case IJSVGViewBoxAlignmentXMidYMid: {
            IJSVGViewBoxComputeXMidYMid(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMid: {
            IJSVGViewBoxComputeXMinYMid(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMid: {
            IJSVGViewBoxComputeXMaxYMid(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMidYMin: {
            IJSVGViewBoxComputeXMidYMin(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMidYMax: {
            IJSVGViewBoxComputeXMidYMax(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMin: {
            IJSVGViewBoxComputeXMinYMin(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMin: {
            IJSVGViewBoxComputeXMaxYMin(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMax: {
            IJSVGViewBoxComputeXMinYMax(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMax: {
            IJSVGViewBoxComputeXMaxYMax(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
    }
    block();
    CGContextRestoreGState(ctx);
}

@end
