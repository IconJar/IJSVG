//
//  IJSVGViewBox.m
//  IJSVG
//
//  Created by Curtis Hard on 14/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGViewBox.h>
#import <IJSVG/IJSVGStringAdditions.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGViewBox

+ (NSString*)aspectRatioWithAlignment:(IJSVGViewBoxAlignment)alignment
                          meetOrSlice:(IJSVGViewBoxMeetOrSlice)meetOrSlice
{
    NSString* str = nil;
    switch(alignment) {
        default:
        case IJSVGViewBoxAlignmentUnknown: {
            return nil;
        }
        case IJSVGViewBoxAlignmentNone: {
            return IJSVGStringNone;
        }
        case IJSVGViewBoxAlignmentXMinYMin: {
            str = @"xMinYMin";
            break;
        }
        case IJSVGViewBoxAlignmentXMidYMin: {
            str = @"xMidYMin";
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMin: {
            str = @"xMaxYMin";
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMid: {
            str = @"xMinYMid";
            break;
        }
        case IJSVGViewBoxAlignmentXMidYMid: {
            str = @"xMidYMid";
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMid: {
            str = @"xMaxYMid";
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMax: {
            str = @"xMinYMax";
            break;
        }
        case IJSVGViewBoxAlignmentXMidYMax: {
            str = @"xMidYMax";
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMax: {
            str = @"xMaxYMax";
            break;
        }
    }
    if(meetOrSlice == IJSVGViewBoxMeetOrSliceMeet) {
        return str;
    }
    return [str stringByAppendingString:@" slice"];
}

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

    const char* name = string.UTF8String;
    if(name == NULL) {
        return IJSVGViewBoxMeetOrSliceUnknown;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "meet") == YES) {
        return IJSVGViewBoxMeetOrSliceMeet;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "slice") == YES) {
        return IJSVGViewBoxMeetOrSliceSlice;
    }
    return IJSVGViewBoxMeetOrSliceUnknown;
}

+ (IJSVGViewBoxAlignment)alignmentForString:(NSString*)string
{
    if(string == nil) {
        return IJSVGViewBoxAlignmentUnknown;
    }

    const char* name = string.UTF8String;
    if(name == NULL) {
        return IJSVGViewBoxAlignmentUnknown;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "none") == YES) {
        return IJSVGViewBoxAlignmentNone;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "xminymin") == YES) {
        return IJSVGViewBoxAlignmentXMinYMin;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "xmidymin") == YES) {
        return IJSVGViewBoxAlignmentXMidYMin;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "xmaxymin") == YES) {
        return IJSVGViewBoxAlignmentXMaxYMin;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "xminymid") == YES) {
        return IJSVGViewBoxAlignmentXMinYMid;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "xmidymid") == YES) {
        return IJSVGViewBoxAlignmentXMidYMid;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "xmaxymid") == YES) {
        return IJSVGViewBoxAlignmentXMaxYMid;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "xminymax") == YES) {
        return IJSVGViewBoxAlignmentXMinYMax;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "xmidymax") == YES) {
        return IJSVGViewBoxAlignmentXMidYMax;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "xmaxymax") == YES) {
        return IJSVGViewBoxAlignmentXMaxYMax;
    }
    return IJSVGViewBoxAlignmentUnknown;
}

static void IJSVGViewBoxAlignmentFactors(IJSVGViewBoxAlignment alignment,
                                         CGFloat* fx, CGFloat* fy)
{
    switch(alignment) {
        case IJSVGViewBoxAlignmentXMinYMin:
            *fx = 0.f;
            *fy = 0.f;
            break;
        case IJSVGViewBoxAlignmentXMidYMin:
            *fx = .5f;
            *fy = 0.f;
            break;
        case IJSVGViewBoxAlignmentXMaxYMin:
            *fx = 1.f;
            *fy = 0.f;
            break;
        case IJSVGViewBoxAlignmentXMinYMid:
            *fx = 0.f;
            *fy = .5f;
            break;
        case IJSVGViewBoxAlignmentXMaxYMid:
            *fx = 1.f;
            *fy = .5f;
            break;
        case IJSVGViewBoxAlignmentXMinYMax:
            *fx = 0.f;
            *fy = 1.f;
            break;
        case IJSVGViewBoxAlignmentXMidYMax:
            *fx = .5f;
            *fy = 1.f;
            break;
        case IJSVGViewBoxAlignmentXMaxYMax:
            *fx = 1.f;
            *fy = 1.f;
            break;
        default:
            *fx = .5f;
            *fy = .5f;
            break;
    }
}

