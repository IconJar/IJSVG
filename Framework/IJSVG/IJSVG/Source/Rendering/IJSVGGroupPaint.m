//
//  IJSVGGroupPaint.m
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterPaint.h>
#import <IJSVGGroupPaint.h>
#import <IJSVGPatternPaint.h>

static BOOL IJSVGGroupNeedsBackgroundPixels(IJSVGPaint* root)
{
    NSMutableArray<IJSVGPaint*>* pending = [NSMutableArray arrayWithObject:root];
    NSMutableSet<IJSVGPaint*>* visited = [[NSMutableSet alloc] init];
    while (pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if ([visited containsObject:paint]) {
            continue;
        }
        [visited addObject:paint];
        if ((paint.paintTraits & IJSVGPaintTraitFilter) != 0) {
            IJSVGFilterPaint* filtered = (IJSVGFilterPaint*)paint;
            if (filtered.usesBackground) {
                return YES;
            }

            // Referenced image trees are resolved during filter evaluation,
            // so their background dependencies are not in this paint tree.
            for (IJSVGFilterPrimitive* primitive in filtered.filter.primitives) {
                if (primitive.type == IJSVGNodeTypeFilterImage) {
                    return YES;
                }
            }
        }
        [pending addObjectsFromArray:paint.children ?: @[]];
        [pending addObjectsFromArray:paint.clipPaints ?: @[]];
        if (paint.maskPaint != nil) {
            [pending addObject:paint.maskPaint];
        }
        if ((paint.paintTraits & IJSVGPaintTraitPattern) != 0) {
            IJSVGPaint* pattern = ((IJSVGPatternPaint*)paint).pattern;
            if (pattern != nil) {
                [pending addObject:pattern];
            }
        }
    }
    return NO;
}

@implementation IJSVGGroupPaint

// Allocation already supplies the class. A static identity
// comparison here avoids object class queries in parsing and drawing, while
// subclasses keep the general implementation.
+ (instancetype)allocWithZone:(NSZone*)zone
{
    IJSVGGroupPaint* instance = [super allocWithZone:zone];
    if (self == IJSVGGroupPaint.class) {
        instance->_builtInPaintKind = IJSVGBuiltInPaintGroup;
    }
    return instance;
}

- (IJSVGPaintTraits)paintTraits
{
    return IJSVGPaintTraitGroup;
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    if (self.sourceNode != nil && !CGRectIsNull(self.sourceNode.backgroundRect)) {
        if (IJSVGGroupNeedsBackgroundPixels(self)) {
            [IJSVGFilterPaint drawBackgroundForPaint:self
                                             context:ctx
                                        drawingBlock:^(CGContextRef bitmap) {
                                            [self drawContentsInContext:bitmap];
                                        }];
        } else {
            // A background scope with no readers only needs group isolation.
            // Let Quartz composite it directly instead of rasterizing and
            // resampling a full clip sized bitmap for every exported group.
            CGRect bounds = self.transparencyBounds;
            if (!CGRectIsNull(bounds) && !CGRectIsInfinite(bounds)) {
                // Match the ordinary opacity path: small details must not
                // allocate and composite a layer as large as their ancestor.
                CGAffineTransform transform = CGContextGetCTM(ctx);
                CGFloat scale = MIN(hypot(transform.a, transform.b), hypot(transform.c, transform.d));
                if (scale > 0.f) {
                    CGContextClipToRect(ctx, CGRectInset(bounds, -2.f / scale, -2.f / scale));
                }
            }
            CGContextSetAlpha(ctx, self.opacity);
            CGContextBeginTransparencyLayer(ctx, NULL);
            [self drawContentsInContext:ctx];
            CGContextEndTransparencyLayer(ctx);
        }
    } else {
        [super performRenderInContext:ctx];
    }
}

- (CGRect)innerBoundingBox
{
    return self.outerBoundingBox;
}

@end
