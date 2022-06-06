//
//  IJSVGViewBox.h
//  IJSVG
//
//  Created by Curtis Hard on 14/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>

typedef NS_ENUM(NSInteger, IJSVGViewBoxAlignment) {
    IJSVGViewBoxAlignmentUnknown,
    IJSVGViewBoxAlignmentNone,
    IJSVGViewBoxAlignmentXMinYMin,
    IJSVGViewBoxAlignmentXMidYMin,
    IJSVGViewBoxAlignmentXMaxYMin,
    IJSVGViewBoxAlignmentXMinYMid,
    IJSVGViewBoxAlignmentXMidYMid,
    IJSVGViewBoxAlignmentXMaxYMid,
    IJSVGViewBoxAlignmentXMinYMax,
    IJSVGViewBoxAlignmentXMidYMax,
    IJSVGViewBoxAlignmentXMaxYMax,
};

typedef NS_ENUM(NSInteger, IJSVGViewBoxMeetOrSlice) {
    IJSVGViewBoxMeetOrSliceUnknown,
    IJSVGViewBoxMeetOrSliceMeet,
    IJSVGViewBoxMeetOrSliceSlice,
};

@interface IJSVGViewBox : NSObject

typedef void (^IJSVGViewBoxDrawingBlock)(CGSize scale);

+ (IJSVGViewBoxAlignment)alignmentForString:(NSString*)string
                                meetOrSlice:(IJSVGViewBoxMeetOrSlice*)meetOrSlice;
+ (IJSVGViewBoxAlignment)alignmentForString:(NSString*)string;
+ (IJSVGViewBoxMeetOrSlice)meetOrSliceForString:(NSString*)string;

void IJSVGContextDrawViewBox(CGContextRef ctx, CGRect viewBox, CGRect boundingBox,
                      IJSVGViewBoxAlignment alignment, IJSVGViewBoxMeetOrSlice meetOrSlice,
                      IJSVGViewBoxDrawingBlock block);

+ (void)drawViewBox:(CGRect)viewBox
             inRect:(CGRect)drawingRect
          alignment:(IJSVGViewBoxAlignment)alignment
        meetOrSlice:(IJSVGViewBoxMeetOrSlice)meetOrSlice
          inContext:(CGContextRef)ctx
       drawingBlock:(IJSVGViewBoxDrawingBlock)block;

@end
