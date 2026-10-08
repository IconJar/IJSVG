//
//  IJSVGQuartzRenderer.m
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGQuartzRenderer.h>
#import <IJSVG/IJSVGTextLayout.h>
#import <IJSVGPaint.h>
#import <IJSVGGroupPaint.h>
#import <IJSVGTransformPaint.h>
#import <IJSVGMaskPaint.h>
#import <IJSVGRootPaint.h>
#import <IJSVGShapePaint.h>
#import <IJSVGRectPaint.h>
#import <IJSVGStrokePaint.h>
#import <IJSVGGradientPaint.h>
#import <IJSVGPatternPaint.h>
#import <IJSVGImagePaint.h>
#import <IJSVGFilterPaint.h>
#import <IJSVG/IJSVGFilterGraph.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGPattern.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGUtils.h>

static CGLineCap IJSVGQuartzLineCap(IJSVGLineCapStyle style)
{
    switch(style) {
        case IJSVGLineCapStyleRound: return kCGLineCapRound;
        case IJSVGLineCapStyleSquare: return kCGLineCapSquare;
        default: return kCGLineCapButt;
    }
}

static CGLineJoin IJSVGQuartzLineJoin(IJSVGLineJoinStyle style)
{
    switch(style) {
        case IJSVGLineJoinStyleRound: return kCGLineJoinRound;
        case IJSVGLineJoinStyleBevel: return kCGLineJoinBevel;
        default: return kCGLineJoinMiter;
    }
}

static void IJSVGQuartzConfigureStroke(IJSVGStrokePaint* paint, IJSVGPath* node,
                                       IJSVGStyle* style)
{
    // Calculate the stroke width.
    CGFloat lineWidth = [node.strokeWidth computeValue:paint.frame.size.width];

    if(style.lineWidth != IJSVGInheritedFloatValue) {
        lineWidth = style.lineWidth;
    }

    // Read the stroke cap and join settings.
    IJSVGLineCapStyle lineCapStyle = node.lineCapStyle;
    IJSVGLineJoinStyle lineJoinStyle = node.lineJoinStyle;
    CGFloat miterLimit = node.strokeMiterLimit.value;

    // Use the settings supplied by the style.
    if(style.lineCapStyle != IJSVGLineCapStyleNone &&
        style.lineCapStyle != IJSVGLineCapStyleInherit) {
        lineCapStyle = style.lineCapStyle;
    }

    if(style.lineJoinStyle != IJSVGLineJoinStyleNone &&
        style.lineJoinStyle != IJSVGLineJoinStyleInherit) {
        lineJoinStyle = style.lineJoinStyle;
    }

    // Use the style limit for sharp corners.
    if(style.miterLimit != IJSVGInheritedFloatValue) {
        miterLimit = style.miterLimit;
    }

    // Store the stroke settings.
    paint.lineWidth = lineWidth;
    paint.lineCap = IJSVGQuartzLineCap(lineCapStyle);
    paint.lineJoin = IJSVGQuartzLineJoin(lineJoinStyle);
    paint.miterLimit = miterLimit;

    CGFloat strokeOpacity = 1.f;
    if(node.strokeOpacity.value != 1.f) {
        strokeOpacity = node.strokeOpacity.value;
    }
    paint.opacity = strokeOpacity;

    // Set the dash pattern.
    paint.lineDashPhase = node.strokeDashOffset.value;
    if(node.strokeDashArrayCount != IJSVGInheritedIntegerValue) {
        paint.lineDashPattern = node.lineDashPattern;
    }

}

static void IJSVGQuartzExpandStrokeBounds(IJSVGStrokePaint* paint)
{
    CGRect frame = paint.frame;
    // Expand the frame to include the stroke.
    CGFloat increase = paint.lineWidth / 2.f;
    frame = CGRectInset(frame, -increase, -increase);

    // Move the path to allow space for the stroke.
    CGAffineTransform transform = CGAffineTransformMakeTranslation(increase, increase);
    CGPathRef path = CGPathCreateCopyByTransformingPath(paint.path, &transform);

    // Keep the path position relative to the new frame.
    paint.frame = (CGRect) {
        .origin = CGPointZero,
        .size = frame.size
    };
    paint.outerBoundingBox = paint.frame;
    paint.path = path;
    CGPathRelease(path);

}

@interface IJSVGQuartzRenderer () {
    NSMutableArray<NSValue*>* _viewPortStack;
    NSMutableArray<NSValue*>* _unitBoundsStack;
    IJSVGRootPaint* _rootPaint;
    IJSVGRootNode* _rootNode;
    CGSize _clientSize;
    NSSet<IJSVGFilterPaint*>* _batchableFilters;
    BOOL _requiresBackdrop;
    BOOL _containsText;
    CGAffineTransform _textTransform;
    CGAffineTransform _textRenderTransform;
    CGSize _textRenderFrameSize;
    IJSVGRootNode* _textBuildRoot;
}
@end

@implementation IJSVGQuartzRenderer

