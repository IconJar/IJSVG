//
//  IJSVGRootNode.m
//  IJSVG
//
//  Created by Curtis Hard on 28/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRootNode.h>

@implementation IJSVGRootNode

- (instancetype)init
{
    if((self = [super init]) != nil) {
        self.viewBoxAlignment = IJSVGViewBoxAlignmentXMidYMid;
        self.viewBoxMeetOrSlice = IJSVGViewBoxMeetOrSliceMeet;
        self.lineCapStyle = IJSVGLineCapStyleButt;
        self.lineJoinStyle = IJSVGLineJoinStyleMiter;
        self.strokeMiterLimit = [IJSVGUnitLength unitWithFloat:4.f];
        self.strokeDashArrayCount = 0;
        self.intrinsicDimensions = IJSVGIntrinsicDimensionNone;
    }
    return self;
}

- (CGRect)bounds
{
    return [self.viewBox computeValue:CGSizeZero];
}

- (IJSVGRootNode *)rootNode
{
    IJSVGRootNode* rootNode = nil;
    if((rootNode = [super rootNode]) == self) {
        IJSVGNode* parent = self.parentNode;
        if([parent isKindOfClass:IJSVGRootNode.class]) {
            return (IJSVGRootNode*)parent;
        }
        return parent.rootNode;
    }
    return rootNode;
}

@end
