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

CGRect IJSVGViewBoxComputeRectXMidYMid(CGRect viewBox, CGRect drawingRect,
                                       IJSVGViewBoxMeetOrSlice meetOrSlice,
                                       CGFloat* scale)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    if(scale != NULL) {
        scale[0] = ratio;
        scale[1] = ratio;
    }
    
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
    return CGRectApplyAffineTransform(drawingRect, transform);
}

CGRect IJSVGViewBoxComputeRectXMinYMid(CGRect viewBox, CGRect drawingRect,
                                       IJSVGViewBoxMeetOrSlice meetOrSlice,
                                       CGFloat* scale)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    if(scale != NULL) {
        scale[0] = ratio;
        scale[1] = ratio;
    }
    
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
    return CGRectApplyAffineTransform(drawingRect, transform);
}

CGRect IJSVGViewBoxComputeRectXMaxYMid(CGRect viewBox, CGRect drawingRect,
                                       IJSVGViewBoxMeetOrSlice meetOrSlice,
                                       CGFloat* scale)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    if(scale != NULL) {
        scale[0] = ratio;
        scale[1] = ratio;
    }
    
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
    return CGRectApplyAffineTransform(drawingRect, transform);
}

CGRect IJSVGViewBoxComputeRectXMidYMin(CGRect viewBox, CGRect drawingRect,
                                       IJSVGViewBoxMeetOrSlice meetOrSlice,
                                       CGFloat* scale)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    if(scale != NULL) {
        scale[0] = ratio;
        scale[1] = ratio;
    }
    
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
    return CGRectApplyAffineTransform(drawingRect, transform);
}

CGRect IJSVGViewBoxComputeRectXMinYMin(CGRect viewBox, CGRect drawingRect,
                                       IJSVGViewBoxMeetOrSlice meetOrSlice,
                                       CGFloat* scale)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    if(scale != NULL) {
        scale[0] = ratio;
        scale[1] = ratio;
    }
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(0.f, 0.f);
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    return CGRectApplyAffineTransform(drawingRect, transform);
}

CGRect IJSVGViewBoxComputeRectXMidYMax(CGRect viewBox, CGRect drawingRect,
                                       IJSVGViewBoxMeetOrSlice meetOrSlice,
                                       CGFloat* scale)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    if(scale != NULL) {
        scale[0] = ratio;
        scale[1] = ratio;
    }
    
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
    return CGRectApplyAffineTransform(drawingRect, transform);
}

CGRect IJSVGViewBoxComputeRectXMaxYMin(CGRect viewBox, CGRect drawingRect,
                                       IJSVGViewBoxMeetOrSlice meetOrSlice,
                                       CGFloat* scale)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    if(scale != NULL) {
        scale[0] = ratio;
        scale[1] = ratio;
    }
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(drawingRect.size.width - (viewBox.size.width * ratio),
                                                                   0.f);
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    return CGRectApplyAffineTransform(drawingRect, transform);
}

