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

+ (IJSVGViewBoxAlignment)alignmentForString:(NSString*)string
                                meetOrSlice:(IJSVGViewBoxMeetOrSlice*)meetOrSlice;
+ (IJSVGViewBoxAlignment)alignmentForString:(NSString*)string;
+ (IJSVGViewBoxMeetOrSlice)meetOrSliceForString:(NSString*)string;

+ (void)drawViewBox:(CGRect)viewBox
             inRect:(CGRect)drawingRect
      contentBounds:(CGRect)bounds
          alignment:(IJSVGViewBoxAlignment)alignment
        meetOrSlice:(IJSVGViewBoxMeetOrSlice)meetOrSlice
          inContext:(CGContextRef)ctx
       drawingBlock:(dispatch_block_t)block;

@end
