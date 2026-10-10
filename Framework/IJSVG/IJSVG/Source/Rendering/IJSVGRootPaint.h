//
//  IJSVGRootPaint.h
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGGroupPaint.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGUnitSize.h>

@interface IJSVGRootPaint : IJSVGGroupPaint

@property (nonatomic, strong) IJSVGUnitRect* viewBox;
@property (nonatomic, strong) NSColor* backgroundColor;
@property (nonatomic, strong) IJSVGUnitSize* intrinsicSize;
@property (nonatomic, assign) IJSVGViewBoxAlignment viewBoxAlignment;
@property (nonatomic, assign) IJSVGViewBoxMeetOrSlice viewBoxMeetOrSlice;

@end
