//
//  IJSVGViewportNode.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGraphicsNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGViewportNode : IJSVGGraphicsNode

@property (nonatomic, strong, nullable) IJSVGUnitRect* viewBox;
@property (nonatomic, assign) IJSVGViewBoxAlignment viewBoxAlignment;
@property (nonatomic, assign) IJSVGViewBoxMeetOrSlice viewBoxMeetOrSlice;

@end

NS_ASSUME_NONNULL_END
