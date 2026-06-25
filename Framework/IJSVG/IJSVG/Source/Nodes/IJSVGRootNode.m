//
//  IJSVGRootNode.m
//  IJSVG
//
//  Created by Curtis Hard on 28/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGThreadManager.h>

@implementation IJSVGRootNode

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags64* storage = [[IJSVGBitFlags64 alloc] init];
    [storage addBits:[super allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeX];
    [storage setBit:IJSVGNodeAttributeY];
    [storage setBit:IJSVGNodeAttributeWidth];
    [storage setBit:IJSVGNodeAttributeHeight];
    [storage setBit:IJSVGNodeAttributePreserveAspectRatio];
    [storage setBit:IJSVGNodeAttributeViewBox];
    return storage;
}

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

- (void)inferViewBoxIfRequired
{
  // Already have a viewBox, no need to do anything
  if(self.viewBox != nil) {
    return;
  }
  
  // We only need to do the following if the FF is enabled.
  if(IJSVGThreadManager.currentManager.featureFlags.inferViewBoxes.enabled == NO) {
    return;
  }
  
  // We can just union our child bounds together and use that.
  CGRect rect = [super bounds];
  if(CGRectIsInfinite(rect) || CGRectIsEmpty(rect)) {
    return;
  }
  self.viewBox = [IJSVGUnitRect rectWithCGRect:rect];
}

- (CGRect)bounds
{
    CGSize resolvingSize = self.clientSize;
    if(CGSizeEqualToSize(resolvingSize, CGSizeZero) == YES) {
        resolvingSize = CGSizeMake(200.f, 200.f);
    }
    return [self.viewBox computeValue:resolvingSize];
}

- (IJSVGRootNode *)rootNode
{
    IJSVGRootNode* rootNode = nil;
    if((rootNode = super.rootNode) == self) {
        IJSVGNode* parent = self.parentNode;
        if([parent isKindOfClass:IJSVGRootNode.class]) {
            return (IJSVGRootNode*)parent;
        }
        return parent.rootNode;
    }
    return rootNode;
}

@end
