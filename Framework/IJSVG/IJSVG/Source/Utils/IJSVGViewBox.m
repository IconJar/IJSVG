//
//  IJSVGViewBox.m
//  IJSVG
//
//  Created by Curtis Hard on 14/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGViewBox.h>
#import <IJSVG/IJSVGStringAdditions.h>

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

CGSize IJSVGViewBoxComputeXMidYMid(CGContextRef ctx, CGRect viewBox,
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
    
    return CGSizeMake(ratio, ratio);
}

CGSize IJSVGViewBoxComputeXMinYMid(CGContextRef ctx, CGRect viewBox,
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
    
    return CGSizeMake(ratio, ratio);
}

CGSize IJSVGViewBoxComputeXMaxYMid(CGContextRef ctx, CGRect viewBox,
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
    
    return CGSizeMake(ratio, ratio);
}

CGSize IJSVGViewBoxComputeXMidYMin(CGContextRef ctx, CGRect viewBox,
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
    
    return CGSizeMake(ratio, ratio);
}

CGSize IJSVGViewBoxComputeXMinYMin(CGContextRef ctx, CGRect viewBox,
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
    
    return CGSizeMake(ratio, ratio);
}

CGSize IJSVGViewBoxComputeXMidYMax(CGContextRef ctx, CGRect viewBox,
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
    
    return CGSizeMake(ratio, ratio);
}

CGSize IJSVGViewBoxComputeXMaxYMin(CGContextRef ctx, CGRect viewBox,
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
    
    return CGSizeMake(ratio, ratio);
}

CGSize IJSVGViewBoxComputeXMinYMax(CGContextRef ctx, CGRect viewBox,
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
    
    return CGSizeMake(ratio, ratio);
}

CGSize IJSVGViewBoxComputeXMaxYMax(CGContextRef ctx, CGRect viewBox,
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
    
    return CGSizeMake(ratio, ratio);
}

CGSize IJSVGViewBoxComputeNone(CGContextRef ctx, CGRect viewBox,
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
    
    return CGSizeMake(width, height);
}

+ (void)drawViewBox:(CGRect)viewBox
             inRect:(CGRect)drawingRect
          alignment:(IJSVGViewBoxAlignment)alignment
        meetOrSlice:(IJSVGViewBoxMeetOrSlice)meetOrSlice
          inContext:(CGContextRef)ctx
       drawingBlock:(IJSVGViewBoxDrawingBlock)block
{
    // this is equal to none, dont do anything fancy
    if(CGRectIsNull(viewBox) == YES ||
       CGRectEqualToRect(viewBox, CGRectZero) == YES) {
        block(CGSizeMake(1.f, 1.f));
        return;
    }
    
    CGContextSaveGState(ctx);
    if(meetOrSlice == IJSVGViewBoxMeetOrSliceSlice) {
        CGContextClipToRect(ctx, drawingRect);
    }
    CGSize scale = CGSizeZero;
    switch(alignment) {
        case IJSVGViewBoxAlignmentNone: {
            scale = IJSVGViewBoxComputeNone(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentUnknown:
        case IJSVGViewBoxAlignmentXMidYMid: {
            scale = IJSVGViewBoxComputeXMidYMid(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMid: {
            scale = IJSVGViewBoxComputeXMinYMid(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMid: {
            scale = IJSVGViewBoxComputeXMaxYMid(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMidYMin: {
            scale = IJSVGViewBoxComputeXMidYMin(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMidYMax: {
            scale = IJSVGViewBoxComputeXMidYMax(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMin: {
            scale = IJSVGViewBoxComputeXMinYMin(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMin: {
            scale = IJSVGViewBoxComputeXMaxYMin(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMax: {
            scale = IJSVGViewBoxComputeXMinYMax(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMax: {
            scale = IJSVGViewBoxComputeXMaxYMax(ctx, viewBox, drawingRect, meetOrSlice);
            break;
        }
    }
    block(scale);
    CGContextRestoreGState(ctx);
}

@end
