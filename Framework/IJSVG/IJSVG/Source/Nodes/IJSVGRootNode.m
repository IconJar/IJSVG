//
//  IJSVGRootNode.m
//  IJSVG
//
//  Created by Curtis Hard on 28/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGRootNode

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeSVG;
}

- (void)applyPropertiesFromNode:(IJSVGNode*)node
{
    [super applyPropertiesFromNode:node];
    if ([node isKindOfClass:IJSVGRootNode.class]) {
        IJSVGRootNode* root = (IJSVGRootNode*)node;
        self.styleAncestors = root.styleAncestors;
        self.clientSize = root.clientSize;
        self.backgroundColor = root.backgroundColor;
        self.intrinsicSize = root.intrinsicSize.copy;
        self.intrinsicDimensions = root.intrinsicDimensions;
        self.viewBoxWasInferred = root.viewBoxWasInferred;
        _hasCalculatedContainsRelativeUnits = NO;
    }
}

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        self.viewBoxAlignment = IJSVGViewBoxAlignmentXMidYMid;
        self.viewBoxMeetOrSlice = IJSVGViewBoxMeetOrSliceMeet;
        self.lineCapStyle = IJSVGLineCapStyleButt;
        self.lineJoinStyle = IJSVGLineJoinStyleMiter;
        self.strokeMiterLimit = IJSVGFourUnitLength;
        self.strokeDashArrayCount = 0;
        _intrinsicDimensions = IJSVGIntrinsicDimensionNone;
    }
    return self;
}

- (void)setViewBox:(IJSVGUnitRect*)viewBox
{
    [super setViewBox:viewBox];
    _viewBoxWasInferred = NO;
}

- (void)inferViewBoxIfRequired
{
    // Already have a viewBox, no need to do anything
    if (self.viewBox != nil) {
        return;
    }

    // We only need to do the following if the FF is enabled.
    if (IJSVGThreadManager.currentManager.featureFlags.inferViewBoxes.enabled == NO) {
        return;
    }

    // We can just union our child bounds together and use that.
    CGRect rect = [super bounds];
    if (CGRectIsInfinite(rect) || CGRectIsEmpty(rect)) {
        return;
    }
    self.viewBox = [IJSVGUnitRect rectWithCGRect:rect];
    self.viewBoxWasInferred = YES;
}

- (BOOL)containsRelativeUnits
{
    if (_hasCalculatedContainsRelativeUnits) {
        return _containsRelativeUnits;
    }
    BOOL flag = self.viewBox.containsRelativeUnits || [super containsRelativeUnits];
    _containsRelativeUnits = flag;
    _hasCalculatedContainsRelativeUnits = YES;
    return _containsRelativeUnits;
}

- (CGRect)bounds
{
    CGSize resolvingSize = self.clientSize;
    if (CGSizeEqualToSize(resolvingSize, CGSizeZero) == YES) {
        resolvingSize = CGSizeMake(200.f, 200.f);
    }
    return [self.viewBox computeValue:resolvingSize];
}

- (IJSVGRootNode*)rootNode
{
    IJSVGRootNode* rootNode = nil;
    if ((rootNode = super.rootNode) == self) {
        IJSVGNode* parent = self.parentNode;
        if ([parent isKindOfClass:IJSVGRootNode.class]) {
            return (IJSVGRootNode*)parent;
        }
        return parent.rootNode;
    }
    return rootNode;
}

@end

#pragma mark - Parsing

@implementation IJSVGRootNode (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeWidth];
    [attributes setBit:IJSVGNodeAttributeHeight];
    [attributes setBit:IJSVGNodeAttributeViewBox];
    [attributes setBit:IJSVGNodeAttributePreserveAspectRatio];
    [attributes setBit:IJSVGNodeAttributeBackgroundColor];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
    IJSVGParsePathAttributes(self, context);
    IJSVGUnitLength* geometryLength = nil;
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeX, &geometryLength)) {
        self.x = geometryLength;
    }
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeY, &geometryLength)) {
        self.y = geometryLength;
    }
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeWidth, &geometryLength)) {
        self.width = geometryLength;
    }
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeHeight, &geometryLength)) {
        self.height = geometryLength;
    }
    IJSVGParseBackgroundAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    IJSVGParsePaintAttributes(self, context);
    IJSVGParseEffectsAttributes(self, context);
    IJSVGParseTransformAttributes(self, context);
    IJSVGParseDisplayAttributes(self, context);
    IJSVGParseOverflowAttributes(self, context);
    IJSVGParseMarkersAttributes(self, context);
    IJSVGParseViewportAttributes(self, context);
    IJSVGParseRootAttributes(self, context);
}

@end