CGAffineTransform IJSVGViewBoxComputeTransform(CGRect viewBox, CGRect drawingRect,
                                               IJSVGViewBoxAlignment alignment,
                                               IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat scaleX = drawingRect.size.width / viewBox.size.width;
    CGFloat scaleY = drawingRect.size.height / viewBox.size.height;

    // 'none' stretches each axis independently to fill the drawing rect, with no
    // aspect-ratio preservation and nothing to align — just offset the origin.
    if(alignment == IJSVGViewBoxAlignmentNone) {
        CGAffineTransform transform = CGAffineTransformMakeScale(scaleX, scaleY);
        return CGAffineTransformConcat(transform,
                                       CGAffineTransformMakeTranslation(-(viewBox.origin.x * scaleX),
                                                                        -(viewBox.origin.y * scaleY)));
    }

    // meet fits the whole viewBox inside the rect (smallest scale), slice covers
    // the rect entirely (largest scale).
    CGFloat ratio = (meetOrSlice == IJSVGViewBoxMeetOrSliceSlice) ?
        MAX(scaleX, scaleY) : MIN(scaleX, scaleY);

    CGFloat fx = .5f;
    CGFloat fy = .5f;
    IJSVGViewBoxAlignmentFactors(alignment, &fx, &fy);

    // position the scaled viewBox within the rect by its alignment factor, then
    // pull back the viewBox origin (also in scaled space).
    CGFloat tx = (drawingRect.size.width - (viewBox.size.width * ratio)) *
        fx - (viewBox.origin.x * ratio);
    CGFloat ty = (drawingRect.size.height - (viewBox.size.height * ratio)) *
        fy - (viewBox.origin.y * ratio);

    CGAffineTransform transform = CGAffineTransformMakeScale(ratio, ratio);
    return CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(tx, ty));
}

CGAffineTransform IJSVGContextDrawViewBox(CGContextRef ctx, CGRect viewBox,
                                          CGRect boundingBox,
                                          IJSVGViewBoxAlignment alignment,
                                          IJSVGViewBoxMeetOrSlice meetOrSlice,
                                          IJSVGViewBoxDrawingBlock block) {
    return [IJSVGViewBox drawViewBox:viewBox
                              inRect:boundingBox
                           alignment:alignment
                         meetOrSlice:meetOrSlice
                           inContext:ctx
                        drawingBlock:block];
}

+ (CGAffineTransform)drawViewBox:(CGRect)viewBox
                          inRect:(CGRect)drawingRect
                       alignment:(IJSVGViewBoxAlignment)alignment
                     meetOrSlice:(IJSVGViewBoxMeetOrSlice)meetOrSlice
                       inContext:(CGContextRef)ctx
                    drawingBlock:(IJSVGViewBoxDrawingBlock)block
{
    CGContextSaveGState(ctx);
    if(meetOrSlice == IJSVGViewBoxMeetOrSliceSlice) {
        CGContextClipToRect(ctx, drawingRect);
    }

    // a missing, empty or identical viewBox maps 1:1 — there is nothing to scale
    // so we draw with an identity transform rather than skipping the draw.
    CGAffineTransform transform = CGAffineTransformIdentity;
    if(CGRectIsNull(viewBox) == NO && viewBox.size.width > 0.f &&
       viewBox.size.height > 0.f && CGRectEqualToRect(viewBox, drawingRect) == NO) {
        transform = IJSVGViewBoxComputeTransform(viewBox, drawingRect,
                                                 alignment, meetOrSlice);
        CGContextConcatCTM(ctx, transform);
    }

    // hand the resolved per-axis scale to the drawing block (used to compute the
    // backing scale factor before rendering).
    CGFloat scale[2] = { transform.a, transform.d };
    block(scale);

    CGContextRestoreGState(ctx);
    return transform;
}

@end
