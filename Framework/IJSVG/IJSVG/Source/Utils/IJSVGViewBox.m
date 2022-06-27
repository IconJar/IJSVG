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
            return @"none";
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

CGAffineTransform IJSVGViewBoxComputeRectXMidYMid(CGRect viewBox, CGRect drawingRect,
                                                  IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
    // scale the viewBox into the drawingRect
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    // translate it
    CGFloat originX = drawingRect.size.width / 2.f - (viewBox.size.width * ratio) / 2.f;
    CGFloat originY = drawingRect.size.height / 2.f - (viewBox.size.height * ratio) / 2.f;
    originX += -(viewBox.origin.x * ratio);
    originY += -(viewBox.origin.y * ratio);
    
    CGAffineTransform translate = CGAffineTransformMakeTranslation(originX, originY);
    transform = CGAffineTransformConcat(transform, translate);
    return transform;
}

CGAffineTransform IJSVGViewBoxComputeRectXMinYMid(CGRect viewBox, CGRect drawingRect,
                                                  IJSVGViewBoxMeetOrSlice meetOrSlice)
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
    return transform;
}

CGAffineTransform IJSVGViewBoxComputeRectXMaxYMid(CGRect viewBox, CGRect drawingRect,
                                                  IJSVGViewBoxMeetOrSlice meetOrSlice)
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
    return transform;
}

CGAffineTransform IJSVGViewBoxComputeRectXMidYMin(CGRect viewBox, CGRect drawingRect,
                                                  IJSVGViewBoxMeetOrSlice meetOrSlice)
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
    return transform;
}

CGAffineTransform IJSVGViewBoxComputeRectXMinYMin(CGRect viewBox, CGRect drawingRect,
                                                  IJSVGViewBoxMeetOrSlice meetOrSlice)
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
    return transform;
}

CGAffineTransform IJSVGViewBoxComputeRectXMidYMax(CGRect viewBox, CGRect drawingRect,
                                                  IJSVGViewBoxMeetOrSlice meetOrSlice)
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
    return transform;
}

CGAffineTransform IJSVGViewBoxComputeRectXMaxYMin(CGRect viewBox, CGRect drawingRect,
                                                  IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
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
    return transform;
}

CGAffineTransform IJSVGViewBoxComputeRectXMinYMax(CGRect viewBox, CGRect drawingRect,
                                                  IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
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
    return transform;
}

CGAffineTransform IJSVGViewBoxComputeRectXMaxYMax(CGRect viewBox, CGRect drawingRect,
                                                  IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    CGFloat width = drawingRect.size.width / viewBox.size.width;
    CGFloat height = drawingRect.size.height / viewBox.size.height;
    CGFloat ratio = meetOrSlice == IJSVGViewBoxMeetOrSliceMeet ? MIN(width, height) : MAX(width, height);
    
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
    return transform;
}

CGAffineTransform IJSVGViewBoxComputeRectNone(CGRect viewBox, CGRect drawingRect,
                                              IJSVGViewBoxMeetOrSlice meetOrSlice)
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
    return transform;
}