CGRect IJSVGViewBoxComputeRectXMinYMax(CGRect viewBox, CGRect drawingRect,
                                       IJSVGViewBoxMeetOrSlice meetOrSlice,
                                       CGFloat* scale)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    if(scale != NULL) {
        scale[0] = ratio;
        scale[1] = ratio;
    }
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(0.f,
                                                                   drawingRect.size.height - (viewBox.size.height * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    return CGRectApplyAffineTransform(drawingRect, transform);
}

CGRect IJSVGViewBoxComputeRectXMaxYMax(CGRect viewBox, CGRect drawingRect,
                                       IJSVGViewBoxMeetOrSlice meetOrSlice,
                                       CGFloat* scale)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    if(scale != NULL) {
        scale[0] = ratio;
        scale[1] = ratio;
    }
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGAffineTransform translate = CGAffineTransformMakeTranslation(drawingRect.size.width - (viewBox.size.width * ratio),
                                                                   drawingRect.size.height - (viewBox.size.height * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    translate = CGAffineTransformMakeTranslation(-(viewBox.origin.x * ratio),
                                                 -(viewBox.origin.y * ratio));
    transform = CGAffineTransformConcat(transform, translate);
    return CGRectApplyAffineTransform(drawingRect, transform);
}

CGRect IJSVGViewBoxComputeRectNone(CGRect viewBox, CGRect drawingRect,
                                   IJSVGViewBoxMeetOrSlice meetOrSlice,
                                   CGFloat* scale)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    
    if(scale != NULL) {
        scale[0] = width;
        scale[1] = height;
    }
    
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
    return CGRectApplyAffineTransform(drawingRect, transform);
}

CGRect IJSVGContextViewBoxConcatNone(CGContextRef ctx, CGRect viewBox,
                                     CGRect drawingRect, IJSVGViewBoxMeetOrSlice meetOrSlice,
                                     CGFloat* scale)
{
    CGFloat ratioX = 1.f;
    CGFloat ratioY = 1.f;
    CGRect rect = IJSVGViewBoxComputeRectNone(viewBox, drawingRect, meetOrSlice, scale);
    CGContextTranslateCTM(ctx, rect.origin.x, rect.origin.y);
    CGContextScaleCTM(ctx, ratioX, ratioY);
    return rect;
}

CGRect IJSVGContextViewBoxConcat(CGContextRef ctx, IJSVGViewBoxComputeRectFunction function,
                                 CGRect viewBox, CGRect drawingRect,
                                 IJSVGViewBoxMeetOrSlice meetOrSlice,
                                 CGFloat* scale)
{
    CGRect rect = function(viewBox, drawingRect, meetOrSlice, scale);
    CGContextTranslateCTM(ctx, rect.origin.x, rect.origin.y);
    CGContextScaleCTM(ctx, scale[0], scale[1]);
    return rect;
}

void IJSVGContextDrawViewBox(CGContextRef ctx, CGRect viewBox, CGRect boundingBox,
                      IJSVGViewBoxAlignment alignment, IJSVGViewBoxMeetOrSlice meetOrSlice,
                      IJSVGViewBoxDrawingBlock block) {
    [IJSVGViewBox drawViewBox:viewBox
                       inRect:boundingBox
                    alignment:alignment
                  meetOrSlice:meetOrSlice
                    inContext:ctx
                 drawingBlock:block];
}

CGRect IJSVGViewBoxComputeRect(CGRect viewBox, CGRect drawingRect, IJSVGViewBoxAlignment alignment,
                               IJSVGViewBoxMeetOrSlice meetOrSlice, CGFloat* scale)
{
    switch(alignment) {
        default:
        case IJSVGViewBoxAlignmentUnknown:
        case IJSVGViewBoxAlignmentXMidYMid: {
            return IJSVGViewBoxComputeRectXMidYMid(viewBox, drawingRect,
                                                   meetOrSlice, scale);
        }
        case IJSVGViewBoxAlignmentNone: {
            return IJSVGViewBoxComputeRectNone(viewBox, drawingRect,
                                               meetOrSlice, scale);
        }
        case IJSVGViewBoxAlignmentXMaxYMax: {
            return IJSVGViewBoxComputeRectXMaxYMax(viewBox, drawingRect,
                                                   meetOrSlice, scale);
        }
        case IJSVGViewBoxAlignmentXMaxYMid: {
            return IJSVGViewBoxComputeRectXMaxYMid(viewBox, drawingRect,
                                                   meetOrSlice, scale);
        }
        case IJSVGViewBoxAlignmentXMaxYMin: {
            return IJSVGViewBoxComputeRectXMaxYMin(viewBox, drawingRect,
                                                   meetOrSlice, scale);
        }
        case IJSVGViewBoxAlignmentXMidYMax: {
            return IJSVGViewBoxComputeRectXMidYMax(viewBox, drawingRect,
                                                   meetOrSlice, scale);
        }
        case IJSVGViewBoxAlignmentXMidYMin: {
            return IJSVGViewBoxComputeRectXMidYMin(viewBox, drawingRect,
                                                   meetOrSlice, scale);
        }
        case IJSVGViewBoxAlignmentXMinYMax: {
            return IJSVGViewBoxComputeRectXMinYMin(viewBox, drawingRect,
                                                   meetOrSlice, scale);
        }
        case IJSVGViewBoxAlignmentXMinYMid: {
            return IJSVGViewBoxComputeRectXMinYMid(viewBox, drawingRect,
                                                   meetOrSlice, scale);
        }
        case IJSVGViewBoxAlignmentXMinYMin: {
            return IJSVGViewBoxComputeRectXMinYMin(viewBox, drawingRect,
                                                   meetOrSlice, scale);
        }
    }
    return CGRectNull;
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
        return;
    }
    
    CGContextSaveGState(ctx);
    if(meetOrSlice == IJSVGViewBoxMeetOrSliceSlice) {
        CGContextClipToRect(ctx, drawingRect);
    }
    
    // init the scaler
    CGFloat* scale = (CGFloat*)malloc(sizeof(CGFloat)*2);
    scale[0] = 1.f;
    scale[1] = 1.f;
    
    CGRect computedRect = CGRectNull;
    switch(alignment) {
        case IJSVGViewBoxAlignmentNone: {
            computedRect = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectNone,
                                                     viewBox, drawingRect, meetOrSlice,
                                                     scale);
            break;
        }
        case IJSVGViewBoxAlignmentUnknown:
        case IJSVGViewBoxAlignmentXMidYMid: {
            computedRect = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMidYMid,
                                                     viewBox, drawingRect, meetOrSlice,
                                                     scale);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMid: {
            computedRect = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMinYMid,
                                                     viewBox, drawingRect, meetOrSlice,
                                                     scale);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMid: {
            computedRect = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMaxYMid,
                                                     viewBox, drawingRect, meetOrSlice,
                                                     scale);
            break;
        }
        case IJSVGViewBoxAlignmentXMidYMin: {
            computedRect = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMidYMin,
                                                     viewBox, drawingRect, meetOrSlice,
                                                     scale);
            break;
        }
        case IJSVGViewBoxAlignmentXMidYMax: {
            computedRect = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMidYMax,
                                                     viewBox, drawingRect, meetOrSlice,
                                                     scale);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMin: {
            computedRect = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMinYMin,
                                                     viewBox, drawingRect, meetOrSlice,
                                                     scale);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMin: {
            computedRect = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMaxYMin,
                                                     viewBox, drawingRect, meetOrSlice,
                                                     scale);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMax: {
            computedRect = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMinYMax,
                                                     viewBox, drawingRect, meetOrSlice,
                                                     scale);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMax: {
            computedRect = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMaxYMax,
                                                     viewBox, drawingRect, meetOrSlice,
                                                     scale);
            break;
        }
    }
    block(computedRect, scale);
    free(scale);
    CGContextRestoreGState(ctx);
}

@end
