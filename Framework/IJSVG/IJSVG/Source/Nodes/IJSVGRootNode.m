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

- (void)normalizeWithOffset:(CGPoint)offset
{
    for(IJSVGNode* node in self.children) {
        [node normalizeWithOffset:offset];
    }
}

- (void)postProcess
{
    // Some SVG's will have a viewBox such as 5, 5, 10, 10, given that
    // we can zero out the origin and shift all its direct children by
    // the viewBox's origin
    if(IJSVGThreadManager.currentManager.featureFlags.viewBoxNormalization.enabled == YES) {
        CGRect vBox = [self.viewBox computeValue:CGSizeZero];
        if(CGPointEqualToPoint(vBox.origin, CGPointZero) == YES) {
            return;
        }
        [self normalizeWithOffset:vBox.origin];
        self.viewBox.origin = IJSVGUnitPoint.zeroPoint;
    }
}

@end