CGAffineTransform IJSVGContextViewBoxConcat(CGContextRef ctx, IJSVGViewBoxComputeTransformFunction function,
                                            CGRect viewBox, CGRect drawingRect,
                                            IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    // if both are equal, nothing will happen, it will be mapped 1:1
    if(CGRectEqualToRect(viewBox, drawingRect) == YES) {
        return CGAffineTransformIdentity;
    }
    CGAffineTransform transform;
    transform = function(viewBox, drawingRect, meetOrSlice);
    CGContextConcatCTM(ctx, transform);
    return transform;
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

CGAffineTransform IJSVGViewBoxComputeTransform(CGRect viewBox, CGRect drawingRect,
                                               IJSVGViewBoxAlignment alignment,
                                               IJSVGViewBoxMeetOrSlice meetOrSlice)
{
    switch(alignment) {
        default:
        case IJSVGViewBoxAlignmentUnknown:
        case IJSVGViewBoxAlignmentXMidYMid: {
            return IJSVGViewBoxComputeRectXMidYMid(viewBox, drawingRect,
                                                   meetOrSlice);
        }
        case IJSVGViewBoxAlignmentNone: {
            return IJSVGViewBoxComputeRectNone(viewBox, drawingRect,
                                               meetOrSlice);
        }
        case IJSVGViewBoxAlignmentXMaxYMax: {
            return IJSVGViewBoxComputeRectXMaxYMax(viewBox, drawingRect,
                                                   meetOrSlice);
        }
        case IJSVGViewBoxAlignmentXMaxYMid: {
            return IJSVGViewBoxComputeRectXMaxYMid(viewBox, drawingRect,
                                                   meetOrSlice);
        }
        case IJSVGViewBoxAlignmentXMaxYMin: {
            return IJSVGViewBoxComputeRectXMaxYMin(viewBox, drawingRect,
                                                   meetOrSlice);
        }
        case IJSVGViewBoxAlignmentXMidYMax: {
            return IJSVGViewBoxComputeRectXMidYMax(viewBox, drawingRect,
                                                   meetOrSlice);
        }
        case IJSVGViewBoxAlignmentXMidYMin: {
            return IJSVGViewBoxComputeRectXMidYMin(viewBox, drawingRect,
                                                   meetOrSlice);
        }
        case IJSVGViewBoxAlignmentXMinYMax: {
            return IJSVGViewBoxComputeRectXMinYMin(viewBox, drawingRect,
                                                   meetOrSlice);
        }
        case IJSVGViewBoxAlignmentXMinYMid: {
            return IJSVGViewBoxComputeRectXMinYMid(viewBox, drawingRect,
                                                   meetOrSlice);
        }
        case IJSVGViewBoxAlignmentXMinYMin: {
            return IJSVGViewBoxComputeRectXMinYMin(viewBox, drawingRect,
                                                   meetOrSlice);
        }
    }
    return CGAffineTransformIdentity;
}

+ (CGAffineTransform)drawViewBox:(CGRect)viewBox
                          inRect:(CGRect)drawingRect
                       alignment:(IJSVGViewBoxAlignment)alignment
                     meetOrSlice:(IJSVGViewBoxMeetOrSlice)meetOrSlice
                       inContext:(CGContextRef)ctx
                    drawingBlock:(IJSVGViewBoxDrawingBlock)block
{
    // this is equal to none, dont do anything fancy
    if(CGRectIsNull(viewBox) == YES ||
       CGRectEqualToRect(viewBox, CGRectZero) == YES) {
        return CGAffineTransformIdentity;
    }
    
    CGContextSaveGState(ctx);
    if(meetOrSlice == IJSVGViewBoxMeetOrSliceSlice) {
        CGContextClipToRect(ctx, drawingRect);
    }
    
    // init the scaler
    CGFloat* scale = (CGFloat*)malloc(sizeof(CGFloat)*2);
    scale[0] = 1.f;
    scale[1] = 1.f;
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    switch(alignment) {
        case IJSVGViewBoxAlignmentNone: {
            transform = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectNone,
                                                  viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentUnknown:
        case IJSVGViewBoxAlignmentXMidYMid: {
            transform = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMidYMid,
                                                  viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMid: {
            transform = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMinYMid,
                                                  viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMid: {
            transform = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMaxYMid,
                                                  viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMidYMin: {
            transform = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMidYMin,
                                                  viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMidYMax: {
            transform = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMidYMax,
                                                  viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMin: {
            transform = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMinYMin,
                                                  viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMin: {
            transform = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMaxYMin,
                                                  viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMinYMax: {
            transform = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMinYMax,
                                                  viewBox, drawingRect, meetOrSlice);
            break;
        }
        case IJSVGViewBoxAlignmentXMaxYMax: {
            transform = IJSVGContextViewBoxConcat(ctx, &IJSVGViewBoxComputeRectXMaxYMax,
                                                  viewBox, drawingRect, meetOrSlice);
            break;
        }
    }
    // grab the scale from the transform
    scale[0] = transform.a;
    scale[1] = transform.d;
    
    // call the draw block and memory clean / restore context
    block(scale);
    free(scale);
    CGContextRestoreGState(ctx);
    return transform;
}

@end
