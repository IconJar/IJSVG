//
//  IJSVGPaintNode.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGPaintNode.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGQuartzRenderer.h>

@implementation IJSVGPaintNode {
    unsigned char _initializedDefaultLengths;
}
@synthesize fill = _fill, fillOpacity = _fillOpacity;

- (void)applyPropertiesFromNode:(IJSVGNode*)source
{
    [super applyPropertiesFromNode:source];
    if ([source isKindOfClass:IJSVGPaintNode.class]) {
        IJSVGPaintNode* node = (IJSVGPaintNode*)source;
        self.fill = node.fill;
        self.fillOpacity = node.fillOpacity;
    }
}

- (void)setFill:(IJSVGNode*)fill
{
    NSAssert([fill matchesTraits:IJSVGNodeTraitPaintable] || fill == nil, @"Fill must a paintable node.");
    _fill = fill;
}

- (void)setFillOpacity:(IJSVGUnitLength*)value
{
    _initializedDefaultLengths |= 2;
    _fillOpacity = value;
}

- (IJSVGUnitLength*)fillOpacity
{
    BOOL needsDefault = (_initializedDefaultLengths & 2) == 0;
    if (needsDefault || _fillOpacity.inherit) {
        IJSVGPaintNode* parent = self.styleParent;
        if (parent != nil) {
            return parent.fillOpacity;
        }
    }
    if (needsDefault) {
        _initializedDefaultLengths |= 2;
        _fillOpacity = IJSVGInheritedOneUnitLength;
    }
    return _fillOpacity;
}

- (IJSVGNode*)fill
{
    return _fill ?: self.styleParent.fill;
}

@end

@implementation IJSVGPaintNode (Rendering)

- (void)addSpecifiedPaintPropertiesToStyle:(IJSVGResolvedPaintStyle*)style atRoot:(BOOL)atRoot
{
    [super addSpecifiedPaintPropertiesToStyle:style atRoot:atRoot];
    style->fill = style->fill ?: _fill;
    if (!style->hasFillOpacity) {
        BOOL needsDefault = (_initializedDefaultLengths & 2) == 0;
        if (atRoot || (!needsDefault && !_fillOpacity.inherit)) {
            style->fillOpacity = needsDefault ? IJSVGInheritedOneUnitLength : _fillOpacity;

            // An explicitly assigned nil is resolved too. It must not inherit.
            style->hasFillOpacity = YES;
        }
    }
}

@end