static BOOL IJSVGRectIsFinite(CGRect rect)
{
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

@synthesize style = _style;
@synthesize renderingOptions = _renderingOptions;

// Create the renderer with default settings.
- (id)init
{
    if((self = [super init]) != nil) {
        _renderingOptions = [[IJSVGRenderingOptions alloc] init];
        _style = [[IJSVGStyle alloc] init];
        _textTransform = CGAffineTransformIdentity;
        _viewPortStack = [[NSMutableArray alloc] init];
        _unitBoundsStack = [[NSMutableArray alloc] init];
    }
    return self;
}

// Return a copy so callers cannot change these settings directly.
- (IJSVGRenderingOptions*)renderingOptions
{
    return _renderingOptions.copy;
}

- (void)pushViewPort:(CGRect)viewPort
{
    NSValue* value = [NSValue valueWithRect:NSRectFromCGRect(viewPort)];
    [_viewPortStack addObject:value];
}

- (CGRect)viewPort
{
    NSValue* value = _viewPortStack.lastObject;
    return (CGRect)NSRectToCGRect(value.rectValue);
}

- (void)popViewPort
{
    [_viewPortStack removeLastObject];
}

- (void)withViewPort:(CGRect)viewPort
             handler:(dispatch_block_t)handler
{
    [self pushViewPort:viewPort];
    // Restore the previous bounds even if drawing raises an exception.
    @try {
        handler();
    } @finally {
        [self popViewPort];
    }
}

- (void)pushUnitBounds:(CGRect)bounds
{
    NSValue* value = [NSValue valueWithRect:NSRectFromCGRect(bounds)];
    [_unitBoundsStack addObject:value];
}

- (CGRect)unitBounds
{
    NSValue* value = _unitBoundsStack.lastObject;
    return value == nil ? CGRectNull : (CGRect)NSRectToCGRect(value.rectValue);
}

- (void)popUnitBounds
{
    [_unitBoundsStack removeLastObject];
}

- (void)withUnitBounds:(CGRect)bounds
               handler:(dispatch_block_t)handler
{
    [self pushUnitBounds:bounds];
    @try {
        handler();
    } @finally {
        [self popUnitBounds];
    }
}

- (void)withViewPort:(CGRect)viewPort
          unitBounds:(CGRect)bounds
             handler:(dispatch_block_t)handler
{
    [self withViewPort:viewPort
               handler:^{
        [self withUnitBounds:bounds
                     handler:handler];
    }];
}

// Measures children with the same placement used during drawing.
- (CGRect)artworkBoundsForChildrenOfPaint:(IJSVGPaint*)paint
{
    CGRect bounds = CGRectNull;
    for(IJSVGPaint* child in paint.children) {
        CGRect local = [self artworkBoundsForPaint:child];
        if(CGRectIsNull(local) || CGRectIsInfinite(local)) {
            continue;
        }
        bounds = CGRectUnion(bounds, CGRectApplyAffineTransform(local, child.placementTransform));
    }
    return bounds;
}

// Includes stroked outlines with resolved caps, joins, dashes, and units.
- (CGRect)artworkBoundsForPaint:(IJSVGPaint*)paint
{
    if(paint.hidden || paint.opacity <= 0.f) {
        return CGRectNull;
    }
    if([paint isKindOfClass:IJSVGRootPaint.class]) {
        return paint.bounds;
    }
    CGRect bounds = [self artworkBoundsForChildrenOfPaint:paint];
    if([paint isKindOfClass:IJSVGFilterPaint.class]) {
        IJSVGFilterPaint* filtered = (IJSVGFilterPaint*)paint;
        IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
        graph.boundingBox = filtered.boundingBox;
        graph.viewPort = filtered.viewPort;
        // Filters can generate pixels beyond the source, but never beyond this region.
        bounds = [graph regionForNode:filtered.filter
                                 units:filtered.filter.units
                         defaultRegion:CGRectZero];
    } else if([paint isKindOfClass:IJSVGShapePaint.class]) {
        IJSVGShapePaint* shape = (IJSVGShapePaint*)paint;
        if(shape.path != NULL) {
            if(shape.fillColor != NULL && CGColorGetAlpha(shape.fillColor) > 0.f) {
                bounds = CGRectUnion(bounds, CGPathGetPathBoundingBox(shape.path));
            }
            if(shape.strokeColor != NULL && CGColorGetAlpha(shape.strokeColor) > 0.f &&
               shape.lineWidth > 0.f) {
                CGPathRef outline = [self.class newPathFromStrokedShapePaint:shape];
                if(outline != NULL) {
                    bounds = CGRectUnion(bounds, CGPathGetPathBoundingBox(outline));
                    CGPathRelease(outline);
                }
            }
        }
    } else if([paint isKindOfClass:IJSVGImagePaint.class]) {
        bounds = CGRectUnion(bounds, paint.bounds);
    }
    if(paint.clipPath != NULL) {
        CGRect clipBounds = CGPathGetPathBoundingBox(paint.clipPath);
        if([paint isKindOfClass:IJSVGGradientPaint.class] ||
           [paint isKindOfClass:IJSVGPatternPaint.class]) {
            bounds = CGRectUnion(bounds, clipBounds);
        }
        bounds = CGRectIntersection(bounds, clipBounds);
    }
    return bounds;
}

// Resolves bounds in viewBox coordinates without the outer viewport clip.
- (CGRect)artworkBoundsForRootNode:(IJSVGRootNode*)rootNode
{
    IJSVGRootPaint* paint = [self rootPaintForRootNode:rootNode];
    return paint.hidden || paint.opacity <= 0.f ? CGRectNull :
        [self artworkBoundsForChildrenOfPaint:paint];
}

// Measures a resolved node including its transform and enabled effects.
- (CGRect)extentForNode:(IJSVGNode*)node inViewPort:(CGRect)viewPort
{
    IJSVGPaint* paint = [self drawablePaintForNode:node inViewPort:viewPort];
    if(paint == nil || paint.hidden || paint.opacity <= 0.f) {
        return CGRectNull;
    }
    CGRect bounds = [self artworkBoundsForPaint:paint];
    return CGRectIsNull(bounds) ? bounds :
        CGRectApplyAffineTransform(bounds, paint.placementTransform);
}

- (IJSVGRootPaint*)rootPaintForRootNode:(IJSVGRootNode*)rootNode
{
    CGRect clientBounds = (CGRect) {
      .origin = CGPointZero,
      .size = rootNode.clientSize
    };
    __block IJSVGRootPaint* paint = nil;
    [self withViewPort:clientBounds
            unitBounds:clientBounds
               handler:^{
        paint = (IJSVGRootPaint*)[self drawablePaintForNode:rootNode];
    }];
    return paint;
}

- (IJSVGPaint*)drawablePaintForNode:(IJSVGNode*)node
                         inViewPort:(CGRect)viewPort
{
    __block IJSVGPaint* paint = nil;
    [self withViewPort:viewPort
            unitBounds:viewPort
               handler:^{
      paint = [self drawablePaintForNode:node];
    }];
    return paint;
}

- (IJSVGTextLayout*)textLayoutForNode:(IJSVGText*)node
{
    _containsText = YES;
    CGFloat scale = sqrt((_textTransform.a * _textTransform.a + _textTransform.b * _textTransform.b +
                          _textTransform.c * _textTransform.c + _textTransform.d * _textTransform.d) / 2);
    IJSVGTextLayout* layout = [[IJSVGTextLayout alloc] initWithText:node
                                                           viewport:[self unitResolutionBoundsForNode:node].size
                                                        renderScale:scale
                                                       pathResolver:^CGPathRef(IJSVGPath* pathNode) {
            CGMutablePathRef path = CGPathCreateMutable();
            CGAffineTransform transform = IJSVGConcatTransforms(pathNode.transforms);
            [self appendResolvedPathForPathNode:pathNode transform:transform toPath:path];
            return path;
        }];
    return layout;
}

- (IJSVGPaint*)drawablePaintForTextNode:(IJSVGText*)node
{
    return [self drawablePaintForGroupNode:[self textLayoutForNode:node].group];
}

- (IJSVGPaint*)drawablePaintForNode:(IJSVGNode*)node
{
    if(node.transforms.count == 0) {
        return [self drawablePaintForNodeWithTextTransform:node];
    }
    CGAffineTransform previous = _textTransform;
    CGRect bounds = [self unitResolutionBoundsForNode:node];
    IJSVGNode* referencingNode = nil;
    IJSVGUnitType units = [node.parentNode contentUnitsWithReferencingNode:&referencingNode];
    CGAffineTransform local = CGAffineTransformIdentity;
    for(IJSVGTransform* transform in node.transforms.reverseObjectEnumerator) {
        IJSVGTransform* resolved = [transform transformByApplyingUnits:units
                                                                bounds:bounds];
        local = CGAffineTransformConcat(local, resolved.CGAffineTransform);
    }
    _textTransform = CGAffineTransformConcat(local, previous);
    @try {
        return [self drawablePaintForNodeWithTextTransform:node];
    } @finally {
        _textTransform = previous;
    }
}

// Build the paint and apply filters when they are enabled.
- (IJSVGPaint*)drawablePaintForNodeWithTextTransform:(IJSVGNode*)node
{
    IJSVGPaint* paint = nil;
    if([node isKindOfClass:IJSVGText.class]) {
        paint = [self drawablePaintForTextNode:(IJSVGText*)node];
    } else if([node isKindOfClass:IJSVGPath.class]) {
        paint = [self drawablePaintForPathNode:(IJSVGPath*)node];
    } else if([node isKindOfClass:IJSVGRootNode.class]) {
        paint = [self drawablePaintForRootNode:(IJSVGRootNode*)node];
    } else if([node isKindOfClass:IJSVGGroup.class]) {
        paint = [self drawablePaintForGroupNode:(IJSVGGroup*)node];
    } else if([node isKindOfClass:IJSVGImage.class]) {
        paint = [self drawablePaintForImageNode:(IJSVGImage*)node];
    }
    if(paint != nil) {
        if(_renderingOptions.filtersEnabled && node.filters.count != 0 &&
            IJSVGThreadManager.currentManager.CIContext != nil) {
            for(IJSVGFilter* filter in node.filters) {
                paint = [self applyFilter:filter
                                  toPaint:paint
                                 fromNode:node];
            }
        }
        [self applyDefaultsToPaint:paint
                          fromNode:node];
        return [self applyTransforms:node.transforms
                             toPaint:paint
                            fromNode:node];
    }
    return paint;
}

- (IJSVGPaint*)drawableBasicPaintForPathNode:(IJSVGPath*)node
                                resolvedPath:(CGPathRef)resolvedPath
                          resolvedPathBounds:(CGRect)resolvedPathBounds
{
    IJSVGShapePaint* paint = node.primitiveType == kIJSVGPrimitivePathTypeRect
        ? IJSVGRectPaint.paint : IJSVGShapePaint.paint;
    paint.primitiveType = node.primitiveType;
    if(CGPathIsEmpty(resolvedPath) == NO) {
        [self applyPath:resolvedPath
                 bounds:resolvedPathBounds
           toShapePaint:paint];
    }
    paint.fillColor = nil;
    paint.fillRule = node.windingRule;
    return paint;
}

// Choose the bounds used to turn relative sizes into points.
- (CGRect)unitResolutionBoundsForNode:(IJSVGNode*)node
{
    CGRect bounds = self.unitBounds;
    if(CGRectIsNull(bounds) == YES || CGRectIsEmpty(bounds) == YES) {
        bounds = self.viewPort;
    }
    if((CGRectIsNull(bounds) == YES || CGRectIsEmpty(bounds) == YES) && node.parentNode != nil) {
        bounds = node.parentNode.bounds;
    }
    return bounds;
}

- (IJSVGUnitLength*)unit:(IJSVGUnitLength*)unit
            matchingNode:(IJSVGNode*)node
{
    if(unit == nil || node.parentNode == nil) {
        return unit;
    }

    IJSVGNode* referencingNode = nil;
    IJSVGUnitType contentUnits = [node.parentNode contentUnitsWithReferencingNode:&referencingNode];
    if(contentUnits == IJSVGUnitObjectBoundingBox) {
        return [unit lengthWithUnitType:IJSVGUnitLengthTypePercentage];
    }
    return unit;
}

- (void)appendResolvedPathForPathNode:(IJSVGPath*)node
                             transform:(CGAffineTransform)transform
                                toPath:(CGMutablePathRef)path
{
    CGRect bounds = [self unitResolutionBoundsForNode:node];
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    if(node.primitiveType == kIJSVGPrimitivePathTypePath ||
        node.primitiveType == kIJSVGPrimitivePathTypePolygon ||
        node.primitiveType == kIJSVGPrimitivePathTypePolyLine) {
        if(node.pathUnits == IJSVGUnitObjectBoundingBox) {
            CGAffineTransform scale = CGAffineTransformMakeScale(width, height);
            transform = CGAffineTransformConcat(scale, transform);
        }
        CGPathAddPath(path, &transform, node.path);
        return;
    }

    switch(node.primitiveType) {
        case kIJSVGPrimitivePathTypeLine: {
            CGFloat x1 = [[self unit:node.x1 matchingNode:node] computeValue:width];
            CGFloat y1 = [[self unit:node.y1 matchingNode:node] computeValue:height];
            CGFloat x2 = [[self unit:node.x2 matchingNode:node] computeValue:width];
            CGFloat y2 = [[self unit:node.y2 matchingNode:node] computeValue:height];
            CGPathMoveToPoint(path, &transform, x1, y1);
            CGPathAddLineToPoint(path, &transform, x2, y2);
            break;
        }
        case kIJSVGPrimitivePathTypeRect: {
            IJSVGUnitLength* rx = [self unit:node.rx matchingNode:node];
            IJSVGUnitLength* ry = [self unit:(node.ry ?: node.rx) matchingNode:node];
            CGRect rect = CGRectMake([[self unit:node.x matchingNode:node] computeValue:width],
                                     [[self unit:node.y matchingNode:node] computeValue:height],
                                     [[self unit:node.width matchingNode:node] computeValue:width],
                                     [[self unit:node.height matchingNode:node] computeValue:height]);
            CGFloat radiusX = [rx computeValue:width];
            CGFloat radiusY = [ry computeValue:height];
            CGPathAddRoundedRect(path, &transform, rect, radiusX, radiusY);
            break;
        }
        case kIJSVGPrimitivePathTypeCircle: {
            CGFloat cx = [[self unit:node.cx matchingNode:node] computeValue:width];
            CGFloat cy = [[self unit:node.cy matchingNode:node] computeValue:height];
            IJSVGUnitLength* radius = [self unit:node.r matchingNode:node];
            CGFloat rx = [radius computeValue:width];
            CGFloat ry = [radius computeValue:height];
            CGRect rect = CGRectMake(cx - rx, cy - ry, rx * 2.f, ry * 2.f);
            CGPathAddEllipseInRect(path, &transform, rect);
            break;
        }
        case kIJSVGPrimitivePathTypeEllipse: {
            CGFloat cx = [[self unit:node.cx matchingNode:node] computeValue:width];
            CGFloat cy = [[self unit:node.cy matchingNode:node] computeValue:height];
            CGFloat rx = [[self unit:node.rx matchingNode:node] computeValue:width];
            CGFloat ry = [[self unit:node.ry matchingNode:node] computeValue:height];
            CGRect rect = CGRectMake(cx - rx, cy - ry, rx * 2.f, ry * 2.f);
            CGPathAddEllipseInRect(path, &transform, rect);
            break;
        }
        default: {
            break;
        }
    }

}

- (CGPathRef)newResolvedPathForPathNode:(IJSVGPath*)node
{
    if(node.primitiveType == kIJSVGPrimitivePathTypePath ||
        node.primitiveType == kIJSVGPrimitivePathTypePolygon ||
        node.primitiveType == kIJSVGPrimitivePathTypePolyLine) {
        if(node.pathUnits == IJSVGUnitObjectBoundingBox) {
            CGRect bounds = [self unitResolutionBoundsForNode:node];
            CGAffineTransform transform = CGAffineTransformMakeScale(bounds.size.width, bounds.size.height);
            return CGPathCreateCopyByTransformingPath(node.path, &transform);
        }
        return CGPathCreateCopy(node.path);
    }
    CGMutablePathRef path = CGPathCreateMutable();
    [self appendResolvedPathForPathNode:node
                              transform:CGAffineTransformIdentity
                                 toPath:path];
    return path;
}

// Move the path to start at zero inside its paint bounds.
- (CGPathRef)newPaintPathForResolvedPath:(CGPathRef)path
                                  bounds:(CGRect)pathBounds
{
    if(IJSVGRectIsFinite(pathBounds) == NO) {
        return CGPathCreateMutable();
    }
    if(pathBounds.origin.x == 0.f && pathBounds.origin.y == 0.f) {
        return CGPathRetain(path);
    }
    CGAffineTransform transform = CGAffineTransformMakeTranslation(-pathBounds.origin.x,
                                                                   -pathBounds.origin.y);
    return CGPathCreateCopyByTransformingPath(path, &transform);
}

- (void)applyPath:(CGPathRef)path
           bounds:(CGRect)pathBounds
     toShapePaint:(IJSVGShapePaint*)paint
{
    paint.path = path;

    // Save the path bounds before adding the stroke.
    // SVG bounds do not include the stroke or control points.
    paint.frame = pathBounds;
    paint.outerBoundingBox = pathBounds;
    paint.boundingBox = pathBounds;
}

+ (CGPathRef)newPathFromStrokedShapePaint:(IJSVGShapePaint*)shapePaint
{
    CGLineCap lineCap = shapePaint.lineCap;
    CGLineJoin lineJoin = shapePaint.lineJoin;
    CGPathRef dashedPath = NULL;
    if(shapePaint.lineDashPattern != nil && shapePaint.lineDashPattern.count != 0.f) {
        NSUInteger count = shapePaint.lineDashPattern.count;
        CGFloat* lengths = (CGFloat*)malloc(sizeof(CGFloat)*count);
        NSUInteger i = 0;
        for(NSNumber* number in shapePaint.lineDashPattern) {
            lengths[i++] = (CGFloat)number.floatValue;
        }
        dashedPath = CGPathCreateCopyByDashingPath(shapePaint.path, NULL,
                                                   shapePaint.lineDashPhase,
                                                   lengths, count);
        (void)free(lengths), lengths = NULL;
    }
    CGPathRef path = dashedPath ?: shapePaint.path;
    CGPathRef newPath = CGPathCreateCopyByStrokingPath(path, NULL, shapePaint.lineWidth,
                                                       lineCap, lineJoin,
                                                       shapePaint.miterLimit);
    if(dashedPath != NULL) {
        CGPathRelease(dashedPath);
    }
    return newPath;
}

- (NSColor*)colorForColor:(NSColor*)color
           matchingTraits:(IJSVGColorUsageTraits)traits
{
    return [_style.colors colorForColor:color
                         matchingTraits:traits];
}

- (IJSVGPaint*)drawableFillPaintForPathNode:(IJSVGPath*)node
                                      paint:(IJSVGShapePaint*)paint
                               resolvedPath:(CGPathRef)paintPath
                         resolvedPathBounds:(CGRect)resolvedPathBounds
{
    // Choose the fill type.
    IJSVGPaint* fillPaint = nil;
    IJSVGPaintFillType fillType = [IJSVGPaint fillTypeForFill:node.fill];

    switch(fillType) {
        // Fill with one color.
        default:
        case IJSVGPaintFillTypeColor: {

            IJSVGColorNode* colorNode = (IJSVGColorNode*)node.fill;
            NSColor* color = colorNode.color ?: NSColor.blackColor;

            // Use the fill color supplied by the style.
            if(_style.fillColor != nil) {
                color = _style.fillColor;
            }

            if(colorNode.isNoneOrTransparent == YES) {
                color = nil;
            } else {
                // Apply any color replacement from the style.
                NSColor* repColor = [self colorForColor:color
                                         matchingTraits:IJSVGColorUsageTraitFill];
                color = repColor ?: color;
            }

            // Use a separate shape for the fill so the stroke can sit around it.
            IJSVGShapePaint* shape = (IJSVGShapePaint*)[self drawableBasicPaintForPathNode:node
                                                                              resolvedPath:paintPath
                                                                        resolvedPathBounds:resolvedPathBounds];
            shape.fillColor = color.CGColor;
            CGRect shapeRect = shape.frame;

            // Start the fill at zero. The stroke spacing is added later.
            shapeRect.origin.x = 0.f;
            shapeRect.origin.y = 0.f;
            shape.frame = shapeRect;
            fillPaint = shape;
            break;
        }

        // Fill with a pattern.
        case IJSVGPaintFillTypePattern: {
            fillPaint = [self drawablePatternPaintForPathNode:node
                                                      pattern:(IJSVGPattern*)node.fill
                                                        paint:paint];
            break;
        }

        // Fill with a gradient.
        case IJSVGPaintFillTypeGradient: {
            fillPaint = [self drawableGradientPaintForPathNode:node
                                                      gradient:(IJSVGGradient*)node.fill
                                                         paint:paint];

            break;
        }
    }

    return fillPaint;
}

- (void)applyStrokePaint:(IJSVGStrokePaint*)strokePaint
                 toPaint:(IJSVGShapePaint*)paint
                fromNode:(IJSVGPath*)node
{
    paint.strokeStyle = strokePaint;
    // Choose how to fill the stroke.
    IJSVGPaintFillType type = [IJSVGPaint fillTypeForFill:node.stroke];

    switch(type) {
        // Fill the stroke with a pattern.
        case IJSVGPaintFillTypePattern: {
            IJSVGPatternPaint* patternPaint = nil;
            patternPaint = [self drawableBasicPatternPaintForPaint:strokePaint
                                                           pattern:(IJSVGPattern*)node.stroke];
            patternPaint.referencingPaint = paint;

            // Keep the drawing inside the stroke shape.
            CGPathRef path = [self.class newPathFromStrokedShapePaint:strokePaint];
            patternPaint.clipPath = path;
            CGPathRelease(path);
            paint.strokePaint = patternPaint;
            [paint addChild:patternPaint];
            break;
        }

        // Fill the stroke with a gradient.
        case IJSVGPaintFillTypeGradient: {
            IJSVGGradientPaint* gradientPaint = nil;
            gradientPaint = [self drawableBasicGradientPaintForPaint:strokePaint
                                                            gradient:(IJSVGGradient*)node.stroke];
            gradientPaint.referencingPaint = paint;

            // Keep the drawing inside the stroke shape.
            CGPathRef path = [self.class newPathFromStrokedShapePaint:strokePaint];
            gradientPaint.clipPath = path;
            CGPathRelease(path);
            paint.strokePaint = gradientPaint;
            [paint addChild:gradientPaint];
            break;
        }

        // Draw a plain stroke.
        default: {
            paint.strokePaint = strokePaint;
            [paint addChild:strokePaint];
            break;
        }
    }

}

- (IJSVGPaint*)drawablePaintForPathNode:(IJSVGPath*)node
{
    CGPathRef resolvedPath = [self newResolvedPathForPathNode:node];
    BOOL resolvedPathIsEmpty = CGPathIsEmpty(resolvedPath);
    CGRect resolvedPathBounds = resolvedPathIsEmpty == YES ? CGRectZero : CGPathGetPathBoundingBox(resolvedPath);
    BOOL resolvedPathBoundsAreFinite = resolvedPathIsEmpty == NO && IJSVGRectIsFinite(resolvedPathBounds);
    if(resolvedPathBoundsAreFinite == NO) {
        resolvedPathBounds = CGRectZero;
    }
    CGPathRef paintPath = resolvedPathBoundsAreFinite == YES ?
        [self newPaintPathForResolvedPath:resolvedPath
                                   bounds:resolvedPathBounds] : CGPathCreateMutable();
    IJSVGShapePaint* paint = (IJSVGShapePaint*)[self drawableBasicPaintForPathNode:node
                                                                      resolvedPath:paintPath
                                                                resolvedPathBounds:resolvedPathBounds];

    // Create the stroke.
    IJSVGStrokePaint* strokePaint = nil;
    CGFloat strokeWidthDifference = 0.f;
    if([node matchesTraits:IJSVGNodeTraitStroked]) {
        // Expand the paint so its frame includes the stroke.
        strokePaint = (IJSVGStrokePaint*)[self drawableStrokedPaintForPathNode:node
                                                                  resolvedPath:paintPath
                                                            resolvedPathBounds:resolvedPathBounds];
        strokeWidthDifference = strokePaint.lineWidth * .5f;

        // Update the bounds to include the stroke.
        paint.frame = CGRectInset(paint.frame, -strokeWidthDifference,
                                  -strokeWidthDifference);
        paint.outerBoundingBox = paint.frame;
    }

    IJSVGPaint* fillPaint = [self drawableFillPaintForPathNode:node
                                                         paint:paint
                                                  resolvedPath:paintPath
                                            resolvedPathBounds:resolvedPathBounds];

    if(fillPaint != nil) {
        // Apply the fill opacity.
        if(node.fillOpacity.value != 1.f) {
            fillPaint.opacity = node.fillOpacity.value;
        }
        fillPaint.affineTransform = CGAffineTransformTranslate(fillPaint.affineTransform,
                                                                   strokeWidthDifference,
                                                                   strokeWidthDifference);
        paint.fillPaint = fillPaint;
        [paint addChild:fillPaint];
    }

    // Attach the stroke.
    if(strokePaint != nil) {
        [self applyStrokePaint:strokePaint
                       toPaint:paint
                      fromNode:node];
    }

    CGPathRelease(paintPath);
    CGPathRelease(resolvedPath);
    return paint;
}

- (IJSVGPaint*)drawableStrokedPaintForPathNode:(IJSVGPath*)node
                                  resolvedPath:(CGPathRef)resolvedPath
                            resolvedPathBounds:(CGRect)resolvedPathBounds
{
    IJSVGStrokePaint* paint = IJSVGStrokePaint.paint;
    [self applyPath:resolvedPath
             bounds:resolvedPathBounds
       toShapePaint:paint];

    // Choose the stroke color.
    NSColor* strokeColor = NSColor.blackColor;
    if([node.stroke isKindOfClass:IJSVGColorNode.class]) {
        IJSVGColorNode* colorNode = (IJSVGColorNode*)node.stroke;
        strokeColor = colorNode.color;
    }

    // Apply any color replacement.
    NSColor* repColor = [self colorForColor:strokeColor
                             matchingTraits:IJSVGColorUsageTraitStroke];
    strokeColor = repColor ?: strokeColor;

    // Use the stroke color supplied by the style.
    if(_style.strokeColor != nil) {
        strokeColor = _style.strokeColor;
    }

    // Store the color.
    paint.fillColor = nil;
    paint.strokeColor = strokeColor.CGColor;

    IJSVGQuartzConfigureStroke(paint, node, _style);
    IJSVGQuartzExpandStrokeBounds(paint);

    return paint;
}

- (IJSVGPaint*)drawablePaintForRootNode:(IJSVGRootNode*)node
{
    IJSVGRootPaint* paint = IJSVGRootPaint.paint;
    paint.viewBox = node.viewBox;
    paint.intrinsicSize = node.intrinsicSize;
    paint.viewBoxAlignment = node.viewBoxAlignment;
    paint.viewBoxMeetOrSlice = node.viewBoxMeetOrSlice;

    CGRect bounds = [self unitResolutionBoundsForNode:node];
    CGFloat boundsWidth = CGRectGetWidth(bounds);
    CGFloat boundsHeight = CGRectGetHeight(bounds);
    CGSize intrinsicSize = [node.intrinsicSize computeValue:bounds.size];
    CGFloat width = [[self unit:node.width
                   matchingNode:node] computeValue:boundsWidth];
    CGFloat height = [[self unit:node.height
                    matchingNode:node] computeValue:boundsHeight];
    if(width == 0.f) {
        width = intrinsicSize.width;
    }
    if(height == 0.f) {
        height = intrinsicSize.height;
    }
    CGRect frame = CGRectMake([[self unit:node.x
                             matchingNode:node] computeValue:boundsWidth],
                              [[self unit:node.y
                             matchingNode:node] computeValue:boundsHeight],
                              width, height);
    paint.frame = frame;

    // Resolve child sizes using the viewBox.
    // The root applies the final scale when drawing so children must not be scaled twice.
    CGRect childBounds = (CGRect) {
        .origin = CGPointZero,
        .size = paint.frame.size
    };
    if(node.viewBox != nil) {
        childBounds = [node.viewBox computeValue:paint.frame.size];
    }

    CGAffineTransform previous = _textTransform;
    if(node.viewBox != nil) {
        CGSize size = node == _textBuildRoot ? _textRenderFrameSize : frame.size;
        CGRect viewBox = [node.viewBox computeValue:size];
        CGAffineTransform transform = IJSVGViewBoxComputeTransform(viewBox,
                                                                   (CGRect){ CGPointZero, size },
                                                                   node.viewBoxAlignment,
                                                                   node.viewBoxMeetOrSlice);
        _textTransform = CGAffineTransformConcat(transform, previous);
    }
    @try {
        [self withViewPort:childBounds
                unitBounds:childBounds
                   handler:^{
            paint.children = [self drawablePaintsForNodes:node.children];
        }];
    } @finally {
        _textTransform = previous;
    }
    return paint;
}

- (IJSVGPaint*)drawablePaintForGroupNode:(IJSVGGroup*)node
{
    NSArray<IJSVGPaint*>* paints = [self drawablePaintsForNodes:node.children];
    return [self drawablePaintForGroupNode:node
                                  children:paints];
}

- (IJSVGPaint*)drawablePaintForGroupNode:(IJSVGNode*)node
                                children:(NSArray<IJSVGPaint*>*)children
{
    IJSVGGroupPaint* paint = [node isKindOfClass:IJSVGMask.class] ? IJSVGMaskPaint.paint
        : IJSVGGroupPaint.paint;
    paint.boundingBox = [IJSVGPaint calculateFrameForChildren:children];
    paint.outerBoundingBox = paint.boundingBox;
    paint.children = children;
    return paint;
}

- (NSArray<IJSVGPaint*>*)drawablePaintsForNodes:(NSArray<IJSVGNode*>*)nodes
{
    NSMutableArray<IJSVGPaint*>* paints = nil;
    paints = [NSMutableArray.alloc initWithCapacity:nodes.count];
    for(IJSVGNode* node in nodes) {
        IJSVGPaint* paint = [self drawablePaintForNode:node];
        if(paint != nil) {
            [paints addObject:paint];
        }
    }
    return paints;
}

#pragma mark Gradients and Patterns

- (IJSVGGradientPaint*)drawableBasicGradientPaintForPaint:(IJSVGPaint*)paint
                                                 gradient:(IJSVGGradient*)gradient
{
    // Create the gradient fill.
    IJSVGGradientPaint* gradientPaint = IJSVGGradientPaint.paint;
    gradientPaint.backingScaleFactor = _backingScale;

    // Copy the gradient so style changes leave the original unchanged.
    IJSVGColorUsageTraits traits = IJSVGColorUsageTraitGradientStop;
    if(_style.colors.replacedColorCount != 0 &&
        [_style.colors matchesReplacementTraits:traits] == YES) {
        gradient = gradient.copy;
        NSMutableArray* colors = nil;
        colors = [NSMutableArray.alloc initWithCapacity:gradient.numberOfStops];
        for(NSColor* color in gradient.colors) {
            NSColor* repColor = [self colorForColor:color
                                     matchingTraits:traits];
            NSColor* compColor = repColor ?: color;
            [colors addObject:compColor];
        }
        gradient.colors = colors;
    }

    gradientPaint.gradient = gradient;
    gradientPaint.frame = paint.bounds;
    gradientPaint.viewBox = self.viewPort;
    gradientPaint.opacity = paint.opacity;

    return gradientPaint;
}

- (IJSVGPaint*)drawableGradientPaintForPathNode:(IJSVGPath*)node
                                       gradient:(IJSVGGradient*)gradient
                                          paint:(IJSVGPaint*)paint
{
    // Create the gradient fill.
    IJSVGGradientPaint* gradientPaint = [self drawableBasicGradientPaintForPaint:paint
                                                                        gradient:gradient];

    // Clip the fill to the shape in its local coordinates.
    gradientPaint.clipRule = paint.fillRule;
    gradientPaint.clipPath = ((IJSVGShapePaint*)paint).path;
    return gradientPaint;
}

- (IJSVGPatternPaint*)drawableBasicPatternPaintForPaint:(IJSVGPaint*)paint
                                                pattern:(IJSVGPattern*)pattern
{
    // Create the pattern fill.
    IJSVGPatternPaint* patternPaint = IJSVGPatternPaint.paint;
    patternPaint.patternNode = pattern;
    patternPaint.frame = (CGRect) {
        .origin = CGPointZero,
        .size = paint.outerBoundingBox.size
    };

    CGRect unitBounds = pattern.units == IJSVGUnitUserSpaceOnUse ? self.viewPort : paint.boundingBox;
    __block IJSVGPaint* patternFill = nil;
    [self withUnitBounds:unitBounds
                 handler:^{
        patternFill = [self drawablePaintForNode:pattern];
    }];
    patternFill.referencingPaint = patternPaint;
    patternPaint.pattern = patternFill;
    patternPaint.opacity = paint.opacity;

    return patternPaint;
}

- (IJSVGPaint*)drawablePatternPaintForPathNode:(IJSVGPath*)node
                                       pattern:(IJSVGPattern*)pattern
                                         paint:(IJSVGPaint*)paint
{
    // Create the pattern fill.
    IJSVGPatternPaint* patternPaint = [self drawableBasicPatternPaintForPaint:paint
                                                                      pattern:pattern];
    // Clip the fill to the shape in its local coordinates.
    patternPaint.clipRule = paint.fillRule;
    patternPaint.clipPath = ((IJSVGShapePaint*)paint).path;

    return patternPaint;
}

- (IJSVGPaint*)maskPaintFromNode:(IJSVGMask*)mask
                referencingPaint:(IJSVGPaint*)paint
                       fromPaint:(IJSVGPaint*)fromPaint

{
    IJSVGMask* maskNode = mask;
    __block IJSVGPaint* maskPaint = nil;
    CGRect viewPort = maskNode.units == IJSVGUnitUserSpaceOnUse ? self.viewPort : paint.boundingBox;
    CGRect contentBounds = maskNode.contentUnits == IJSVGUnitUserSpaceOnUse ? self.viewPort : paint.boundingBox;
    if(fromPaint == nil) {
        [self withUnitBounds:contentBounds
                     handler:^{
            maskPaint = (IJSVGPaint*)[self drawablePaintForNode:maskNode];
        }];
    } else {
        maskPaint = fromPaint;
    }
    CGFloat width = CGRectGetWidth(viewPort);
    CGFloat height = CGRectGetHeight(viewPort);
    CGRect rect = CGRectZero;
    IJSVGUnitLength* xUnit = maskNode.x;
    IJSVGUnitLength* yUnit = maskNode.y;
    IJSVGUnitLength* widthUnit = maskNode.width;
    IJSVGUnitLength* heightUnit = maskNode.height;

    // Treat these values as fractions of the object bounds.
    if(maskNode.units == IJSVGUnitObjectBoundingBox) {
        xUnit = [xUnit lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        yUnit = [yUnit lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        widthUnit = [widthUnit lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        heightUnit = [heightUnit lengthWithUnitType:IJSVGUnitLengthTypePercentage];
    }

    // Calculate the mask clip rectangle.
    rect.origin.x = [xUnit computeValue:width];
    rect.origin.y = [yUnit computeValue:height];
    rect.size.width = [widthUnit computeValue:width];
    rect.size.height = [heightUnit computeValue:height];

    // Find the bounds where the mask will be drawn.
    CGRect paintBounds = paint.innerBoundingBox;
    CGRect maskBounds = maskPaint.outerBoundingBox;
    CGRect maskingBounds = paintBounds;
    rect.origin.x += paintBounds.origin.x;
    rect.origin.y += paintBounds.origin.y;

    maskingBounds.size.width = maskBounds.size.width;
    maskingBounds.size.height = maskBounds.size.height;

    CGAffineTransform userSpaceTransform = [IJSVGPaint userSpaceTransformForPaint:paint];
    if(maskNode.contentUnits == IJSVGUnitUserSpaceOnUse) {
        maskingBounds.origin.x += maskBounds.origin.x;
        maskingBounds.origin.y += maskBounds.origin.y;
        maskingBounds = CGRectApplyAffineTransform(maskingBounds, userSpaceTransform);
    }

    if(maskNode.units == IJSVGUnitUserSpaceOnUse) {
        rect = CGRectApplyAffineTransform(rect, userSpaceTransform);
    }

    maskPaint.maskingBoundingBox = maskingBounds;
    maskPaint.maskingClippingRect = rect;
    maskPaint.referencingPaint = paint;
    [maskPaint prepareMaskCaching];
    return maskPaint;
}

- (NSArray<IJSVGPaint*>*)clipPaintsFromNode:(IJSVGClipPath*)node
                           referencingPaint:(IJSVGPaint*)paint
                                  fromPaint:(IJSVGPaint*)fromPaint
{
    NSMutableArray<IJSVGPaint*>* paints = nil;
    paints = [[NSMutableArray alloc] init];
    IJSVGClipPath* refClipPath = node;
    __block IJSVGGroupPaint* groupPaint = nil;
    CGRect contentBounds = node.contentUnits == IJSVGUnitUserSpaceOnUse ? self.viewPort : paint.boundingBox;
    while(refClipPath != nil) {
        [self withUnitBounds:contentBounds
                     handler:^{
            groupPaint = (IJSVGGroupPaint*)[self drawablePaintForNode:refClipPath];
        }];
        if(groupPaint != nil) {
            groupPaint.referencingPaint = paint;
            [paints addObject:groupPaint];
        }
        refClipPath = refClipPath.clipPath;
    }
    CGRect clippingRect = [IJSVGPaint calculateFrameForChildren:paints];
    CGAffineTransform userSpaceTransform = [IJSVGPaint userSpaceTransformForPaint:paint];
    CGAffineTransform clippingTransform = CGAffineTransformIdentity;
    if(node.contentUnits == IJSVGUnitUserSpaceOnUse) {
        clippingRect = CGRectApplyAffineTransform(clippingRect, userSpaceTransform);
        clippingTransform = userSpaceTransform;
    }
    CGAffineTransform ident = CGAffineTransformMakeTranslation(-CGRectGetMinX(clippingRect),
                                                               -CGRectGetMinY(clippingRect));
    clippingTransform = CGAffineTransformConcat(clippingTransform, ident);
    paint.clippingTransform = clippingTransform;
    paint.clippingBoundingBox = clippingRect;
    return paints;
}

// Collect paths from this group and any groups inside it.
- (void)recursivelyAddResolvedPathsForNodes:(NSArray<IJSVGNode*>*)nodes
                                  transform:(CGAffineTransform)transform
                                     toPath:(CGMutablePathRef)mutPath
{
    for(IJSVGNode* node in nodes) {
        if([node isKindOfClass:IJSVGText.class]) {
            IJSVGTextLayout* layout = [self textLayoutForNode:(IJSVGText*)node];
            [self recursivelyAddResolvedPathsForNodes:layout.group.children
                                            transform:transform
                                               toPath:mutPath];
            continue;
        }
        if([node isKindOfClass:IJSVGPath.class] == YES &&
            [node matchesTraits:IJSVGNodeTraitPathed] == YES) {
            [self appendResolvedPathForPathNode:(IJSVGPath*)node
                                      transform:transform
                                         toPath:mutPath];
            continue;
        }
        if([node isKindOfClass:IJSVGGroup.class] == YES) {
            [self recursivelyAddResolvedPathsForNodes:((IJSVGGroup*)node).children
                                            transform:transform
                                               toPath:mutPath];
        }
    }
}

// Combine the clip shapes in the same coordinate space as the paint.
- (CGPathRef)newClipPathFromNode:(IJSVGClipPath*)node
                       fromPaint:(IJSVGPaint*)paint
{
    CGMutablePathRef mPath = CGPathCreateMutable();
    CGAffineTransform transform = CGAffineTransformIdentity;
    if(node.contentUnits == IJSVGUnitUserSpaceOnUse) {
        transform = [IJSVGPaint userSpaceTransformForPaint:paint];
    }
    CGRect paintRect = paint.innerBoundingBox;
    CGAffineTransform paintTransform = CGAffineTransformMakeTranslation(CGRectGetMinX(paintRect),
                                                                        CGRectGetMinY(paintRect));
    transform = CGAffineTransformConcat(transform, paintTransform);
    CGRect contentBounds = node.contentUnits == IJSVGUnitUserSpaceOnUse ? self.viewPort : paint.boundingBox;
    IJSVGClipPath* clipPath = node;
    while(clipPath != nil) {
        [self withUnitBounds:contentBounds
                     handler:^{
            [self recursivelyAddResolvedPathsForNodes:clipPath.children
                                            transform:transform
                                               toPath:mPath];
        }];
        clipPath = clipPath.clipPath;
    }
    return mPath;
}

// Draw a solid color, gradient or pattern while preserving the context settings.
- (void)drawPaint:(IJSVGNode*)paint
      boundingBox:(CGRect)boundingBox
         viewPort:(CGRect)viewPort
           region:(CGRect)region
        inContext:(CGContextRef)context
{
    CGContextSaveGState(context);
    if([paint isKindOfClass:IJSVGColorNode.class]) {
        NSColor* color = ((IJSVGColorNode*)paint).color;
        if(color != nil) {
            CGContextSetFillColorWithColor(context, color.CGColor);
            CGContextFillRect(context, region);
        }
    } else if([paint isKindOfClass:IJSVGGradient.class]) {
        IJSVGGradient* gradient = (IJSVGGradient*)paint;
        if(gradient.units == IJSVGUnitObjectBoundingBox) {
            CGContextTranslateCTM(context, boundingBox.origin.x, boundingBox.origin.y);
        }
        [gradient drawInContextRef:context
                            bounds:gradient.units == IJSVGUnitObjectBoundingBox ? boundingBox : viewPort
                         transform:CGAffineTransformIdentity];
    } else if([paint isKindOfClass:IJSVGPattern.class]) {
        IJSVGGroupPaint* reference = IJSVGGroupPaint.paint;
        reference.boundingBox = boundingBox;
        reference.outerBoundingBox = boundingBox;
        reference.frame = boundingBox;
        [self withViewPort:viewPort
                unitBounds:boundingBox
                   handler:^{
             IJSVGPatternPaint* pattern = [self drawableBasicPatternPaintForPaint:reference
                                                                          pattern:(IJSVGPattern*)paint];
             pattern.referencingPaint = reference;
             pattern.frame = region;
             pattern.boundingBox = region;
             pattern.outerBoundingBox = region;
             CGContextTranslateCTM(context, region.origin.x, region.origin.y);
             [pattern renderInContext:context];
        }];
    }
    CGContextRestoreGState(context);
}

#pragma mark Filters

- (IJSVGPaint*)applyFilter:(IJSVGFilter*)filter
                   toPaint:(IJSVGPaint*)paint
                  fromNode:(IJSVGNode*)node
{
    if(filter == nil) {
        return paint;
    }

    if([paint isKindOfClass:IJSVGRootPaint.class]) {
        // Filter root contents in viewBox coordinates.
        // Apply root opacity and clipping afterward.
        IJSVGRootPaint* rootPaint = (IJSVGRootPaint*)paint;
        IJSVGGroupPaint* source = IJSVGGroupPaint.paint;
        source.children = rootPaint.children;
        rootPaint.children = @[];
        source.boundingBox = [IJSVGPaint calculateFrameForChildren:source.children];
        source.outerBoundingBox = source.boundingBox;
        CGRect viewPort
            = rootPaint.viewBox != nil ? [rootPaint.viewBox computeValue:rootPaint.frame.size] : rootPaint.bounds;
        IJSVGFilterPaint* filtered = [IJSVGFilterPaint.alloc initWithSourcePaint:source
                                                                          filter:filter
                                                                        viewPort:viewPort];
        filtered.sourceNode = node;
        filtered.cachesRenderedOutput = YES;
        [rootPaint addChild:filtered];
        return rootPaint;
    }

    IJSVGFilterPaint* filtered = [IJSVGFilterPaint.alloc initWithSourcePaint:paint
                                                                      filter:filter
                                                                    viewPort:self.viewPort];
    filtered.sourceNode = node;
    filtered.cachesRenderedOutput = YES;
    return filtered;
}

#pragma mark Defaults

- (void)applyDefaultsToPaint:(IJSVGPaint*)paint
                    fromNode:(IJSVGNode*)node
{
    paint.sourceNode = node;
    paint.viewPort = self.viewPort;

    // Apply the mask.
    if(node.mask != nil) {
        paint.maskPaint = [self maskPaintFromNode:node.mask
                                 referencingPaint:paint
                                        fromPaint:nil];
    }

    // Apply the clip path.
    if(node.clipPath != nil) {
        IJSVGClipPath* clipPath = node.clipPath;
        CGPathRef path = [self newClipPathFromNode:clipPath
                                         fromPaint:paint];

        IJSVGWindingRule clipRule = node.clipRule;
        if(clipRule == IJSVGWindingRuleInherit) {
            clipRule = clipPath.computedClipRule;
        }

        paint.clipPath = path;
        paint.clipRule = clipRule;
        CGPathRelease(path);
    }

    // Set the opacity.
    CGFloat opacity = node.opacity.value;
    if(opacity != 1.f) {
        paint.opacity = opacity;
    }

    // Set the blend mode.
    if(node.blendMode != IJSVGBlendModeNormal) {
        paint.blendingMode = (CGBlendMode)node.blendMode;
    }

    // Hide the paint when needed.
    if(node.shouldRender == NO) {
        paint.hidden = YES;
    }
}

#pragma mark Transforms

- (IJSVGPaint*)applyTransforms:(NSArray<IJSVGTransform*>*)transforms
                       toPaint:(IJSVGPaint*)paint
                      fromNode:(IJSVGNode*)node

{
    // Read the node position.
    CGRect unitBounds = [self unitResolutionBoundsForNode:node];
    CGFloat unitWidth = CGRectGetWidth(unitBounds);
    CGFloat unitHeight = CGRectGetHeight(unitBounds);
    CGFloat x = 0.f;
    CGFloat y = 0.f;

    BOOL shouldApplyImplicitOrigin = paint.treatImplicitOriginAsTransform == YES;
    if(shouldApplyImplicitOrigin == YES) {
        x = [[self unit:node.x matchingNode:node] computeValue:unitWidth];
        y = [[self unit:node.y matchingNode:node] computeValue:unitHeight];
    }

    // Skip the wrapper when the position and transform are unchanged.
    if(transforms.count == 0 && x == 0.f && y == 0.f) {
        return paint;
    }

    // Combine the transforms.
    CGAffineTransform identity = CGAffineTransformIdentity;
    if(x != 0.f || y != 0.f) {
        identity = CGAffineTransformTranslate(identity, x, y);
    }

    IJSVGNode* referencingNode = nil;
    IJSVGUnitType contentUnits = [node.parentNode contentUnitsWithReferencingNode:&referencingNode];

    // Use one wrapper for all transforms to save memory.
    // Keep their original order.
    IJSVGTransformPaint* parentPaint = IJSVGTransformPaint.paint;
    for(IJSVGTransform* transform in transforms.reverseObjectEnumerator) {
        IJSVGTransform* resolvedTransform = [transform transformByApplyingUnits:contentUnits
                                                                         bounds:unitBounds];
        identity = CGAffineTransformConcat(identity, resolvedTransform.CGAffineTransform);
    }
    parentPaint.affineTransform = identity;
    [parentPaint addChild:paint];
    parentPaint.outerBoundingBox = [IJSVGPaint calculateFrameForChildren:parentPaint.children];
    return parentPaint;
}

#pragma mark Images

- (IJSVGPaint*)drawablePaintForImageNode:(IJSVGImage*)image
{
    IJSVGImagePaint* paint = [IJSVGImagePaint.alloc initWithImage:image];
    CGRect bounds = [self unitResolutionBoundsForNode:image];
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    CGRect frame = CGRectMake([[self unit:image.x matchingNode:image] computeValue:width],
                              [[self unit:image.y matchingNode:image] computeValue:height],
                              [[self unit:image.width matchingNode:image] computeValue:width],
                              [[self unit:image.height matchingNode:image] computeValue:height]);

    if(frame.size.width == 0.f) {
        frame.size.width = image.intrinsicSize.width;
    }
    if(frame.size.height == 0.f) {
        frame.size.height = image.intrinsicSize.height;
    }

    paint.frame = frame;

    return (IJSVGPaint*)paint;
}

// Keep earlier artwork in a bitmap so filters can read the background.
// Use this for screen drawing and PDF output.
- (BOOL)paintRequiresBackdrop:(IJSVGPaint*)root
{
    NSMutableArray<IJSVGPaint*>* pending = [NSMutableArray arrayWithObject:root];
    NSMutableSet<IJSVGPaint*>* visited = [[NSMutableSet alloc] init];
    while(pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if([visited containsObject:paint]) {
            continue;
        }
        [visited addObject:paint];
        if([paint isKindOfClass:IJSVGFilterPaint.class]) {
            if(((IJSVGFilterPaint*)paint).usesBackground) {
                return YES;
            }
        }
        [pending addObjectsFromArray:paint.children ?: @[]];
        [pending addObjectsFromArray:paint.clipPaints ?: @[]];
        if(paint.maskPaint != nil) {
            [pending addObject:paint.maskPaint];
        }
        if([paint isKindOfClass:IJSVGPatternPaint.class]) {
            IJSVGPaint* pattern = ((IJSVGPatternPaint*)paint).pattern;
            if(pattern != nil) {
                [pending addObject:pattern];
            }
        }
    }
    return NO;
}

- (void)renderBackdropPaintInContext:(CGContextRef)ctx
                               frame:(CGRect)frame
{
    // Include the display scale when mapping to pixels.
    // One pixel in the temporary image should match one output pixel.
    CGPoint origin = CGContextConvertPointToDeviceSpace(ctx, CGPointZero);
    CGPoint xAxis = CGContextConvertPointToDeviceSpace(ctx, CGPointMake(1, 0));
    CGPoint yAxis = CGContextConvertPointToDeviceSpace(ctx, CGPointMake(0, 1));
    CGAffineTransform transform = CGAffineTransformMake(
        xAxis.x - origin.x, xAxis.y - origin.y,
        yAxis.x - origin.x, yAxis.y - origin.y, origin.x, origin.y);
    CGRect bounds = CGRectIntegral(CGRectApplyAffineTransform(
        CGRectMake(0, 0, frame.size.width, frame.size.height), transform));
    if(!IJSVGRectIsFinite(bounds) || CGRectIsEmpty(bounds) ||
        transform.a * transform.d - transform.b * transform.c == 0) {
        return;
    }
    // Limit memory use for large print and export sizes.
    // Keep full pixel detail for normal drawing.
    CGFloat scale = MIN(1.f, MIN(4096.f / bounds.size.width, 4096.f / bounds.size.height));
    size_t width = MAX(1, ceil(bounds.size.width * scale));
    size_t height = MAX(1, ceil(bounds.size.height * scale));
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, 0,
        space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if(bitmap == NULL) {
        return;
    }
    CGContextSetInterpolationQuality(bitmap, CGContextGetInterpolationQuality(ctx));
    CGContextScaleCTM(bitmap, width / bounds.size.width, height / bounds.size.height);
    CGContextTranslateCTM(bitmap, -bounds.origin.x, -bounds.origin.y);
    CGContextConcatCTM(bitmap, transform);
    CGImageRef image = NULL;
    @try {
        [IJSVGFilterPaint renderPaint:_rootPaint
                      inBitmapContext:bitmap];
        image = CGBitmapContextCreateImage(bitmap);
    } @finally {
        CGContextRelease(bitmap);
    }
    if(image != NULL) {
        CGContextSaveGState(ctx);
        CGContextConcatCTM(ctx, CGAffineTransformInvert(transform));
        CGContextDrawImage(ctx, bounds, image);
        CGContextRestoreGState(ctx);
        CGImageRelease(image);
    }
}

- (void)renderNode:(IJSVGRootNode*)rootNode
         inContext:(CGContextRef)ctx
          viewPort:(CGRect)viewPort
      backingScale:(CGFloat)backingScale
{
    if(ctx == NULL || rootNode == nil || !IJSVGRectIsFinite(viewPort) || CGRectIsEmpty(viewPort)) {
        return;
    }
    CGRect frame = viewPort;
    if(!_renderingOptions.ignoreIntrinsicSize && rootNode.intrinsicSize != nil) {
        CGSize size = [rootNode.intrinsicSize computeValue:viewPort.size];
        if(size.width != 0.f) {
            frame.size.width = size.width;
        }
        if(size.height != 0.f) {
            frame.size.height = size.height;
        }
    }
    CGAffineTransform outputTransform = CGContextGetUserSpaceToDeviceSpaceTransform(ctx);
    outputTransform.tx = 0;
    outputTransform.ty = 0;
    BOOL textScaleChanged = _containsText &&
        (!CGAffineTransformEqualToTransform(outputTransform,
                                            _textRenderTransform) ||
         !CGSizeEqualToSize(frame.size, _textRenderFrameSize));
    if(_rootPaint == nil || _rootNode != rootNode ||
       !CGSizeEqualToSize(_clientSize, rootNode.clientSize) || textScaleChanged) {
        _backingScale = backingScale;
        _textRenderTransform = outputTransform;
        _textRenderFrameSize = frame.size;
        _textTransform = outputTransform;
        _textBuildRoot = rootNode;
        _containsText = NO;
        @try {
            _rootPaint = [self rootPaintForRootNode:rootNode];
        } @finally {
            _textTransform = CGAffineTransformIdentity;
            _textBuildRoot = nil;
        }
        _batchableFilters = [IJSVGFilterPaint batchableFiltersForPaint:_rootPaint];
        _requiresBackdrop = [self paintRequiresBackdrop:_rootPaint];
        _rootNode = rootNode;
        _clientSize = rootNode.clientSize;
    }
    _rootPaint.frame = frame;
    _rootPaint.backingScaleFactor = backingScale;
    _rootPaint.renderQuality = _renderingOptions.renderQuality;
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, viewPort.origin.x, viewPort.origin.y);
    @try {
        void (^drawingBlock)(CGContextRef) = ^(CGContextRef destination) {
            [self->_rootPaint renderInContext:destination];
        };
        // Resolve the destination pixels once for filters and batch collection.
        CGAffineTransform pixelTransform = CGContextGetUserSpaceToDeviceSpaceTransform(ctx);
        [IJSVGFilterPaint drawInContext:ctx
                         pixelTransform:pixelTransform
                           drawingBlock:^{
            if(self->_requiresBackdrop) {
                [self renderBackdropPaintInContext:ctx
                                             frame:frame];
            } else if(self->_batchableFilters == nil || ![IJSVGFilterPaint renderBatchedPaints:self->_batchableFilters
                                                                                     inContext:ctx
                                                                                  drawingBlock:drawingBlock]) {
                drawingBlock(ctx);
            }
        }];
    } @finally {
        CGContextRestoreGState(ctx);
    }
}

- (void)setStyle:(IJSVGStyle*)style
{
    _style = style;
    _rootPaint = nil;
    _batchableFilters = nil;
}

- (void)setRenderingOptions:(IJSVGRenderingOptions*)options
{
    _renderingOptions = options.copy;
    _rootPaint = nil;
    _batchableFilters = nil;
}

@end
