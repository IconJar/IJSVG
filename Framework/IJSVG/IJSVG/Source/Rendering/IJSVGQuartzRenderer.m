//
//  IJSVGQuartzRenderer.m
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGByteCache.h"
#import <IJSVG/IJSVGAnchor.h>
#import <IJSVG/IJSVGCircle.h>
#import <IJSVG/IJSVGEllipse.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGLine.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGPattern.h>
#import <IJSVG/IJSVGRect.h>
#import <IJSVG/IJSVGRegion.h>
#import <IJSVG/IJSVGRoundedShape.h>
#import <IJSVG/IJSVGSymbol.h>
#import <IJSVG/IJSVGTextLayout.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUse.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGColorMatrixFilterEffect.h>
#import <IJSVGFilterGraph.h>
#import <IJSVGFilterPaint.h>
#import <IJSVGGradientPaint.h>
#import <IJSVGGroupPaint.h>
#import <IJSVGImagePaint.h>
#import <IJSVGMaskPaint.h>
#import <IJSVGPaint.h>
#import <IJSVGPatternPaint.h>
#import <IJSVGQuartzRenderer.h>
#import <IJSVGRectPaint.h>
#import <IJSVGRootPaint.h>
#import <IJSVGShapePaint.h>
#import <IJSVGStrokePaint.h>
#import <IJSVGTextFontResolver.h>
#import <IJSVGTextPathMetrics.h>
#import <IJSVGTransformPaint.h>

static IJSVGFilterPrimitive* IJSVGCSSChainColorPrimitive(IJSVGFilter* filter)
{
    if (!filter.usesSourceRegion || filter.cssBlurRadius != nil || filter.children.count != 1 || filter.filterColorInterpolation != IJSVGColorInterpolationSRGB) {
        return nil;
    }
    IJSVGFilterPrimitive* primitive = (id)filter.children.firstObject;
    if (primitive.type != IJSVGNodeTypeFilterColorMatrix || primitive.filterColorInterpolation != IJSVGColorInterpolationSRGB || primitive.input.length != 0 || primitive.input2.length != 0 || primitive.result.length != 0 || primitive.children.count != 0 || primitive.x != nil || primitive.y != nil || primitive.width != nil || primitive.height != nil) {
        return nil;
    }
    return primitive;
}

static BOOL IJSVGColorMatrixIsIdentity(IJSVGFilterPrimitive* primitive)
{
    NSData* coefficients = [IJSVGColorMatrixFilterEffect preparedMatrixForPrimitive:primitive][@"matrix"];
    if (coefficients.length != 20 * sizeof(double)) {
        return NO;
    }
    const double* matrix = coefficients.bytes;
    for (NSUInteger index = 0; index < 20; index++) {
        double expected = index == 0 || index == 6 || index == 12 || index == 18 ? 1 : 0;
        if (matrix[index] != expected) {
            return NO;
        }
    }
    return YES;
}

// Separate point subpaths before Quartz chooses an arbitrary cap direction.
static BOOL IJSVGQuartzSeparatePointSubpaths(CGPathRef path, CGMutablePathRef segments, CGMutablePathRef points)
{
    __block CGPoint start = CGPointZero;
    __block BOOL active = NO;
    __block BOOL hasLength = NO;
    __block BOOL found = NO;
    __block CGMutablePathRef subpath = segments != NULL ? CGPathCreateMutable() : NULL;
    void (^finish)(void) = ^{
        if (!active) {
            return;
        }
        if (hasLength) {
            if (segments != NULL) {
                CGPathAddPath(segments, NULL, subpath);
            }
        } else {
            found = YES;
            if (points != NULL) {
                CGPathMoveToPoint(points, NULL, start.x, start.y);
                CGPathAddLineToPoint(points, NULL, start.x, start.y);
            }
        }
    };
    CGPathApplyWithBlock(path, ^(const CGPathElement* element) {
        if (element->type == kCGPathElementMoveToPoint) {
            finish();
            start = element->points[0];
            active = YES;
            hasLength = NO;
            if (subpath != NULL) {
                CGPathRelease(subpath);
                subpath = CGPathCreateMutable();
                CGPathMoveToPoint(subpath, NULL, start.x, start.y);
            }
            return;
        }
        NSUInteger count = element->type == kCGPathElementAddCurveToPoint ? 3 : element->type == kCGPathElementAddQuadCurveToPoint ? 2
            : element->type == kCGPathElementAddLineToPoint                                                                        ? 1
                                                                                                                                   : 0;
        for (NSUInteger index = 0; index < count; index++) {
            hasLength |= !CGPointEqualToPoint(start, element->points[index]);
        }
        if (subpath == NULL) {
            return;
        }
        const CGPoint* p = element->points;
        switch (element->type) {
            case kCGPathElementAddLineToPoint:
                CGPathAddLineToPoint(subpath, NULL, p[0].x, p[0].y);
                break;
            case kCGPathElementAddQuadCurveToPoint:
                CGPathAddQuadCurveToPoint(subpath, NULL, p[0].x, p[0].y, p[1].x, p[1].y);
                break;
            case kCGPathElementAddCurveToPoint:
                CGPathAddCurveToPoint(subpath, NULL, p[0].x, p[0].y, p[1].x, p[1].y, p[2].x, p[2].y);
                break;
            case kCGPathElementCloseSubpath:
                CGPathCloseSubpath(subpath);
                break;
            default:
                break;
        }
    });
    finish();
    CGPathRelease(subpath);
    return found;
}

static CGLineCap IJSVGQuartzLineCap(IJSVGLineCapStyle style)
{
    switch (style) {
        case IJSVGLineCapStyleRound:
            return kCGLineCapRound;
        case IJSVGLineCapStyleSquare:
            return kCGLineCapSquare;
        default:
            return kCGLineCapButt;
    }
}

static CGLineJoin IJSVGQuartzLineJoin(IJSVGLineJoinStyle style)
{
    switch (style) {
        case IJSVGLineJoinStyleRound:
            return kCGLineJoinRound;
        case IJSVGLineJoinStyleBevel:
            return kCGLineJoinBevel;
        default:
            return kCGLineJoinMiter;
    }
}

static void IJSVGQuartzConfigureStroke(IJSVGStrokePaint* paint, const IJSVGResolvedStrokeStyle* stroke, IJSVGStyle* style, CGFloat lineWidth)
{
    // Read the stroke cap and join settings.
    IJSVGLineCapStyle lineCapStyle = stroke->lineCap;
    IJSVGLineJoinStyle lineJoinStyle = stroke->lineJoin;
    CGFloat miterLimit = stroke->miterLimit.value;

    // Use the settings supplied by the style.
    if (style.lineCapStyle != IJSVGLineCapStyleNone && style.lineCapStyle != IJSVGLineCapStyleInherit) {
        lineCapStyle = style.lineCapStyle;
    }

    if (style.lineJoinStyle != IJSVGLineJoinStyleNone && style.lineJoinStyle != IJSVGLineJoinStyleInherit) {
        lineJoinStyle = style.lineJoinStyle;
    }

    // Use the style limit for sharp corners.
    if (style.miterLimit != IJSVGInheritedFloatValue) {
        miterLimit = style.miterLimit;
    }

    // Store the stroke settings.
    paint.lineWidth = lineWidth;
    paint.lineCap = IJSVGQuartzLineCap(lineCapStyle);
    paint.lineJoin = IJSVGQuartzLineJoin(lineJoinStyle);
    paint.miterLimit = miterLimit;

    paint.opacity = stroke->opacity.value;
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
    paint.frame = (CGRect) { .origin = CGPointZero, .size = frame.size };
    paint.outerBoundingBox = paint.frame;
    paint.path = path;
    CGPathRelease(path);
}

@interface IJSVGMarkerTemplate : NSObject
@property (nonatomic, strong) IJSVGMarker* marker;
@property (nonatomic, strong) id recursionKey;
@property (nonatomic, assign) BOOL reuseDisabled;
@property (nonatomic, strong) IJSVGPaint* paint;
@property (nonatomic, assign) CGPoint reference;
@property (nonatomic, assign) CGFloat scale;
@end

@implementation IJSVGMarkerTemplate

+ (instancetype)templateWithMarker:(IJSVGMarker*)marker
{
    if (marker.children.count == 0) {
        return nil;
    }
    IJSVGMarkerTemplate* prototype = [[self alloc] init];
    prototype.marker = marker;
    prototype.recursionKey = marker.identifier ?: (id)[NSValue valueWithNonretainedObject:marker];
    return prototype;
}

@end

// Immutable snapshots shared only while one paint tree is being built.
@interface IJSVGQuartzClipPath : NSObject
@property (nonatomic, assign) CGPathRef source;
@property (nonatomic, assign) CGPathRef path;
@property (nonatomic, assign) CGAffineTransform transform;
@end

@implementation IJSVGQuartzClipPath

- (void)dealloc
{
    CGPathRelease(_source);
    CGPathRelease(_path);
}

@end

// Full geometry bytes avoid pointer lifetime assumptions and hash collisions.
// Bound key construction so unusually large paths keep the direct stroker.
typedef struct {
    unsigned char bytes[8192];
    size_t length;
    BOOL valid;
} IJSVGStrokeCacheKey;

static void IJSVGAppendStrokeKey(IJSVGStrokeCacheKey* key, const void* bytes, size_t length)
{
    if (!key->valid || length > sizeof(key->bytes) - key->length) {
        key->valid = NO;
        return;
    }
    if (length != 0) {
        memcpy(key->bytes + key->length, bytes, length);
    }
    key->length += length;
}

static void IJSVGAppendStrokePathElement(void* info, const CGPathElement* element)
{
    IJSVGStrokeCacheKey* key = info;
    uint64_t type = element->type;
    IJSVGAppendStrokeKey(key, &type, sizeof(type));
    static const size_t counts[] = { 1, 1, 2, 3, 0 };
    if (type >= sizeof(counts) / sizeof(counts[0])) {
        key->valid = NO;
        return;
    }
    IJSVGAppendStrokeKey(key, element->points, counts[type] * sizeof(CGPoint));
}

static void IJSVGCountStrokeOutlineCost(void* info, const CGPathElement* element)
{
    size_t* cost = info;
    static const size_t counts[] = { 1, 1, 2, 3, 0 };

    // A conservative per element estimate also accounts for internal storage.
    // Saturate once the cache budget is exceeded, avoiding arithmetic overflow.
    if (*cost <= 4 * 1024 * 1024 && (NSUInteger)element->type < 5) {
        *cost += 32 + counts[element->type] * sizeof(CGPoint);
    }
}

@interface IJSVGRegionNodeStyle : NSObject
@property (nonatomic, assign) IJSVGResolvedPaintStyle paintStyle;
@end

@implementation IJSVGRegionNodeStyle
@end

@interface IJSVGRegionPaintInfo : NSObject
@property (nonatomic, strong) IJSVGNode* node;
@property (nonatomic, strong) IJSVGPaint* localPaint;
@property (nonatomic, assign) BOOL inactiveAnchor;
@property (nonatomic, assign) CGRect measuredBounds;
@property (nonatomic, assign) CGRect localBounds;
@property (nonatomic, assign) BOOL hasLocalBounds;
@end

@implementation IJSVGRegionPaintInfo
@end

@interface IJSVGQuartzRenderer () {
    NSMapTable<IJSVGPaint*, IJSVGRegionPaintInfo*>* _regionPaints;
    CFMutableDictionaryRef _regionUnitNodes;
    NSMapTable<IJSVGPaint*, NSValue*>* _regionArtworkBounds;
    NSMapTable<IJSVGGraphicsNode*, IJSVGRegionNodeStyle*>* _regionStyles;
    NSMapTable<IJSVGNode*, IJSVGNode*>* _regionTextNodes;
    NSUInteger _regionTextDepth;
    NSMutableArray<IJSVGQuartzClipPath*>* _sharedClipPaths;
    IJSVGByteCache* _strokeOutlineCache;
    BOOL _buildingStrokeOutlines;
    IJSVGTextFontResolver* _lengthFontResolver;
    BOOL _resolvingGradientFonts;
    IJSVGGradient* _fontGradientSource;
    IJSVGGradient* _fontGradientResult;
    CGRect _currentViewPort;
    CGRect _currentUnitBounds;
    IJSVGRootPaint* _rootPaint;
    IJSVGRootNode* _rootNode;
    CGSize _clientSize;
    NSSet<IJSVGFilterPaint*>* _batchableFilters;
    BOOL _requiresBackdrop;
    BOOL _buildHasFilters;
    BOOL _buildMayRequireBackdrop;
    BOOL _containsText;
    BOOL _containsNonScalingStrokes;
    NSArray<IJSVGShapePaint*>* _viewportStrokeShapes;
    NSData* _viewportStrokeTransforms;
    CGAffineTransform _textTransform;
    CGAffineTransform _textRenderTransform;
    CGSize _textRenderFrameSize;
    IJSVGRootNode* _textBuildRoot;
    NSMutableDictionary<NSNumber*, id>* _outlinePaths;
    IJSVGRootNode* _measurementRootNode;
    CGSize _measurementClientSize;
    IJSVGRootPaint* _geometryMeasurementPaint;
    IJSVGRootPaint* _effectsMeasurementPaint;
    BOOL _resolvingGeometryOnly;
    BOOL _resolvingMeasurements;
    BOOL _measurementHasFilters;
    NSMutableSet* _activeMarkers;
    NSMapTable<IJSVGPattern*, NSArray<NSValue*>*>* _contextPatternBounds;
    IJSVGUse* _resolvedContextUse;
    BOOL _measuringContextUse;
    BOOL _hasGeometryBounds;
    BOOL _hasEffectsBounds;
    CGRect _geometryBounds;
    CGRect _effectsBounds;
}

@end

@implementation IJSVGQuartzRenderer

static BOOL IJSVGRectIsFinite(CGRect rect)
{
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) && isfinite(rect.size.width) && isfinite(rect.size.height);
}

@synthesize style = _style;
@synthesize renderingOptions = _renderingOptions;

// Create the renderer with default settings.
- (id)init
{
    if ((self = [super init]) != nil) {
        _renderingOptions = [[IJSVGRenderingOptions alloc] init];
        _style = [[IJSVGStyle alloc] init];
        _textTransform = CGAffineTransformIdentity;
        _currentUnitBounds = CGRectNull;
    }
    return self;
}

// Return a copy so callers cannot change these settings directly.
- (IJSVGRenderingOptions*)renderingOptions
{
    return _renderingOptions.copy;
}

- (CGRect)viewPort
{
    return _currentViewPort;
}

- (CGRect)unitBounds
{
    return _currentUnitBounds;
}

- (void)withViewPort:(CGRect)viewPort handler:(dispatch_block_t)handler
{
    CGRect previous = _currentViewPort;
    _currentViewPort = viewPort;
    @try {
        handler();
    } @finally {
        _currentViewPort = previous;
    }
}

- (void)withUnitBounds:(CGRect)bounds handler:(dispatch_block_t)handler
{
    CGRect previous = _currentUnitBounds;
    _currentUnitBounds = bounds;
    @try {
        handler();
    } @finally {
        _currentUnitBounds = previous;
    }
}

- (void)withViewPort:(CGRect)viewPort unitBounds:(CGRect)bounds handler:(dispatch_block_t)handler
{
    CGRect previousViewPort = _currentViewPort;
    CGRect previousUnitBounds = _currentUnitBounds;
    _currentViewPort = viewPort;
    _currentUnitBounds = bounds;

    // The call stack holds each nested scope, including exception unwinding.
    @try {
        handler();
    } @finally {
        _currentViewPort = previousViewPort;
        _currentUnitBounds = previousUnitBounds;
    }
}

// Measures children with the same placement used during drawing.
- (CGRect)artworkBoundsForChildrenOfPaint:(IJSVGPaint*)paint
{
    CGRect bounds = CGRectNull;
    for (IJSVGPaint* child in paint.children) {
        CGRect local = [self artworkBoundsForPaint:child];
        if (CGRectIsNull(local) || CGRectIsInfinite(local)) {
            continue;
        }
        bounds = CGRectUnion(bounds, CGRectApplyAffineTransform(local, child.placementTransform));
    }
    return bounds;
}

// Includes stroked outlines with resolved caps, joins, dashes, and units.
- (CGRect)artworkBoundsForPaint:(IJSVGPaint*)paint
{
    if (paint.hidden || paint.opacity <= 0.f) {
        return CGRectNull;
    }
    if ((paint.paintTraits & IJSVGPaintTraitRoot) != 0) {
        return paint.bounds;
    }
    BOOL filteredPaint = (paint.paintTraits & IJSVGPaintTraitFilter) != 0;

    // The filter region replaces source bounds, avoid measuring discarded
    // geometry.
    CGRect bounds = filteredPaint ? CGRectNull : [self artworkBoundsForChildrenOfPaint:paint];
    if (filteredPaint) {
        IJSVGFilterPaint* filtered = (IJSVGFilterPaint*)paint;

        // Filters can generate pixels beyond the source, but never beyond this
        // region.
        bounds = filtered.filterRegion;
    } else if ((paint.paintTraits & IJSVGPaintTraitShape) != 0) {
        IJSVGShapePaint* shape = (IJSVGShapePaint*)paint;
        if (shape.path != NULL) {
            if (shape.fillGradient != nil || (shape.fillColor != NULL && CGColorGetAlpha(shape.fillColor) > 0.f)) {
                bounds = CGRectUnion(bounds, CGPathGetPathBoundingBox(shape.path));
            }
            if (shape.strokeColor != NULL && CGColorGetAlpha(shape.strokeColor) > 0.f && shape.lineWidth > 0.f) {
                CGPathRef outline = [self.class newPathFromStrokedShapePaint:shape];
                if (outline != NULL) {
                    bounds = CGRectUnion(bounds, CGPathGetPathBoundingBox(outline));
                    CGPathRelease(outline);
                }
            }
        }
    } else if ((paint.paintTraits & IJSVGPaintTraitImage) != 0) {
        bounds = CGRectUnion(bounds, paint.bounds);
    }
    if (paint.clipPath != NULL) {
        CGRect clipBounds = CGPathGetPathBoundingBox(paint.clipPath);
        if ((paint.paintTraits & IJSVGPaintTraitGradient) != 0 || (paint.paintTraits & IJSVGPaintTraitPattern) != 0) {
            bounds = CGRectUnion(bounds, clipBounds);
        }
        bounds = CGRectIntersection(bounds, clipBounds);
    }
    return bounds;
}

// Geometry is already covered by outerBoundingBox. Only measure the extra
// coverage from filters here, re stroking every mask path is expensive.
- (CGRect)filterCoverageBoundsForPaint:(IJSVGPaint*)paint
{
    if (paint.hidden || paint.opacity <= 0.f || (paint.paintTraits & IJSVGPaintTraitRoot) != 0) {
        return CGRectNull;
    }
    if ((paint.paintTraits & IJSVGPaintTraitFilter) != 0) {
        // A filters declared region bounds its output, including nested filters.
        return [self artworkBoundsForPaint:paint];
    }
    CGRect bounds = CGRectNull;
    for (IJSVGPaint* child in paint.children) {
        CGRect local = [self filterCoverageBoundsForPaint:child];
        if (!IJSVGRectIsFinite(local)) {
            continue;
        }
        bounds = CGRectUnion(bounds, CGRectApplyAffineTransform(local, child.placementTransform));
    }
    if (paint.clipPath != NULL && !CGRectIsNull(bounds)) {
        bounds = CGRectIntersection(bounds, CGPathGetPathBoundingBox(paint.clipPath));
    }
    return bounds;
}

// Reject disjoint control bounds before allocating or transforming paths.
// A contained nonempty path is conservatively visible, only boundary cases
// need the more expensive filled area intersection (including compound holes).
static BOOL IJSVGPathMayIntersectViewBox(CGPathRef path, CGAffineTransform transform, CGRect viewBox, CGPathRef viewport, BOOL evenOdd)
{
    if (path == NULL || CGPathIsEmpty(path)) {
        return NO;
    }
    CGRect bounds = CGRectApplyAffineTransform(CGPathGetBoundingBox(path), transform);
    if (!IJSVGRectIsFinite(bounds)) {
        return YES;
    }
    if (!CGRectIntersectsRect(bounds, viewBox)) {
        return NO;
    }
    if (CGRectContainsRect(viewBox, bounds)) {
        return YES;
    }
    CGPathRef placed = CGPathCreateCopyByTransformingPath(path, &transform);
    if (placed == NULL) {
        return YES;
    }
    BOOL intersects = CGPathIntersectsPath(placed, viewport, evenOdd);
    CGPathRelease(placed);
    return intersects;
}

- (BOOL)paintHasGeometryInViewBox:(IJSVGPaint*)paint transform:(CGAffineTransform)transform viewBox:(CGRect)viewBox viewport:(CGPathRef)viewport
{
    if ((paint.paintTraits & IJSVGPaintTraitShape) != 0) {
        IJSVGShapePaint* shape = (IJSVGShapePaint*)paint;
        if ((shape.fillGradient != nil || (shape.fillColor != NULL && CGColorGetAlpha(shape.fillColor) > 0.f)) && IJSVGPathMayIntersectViewBox(shape.path, transform, viewBox, viewport, shape.fillRule == IJSVGWindingRuleEvenOdd)) {
            return YES;
        }
        if (shape.path != NULL && shape.strokeColor != NULL && CGColorGetAlpha(shape.strokeColor) > 0.f && shape.lineWidth > 0.f) {
            if (CGPathIsEmpty(shape.path)) {
                return NO;
            }

            // A generous envelope covers caps and miter joins without allocating
            // the dashed/stroked outline for clearly contained or disjoint paths.
            CGFloat padding = shape.lineWidth * MAX(2.f, shape.miterLimit);
            CGRect envelope = CGRectApplyAffineTransform(CGRectInset(CGPathGetBoundingBox(shape.path), -padding, -padding), transform);
            if (!IJSVGRectIsFinite(envelope)) {
                return YES;
            }
            if (!CGRectIntersectsRect(envelope, viewBox)) {
                return NO;
            }
            if (CGRectContainsRect(viewBox, envelope)) {
                return YES;
            }
            CGPathRef outline = [self.class newPathFromStrokedShapePaint:shape];
            BOOL intersects = outline == NULL || IJSVGPathMayIntersectViewBox(outline, transform, viewBox, viewport, NO);
            CGPathRelease(outline);
            if (intersects) {
                return YES;
            }
        }
    } else if ((paint.paintTraits & IJSVGPaintTraitGradient) != 0 || (paint.paintTraits & IJSVGPaintTraitPattern) != 0) {
        return paint.clipPath == NULL || IJSVGPathMayIntersectViewBox(paint.clipPath, transform, viewBox, viewport, paint.clipRule == IJSVGWindingRuleEvenOdd);
    } else if ((paint.paintTraits & IJSVGPaintTraitImage) != 0) {
        CGRect bounds = CGRectApplyAffineTransform(paint.bounds, transform);
        return !IJSVGRectIsFinite(bounds) || CGRectIntersectsRect(bounds, viewBox);
    }
    return NO;
}

// Postorder traversal measures each paint once and propagates visibility to
// groups. Multiple fill/stroke paints can refer to the same source node.
- (BOOL)collectOutsideNodesForPaint:(IJSVGPaint*)paint transform:(CGAffineTransform)parentTransform viewBox:(CGRect)viewBox viewport:(CGPathRef)viewport outside:(NSMutableSet<IJSVGNode*>*)outside visible:(NSMutableSet<IJSVGNode*>*)visible
{
    IJSVGNode* node = paint.sourceNode;
    if ((paint.paintTraits & (IJSVGPaintTraitFilter | IJSVGPaintTraitRoot)) != 0) {
        // Do not classify descendants whose output can be moved or generated.
        if (node != nil) {
            [visible addObject:node];
        }
        return YES;
    }
    if (paint.hidden || paint.opacity <= 0.f) {
        if (node != nil) {
            [outside addObject:node];
        }
        return NO;
    }
    CGAffineTransform transform = CGAffineTransformConcat(paint.placementTransform, parentTransform);
    BOOL intersects = NO;
    for (IJSVGPaint* child in paint.children) {
        // Visit every child even when the group is already known to be visible.
        BOOL childIntersects = [self collectOutsideNodesForPaint:child transform:transform viewBox:viewBox viewport:viewport outside:outside visible:visible];
        intersects = intersects || childIntersects;
    }
    intersects = intersects || [self paintHasGeometryInViewBox:paint transform:transform viewBox:viewBox viewport:viewport];
    if (node != nil) {
        [(intersects ? visible : outside) addObject:node];
    }
    return intersects;
}

- (NSSet<IJSVGNode*>*)nodesOutsideViewBox:(CGRect)viewBox ofRootNode:(IJSVGRootNode*)rootNode
{
    if (!IJSVGRectIsFinite(viewBox) || CGRectIsEmpty(viewBox)) {
        return [NSSet set];
    }
    return [self nodesOutsideViewBox:viewBox ofRootPaint:[self measurementPaintForRootNode:rootNode includingFilters:YES]];
}

- (NSSet<IJSVGNode*>*)nodesOutsideViewBox:(CGRect)viewBox ofRootPaint:(IJSVGRootPaint*)root
{
    if (!IJSVGRectIsFinite(viewBox) || CGRectIsEmpty(viewBox)) {
        return [NSSet set];
    }
    NSMutableSet<IJSVGNode*>* outside = [NSMutableSet set];
    NSMutableSet<IJSVGNode*>* visible = [NSMutableSet set];
    CGPathRef viewport = CGPathCreateWithRect(viewBox, NULL);
    for (IJSVGPaint* child in root.children) {
        [self collectOutsideNodesForPaint:child transform:CGAffineTransformIdentity viewBox:viewBox viewport:viewport outside:outside visible:visible];
    }
    CGPathRelease(viewport);
    [outside minusSet:visible];
    if (root.sourceNode != nil) {
        [outside removeObject:root.sourceNode];
    }
    return outside.copy;
}

- (BOOL)outlineFilterModesSharePaint
{
    return !_renderingOptions.filtersEnabled || (_geometryMeasurementPaint != nil && _geometryMeasurementPaint == _effectsMeasurementPaint);
}

- (NSMutableDictionary<NSNumber*, id>*)outlinePathCache
{
    if (_outlinePaths == nil) {
        _outlinePaths = [[NSMutableDictionary alloc] initWithCapacity:4];
    }
    return _outlinePaths;
}

// Measurement uses viewBox space text geometry, independently of the drawing
// context pixel scale. Cache the two filter modes without changing options.
- (IJSVGRootPaint*)measurementPaintForRootNode:(IJSVGRootNode*)rootNode includingFilters:(BOOL)includingFilters
{
    if (_measurementRootNode != rootNode || !CGSizeEqualToSize(_measurementClientSize, rootNode.clientSize)) {
        _geometryMeasurementPaint = nil;
        _effectsMeasurementPaint = nil;
        _hasGeometryBounds = NO;
        _outlinePaths = nil;
        _hasEffectsBounds = NO;
        _measurementRootNode = rootNode;
        _measurementClientSize = rootNode.clientSize;
    }
    BOOL effects = includingFilters && _renderingOptions.filtersEnabled;
    IJSVGRootPaint* cached = effects ? _effectsMeasurementPaint : _geometryMeasurementPaint;
    if (cached != nil) {
        return cached;
    }
    BOOL previousGeometryOnly = _resolvingGeometryOnly;
    BOOL previousMeasurements = _resolvingMeasurements;
    _resolvingMeasurements = YES;
    _resolvingGeometryOnly = !effects;
    _measurementHasFilters = NO;
    IJSVGRootPaint* paint = nil;
    @try {
        CGRect viewport = (CGRect) { CGPointZero, rootNode.clientSize };
        CGRect frame = [self renderFrameForRootNode:rootNode viewport:viewport];
        paint = [self rootPaintForRootNode:rootNode viewportSize:frame.size];
    } @finally {
        _resolvingGeometryOnly = previousGeometryOnly;
        _resolvingMeasurements = previousMeasurements;
    }
    if (effects) {
        _effectsMeasurementPaint = paint;
    } else {
        _geometryMeasurementPaint = paint;
    }

    // Unfiltered artwork needs only one resolved tree for all three queries.
    if (!_measurementHasFilters) {
        _geometryMeasurementPaint = paint;
        _effectsMeasurementPaint = paint;
    }
    return paint;
}

- (void)hideNodes:(NSSet<IJSVGNode*>*)nodes inMeasurementPaint:(IJSVGPaint*)paint
{
    if (paint.sourceNode != nil && [nodes containsObject:paint.sourceNode]) {
        paint.hidden = YES;
        return;
    }
    for (IJSVGPaint* child in paint.children) {
        [self hideNodes:nodes inMeasurementPaint:child];
    }
}

- (void)hideNodesInMeasurements:(NSSet<IJSVGNode*>*)nodes
{
    if (nodes.count == 0) {
        return;
    }
    [self hideNodes:nodes inMeasurementPaint:_geometryMeasurementPaint];
    if (_effectsMeasurementPaint != _geometryMeasurementPaint) {
        [self hideNodes:nodes inMeasurementPaint:_effectsMeasurementPaint];
    }
    _hasGeometryBounds = NO;
    _outlinePaths = nil;
    _hasEffectsBounds = NO;
}

// Resolves bounds in viewBox coordinates without the outer viewport clip.
- (CGRect)artworkBoundsForRootNode:(IJSVGRootNode*)rootNode
{
    return [self artworkBoundsForRootNode:rootNode includingFilters:YES];
}

- (CGRect)artworkBoundsForRootNode:(IJSVGRootNode*)rootNode includingFilters:(BOOL)includingFilters
{
    IJSVGRootPaint* paint = [self measurementPaintForRootNode:rootNode includingFilters:includingFilters];
    BOOL effects = includingFilters && _renderingOptions.filtersEnabled;
    if (effects ? _hasEffectsBounds : _hasGeometryBounds) {
        return effects ? _effectsBounds : _geometryBounds;
    }
    CGRect bounds = paint.hidden || paint.opacity <= 0.f ? CGRectNull : [self artworkBoundsForChildrenOfPaint:paint];

    // The two modes share the result when no filter changes the geometry.
    if (paint == _geometryMeasurementPaint) {
        _geometryBounds = bounds;
        _hasGeometryBounds = YES;
    }
    if (paint == _effectsMeasurementPaint) {
        _effectsBounds = bounds;
        _hasEffectsBounds = YES;
    }
    return bounds;
}

// Measures a resolved node including its transform and enabled effects.
- (CGRect)extentForNode:(IJSVGNode*)node inViewPort:(CGRect)viewPort
{
    IJSVGPaint* paint = [self drawablePaintForNode:node inViewPort:viewPort];
    if (paint == nil || paint.hidden || paint.opacity <= 0.f) {
        return CGRectNull;
    }
    CGRect bounds = [self artworkBoundsForPaint:paint];
    return CGRectIsNull(bounds) ? bounds : CGRectApplyAffineTransform(bounds, paint.placementTransform);
}

- (IJSVGRootPaint*)rootPaintForRootNode:(IJSVGRootNode*)rootNode viewportSize:(CGSize)size
{
    if (!isfinite(size.width) || !isfinite(size.height) || size.width <= 0 || size.height <= 0) {
        return [self rootPaintForRootNode:rootNode];
    }
    IJSVGRootNode* previousRoot = _textBuildRoot;
    CGSize previousSize = _textRenderFrameSize;
    CGAffineTransform previousTransform = _textTransform;
    CGAffineTransform previousOutput = _textRenderTransform;
    _textBuildRoot = rootNode;
    _textRenderFrameSize = size;
    _textTransform = CGAffineTransformIdentity;
    _textRenderTransform = CGAffineTransformIdentity;
    @try {
        return [self rootPaintForRootNode:rootNode];
    } @finally {
        _textBuildRoot = previousRoot;
        _textRenderFrameSize = previousSize;
        _textTransform = previousTransform;
        _textRenderTransform = previousOutput;
    }
}

- (IJSVGRootPaint*)rootPaintForRootNode:(IJSVGRootNode*)rootNode
{
    CGRect clientBounds = (CGRect) { .origin = CGPointZero, .size = rootNode.clientSize };
    __block IJSVGRootPaint* paint = nil;
    IJSVGByteCache* previousOutlines = _strokeOutlineCache;
    BOOL previousOutlineScope = _buildingStrokeOutlines;
    _strokeOutlineCache = NULL;
    _buildingStrokeOutlines = YES;
    NSMutableArray<IJSVGQuartzClipPath*>* previousClips = _sharedClipPaths;
    _sharedClipPaths = [[NSMutableArray alloc] init];
    BOOL previousGradientScope = _resolvingGradientFonts;
    IJSVGGradient* previousGradientSource = _fontGradientSource;
    IJSVGGradient* previousGradientResult = _fontGradientResult;
    _resolvingGradientFonts = YES;
    _fontGradientSource = nil;
    _fontGradientResult = nil;
    @try {
        [self withViewPort:clientBounds
                unitBounds:clientBounds
                   handler:^{
                       paint = (IJSVGRootPaint*)[self drawablePaintForNode:rootNode];
                   }];
    } @finally {
        IJSVGByteCacheDestroy(_strokeOutlineCache);
        _strokeOutlineCache = previousOutlines;
        _buildingStrokeOutlines = previousOutlineScope;
        _sharedClipPaths = previousClips;
        _resolvingGradientFonts = previousGradientScope;
        _fontGradientSource = previousGradientSource;
        _fontGradientResult = previousGradientResult;
    }
    return paint;
}

- (IJSVGPaint*)drawablePaintForNode:(IJSVGNode*)node inViewPort:(CGRect)viewPort
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
    CGFloat scale = sqrt((_textTransform.a * _textTransform.a + _textTransform.b * _textTransform.b + _textTransform.c * _textTransform.c + _textTransform.d * _textTransform.d) / 2);
    IJSVGTextLayout* layout = [[IJSVGTextLayout alloc] initWithText:node
        viewport:[self unitResolutionBoundsForNode:node].size
        renderScale:scale
        renderingOptions:_renderingOptions
        pathResolver:^CGPathRef(IJSVGPath* pathNode) {
            CGMutablePathRef path = CGPathCreateMutable();
            CGAffineTransform transform = IJSVGConcatTransforms(pathNode.transforms);
            [self appendResolvedPathForPathNode:pathNode transform:transform toPath:path];
            return path;
        }
        geometryHandler:_regionTextNodes == nil ? nil : ^(IJSVGGroup* group, IJSVGText* source) {
            [self->_regionTextNodes setObject:source forKey:group];
        }];
    return layout;
}

- (IJSVGPaint*)drawablePaintForTextNode:(IJSVGText*)node
{
    IJSVGTextLayout* layout = [self textLayoutForNode:node];
    IJSVGPaint* paint = nil;
    _regionTextDepth++;
    @try {
        paint = [self drawablePaintForGroupNode:layout.group];
    } @finally {
        _regionTextDepth--;
    }
    paint.boundingBox = layout.boundingBox;
    return paint;
}

// Source nodes remain intact: descendants still inherit their styles and
// resolve resource coordinates through the original tree. Only the redundant
// rendering container is omitted. Measurement trees preserve every node.
- (BOOL)canOmitContainerPaint:(IJSVGGraphicsNode*)node
{
    return !_resolvingMeasurements && node.shouldRender && node.transforms.count == 0 && !node.x.isCalculated && !node.y.isCalculated && node.x.value == 0.f && node.y.value == 0.f && node.opacity.value == 1.f && !node.isolated && node.blendMode == IJSVGBlendModeNormal && node.clipPath == nil && node.mask == nil && node.filters.count == 0 && CGRectIsNull(node.backgroundRect);
}

- (IJSVGPaint*)drawablePaintForNode:(IJSVGNode*)source
{
    if ((source.nodeTraits & IJSVGNodeTypeTraitGraphics) == 0) {
        return nil;
    }
    IJSVGGraphicsNode* node = (IJSVGGraphicsNode*)source;
    if (node.type == IJSVGNodeTypeUse && node != _resolvedContextUse && !_measuringContextUse && [self useChildrenNeedContextPaint:(IJSVGUse*)node]) {
        return [self drawablePaintForContextUse:(IJSVGUse*)node];
    }

    // A plain single child group or unpositioned path use contributes neither
    // geometry nor drawing state.
    // Keep the source tree intact for inherited styles and resource coordinates,
    // omit only its redundant paint allocation and bounds calculation.
    // Measurement trees retain every source node for visibility queries.
    BOOL plainGroup = [node isMemberOfClass:IJSVGGroup.class] && [node.name isEqualToString:@"g"];
    BOOL pathUse = [node isMemberOfClass:IJSVGUse.class] && !node.x.isCalculated && !node.y.isCalculated && ((((IJSVGUse*)node).children.firstObject.nodeTraits & IJSVGNodeTypeTraitPath) != 0);
    if ((plainGroup || pathUse) && ((IJSVGGroup*)node).children.count == 1 && [self canOmitContainerPaint:node]) {
        return [self drawablePaintForNode:((IJSVGGroup*)node).children.firstObject];
    }
    if (node.transforms.count == 0) {
        return [self drawablePaintForNodeWithTextTransform:node];
    }
    CGAffineTransform previous = _textTransform;
    CGRect bounds = [self unitResolutionBoundsForNode:node];
    IJSVGGraphicsNode* referencingNode = nil;
    IJSVGUnitType units = [self contentUnitsForNode:node.parentNode referencingNode:&referencingNode];
    CGAffineTransform local = CGAffineTransformIdentity;
    for (IJSVGTransform* transform in node.transforms.reverseObjectEnumerator) {
        IJSVGTransform* resolved = [transform transformByApplyingUnits:units bounds:bounds];
        local = CGAffineTransformConcat(local, resolved.CGAffineTransform);
    }
    _textTransform = CGAffineTransformConcat(local, previous);
    @try {
        return [self drawablePaintForNodeWithTextTransform:node];
    } @finally {
        _textTransform = previous;
    }
}

- (IJSVGResolvedPaintStyle)resolvedPaintStyleForNode:(IJSVGGraphicsNode*)node
{
    if (_regionStyles == nil) {
        return [node resolvedPaintStyle];
    }
    IJSVGRegionNodeStyle* entry = [_regionStyles objectForKey:node];
    if (entry != nil) {
        return entry.paintStyle;
    }
    IJSVGGraphicsNode* parent = node.styleParent;
    IJSVGResolvedPaintStyle style = { .windingRule = IJSVGWindingRuleInherit, .paintOrder = IJSVGPaintOrderInherit };
    [node addSpecifiedPaintPropertiesToStyle:&style atRoot:parent == nil];
    if (!style.complete && parent != nil) {
        IJSVGResolvedPaintStyle inherited = [self resolvedPaintStyleForNode:parent];
        style.fill = style.fill ?: inherited.fill;
        if (!style.hasFillOpacity) {
            style.fillOpacity = inherited.fillOpacity;
            style.hasFillOpacity = inherited.hasFillOpacity;
        }
        if (style.windingRule == IJSVGWindingRuleInherit) {
            style.windingRule = inherited.windingRule;
        }
        if (style.paintOrder == IJSVGPaintOrderInherit) {
            style.paintOrder = inherited.paintOrder;
        }
        if (style.visibility == IJSVGVisibilityInherit) {
            style.visibility = inherited.visibility;
        }
        style.currentColor = style.currentColor ?: inherited.currentColor ?
                                                                          : IJSVGColor.blackColor;
        style.markerStart = style.markerStart ?: inherited.markerStart;
        style.markerMid = style.markerMid ?: inherited.markerMid;
        style.markerEnd = style.markerEnd ?: inherited.markerEnd;
    }
    if (style.visibility == IJSVGVisibilityInherit) {
        style.visibility = IJSVGVisibilityVisible;
    }
    if (!style.complete && style.paintOrder == IJSVGPaintOrderInherit) {
        style.paintOrder = IJSVGPaintOrderNormal;
    }
    style.opacity = node.opacity.value;
    entry = [[IJSVGRegionNodeStyle alloc] init];
    entry.paintStyle = style;
    [_regionStyles setObject:entry forKey:node];
    return style;
}

// Build the paint and apply filters when they are enabled.
- (IJSVGPaint*)drawablePaintForNodeWithTextTransform:(IJSVGGraphicsNode*)node
{
    IJSVGPaint* paint = nil;
    IJSVGResolvedPaintStyle style = { 0 };
    BOOL hasResolvedStyle = NO;
    if ((node.nodeTraits & IJSVGNodeTypeTraitText) != 0) {
        paint = [self drawablePaintForTextNode:(IJSVGText*)node];
    } else if ((node.nodeTraits & IJSVGNodeTypeTraitPath) != 0) {
        style = [self resolvedPaintStyleForNode:node];
        hasResolvedStyle = YES;
        paint = [self drawablePaintForPathNode:(IJSVGPath*)node style:&style];
    } else if (node.type == IJSVGNodeTypeSymbol) {
        paint = [self drawablePaintForSymbolNode:(IJSVGSymbol*)node];
    } else if ((node.nodeTraits & IJSVGNodeTypeTraitRoot) != 0) {
        paint = [self drawablePaintForRootNode:(IJSVGRootNode*)node];
    } else if ((node.nodeTraits & IJSVGNodeTypeTraitGroup) != 0) {
        paint = [self drawablePaintForGroupNode:(IJSVGGroup*)node];
    } else if ((node.nodeTraits & IJSVGNodeTypeTraitImage) != 0) {
        paint = [self drawablePaintForImageNode:(IJSVGImage*)node];
    }
    if (paint != nil) {
        if (![self hasSymbolContentEffects:node]) {
            paint = [self applyEffectsToPaint:paint fromNode:node style:hasResolvedStyle ? &style : NULL];
        }
        IJSVGPaint* localPaint = paint;
        paint = [self applyTransforms:node.transforms toPaint:paint fromNode:node];
        if (_regionPaints != nil) {
            IJSVGNode* source = [_regionTextNodes objectForKey:node];
            if (source != nil || _regionTextDepth == 0) {
                IJSVGRegionPaintInfo* info = [[IJSVGRegionPaintInfo alloc] init];
                info.node = source ?: node;
                info.localPaint = localPaint;
                [_regionPaints setObject:info forKey:paint];
            }
        }
        return paint;
    }
    return paint;
}

- (BOOL)hasSymbolContentEffects:(IJSVGGraphicsNode*)node
{
    return node.type == IJSVGNodeTypeSymbol && (node.clipPath != nil || node.mask != nil || node.filters.count != 0 || node.isolated || node.opacity.value != 1.f || node.blendMode != IJSVGBlendModeNormal || !CGRectIsNull(node.backgroundRect));
}

- (IJSVGPaint*)applyEffectsToPaint:(IJSVGPaint*)paint fromNode:(IJSVGGraphicsNode*)node
{
    return [self applyEffectsToPaint:paint fromNode:node style:NULL];
}

- (IJSVGPaint*)applyEffectsToPaint:(IJSVGPaint*)paint fromNode:(IJSVGGraphicsNode*)node style:(const IJSVGResolvedPaintStyle*)style
{
    if (_renderingOptions.filtersEnabled && node.filters.count != 0) {
        _measurementHasFilters = YES;
    }

    // Resolving geometry must not initialize the GPU. Bitmap CPU fast paths and
    // completely clipped content may never need a Core Image context.
    if (!_resolvingGeometryOnly && _renderingOptions.filtersEnabled && node.filters.count != 0) {
        NSArray<IJSVGFilter*>* filters = node.filters;
        for (NSUInteger index = 0; index < filters.count;) {
            IJSVGFilter* filter = filters[index];
            NSUInteger end = index + 1;
            if (end < filters.count && IJSVGCSSChainColorPrimitive(filter) != nil) {
                while (end < filters.count && IJSVGCSSChainColorPrimitive(filters[end]) != nil) {
                    end++;
                }
            }
            if (end > index + 1) {
                IJSVGFilter* chain = [[IJSVGFilter alloc] init];
                chain.usesSourceRegion = YES;
                chain.filterColorInterpolation = IJSVGColorInterpolationSRGB;
                for (NSUInteger stage = index; stage < end; stage++) {
                    IJSVGFilterPrimitive* primitive = (id)filters[stage].children.firstObject;
                    if (!IJSVGColorMatrixIsIdentity(primitive)) {
                        // Preserve separate operations so each stage still clamps its output.
                        [chain addChild:primitive.copy];
                    }
                }
                if (chain.children.count == 0) {
                    // An identity filter still groups its source before compositing.
                    [chain addChild:filter.children.firstObject.copy];
                }
                filter = chain;
            }
            paint = [self applyFilter:filter toPaint:paint fromNode:node];
            index = end;
        }
    }
    [self applyDefaultsToPaint:paint fromNode:node style:style];
    return paint;
}

- (IJSVGPaint*)drawableBasicPaintForPathNode:(IJSVGPath*)node resolvedPath:(CGPathRef)resolvedPath resolvedPathBounds:(CGRect)resolvedPathBounds fillRule:(IJSVGWindingRule)fillRule
{
    IJSVGShapePaint* paint = node.primitiveType == kIJSVGPrimitivePathTypeRect ? IJSVGRectPaint.paint : IJSVGShapePaint.paint;
    paint.primitiveType = node.primitiveType;
    if (CGPathIsEmpty(resolvedPath) == NO) {
        [self applyPath:resolvedPath bounds:resolvedPathBounds toShapePaint:paint];
    }
    paint.fillColor = nil;
    paint.fillRule = fillRule;
    return paint;
}

// Choose the bounds used to turn relative sizes into points.
- (CGRect)unitResolutionBoundsForNode:(IJSVGGraphicsNode*)node
{
    CGRect bounds = self.unitBounds;
    if (CGRectIsNull(bounds) == YES || CGRectIsEmpty(bounds) == YES) {
        bounds = self.viewPort;
    }
    if ((CGRectIsNull(bounds) == YES || CGRectIsEmpty(bounds) == YES) && node.parentNode != nil) {
        bounds = node.parentNode.bounds;
    }
    return bounds;
}

- (IJSVGUnitType)contentUnitsForNode:(IJSVGGraphicsNode*)node referencingNode:(IJSVGGraphicsNode**)referencingNode
{
    if (_regionUnitNodes != NULL) {
        return [node contentUnitsWithReferencingNode:referencingNode cache:_regionUnitNodes];
    }
    return [node contentUnitsWithReferencingNode:referencingNode];
}

- (IJSVGUnitLength*)unit:(IJSVGUnitLength*)unit matchingNode:(IJSVGGraphicsNode*)node
{
    if (unit == nil || node.parentNode == nil) {
        return unit;
    }

    IJSVGGraphicsNode* referencingNode = nil;
    IJSVGUnitType contentUnits = [self contentUnitsForNode:node.parentNode referencingNode:&referencingNode];
    if (contentUnits == IJSVGUnitObjectBoundingBox) {
        if (unit.usesFontMetrics) {
            BOOL css = node.type == IJSVGNodeTypeRect || node.type == IJSVGNodeTypeCircle || node.type == IJSVGNodeTypeEllipse || node.type == IJSVGNodeTypeImage;
            unit = [self.lengthFontResolver unitByResolvingFontLength:unit node:node css:css];
        }
        return [unit lengthWithUnitType:IJSVGUnitLengthTypePercentage];
    }
    return unit;
}

- (void)appendResolvedPathForPathNode:(IJSVGPath*)node transform:(CGAffineTransform)transform toPath:(CGMutablePathRef)path
{
    CGRect bounds = [self unitResolutionBoundsForNode:node];
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    if (node.primitiveType == kIJSVGPrimitivePathTypePath || node.primitiveType == kIJSVGPrimitivePathTypePolygon || node.primitiveType == kIJSVGPrimitivePathTypePolyLine) {
        if (node.pathUnits == IJSVGUnitObjectBoundingBox) {
            CGAffineTransform scale = CGAffineTransformMakeScale(width, height);
            transform = CGAffineTransformConcat(scale, transform);
        }
        CGPathAddPath(path, &transform, node.path);
        return;
    }

    switch (node.primitiveType) {
        case kIJSVGPrimitivePathTypeLine: {
            IJSVGLine* shape = (IJSVGLine*)node;
            CGFloat x1 = [self resolveLength:[self unit:shape.x1 matchingNode:shape] percentage:width node:shape];
            CGFloat y1 = [self resolveLength:[self unit:shape.y1 matchingNode:shape] percentage:height node:shape];
            CGFloat x2 = [self resolveLength:[self unit:shape.x2 matchingNode:shape] percentage:width node:shape];
            CGFloat y2 = [self resolveLength:[self unit:shape.y2 matchingNode:shape] percentage:height node:shape];
            CGPathMoveToPoint(path, &transform, x1, y1);
            CGPathAddLineToPoint(path, &transform, x2, y2);
            break;
        }
        case kIJSVGPrimitivePathTypeRect: {
            IJSVGRect* shape = (IJSVGRect*)node;
            CGRect rect = CGRectMake([self resolveCSSLength:[self unit:shape.x matchingNode:shape] percentage:width node:shape], [self resolveCSSLength:[self unit:shape.y matchingNode:shape] percentage:height node:shape], [self resolveCSSLength:[self unit:shape.width matchingNode:shape] percentage:width node:shape], [self resolveCSSLength:[self unit:shape.height matchingNode:shape] percentage:height node:shape]);
            if (rect.size.width <= 0.f || rect.size.height <= 0.f) {
                break;
            }
            CGSize radii = [self resolvedRadiiForNode:shape width:width height:height];
            CGFloat rx = MIN(radii.width, rect.size.width / 2.f);
            CGFloat ry = MIN(radii.height, rect.size.height / 2.f);
            if (rx == 0.f || ry == 0.f) {
                CGPathAddRect(path, &transform, rect);
                break;
            }

            // SVG starts at the end of the top left arc and proceeds clockwise.
            // The Core Graphics rounded rectangle starts elsewhere, shifting dashes.
            CGFloat left = CGRectGetMinX(rect), right = CGRectGetMaxX(rect);
            CGFloat top = CGRectGetMinY(rect), bottom = CGRectGetMaxY(rect);
            CGFloat kappa = 4.f * (sqrt(2.f) - 1.f) / 3.f;
            CGFloat dx = rx * kappa, dy = ry * kappa;
            CGPathMoveToPoint(path, &transform, left + rx, top);
            CGPathAddLineToPoint(path, &transform, right - rx, top);
            CGPathAddCurveToPoint(path, &transform, right - rx + dx, top, right, top + ry - dy, right, top + ry);
            CGPathAddLineToPoint(path, &transform, right, bottom - ry);
            CGPathAddCurveToPoint(path, &transform, right, bottom - ry + dy, right - rx + dx, bottom, right - rx, bottom);
            CGPathAddLineToPoint(path, &transform, left + rx, bottom);
            CGPathAddCurveToPoint(path, &transform, left + rx - dx, bottom, left, bottom - ry + dy, left, bottom - ry);
            CGPathAddLineToPoint(path, &transform, left, top + ry);
            CGPathAddCurveToPoint(path, &transform, left, top + ry - dy, left + rx - dx, top, left + rx, top);
            CGPathCloseSubpath(path);
            break;
        }
        case kIJSVGPrimitivePathTypeCircle: {
            IJSVGCircle* shape = (IJSVGCircle*)node;
            CGFloat cx = [self resolveCSSLength:[self unit:shape.cx matchingNode:shape] percentage:width node:shape];
            CGFloat cy = [self resolveCSSLength:[self unit:shape.cy matchingNode:shape] percentage:height node:shape];
            IJSVGUnitLength* radius = [self unit:shape.r matchingNode:shape];
            BOOL objectUnits = radius != shape.r;
            CGFloat diagonal = hypot(width, height) / M_SQRT2;
            CGFloat rx = [self resolveCSSLength:radius percentage:objectUnits ? width : diagonal node:shape];
            CGFloat ry = objectUnits ? [self resolveCSSLength:radius percentage:height node:shape] : rx;
            if (rx <= 0.f || ry <= 0.f) {
                break;
            }
            CGRect rect = CGRectMake(cx - rx, cy - ry, rx * 2.f, ry * 2.f);
            CGPathAddEllipseInRect(path, &transform, rect);
            break;
        }
        case kIJSVGPrimitivePathTypeEllipse: {
            IJSVGEllipse* shape = (IJSVGEllipse*)node;
            CGFloat cx = [self resolveCSSLength:[self unit:shape.cx matchingNode:shape] percentage:width node:shape];
            CGFloat cy = [self resolveCSSLength:[self unit:shape.cy matchingNode:shape] percentage:height node:shape];
            CGSize radii = [self resolvedRadiiForNode:shape width:width height:height];
            CGFloat rx = radii.width;
            CGFloat ry = radii.height;
            if (rx <= 0.f || ry <= 0.f) {
                break;
            }
            CGRect rect = CGRectMake(cx - rx, cy - ry, rx * 2.f, ry * 2.f);
            CGPathAddEllipseInRect(path, &transform, rect);
            break;
        }
        default: {
            break;
        }
    }
}

- (CGSize)resolvedRadiiForNode:(IJSVGRoundedShape*)node width:(CGFloat)width height:(CGFloat)height
{
    BOOL autoX = node.rx == nil || node.rx.value < 0.f;
    BOOL autoY = node.ry == nil || node.ry.value < 0.f;
    CGFloat rx = autoX ? 0.f : [self resolveCSSLength:[self unit:node.rx matchingNode:node] percentage:width node:node];
    CGFloat ry = autoY ? 0.f : [self resolveCSSLength:[self unit:node.ry matchingNode:node] percentage:height node:node];
    if (autoX) {
        rx = ry;
    }
    if (autoY) {
        ry = rx;
    }
    return CGSizeMake(rx, ry);
}

- (CGPathRef)newResolvedPathForPathNode:(IJSVGPath*)node
{
    if (node.primitiveType == kIJSVGPrimitivePathTypePath || node.primitiveType == kIJSVGPrimitivePathTypePolygon || node.primitiveType == kIJSVGPrimitivePathTypePolyLine) {
        if (node.pathUnits == IJSVGUnitObjectBoundingBox) {
            CGRect bounds = [self unitResolutionBoundsForNode:node];
            CGAffineTransform transform = CGAffineTransformMakeScale(bounds.size.width, bounds.size.height);
            return CGPathCreateCopyByTransformingPath(node.path, &transform);
        }
        return CGPathCreateCopy(node.path);
    }
    CGMutablePathRef path = CGPathCreateMutable();
    [self appendResolvedPathForPathNode:node transform:CGAffineTransformIdentity toPath:path];
    return path;
}

// Move the path to start at zero inside its paint bounds.
- (CGPathRef)newPaintPathForResolvedPath:(CGPathRef)path bounds:(CGRect)pathBounds
{
    if (IJSVGRectIsFinite(pathBounds) == NO) {
        return CGPathCreateMutable();
    }
    if (pathBounds.origin.x == 0.f && pathBounds.origin.y == 0.f) {
        return CGPathRetain(path);
    }
    CGAffineTransform transform = CGAffineTransformMakeTranslation(-pathBounds.origin.x, -pathBounds.origin.y);
    return CGPathCreateCopyByTransformingPath(path, &transform);
}

- (void)applyPath:(CGPathRef)path bounds:(CGRect)pathBounds toShapePaint:(IJSVGShapePaint*)paint
{
    paint.path = path;

    // Save the path bounds before adding the stroke.
    // SVG bounds do not include the stroke or control points.
    paint.frame = pathBounds;
    paint.outerBoundingBox = pathBounds;
    paint.boundingBox = pathBounds;
}

- (CGPathRef)newCachedPathFromStrokedShapePaint:(IJSVGShapePaint*)shape
{
    if (!_buildingStrokeOutlines || shape.path == NULL || shape.lineWidth <= 0) {
        return [self.class newPathFromStrokedShapePaint:shape];
    }
    IJSVGStrokeCacheKey key = { .valid = YES };
    CGAffineTransform transform = shape.nonScalingStroke ? shape.strokeHostTransform : CGAffineTransformIdentity;
    CGFloat values[] = { shape.lineWidth, shape.miterLimit, shape.lineDashPhase,
        transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty };
    uint64_t flags[] = { shape.lineCap, shape.lineJoin, shape.nonScalingStroke, shape.hasPointSubpaths, shape.lineDashData.length };
    IJSVGAppendStrokeKey(&key, values, sizeof(values));
    IJSVGAppendStrokeKey(&key, flags, sizeof(flags));
    NSData* dash = shape.lineDashData;
    IJSVGAppendStrokeKey(&key, dash.bytes, dash.length);
    CGPathApply(shape.path, &key, IJSVGAppendStrokePathElement);
    if (!key.valid) {
        return [self.class newPathFromStrokedShapePaint:shape];
    }
    CGPathRef cached = (CGPathRef)IJSVGByteCacheGetValue(_strokeOutlineCache, key.bytes, key.length);
    if (cached != NULL) {
        return CGPathRetain(cached);
    }
    CGPathRef outline = [self.class newPathFromStrokedShapePaint:shape];
    if (outline != NULL) {
        if (_strokeOutlineCache == NULL) {
            _strokeOutlineCache = IJSVGByteCacheCreate(256, 4 * 1024 * 1024);
        }
        size_t cost = 128;
        CGPathApply(outline, &cost, IJSVGCountStrokeOutlineCost);
        if (cost > 4 * 1024 * 1024 - key.length - 256) {
            return outline;
        }
        CGPathRef snapshot = CGPathCreateCopy(outline);
        if (snapshot != NULL) {
            IJSVGByteCacheSetValueWithCost(_strokeOutlineCache, key.bytes, key.length, snapshot, cost);
            CGPathRelease(outline);
            return snapshot;
        }
    }
    return outline;
}

+ (CGPathRef)newPathFromStrokedShapePaint:(IJSVGShapePaint*)shapePaint
{
    if (shapePaint.path == NULL || shapePaint.lineWidth <= 0.f) {
        return CGPathCreateMutable();
    }
    CGAffineTransform hostTransform = shapePaint.strokeHostTransform;
    CGPathRef hostPath = NULL;
    if (shapePaint.nonScalingStroke) {
        CGFloat determinant = hostTransform.a * hostTransform.d - hostTransform.b * hostTransform.c;
        if (!isfinite(determinant) || determinant == 0.f) {
            return CGPathCreateMutable();
        }
        hostPath = CGPathCreateCopyByTransformingPath(shapePaint.path, &hostTransform);
    }
    CGPathRef centerline = hostPath ?: shapePaint.path;
    CGLineCap lineCap = shapePaint.lineCap;
    CGLineJoin lineJoin = shapePaint.lineJoin;
    CGMutablePathRef segments = NULL;
    CGMutablePathRef points = NULL;
    BOOL hasPoints = shapePaint.hasPointSubpaths;
    if (hasPoints) {
        segments = CGPathCreateMutable();
        points = CGPathCreateMutable();
        IJSVGQuartzSeparatePointSubpaths(centerline, segments, points);
        centerline = segments;
    }
    BOOL paintsPoints = YES;
    CGPathRef dashedPath = NULL;
    NSData* dashData = shapePaint.lineDashData;
    NSUInteger count = dashData.length / sizeof(CGFloat);
    if (count != 0) {
        const CGFloat* values = dashData.bytes;
        CGFloat* lengths = (CGFloat*)malloc(sizeof(CGFloat) * count);

        // Preserve the existing outline precision without boxing the values.
        for (NSUInteger index = 0; index < count; index++) {
            lengths[index] = (CGFloat)(float)values[index];
        }
        if (hasPoints) {
            NSUInteger dashCount = count % 2 == 0 ? count : count * 2;
            CGFloat total = 0.f;
            for (NSUInteger index = 0; index < dashCount; index++) {
                total += lengths[index % count];
            }
            if (total > 0.f) {
                CGFloat phase = fmod(shapePaint.lineDashPhase, total);
                if (phase < 0.f) {
                    phase += total;
                }
                for (NSUInteger index = 0; index < dashCount; index++) {
                    CGFloat length = lengths[index % count];
                    if (phase < length || (phase == 0.f && index % 2 == 0)) {
                        paintsPoints = index % 2 == 0;
                        break;
                    }
                    phase -= length;
                }
            }
        }
        dashedPath = CGPathCreateCopyByDashingPath(centerline, NULL, shapePaint.lineDashPhase, lengths, count);
        (void)free(lengths), lengths = NULL;
    }
    CGPathRef path = dashedPath ?: centerline;
    CGPathRef newPath = CGPathCreateCopyByStrokingPath(path, NULL, shapePaint.lineWidth, lineCap, lineJoin, shapePaint.miterLimit);
    if (hasPoints && paintsPoints && lineCap != kCGLineCapButt) {
        CGMutablePathRef outline = CGPathCreateMutableCopy(newPath);
        CGFloat radius = shapePaint.lineWidth / 2.f;
        CGPathApplyWithBlock(points, ^(const CGPathElement* element) {
            if (element->type != kCGPathElementMoveToPoint) {
                return;
            }
            CGPoint point = element->points[0];
            CGRect bounds = CGRectMake(point.x - radius, point.y - radius, shapePaint.lineWidth, shapePaint.lineWidth);
            if (lineCap == kCGLineCapRound) {
                CGPathAddEllipseInRect(outline, NULL, bounds);
            } else {
                CGPathAddRect(outline, NULL, bounds);
            }
        });
        CGPathRelease(newPath);
        newPath = outline;
    }
    CGPathRelease(segments);
    CGPathRelease(points);
    if (dashedPath != NULL) {
        CGPathRelease(dashedPath);
    }

    if (hostPath != NULL) {
        // SVG 2 paints the host space outline back in the original user space,
        // preserving gradient and pattern coordinates even under shear.
        CGAffineTransform inverse = CGAffineTransformInvert(hostTransform);
        CGPathRef localOutline = CGPathCreateCopyByTransformingPath(newPath, &inverse);
        CGPathRelease(newPath);
        CGPathRelease(hostPath);
        newPath = localOutline;
    }
    return newPath;
}

- (CGColorRef)colorForColor:(CGColorRef)color matchingTraits:(IJSVGColorUsageTraits)traits
{
    return [_style.colors colorForColor:color matchingTraits:traits];
}

- (IJSVGPaint*)drawableFillPaintForPathNode:(IJSVGPath*)node fill:(IJSVGNode*)fill currentColor:(CGColorRef)currentColor paint:(IJSVGShapePaint*)paint resolvedPath:(CGPathRef)paintPath resolvedPathBounds:(CGRect)resolvedPathBounds
{
    // Choose the fill type.
    IJSVGPaint* fillPaint = nil;
    IJSVGPaintFillType fillType = [IJSVGPaint fillTypeForFill:fill];

    switch (fillType) {
        // Fill with one color.
        default:
        case IJSVGPaintFillTypeColor: {
            IJSVGColorNode* colorNode = (IJSVGColorNode*)fill;
            CGColorRef color = colorNode.usesCurrentColor ? currentColor : (colorNode.color ?: IJSVGColor.blackColor);

            // Use the fill color supplied by the style.
            if (_style.fillColor != nil) {
                color = _style.fillColor;
            }

            if (colorNode.isNoneOrTransparent == YES) {
                color = nil;
            } else {
                // Apply any color replacement from the style.
                CGColorRef repColor = [self colorForColor:color matchingTraits:IJSVGColorUsageTraitFill];
                color = repColor ?: color;
            }

            if (paint.directFill) {
                paint.fillColor = color;
                return nil;
            }

            // Use a separate shape for the fill so the stroke can sit around it.
            IJSVGShapePaint* shape = (IJSVGShapePaint*)[self drawableBasicPaintForPathNode:node resolvedPath:paintPath resolvedPathBounds:resolvedPathBounds fillRule:paint.fillRule];
            shape.fillColor = color;
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
            fillPaint = [self drawablePatternPaintForPathNode:node pattern:(IJSVGPattern*)fill paint:paint];
            break;
        }

        // Fill with a gradient.
        case IJSVGPaintFillTypeGradient: {
            fillPaint = [self drawableGradientPaintForPathNode:node gradient:(IJSVGGradient*)fill paint:paint];

            break;
        }
    }

    return fillPaint;
}

- (void)applyStrokePaint:(IJSVGStrokePaint*)strokePaint toPaint:(IJSVGShapePaint*)paint stroke:(IJSVGNode*)stroke
{
    paint.strokeStyle = strokePaint;

    // Choose how to fill the stroke.
    IJSVGPaintFillType type = [IJSVGPaint fillTypeForFill:stroke];

    switch (type) {
        // Fill the stroke with a pattern.
        case IJSVGPaintFillTypePattern: {
            IJSVGPatternPaint* patternPaint = nil;
            patternPaint = [self drawableBasicPatternPaintForPaint:strokePaint pattern:(IJSVGPattern*)stroke];
            patternPaint.referencingPaint = paint;

            // Keep the drawing inside the stroke shape.
            CGPathRef path = [self newCachedPathFromStrokedShapePaint:strokePaint];
            patternPaint.clipPath = path;
            CGPathRelease(path);
            paint.strokePaint = patternPaint;
            [paint addChild:patternPaint];
            break;
        }

        // Fill the stroke with a gradient.
        case IJSVGPaintFillTypeGradient: {
            IJSVGGradientPaint* gradientPaint = nil;
            gradientPaint = [self drawableBasicGradientPaintForPaint:strokePaint gradient:(IJSVGGradient*)stroke];
            gradientPaint.referencingPaint = paint;

            // Keep the drawing inside the stroke shape.
            CGPathRef path = [self newCachedPathFromStrokedShapePaint:strokePaint];
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

- (IJSVGPaint*)drawablePaintForPathNode:(IJSVGPath*)node style:(const IJSVGResolvedPaintStyle*)style
{
    CGPathRef resolvedPath = [self newResolvedPathForPathNode:node];
    BOOL resolvedPathIsEmpty = CGPathIsEmpty(resolvedPath);
    CGRect resolvedPathBounds = resolvedPathIsEmpty == YES ? CGRectZero : CGPathGetPathBoundingBox(resolvedPath);
    BOOL resolvedPathBoundsAreFinite = resolvedPathIsEmpty == NO && IJSVGRectIsFinite(resolvedPathBounds);
    if (resolvedPathBoundsAreFinite == NO) {
        resolvedPathBounds = CGRectZero;
    }
    CGPathRef paintPath = resolvedPathBoundsAreFinite == YES ? [self newPaintPathForResolvedPath:resolvedPath bounds:resolvedPathBounds] : CGPathCreateMutable();
    IJSVGNode* fill = style->fill;
    IJSVGGradient* gradient = [fill isMemberOfClass:IJSVGLinearGradient.class] ? (IJSVGGradient*)fill : nil;
    IJSVGPrimitivePathType primitiveType = node.primitiveType;
    BOOL needsMarkers = primitiveType == kIJSVGPrimitivePathTypePath || primitiveType == kIJSVGPrimitivePathTypeLine || primitiveType == kIJSVGPrimitivePathTypePolygon || primitiveType == kIJSVGPrimitivePathTypePolyLine || (gradient != nil && gradient.units == IJSVGUnitObjectBoundingBox);
    IJSVGMarker* markerStart = needsMarkers ? style->markerStart : nil;
    IJSVGMarker* markerMid = needsMarkers ? style->markerMid : nil;
    IJSVGMarker* markerEnd = needsMarkers ? style->markerEnd : nil;
    IJSVGWindingRule fillRule = style->windingRule;
    IJSVGShapePaint* paint = (IJSVGShapePaint*)[self drawableBasicPaintForPathNode:node resolvedPath:paintPath resolvedPathBounds:resolvedPathBounds fillRule:fillRule];

    // Create the stroke.
    IJSVGStrokePaint* strokePaint = nil;
    IJSVGNode* stroke = nil;
    CGFloat strokeWidthDifference = 0.f;
    if ([node matchesTraits:IJSVGNodeTraitStroked]) {
        IJSVGResolvedStrokeStyle strokeStyle = [node resolvedStrokeStyle];
        stroke = strokeStyle.stroke;

        // Expand the paint so its frame includes the stroke.
        strokePaint = (IJSVGStrokePaint*)[self drawableStrokedPaintForPathNode:node style:&strokeStyle currentColor:style->currentColor resolvedPath:paintPath resolvedPathBounds:resolvedPathBounds];
        strokeWidthDifference = strokePaint.lineWidth * .5f;

        // Update the bounds to include the stroke.
        paint.frame = CGRectInset(paint.frame, -strokeWidthDifference, -strokeWidthDifference);
        paint.outerBoundingBox = paint.frame;
    }

    CGFloat fillOpacity = style->fillOpacity.value;
    BOOL directGradient = gradient != nil && gradient.units == IJSVGUnitObjectBoundingBox && strokePaint == nil && fillOpacity == 1.f && style->opacity == 1.f && !node.isolated && node.blendMode == IJSVGBlendModeNormal && markerStart == nil && markerMid == nil && markerEnd == nil && paint.class == IJSVGShapePaint.class && _style.colors.replacedColorCount == 0;

    // With no separate stroke, opacity or marker operations, a solid fill
    // can use the existing shape instead of allocating a second paint and path.
    paint.directFill = gradient == nil && strokePaint == nil && [IJSVGPaint fillTypeForFill:fill] == IJSVGPaintFillTypeColor && fillOpacity == 1.f && style->opacity == 1.f && !node.isolated && node.blendMode == IJSVGBlendModeNormal && markerStart == nil && markerMid == nil && markerEnd == nil && paint.class == IJSVGShapePaint.class;
    IJSVGPaint* fillPaint = nil;
    if (directGradient) {
        paint.fillGradient = [self gradientByResolvingFontLengths:gradient];
    } else {
        fillPaint = [self drawableFillPaintForPathNode:node fill:fill currentColor:style->currentColor paint:paint resolvedPath:paintPath resolvedPathBounds:resolvedPathBounds];
    }

    if (fillPaint != nil) {
        // Apply the fill opacity.
        if (fillOpacity != 1.f) {
            fillPaint.opacity = fillOpacity;
        }
        fillPaint.affineTransform = CGAffineTransformTranslate(fillPaint.affineTransform, strokeWidthDifference, strokeWidthDifference);
        paint.fillPaint = fillPaint;
        [paint addChild:fillPaint];
    }

    // Attach the stroke.
    if (strokePaint != nil) {
        [self applyStrokePaint:strokePaint toPaint:paint stroke:stroke];
    }

    if (paint.fillPaint != nil && paint.strokePaint != nil) {
        IJSVGPaintOrder order = style->paintOrder;
        for (NSUInteger index = 0; index < 3; index++) {
            NSUInteger operation = (order >> (index * 2)) & 3;
            if (operation == 0) {
                break;
            }
            if (operation == 1) {
                paint.children = @[ paint.strokePaint, paint.fillPaint ];
                break;
            }
        }
    }
    IJSVGPaint* result = [self paintByAddingMarkersToPaint:paint forNode:node resolvedPath:resolvedPath bounds:resolvedPathBounds markerStart:markerStart markerMid:markerMid markerEnd:markerEnd paintOrder:style->paintOrder];
    CGPathRelease(paintPath);
    CGPathRelease(resolvedPath);
    return result;
}

- (IJSVGGradient*)gradientByResolvingFontLengths:(IJSVGGradient*)gradient
{
    if (_resolvingGradientFonts && gradient == _fontGradientSource) {
        return _fontGradientResult;
    }
    IJSVGRadialGradient* radial = (gradient.nodeTraits & IJSVGNodeTypeTraitRadialGradient) != 0 ? (IJSVGRadialGradient*)gradient : nil;
    BOOL relative = gradient.x1.usesFontMetrics || gradient.y1.usesFontMetrics || gradient.x2.usesFontMetrics || gradient.y2.usesFontMetrics;
    if (!relative && radial != nil) {
        relative = radial.cx.usesFontMetrics || radial.cy.usesFontMetrics || radial.fx.usesFontMetrics || radial.fy.usesFontMetrics || radial.r.usesFontMetrics || radial.fr.usesFontMetrics;
    }
    if (!relative) {
        return gradient;
    }
    IJSVGGradient* copy = gradient.copy;
    copy.x1 = [self.lengthFontResolver unitByResolvingFontLength:gradient.x1 node:gradient];
    copy.y1 = [self.lengthFontResolver unitByResolvingFontLength:gradient.y1 node:gradient];
    copy.x2 = [self.lengthFontResolver unitByResolvingFontLength:gradient.x2 node:gradient];
    copy.y2 = [self.lengthFontResolver unitByResolvingFontLength:gradient.y2 node:gradient];
    if (radial != nil) {
        IJSVGRadialGradient* result = (IJSVGRadialGradient*)copy;
        result.cx = [self.lengthFontResolver unitByResolvingFontLength:radial.cx node:radial];
        result.cy = [self.lengthFontResolver unitByResolvingFontLength:radial.cy node:radial];
        result.fx = [self.lengthFontResolver unitByResolvingFontLength:radial.fx node:radial];
        result.fy = [self.lengthFontResolver unitByResolvingFontLength:radial.fy node:radial];
        result.r = [self.lengthFontResolver unitByResolvingFontLength:radial.r node:radial];
        result.fr = [self.lengthFontResolver unitByResolvingFontLength:radial.fr node:radial];
    }

    // Siblings often share an inherited paint server. Keep only the most recent
    // result relative to the font, using only the rendering options of this build.
    if (_resolvingGradientFonts) {
        _fontGradientSource = gradient;
        _fontGradientResult = copy;
    }
    return copy;
}

- (BOOL)hasFontRelativeRegion:(IJSVGGraphicsNode*)node
{
    IJSVGUnitLength* lengths[] = { node.x, node.y, node.width, node.height };
    for (NSUInteger index = 0; index < 4; index++) {
        if (lengths[index].usesFontMetrics) {
            return YES;
        }
    }
    return NO;
}

- (void)resolveRegionFontLengths:(IJSVGGraphicsNode*)node
{
    [self resolveRegionFontLengths:node css:NO];
}

- (void)resolveRegionFontLengths:(IJSVGGraphicsNode*)node css:(BOOL)css
{
    node.x = [self.lengthFontResolver unitByResolvingFontLength:node.x node:node css:css];
    node.y = [self.lengthFontResolver unitByResolvingFontLength:node.y node:node css:css];
    node.width = [self.lengthFontResolver unitByResolvingFontLength:node.width node:node css:css];
    node.height = [self.lengthFontResolver unitByResolvingFontLength:node.height node:node css:css];
}

#pragma mark Context Paint

- (BOOL)nodeNeedsContextPaint:(IJSVGNode*)source
{
    if ((source.nodeTraits & IJSVGNodeTypeTraitGraphics) == 0) {
        return NO;
    }
    IJSVGGraphicsNode* node = (IJSVGGraphicsNode*)source;
    IJSVGNode* paints[] = { node.fill, node.stroke };
    for (NSUInteger index = 0; index < 2; index++) {
        if ((paints[index].nodeTraits & IJSVGNodeTypeTraitColor) != 0 && ((IJSVGColorNode*)paints[index]).contextPaint != IJSVGContextPaintNone) {
            return YES;
        }
    }
    if ((node.nodeTraits & IJSVGNodeTypeTraitGroup) != 0) {
        for (IJSVGNode* child in ((IJSVGGroup*)node).children) {
            if ([self nodeNeedsContextPaint:child]) {
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)useChildrenNeedContextPaint:(IJSVGUse*)node
{
    for (IJSVGNode* child in node.children) {
        if ([self nodeNeedsContextPaint:child]) {
            return YES;
        }
    }
    return NO;
}

- (IJSVGPaint*)drawablePaintForContextUse:(IJSVGUse*)source
{
    // Only instances with context paints are copied. Their resolved paints must not
    // leak into the editable source tree or another differently styled use.
    IJSVGUse* node = source.copy;
    CGRect viewport = [self unitResolutionBoundsForNode:source];
    CGRect bounds = CGRectZero;
    NSMapTable<IJSVGNode*, NSValue*>* transforms = nil;
    BOOL hasServer = (node.fill.nodeTraits & IJSVGNodeTypeTraitGradient) != 0 || (node.fill.nodeTraits & IJSVGNodeTypeTraitPattern) != 0 || (node.stroke.nodeTraits & IJSVGNodeTypeTraitGradient) != 0 || (node.stroke.nodeTraits & IJSVGNodeTypeTraitPattern) != 0;
    if (hasServer) {
        BOOL previous = _measuringContextUse;
        _measuringContextUse = YES;
        @try {
            // The geometry pass includes symbol viewBoxes and child transforms,
            // even when the unresolved context paint is transparent.
            IJSVGPaint* geometry = [self drawablePaintForGroupNode:node];
            bounds = geometry.boundingBox;
            transforms = [NSMapTable strongToStrongObjectsMapTable];
            [self collectContextTransformsFromPaint:geometry transform:CGAffineTransformIdentity into:transforms];
        } @finally {
            _measuringContextUse = previous;
        }
    }
    for (IJSVGNode* child in node.children) {
        [self resolveUseContextInNode:child referencingNode:node bounds:bounds viewport:viewport transforms:transforms];
    }
    IJSVGUse* previous = _resolvedContextUse;
    _resolvedContextUse = node;
    @try {
        IJSVGPaint* paint = [self drawablePaintForNode:node];
        paint.contextPaintOwner = node;
        return paint;
    } @finally {
        _resolvedContextUse = previous;
    }
}

// Reuse resolved placement instead of reimplementing CSS transform origins,
// units, symbol reference points and nested viewBox geometry for context paints.
- (void)collectContextTransformsFromPaint:(IJSVGPaint*)paint transform:(CGAffineTransform)transform into:(NSMapTable<IJSVGNode*, NSValue*>*)transforms
{
    if (paint.sourceNode != nil && [transforms objectForKey:paint.sourceNode] == nil) {
        [transforms setObject:[NSValue valueWithBytes:&transform objCType:@encode(CGAffineTransform)] forKey:paint.sourceNode];
    }
    CGAffineTransform childrenTransform = CGAffineTransformConcat(paint.placementTransform, transform);
    if ((paint.paintTraits & IJSVGPaintTraitRoot) != 0) {
        IJSVGRootPaint* root = (IJSVGRootPaint*)paint;
        if (root.viewBox != nil) {
            CGRect viewBox = [root.viewBox computeValue:root.frame.size];
            CGAffineTransform mapping = IJSVGViewBoxComputeTransform(viewBox, IJSVGPaintGetBoundingBoxBounds(root), root.viewBoxAlignment, root.viewBoxMeetOrSlice);
            childrenTransform = CGAffineTransformConcat(mapping, childrenTransform);
        }
    }
    for (IJSVGPaint* child in paint.children) {
        [self collectContextTransformsFromPaint:child transform:childrenTransform into:transforms];
    }
}

- (void)resolveUseContextInNode:(IJSVGNode*)source referencingNode:(IJSVGUse*)context bounds:(CGRect)bounds viewport:(CGRect)viewport transforms:(NSMapTable<IJSVGNode*, NSValue*>*)transforms
{
    if ((source.nodeTraits & IJSVGNodeTypeTraitGraphics) == 0) {
        return;
    }
    IJSVGGraphicsNode* node = (IJSVGGraphicsNode*)source;

    // Resolve descendants before their parent, so inherited context tokens are
    // still visible. A nested use establishes its own context during its build.
    if (node.type != IJSVGNodeTypeUse && (node.nodeTraits & IJSVGNodeTypeTraitGroup) != 0) {
        for (IJSVGNode* child in ((IJSVGGroup*)node).children) {
            [self resolveUseContextInNode:child referencingNode:context bounds:bounds viewport:viewport transforms:transforms];
        }
    }
    CGAffineTransform transform = CGAffineTransformIdentity;
    [[transforms objectForKey:node] getValue:&transform size:sizeof(transform)];
    node.fill = [self resolvedContextPaint:node.fill referencingNode:context bounds:bounds viewport:viewport transform:transform];
    node.stroke = [self resolvedContextPaint:node.stroke referencingNode:context bounds:bounds viewport:viewport transform:transform];
    [node computeTraits];
}

- (IJSVGGradient*)contextGradient:(IJSVGGradient*)source bounds:(CGRect)bounds viewport:(CGRect)viewport transform:(CGAffineTransform)transform
{
    // Context gradients retain the coordinate space of the referencing shape.
    IJSVGGradient* gradient = [[self gradientByResolvingFontLengths:source] copy];
    BOOL objectUnits = gradient.units == IJSVGUnitObjectBoundingBox;
    CGSize size = objectUnits ? CGSizeMake(1, 1) : viewport.size;
    if ((gradient.nodeTraits & IJSVGNodeTypeTraitRadialGradient) != 0) {
        IJSVGRadialGradient* radial = (IJSVGRadialGradient*)gradient;
        radial.cx = [IJSVGUnitLength unitWithFloat:[radial.cx computeValue:size.width]];
        radial.fx = [IJSVGUnitLength unitWithFloat:[radial.fx computeValue:size.width]];
        radial.cy = [IJSVGUnitLength unitWithFloat:[radial.cy computeValue:size.height]];
        radial.fy = [IJSVGUnitLength unitWithFloat:[radial.fy computeValue:size.height]];
        radial.r = [IJSVGUnitLength unitWithFloat:[radial.r computeValue:MIN(size.width, size.height)]];
        radial.fr = [IJSVGUnitLength unitWithFloat:[radial.fr computeValue:MIN(size.width, size.height)]];
    } else {
        gradient.x1 = [IJSVGUnitLength unitWithFloat:[gradient.x1 computeValue:size.width]];
        gradient.x2 = [IJSVGUnitLength unitWithFloat:[gradient.x2 computeValue:size.width]];
        gradient.y1 = [IJSVGUnitLength unitWithFloat:[gradient.y1 computeValue:size.height]];
        gradient.y2 = [IJSVGUnitLength unitWithFloat:[gradient.y2 computeValue:size.height]];
    }
    CGAffineTransform placement = IJSVGConcatTransforms(gradient.transforms);
    if (objectUnits) {
        CGAffineTransform box = CGAffineTransformMake(bounds.size.width, 0, 0, bounds.size.height, bounds.origin.x, bounds.origin.y);
        placement = CGAffineTransformConcat(placement, box);
    }
    placement = CGAffineTransformConcat(placement, CGAffineTransformInvert(transform));
    gradient.units = IJSVGUnitUserSpaceOnUse;
    gradient.transforms = [IJSVGTransform transformsFromAffineTransform:placement];
    return gradient;
}

- (IJSVGPattern*)contextPattern:(IJSVGPattern*)source bounds:(CGRect)bounds viewport:(CGRect)viewport transform:(CGAffineTransform)transform
{
    IJSVGPattern* pattern = [source copy];
    if ([self hasFontRelativeRegion:pattern]) {
        [self resolveRegionFontLengths:pattern];
    }
    BOOL objectUnits = pattern.units == IJSVGUnitObjectBoundingBox;
    CGSize size = objectUnits ? bounds.size : viewport.size;
    if (objectUnits) {
        pattern.x = pattern.x.lengthByMatchingPercentage;
        pattern.y = pattern.y.lengthByMatchingPercentage;
        pattern.width = pattern.width.lengthByMatchingPercentage;
        pattern.height = pattern.height.lengthByMatchingPercentage;
    }
    CGPoint origin = objectUnits ? bounds.origin : CGPointZero;
    pattern.x = [IJSVGUnitLength unitWithFloat:[pattern.x computeValue:size.width] + origin.x];
    pattern.y = [IJSVGUnitLength unitWithFloat:[pattern.y computeValue:size.height] + origin.y];
    pattern.width = [IJSVGUnitLength unitWithFloat:[pattern.width computeValue:size.width]];
    pattern.height = [IJSVGUnitLength unitWithFloat:[pattern.height computeValue:size.height]];
    pattern.units = IJSVGUnitUserSpaceOnUse;
    CGAffineTransform placement = IJSVGConcatTransforms(pattern.transforms);
    placement = CGAffineTransformConcat(placement, CGAffineTransformInvert(transform));
    pattern.transforms = [IJSVGTransform transformsFromAffineTransform:placement];
    if (_contextPatternBounds == nil) {
        _contextPatternBounds = [NSMapTable weakToStrongObjectsMapTable];
    }
    [_contextPatternBounds setObject:@[ IJSVGValueWithRect(bounds), IJSVGValueWithRect(viewport) ] forKey:pattern];
    return pattern;
}

- (IJSVGNode*)resolvedContextPaint:(IJSVGNode*)paint referencingNode:(IJSVGGraphicsNode*)context bounds:(CGRect)bounds viewport:(CGRect)viewport transform:(CGAffineTransform)transform
{
    if ((paint.nodeTraits & IJSVGNodeTypeTraitColor) == 0) {
        return paint;
    }
    IJSVGContextPaint type = ((IJSVGColorNode*)paint).contextPaint;
    if (type == IJSVGContextPaintNone) {
        return paint;
    }
    IJSVGNode* resolved = type == IJSVGContextPaintFill ? context.fill : context.stroke;
    if (resolved == nil) {
        CGColorRef defaultColor = type == IJSVGContextPaintFill ? IJSVGColor.blackColor : nil;
        IJSVGColorNode* color = [[IJSVGColorNode alloc] initWithColor:defaultColor];
        color.isNoneOrTransparent = type == IJSVGContextPaintStroke;
        return color;
    }
    if ((resolved.nodeTraits & IJSVGNodeTypeTraitColor) != 0 && ((IJSVGColorNode*)resolved).usesCurrentColor) {
        return [IJSVGColorNode colorNodeWithColor:context.currentColor];
    }
    if ((resolved.nodeTraits & IJSVGNodeTypeTraitGradient) != 0) {
        return [self contextGradient:(IJSVGGradient*)resolved bounds:bounds viewport:viewport transform:transform];
    }
    if ((resolved.nodeTraits & IJSVGNodeTypeTraitPattern) != 0) {
        return [self contextPattern:(IJSVGPattern*)resolved bounds:bounds viewport:viewport transform:transform];
    }
    return resolved;
}

// Resolve on an instance copy so a shared marker retains its context
// references.
- (void)resolveContextPaintInNode:(IJSVGNode*)source referencingNode:(IJSVGGraphicsNode*)context bounds:(CGRect)bounds viewport:(CGRect)viewport transform:(CGAffineTransform)transform
{
    if ((source.nodeTraits & IJSVGNodeTypeTraitGraphics) == 0) {
        return;
    }
    IJSVGGraphicsNode* node = (IJSVGGraphicsNode*)source;
    transform = CGAffineTransformConcat(IJSVGConcatTransforms(node.transforms), transform);
    node.fill = [self resolvedContextPaint:node.fill referencingNode:context bounds:bounds viewport:viewport transform:transform];
    IJSVGNode* stroke = [self resolvedContextPaint:node.stroke referencingNode:context bounds:bounds viewport:viewport transform:transform];
    if (stroke != node.stroke) {
        node.stroke = stroke;
        [node computeTraits];
    }

    if ((node.nodeTraits & IJSVGNodeTypeTraitGroup) != 0) {
        for (IJSVGNode* child in ((IJSVGGroup*)node).children) {
            [self resolveContextPaintInNode:child referencingNode:context bounds:bounds viewport:viewport transform:transform];
        }
    }
}

#pragma mark Markers

- (IJSVGPaint*)paintByAddingMarkersToPaint:(IJSVGPaint*)paint forNode:(IJSVGPath*)node resolvedPath:(CGPathRef)resolvedPath bounds:(CGRect)resolvedPathBounds markerStart:(IJSVGMarker*)markerStart markerMid:(IJSVGMarker*)markerMid markerEnd:(IJSVGMarker*)markerEnd paintOrder:(IJSVGPaintOrder)paintOrder
{
    switch (node.primitiveType) {
        case kIJSVGPrimitivePathTypePath:
        case kIJSVGPrimitivePathTypeLine:
        case kIJSVGPrimitivePathTypePolygon:
        case kIJSVGPrimitivePathTypePolyLine:
            break;
        default:
            return paint;
    }
    if (markerStart.children.count == 0 && markerMid.children.count == 0 && markerEnd.children.count == 0) {
        return paint;
    }

    NSString* data = node.pathUnits == IJSVGUnitObjectBoundingBox ? nil : node.markerPathData;
    NSArray<IJSVGMarkerPosition*>* positions = IJSVGMarkerPositions(resolvedPath, data);
    NSMutableArray<IJSVGPaint*>* children = [[NSMutableArray alloc] initWithCapacity:positions.count + 1];
    [children addObject:paint];
    IJSVGMarkerTemplate* start = [IJSVGMarkerTemplate templateWithMarker:markerStart];
    IJSVGMarkerTemplate* mid = markerMid == start.marker ? start : [IJSVGMarkerTemplate templateWithMarker:markerMid];
    IJSVGMarkerTemplate* end = markerEnd == start.marker ? start : (markerEnd == mid.marker ? mid : [IJSVGMarkerTemplate templateWithMarker:markerEnd]);
    for (IJSVGMarkerPosition* position in positions) {
        IJSVGMarkerTemplate* prototype = mid;
        if (position.type == IJSVGMarkerPositionStart) {
            prototype = start;
        } else if (position.type == IJSVGMarkerPositionEnd) {
            prototype = end;
        }
        IJSVGPaint* instance = [self paintForMarkerTemplate:prototype position:position referencingNode:node bounds:resolvedPathBounds];
        if (instance != nil) {
            [children addObject:instance];
        }
    }
    if (children.count == 1) {
        return paint;
    }

    if (paintOrder != IJSVGPaintOrderNormal) {
        NSArray<IJSVGPaint*>* markers = [children subarrayWithRange:NSMakeRange(1, children.count - 1)];
        [children removeAllObjects];
        IJSVGShapePaint* shape = (IJSVGShapePaint*)paint;
        for (NSUInteger index = 0; index < 3; index++) {
            NSUInteger operation = (paintOrder >> (index * 2)) & 3;
            if (operation == 2) {
                [children addObjectsFromArray:markers];
                continue;
            }
            IJSVGPaint* component = operation == 0 ? shape.fillPaint : shape.strokePaint;
            if (component != nil) {
                // Retain shape metadata so vector export can reconstruct paint servers
                // and stroke geometry, even when markers separate the two operations.
                IJSVGShapePaint* placed = IJSVGShapePaint.paint;
                placed.path = shape.path;
                placed.primitiveType = shape.primitiveType;
                placed.sourceNode = shape.sourceNode;
                placed.viewPort = shape.viewPort;
                placed.frame = shape.frame;
                placed.affineTransform = shape.affineTransform;
                placed.boundingBox = shape.boundingBox;
                placed.outerBoundingBox = shape.outerBoundingBox;
                placed.children = @[ component ];
                if (operation == 0) {
                    placed.fillPaint = component;
                    placed.fillRule = shape.fillRule;
                    if (shape.strokeStyle != nil) {
                        // Keep the fill export path in the padded stroke frame.
                        CGFloat inset = shape.strokeStyle.lineWidth * .5f;
                        CGAffineTransform transform = CGAffineTransformMakeTranslation(inset, inset);
                        CGPathRef path = CGPathCreateCopyByTransformingPath(shape.path, &transform);
                        placed.path = path;
                        CGPathRelease(path);
                    }
                } else {
                    placed.strokePaint = component;
                    placed.strokeStyle = shape.strokeStyle;
                }
                [children addObject:placed];
            }
        }
    }
    IJSVGPaint* result = [self drawablePaintForGroupNode:node children:children];

    // Markers contribute to visual coverage, never to objectBoundingBox geometry.
    result.boundingBox = resolvedPathBounds;
    return result;
}

- (IJSVGPaint*)paintForMarkerTemplate:(IJSVGMarkerTemplate*)prototype position:(IJSVGMarkerPosition*)position referencingNode:(IJSVGPath*)node bounds:(CGRect)contextBounds
{
    if (prototype == nil) {
        return nil;
    }
    IJSVGMarker* marker = prototype.marker;
    id key = prototype.recursionKey;
    if ([_activeMarkers containsObject:key] || _activeMarkers.count >= 32) {
        return nil;
    }
    if (prototype.paint != nil && !prototype.reuseDisabled) {
        IJSVGPaint* instance = [prototype.paint copyForMarker];
        if (instance != nil) {
            instance.affineTransform = [self transformForMarker:marker position:position reference:prototype.reference scale:prototype.scale];
            return instance;
        }
        prototype.reuseDisabled = YES;
        prototype.paint = nil;
    }

    CGRect bounds = [self unitResolutionBoundsForNode:node];
    CGSize size = CGSizeMake([self resolveLength:marker.markerWidth percentage:bounds.size.width node:marker], [self resolveLength:marker.markerHeight percentage:bounds.size.height node:marker]);

    CGFloat normalizedDiagonal = hypot(bounds.size.width, bounds.size.height) / M_SQRT2;
    CGFloat strokeWidth = [self resolveStrokeWidthForNode:node percentage:normalizedDiagonal];

    CGFloat scale = marker.markerUnits == IJSVGMarkerUnitsStrokeWidth ? strokeWidth : 1;
    if (size.width <= 0 || size.height <= 0 || scale <= 0 || !isfinite(size.width) || !isfinite(size.height) || !isfinite(scale)) {
        return nil;
    }

    CGRect viewport = (CGRect) { CGPointZero, size };
    CGRect viewBox = marker.viewBox == nil ? viewport : [marker.viewBox computeValue:size];
    if (!IJSVGRectIsFinite(viewBox) || CGRectIsEmpty(viewBox)) {
        return nil;
    }

    CGAffineTransform mapping = IJSVGViewBoxComputeTransform(viewBox, viewport, marker.viewBoxAlignment, marker.viewBoxMeetOrSlice);
    CGPoint reference = CGPointMake([self resolveLength:marker.refX percentage:viewBox.size.width node:marker], [self resolveLength:marker.refY percentage:viewBox.size.height node:marker]);
    reference = CGPointApplyAffineTransform(reference, mapping);
    CGAffineTransform transform = [self transformForMarker:marker position:position reference:reference scale:scale];
    CGAffineTransform contentTransform = CGAffineTransformConcat(mapping, transform);
    marker = [marker copy];
    [self resolveContextPaintInNode:marker referencingNode:node bounds:contextBounds viewport:bounds transform:contentTransform];
    IJSVGPaint* content = [self contentPaintForMarker:marker viewBox:viewBox transform:contentTransform recursionKey:key];
    if (content == nil) {
        return nil;
    }
    IJSVGPaint* instance = [self markerInstanceWithContent:content marker:marker viewport:viewport mapping:mapping transform:transform];
    if (!prototype.reuseDisabled) {
        prototype.paint = instance;
        prototype.reference = reference;
        prototype.scale = scale;
    }
    return instance;
}

- (CGAffineTransform)transformForMarker:(IJSVGMarker*)marker position:(IJSVGMarkerPosition*)position reference:(CGPoint)reference scale:(CGFloat)scale
{
    CGFloat angle = marker.orientType == IJSVGMarkerOrientTypeAngle ? marker.orientAngle : position.angle;
    if (marker.orientType == IJSVGMarkerOrientTypeAutoStartReverse && position.type == IJSVGMarkerPositionStart) {
        angle += 180;
    }

    CGAffineTransform transform = CGAffineTransformMakeTranslation(position.point.x, position.point.y);
    transform = CGAffineTransformRotate(transform, angle * M_PI / 180);
    transform = CGAffineTransformScale(transform, scale, scale);
    return CGAffineTransformTranslate(transform, -reference.x, -reference.y);
}

- (IJSVGPaint*)contentPaintForMarker:(IJSVGMarker*)marker viewBox:(CGRect)viewBox transform:(CGAffineTransform)transform recursionKey:(id)key
{
    if (_activeMarkers == nil) {
        _activeMarkers = [[NSMutableSet alloc] init];
    }
    [_activeMarkers addObject:key];
    CGAffineTransform previous = _textTransform;
    _textTransform = CGAffineTransformConcat(transform, previous);
    __block IJSVGPaint* content = nil;
    @try {
        [self withViewPort:viewBox
                unitBounds:viewBox
                   handler:^{
                       content = [self drawablePaintForNode:marker];
                   }];
    } @finally {
        _textTransform = previous;
        [_activeMarkers removeObject:key];
    }
    return content;
}

- (IJSVGPaint*)markerInstanceWithContent:(IJSVGPaint*)content marker:(IJSVGMarker*)marker viewport:(CGRect)viewport mapping:(CGAffineTransform)mapping transform:(CGAffineTransform)transform
{
    NSArray<IJSVGPaint*>* children = @[ content ];
    if (content.class == IJSVGGroupPaint.class && content.opacity == 1.f && !content.hidden && !content.isolated && content.blendingMode == kCGBlendModeNormal && content.clipPath == NULL && content.clipPaints.count == 0 && content.maskPaint == nil && CGRectIsNull(content.sourceNode.backgroundRect) && CGAffineTransformIsIdentity(content.placementTransform)) {
        children = content.children;
    }
    if (!CGAffineTransformIsIdentity(mapping)) {
        IJSVGTransformPaint* mapped = IJSVGTransformPaint.paint;
        mapped.affineTransform = mapping;
        mapped.children = children;
        children = @[ mapped ];
    }
    if (marker.overflowVisibility != IJSVGOverflowVisibilityVisible) {
        IJSVGGroupPaint* clipped = IJSVGGroupPaint.paint;
        clipped.children = children;
        clipped.boundingBox = [IJSVGPaint calculateBoundingBoxForChildren:children];
        clipped.outerBoundingBox = CGRectIntersection([IJSVGPaint calculateFrameForChildren:children], viewport);
        CGPathRef clip = CGPathCreateWithRect(viewport, NULL);
        clipped.clipPath = clip;
        CGPathRelease(clip);
        children = @[ clipped ];
    }

    IJSVGTransformPaint* instance = IJSVGTransformPaint.paint;
    instance.children = children;
    instance.affineTransform = transform;
    return instance;
}

- (CGFloat)zeroPathLengthScaleForValues:(const CGFloat*)values count:(NSUInteger)count lengths:(NSArray<IJSVGUnitLength*>*)lengths phase:(CGFloat)phase offset:(IJSVGUnitLength*)offset pathLength:(CGFloat)pathLength
{
    // Replace the infinite calibration with a finite equivalent over this path.
    // Keep every nonzero distance to a dash boundary beyond the visible length.
    // This also keeps Core Graphics and SVG export free of infinite values.
    CGFloat period = 0.f;
    CGFloat finiteLength = pathLength + fabs(phase) + 1.f;
    NSUInteger repeatedCount = count % 2 == 0 ? count : count * 2;
    for (NSUInteger index = 0; index < repeatedCount; index++) {
        NSUInteger item = index % count;
        CGFloat value = values[item];
        if (item < lengths.count && lengths[item].type == IJSVGUnitLengthTypePercentage) {
            finiteLength += value;
        } else {
            period += value;
        }
    }
    if (period == 0.f) {
        return 1.f;
    }
    CGFloat position = offset.type == IJSVGUnitLengthTypePercentage ? 0.f : fmod(phase, period);
    if (position < 0.f) {
        position += period;
    }
    CGFloat minimum = period;
    CGFloat boundary = 0.f;
    for (NSUInteger index = 0; index < repeatedCount; index++) {
        NSUInteger item = index % count;
        if (item >= lengths.count || lengths[item].type != IJSVGUnitLengthTypePercentage) {
            CGFloat value = values[item];
            if (value > 0.f) {
                minimum = MIN(minimum, value);
            }
            boundary += value;
        }
        CGFloat distance = fabs(boundary - position);
        if (distance > 0.f) {
            minimum = MIN(minimum, distance);
        }
        if (distance < period) {
            minimum = MIN(minimum, period - distance);
        }
    }
    return 2.f * finiteLength / minimum;
}

- (IJSVGPaint*)drawableStrokedPaintForPathNode:(IJSVGPath*)node style:(const IJSVGResolvedStrokeStyle*)style currentColor:(CGColorRef)currentColor resolvedPath:(CGPathRef)resolvedPath resolvedPathBounds:(CGRect)resolvedPathBounds
{
    IJSVGStrokePaint* paint = IJSVGStrokePaint.paint;
    [self applyPath:resolvedPath bounds:resolvedPathBounds toShapePaint:paint];

    // Choose the stroke color.
    CGColorRef strokeColor = IJSVGColor.blackColor;
    IJSVGNode* stroke = style->stroke;
    if ((stroke.nodeTraits & IJSVGNodeTypeTraitColor) != 0) {
        IJSVGColorNode* colorNode = (IJSVGColorNode*)stroke;
        strokeColor = colorNode.usesCurrentColor ? currentColor : colorNode.color;
    }

    // Apply any color replacement.
    CGColorRef repColor = [self colorForColor:strokeColor matchingTraits:IJSVGColorUsageTraitStroke];
    strokeColor = repColor ?: strokeColor;

    // Use the stroke color supplied by the style.
    if (_style.strokeColor != nil) {
        strokeColor = _style.strokeColor;
    }

    // Store the color.
    paint.fillColor = nil;
    paint.strokeColor = strokeColor;

    CGRect unitBounds = [self unitResolutionBoundsForNode:node];
    CGFloat diagonal = hypot(unitBounds.size.width, unitBounds.size.height) / M_SQRT2;
    CGFloat lineWidth = _style.lineWidth;
    if (lineWidth == IJSVGInheritedFloatValue) {
        lineWidth = style->widthOwner != nil ? [self resolveCSSLength:style->width percentage:diagonal node:style->widthOwner] : [self resolveStrokeWidth:style->width forNode:node percentage:diagonal];
    }
    IJSVGQuartzConfigureStroke(paint, style, _style, lineWidth);
    IJSVGGraphicsNode* offsetOwner = style->dashOffsetOwner ?: node;
    IJSVGUnitLength* offset = style->dashOffset;
    if (style->dashOffsetOwner == nil && offset.usesFontMetrics) {
        IJSVGGraphicsNode* parent = offsetOwner.styleParent;
        while (parent != nil && parent.strokeDashOffset == offset) {
            offsetOwner = parent;
            parent = parent.styleParent;
        }
    }
    paint.lineDashPhase = [self resolveCSSLength:offset percentage:diagonal node:offsetOwner];
    NSArray<IJSVGUnitLength*>* lengths = style->dashLengths;
    IJSVGGraphicsNode* owner = style->dashLengthsOwner ?: node;
    NSInteger dashCount = style->dashCount;
    BOOL hasLengths = lengths != nil && dashCount != 0;
    BOOL usesCustomPattern = !hasLengths && dashCount != IJSVGInheritedIntegerValue && style->usesCustomDashPattern;
    NSArray<NSNumber*>* customPattern = usesCustomPattern ? node.lineDashPattern : nil;
    NSUInteger count = MAX(0, dashCount);
    if (hasLengths) {
        count = lengths.count;
    } else if (usesCustomPattern) {
        count = customPattern.count;
    }
    CGFloat* values = count != 0 ? malloc(count * sizeof(CGFloat)) : NULL;
    if (count != 0 && values == NULL) {
        [NSException raise:NSMallocException format:@"Unable to allocate stroke dash values"];
    }

    // The immutable data owns this buffer. Resolve and scale it before publication.
    NSData* pattern = count != 0 ? [[NSData alloc] initWithBytesNoCopy:values length:count * sizeof(CGFloat) freeWhenDone:YES] : nil;
    if (hasLengths) {
        BOOL usesFontMetrics = NO;
        for (IJSVGUnitLength* length in lengths) {
            usesFontMetrics |= length.usesFontMetrics;
        }
        if (style->dashLengthsOwner == nil && usesFontMetrics) {
            IJSVGGraphicsNode* parent = owner.styleParent;
            while (parent != nil && parent.strokeDashLengths == lengths) {
                owner = parent;
                parent = parent.styleParent;
            }
        }
        for (NSUInteger index = 0; index < count; index++) {
            values[index] = [self resolveCSSLength:lengths[index] percentage:diagonal node:owner];
        }
    } else {
        for (NSUInteger index = 0; index < count; index++) {
            values[index] = customPattern != nil ? customPattern[index].doubleValue : style->dashArray[index];
        }
    }
    if (node.pathLength != nil && count != 0) {
        IJSVGTextPathMetrics* metrics = [[IJSVGTextPathMetrics alloc] initWithPath:resolvedPath];
        CGFloat authorLength = node.pathLength.doubleValue;
        CGFloat scale = authorLength > 0.f ? metrics.length / authorLength : INFINITY;
        if (!isfinite(scale)) {
            scale = [self zeroPathLengthScaleForValues:values count:count lengths:lengths phase:paint.lineDashPhase offset:offset pathLength:metrics.length];
        }
        for (NSUInteger index = 0; index < count; index++) {
            CGFloat value = values[index];
            if (index < lengths.count && lengths[index].isCalculated) {
                IJSVGUnitLength* scaled = [lengths[index] lengthByScalingAbsoluteUnits:scale];
                value = [self resolveCSSLength:scaled percentage:diagonal node:owner];
            } else if (index >= lengths.count || lengths[index].type != IJSVGUnitLengthTypePercentage) {
                value = value == 0.f ? 0.f : value * scale;
            }
            values[index] = value;
        }
        if (offset.isCalculated) {
            paint.lineDashPhase = [self resolveCSSLength:[offset lengthByScalingAbsoluteUnits:scale] percentage:diagonal node:offsetOwner];
        } else if (offset.type != IJSVGUnitLengthTypePercentage && paint.lineDashPhase != 0.f) {
            paint.lineDashPhase *= scale;
        }
    }
    paint.lineDashData = pattern;
    paint.nonScalingStroke = style->vectorEffect == IJSVGVectorEffectNonScalingStroke;
    if (paint.nonScalingStroke) {
        _containsNonScalingStrokes = YES;
        CGAffineTransform hostTransform = _textTransform;
        if (_textBuildRoot != nil) {
            // The callers CTM includes Retina/export resolution, which must
            // still scale CSS pixels. Only SVG transforms affect this outline.
            hostTransform = CGAffineTransformConcat(hostTransform, CGAffineTransformInvert(_textRenderTransform));
        }
        hostTransform.tx = 0.f;
        hostTransform.ty = 0.f;
        paint.strokeHostTransform = hostTransform;
    }
    IJSVGQuartzExpandStrokeBounds(paint);

    // Reuse source geometry metadata when resolution preserves its subpaths.
    switch (node.primitiveType) {
        case kIJSVGPrimitivePathTypePath:
        case kIJSVGPrimitivePathTypePolygon:
        case kIJSVGPrimitivePathTypePolyLine:
            if (node.pathUnits != IJSVGUnitObjectBoundingBox) {
                paint.hasPointSubpaths = node.hasPointSubpaths;
            }
            break;
        case kIJSVGPrimitivePathTypeLine:
            paint.hasPointSubpaths = resolvedPathBounds.size.width == 0.f && resolvedPathBounds.size.height == 0.f;
            break;
        default:
            paint.hasPointSubpaths = NO;
            break;
    }

    return paint;
}

- (IJSVGTextFontResolver*)lengthFontResolver
{
    if (_lengthFontResolver == nil) {
        _lengthFontResolver = [[IJSVGTextFontResolver alloc] initWithRenderingOptions:_renderingOptions];
    }
    return _lengthFontResolver;
}

- (CGFloat)resolveStrokeWidthForNode:(IJSVGGraphicsNode*)node percentage:(CGFloat)percentage
{
    return [self resolveStrokeWidth:node.strokeWidth forNode:node percentage:percentage];
}

- (CGFloat)resolveStrokeWidth:(IJSVGUnitLength*)length forNode:(IJSVGGraphicsNode*)node percentage:(CGFloat)percentage
{
    if (_style.lineWidth != IJSVGInheritedFloatValue) {
        return _style.lineWidth;
    }
    if (length.usesFontMetrics) {
        // Inherited stroke widths retain the font metrics of the declaring element.
        while (node.styleParent != nil && node.styleParent.strokeWidth == length) {
            node = (IJSVGGraphicsNode*)node.styleParent;
        }
    }
    return [self resolveCSSLength:length percentage:percentage node:node];
}

- (CGFloat)resolveCSSLength:(IJSVGUnitLength*)length percentage:(CGFloat)percentage node:(IJSVGGraphicsNode*)node
{
    if (!length.usesFontMetrics) {
        return [length computeValue:percentage];
    }
    return [self.lengthFontResolver resolveCSSLength:length percentage:percentage node:node];
}

- (CGFloat)resolveLength:(IJSVGUnitLength*)length percentage:(CGFloat)percentage node:(IJSVGGraphicsNode*)node
{
    if (!length.usesFontMetrics) {
        return [length computeValue:percentage];
    }
    return [self.lengthFontResolver resolveLength:length percentage:percentage node:node];
}

- (IJSVGPaint*)drawablePaintForSymbolNode:(IJSVGSymbol*)node
{
    CGRect bounds = [self unitResolutionBoundsForNode:node];
    CGSize size = CGSizeMake([self resolveLength:node.width percentage:bounds.size.width node:node.width == node.parentNode.width ? node.parentNode : node], [self resolveLength:node.height percentage:bounds.size.height node:node.height == node.parentNode.height ? node.parentNode : node]);
    CGRect viewport = (CGRect) { CGPointZero, size };
    CGRect viewBox = node.viewBox == nil ? viewport : [node.viewBox computeValue:size];
    if (!IJSVGRectIsFinite(viewport) || CGRectIsEmpty(viewport) || !IJSVGRectIsFinite(viewBox) || CGRectIsEmpty(viewBox)) {
        return nil;
    }

    CGAffineTransform mapping = IJSVGViewBoxComputeTransform(viewBox, viewport, node.viewBoxAlignment, node.viewBoxMeetOrSlice);
    CGPoint reference = CGPointMake([self resolveLength:node.refX percentage:viewBox.size.width node:node], [self resolveLength:node.refY percentage:viewBox.size.height node:node]);
    reference = CGPointApplyAffineTransform(reference, mapping);

    // An absent reference leaves the viewport edge at the symbol position.
    CGAffineTransform placement = CGAffineTransformMakeTranslation(node.refX == nil ? 0 : -reference.x, node.refY == nil ? 0 : -reference.y);
    CGAffineTransform previous = _textTransform;
    _textTransform = CGAffineTransformConcat(CGAffineTransformConcat(mapping, placement), previous);
    __block NSArray<IJSVGPaint*>* children = nil;
    @try {
        [self withViewPort:viewBox
                unitBounds:viewBox
                   handler:^{
                       children = [self drawablePaintsForNodes:node.children];
                       if ([self hasSymbolContentEffects:node]) {
                           // User space effects share the children coordinates, before
                           // viewBox mapping.
                           IJSVGPaint* effects = [self drawablePaintForGroupNode:node children:children];
                           effects = [self applyEffectsToPaint:effects fromNode:node];
                           children = @[ effects ];
                       }
                   }];
    } @finally {
        _textTransform = previous;
    }

    // Avoid allocating and drawing a transform container for an identity viewBox.
    if (!CGAffineTransformIsIdentity(mapping)) {
        IJSVGTransformPaint* mapped = IJSVGTransformPaint.paint;
        mapped.affineTransform = mapping;
        mapped.children = children;
        children = @[ mapped ];
    }
    IJSVGGroupPaint* content = IJSVGGroupPaint.paint;
    content.children = children;
    content.boundingBox = [IJSVGPaint calculateBoundingBoxForChildren:content.children];
    content.outerBoundingBox = [IJSVGPaint calculateFrameForChildren:content.children];
    if (node.overflowVisibility != IJSVGOverflowVisibilityVisible) {
        CGPathRef clip = CGPathCreateWithRect(viewport, NULL);
        content.clipPath = clip;
        CGPathRelease(clip);
        content.outerBoundingBox = CGRectIntersection(content.outerBoundingBox, viewport);
    }

    // Reference offsets keep a transform paint for parent bounds calculations.
    if (CGAffineTransformIsIdentity(placement)) {
        return content;
    }
    IJSVGTransformPaint* paint = IJSVGTransformPaint.paint;
    paint.affineTransform = placement;
    paint.children = @[ content ];
    return paint;
}

- (IJSVGPaint*)drawablePaintForRootNode:(IJSVGRootNode*)node
{
    IJSVGRootPaint* paint = IJSVGRootPaint.paint;
    IJSVGUnitRect* resolvedViewBox = [self.lengthFontResolver rectByResolvingFontLengths:node.viewBox node:node];
    paint.viewBox = resolvedViewBox;
    paint.backgroundColor = node.backgroundColor;
    paint.intrinsicSize = node.intrinsicSize;
    paint.viewBoxAlignment = node.viewBoxAlignment;
    paint.viewBoxMeetOrSlice = node.viewBoxMeetOrSlice;

    CGRect bounds = [self unitResolutionBoundsForNode:node];
    CGFloat boundsWidth = CGRectGetWidth(bounds);
    CGFloat boundsHeight = CGRectGetHeight(bounds);
    CGSize intrinsicSize = [self.lengthFontResolver resolveSize:node.intrinsicSize percentage:bounds.size node:node];
    IJSVGUnitLength* widthUnit = [self unit:node.width matchingNode:node];
    IJSVGUnitLength* heightUnit = [self unit:node.height matchingNode:node];
    CGFloat width = [self resolveLength:widthUnit percentage:boundsWidth node:node];
    CGFloat height = [self resolveLength:heightUnit percentage:boundsHeight node:node];
    if (node.parentNode != nil) {
        if (widthUnit == nil || widthUnit.value < 0.f) {
            width = boundsWidth;
        }
        if (heightUnit == nil || heightUnit.value < 0.f) {
            height = boundsHeight;
        }
    } else {
        if (width == 0.f) {
            width = intrinsicSize.width;
        }
        if (height == 0.f) {
            height = intrinsicSize.height;
        }
    }
    CGRect frame = CGRectMake([self resolveLength:[self unit:node.x matchingNode:node] percentage:boundsWidth node:node], [self resolveLength:[self unit:node.y matchingNode:node] percentage:boundsHeight node:node], width, height);
    paint.frame = frame;
    if (node.parentNode != nil) {
        paint.intrinsicSize = [IJSVGUnitSize sizeWithCGSize:frame.size];
    }

    // Resolve child sizes using the viewBox.
    // The root applies the final scale when drawing so children must not be
    // scaled twice.
    CGRect childBounds = (CGRect) { .origin = CGPointZero, .size = paint.frame.size };
    if (node.viewBox != nil) {
        childBounds = [resolvedViewBox computeValue:paint.frame.size];
    }

    CGAffineTransform previous = _textTransform;
    if (node.viewBox != nil) {
        CGSize size = node == _textBuildRoot ? _textRenderFrameSize : frame.size;
        CGRect viewBox = [resolvedViewBox computeValue:size];
        CGAffineTransform transform = IJSVGViewBoxComputeTransform(viewBox, (CGRect) { CGPointZero, size }, node.viewBoxAlignment, node.viewBoxMeetOrSlice);
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
    return [self drawablePaintForGroupNode:node children:paints];
}

- (IJSVGPaint*)drawablePaintForGroupNode:(IJSVGGraphicsNode*)node children:(NSArray<IJSVGPaint*>*)children
{
    IJSVGGroupPaint* paint = (node.nodeTraits & IJSVGNodeTypeTraitMask) != 0 ? IJSVGMaskPaint.paint : IJSVGGroupPaint.paint;

    // Keep objectBoundingBox units independent of stroke coverage, including
    // when export introduces a group around a filtered, stroked shape.
    paint.boundingBox = [IJSVGPaint calculateBoundingBoxForChildren:children];
    paint.outerBoundingBox = [IJSVGPaint calculateFrameForChildren:children];
    paint.children = children;
    return paint;
}

- (void)appendDrawablePaintsForNodes:(NSArray<IJSVGNode*>*)nodes toArray:(NSMutableArray<IJSVGPaint*>*)paints
{
    for (IJSVGNode* node in nodes) {
        if ([node isMemberOfClass:IJSVGGroup.class] && [node.name isEqualToString:@"g"] && [self canOmitContainerPaint:(IJSVGGroup*)node]) {
            [self appendDrawablePaintsForNodes:((IJSVGGroup*)node).children toArray:paints];
            continue;
        }
        IJSVGPaint* paint = [self drawablePaintForNode:node];
        if (paint != nil) {
            [paints addObject:paint];
        }
    }
}

- (NSArray<IJSVGPaint*>*)drawablePaintsForNodes:(NSArray<IJSVGNode*>*)nodes
{
    NSMutableArray<IJSVGPaint*>* paints = [[NSMutableArray alloc] initWithCapacity:nodes.count];
    [self appendDrawablePaintsForNodes:nodes toArray:paints];
    return paints;
}

#pragma mark Gradients and Patterns

- (IJSVGGradientPaint*)drawableBasicGradientPaintForPaint:(IJSVGPaint*)paint gradient:(IJSVGGradient*)gradient
{
    // Create the gradient fill.
    IJSVGGradientPaint* gradientPaint = IJSVGGradientPaint.paint;
    gradientPaint.backingScaleFactor = _backingScale;

    // Copy the gradient so style changes leave the original unchanged.
    IJSVGColorUsageTraits traits = IJSVGColorUsageTraitGradientStop;
    if (_style.colors.replacedColorCount != 0 && [_style.colors matchesReplacementTraits:traits] == YES) {
        gradient = gradient.copy;
        NSMutableArray* colors = nil;
        colors = [NSMutableArray.alloc initWithCapacity:gradient.numberOfStops];
        for (id colorObject in gradient.colors) {
            CGColorRef color = (__bridge CGColorRef)colorObject;
            CGColorRef repColor = [self colorForColor:color matchingTraits:traits];
            CGColorRef compColor = repColor ?: color;
            [colors addObject:(__bridge id)compColor];
        }
        gradient.colors = colors;
    }

    gradientPaint.gradient = [self gradientByResolvingFontLengths:gradient];
    gradientPaint.frame = paint.bounds;
    gradientPaint.viewBox = self.viewPort;
    gradientPaint.opacity = paint.opacity;

    return gradientPaint;
}

- (IJSVGPaint*)drawableGradientPaintForPathNode:(IJSVGPath*)node gradient:(IJSVGGradient*)gradient paint:(IJSVGPaint*)paint
{
    // Create the gradient fill.
    IJSVGGradientPaint* gradientPaint = [self drawableBasicGradientPaintForPaint:paint gradient:gradient];

    // Clip the fill to the shape in its local coordinates.
    gradientPaint.clipRule = paint.fillRule;
    gradientPaint.clipPath = ((IJSVGShapePaint*)paint).path;
    return gradientPaint;
}

- (IJSVGPatternPaint*)drawableBasicPatternPaintForPaint:(IJSVGPaint*)paint pattern:(IJSVGPattern*)pattern
{
    if ([self hasFontRelativeRegion:pattern]) {
        pattern = pattern.copy;
        [self resolveRegionFontLengths:pattern];
    }

    // Create the pattern fill.
    IJSVGPatternPaint* patternPaint = IJSVGPatternPaint.paint;
    patternPaint.patternNode = pattern;
    patternPaint.frame = (CGRect) { .origin = CGPointZero, .size = paint.outerBoundingBox.size };

    CGRect unitBounds = pattern.contentUnits == IJSVGUnitUserSpaceOnUse ? self.viewPort : paint.boundingBox;
    NSArray<NSValue*>* contextBounds = [_contextPatternBounds objectForKey:pattern];
    CGRect viewport = self.viewPort;
    if (contextBounds != nil) {
        viewport = IJSVGRectFromValue(contextBounds[1]);
        unitBounds = pattern.contentUnits == IJSVGUnitObjectBoundingBox ? IJSVGRectFromValue(contextBounds[0]) : viewport;
    }
    patternPaint.viewPort = viewport;

    // Placement belongs to the tile, never to the artwork inside that tile.
    pattern = [pattern copy];
    pattern.transforms = @[];
    pattern.x = IJSVGZeroUnitLength;
    pattern.y = IJSVGZeroUnitLength;
    if (pattern.viewBox != nil && !pattern.viewBox.isZeroRect) {
        unitBounds = [pattern.viewBox computeValue:paint.boundingBox.size];
        viewport = unitBounds;
        pattern.contentUnits = IJSVGUnitUserSpaceOnUse;
    }
    __block IJSVGPaint* patternFill = nil;
    [self withViewPort:viewport
            unitBounds:unitBounds
               handler:^{
                   patternFill = [self drawablePaintForNode:pattern];
               }];
    patternFill.referencingPaint = patternPaint;
    patternPaint.pattern = patternFill;
    patternPaint.opacity = paint.opacity;

    return patternPaint;
}

- (IJSVGPaint*)drawablePatternPaintForPathNode:(IJSVGPath*)node pattern:(IJSVGPattern*)pattern paint:(IJSVGPaint*)paint
{
    // Create the pattern fill.
    IJSVGPatternPaint* patternPaint = [self drawableBasicPatternPaintForPaint:paint pattern:pattern];

    // Clip the fill to the shape in its local coordinates.
    patternPaint.clipRule = paint.fillRule;
    patternPaint.clipPath = ((IJSVGShapePaint*)paint).path;

    return patternPaint;
}

- (IJSVGPaint*)maskPaintFromNode:(IJSVGMask*)mask referencingPaint:(IJSVGPaint*)paint fromPaint:(IJSVGPaint*)fromPaint

{
    IJSVGMask* maskNode = mask;
    __block IJSVGPaint* maskPaint = nil;
    CGRect viewPort = maskNode.units == IJSVGUnitUserSpaceOnUse ? self.viewPort : paint.boundingBox;
    CGRect contentBounds = maskNode.contentUnits == IJSVGUnitUserSpaceOnUse ? self.viewPort : paint.boundingBox;
    if (fromPaint == nil) {
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
    if (maskNode.units == IJSVGUnitObjectBoundingBox) {
        xUnit = [[self.lengthFontResolver unitByResolvingFontLength:xUnit node:maskNode] lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        yUnit = [[self.lengthFontResolver unitByResolvingFontLength:yUnit node:maskNode] lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        widthUnit = [[self.lengthFontResolver unitByResolvingFontLength:widthUnit node:maskNode] lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        heightUnit = [[self.lengthFontResolver unitByResolvingFontLength:heightUnit node:maskNode] lengthWithUnitType:IJSVGUnitLengthTypePercentage];
    }

    // Calculate the mask clip rectangle.
    rect.origin.x = [self resolveLength:xUnit percentage:width node:maskNode];
    rect.origin.y = [self resolveLength:yUnit percentage:height node:maskNode];
    rect.size.width = [self resolveLength:widthUnit percentage:width node:maskNode];
    rect.size.height = [self resolveLength:heightUnit percentage:height node:maskNode];

    // Find the bounds where the mask will be drawn.
    CGRect paintBounds = paint.innerBoundingBox;
    CGRect maskBounds = maskPaint.outerBoundingBox;
    CGRect maskingBounds = paintBounds;
    rect.origin.x += paintBounds.origin.x;
    rect.origin.y += paintBounds.origin.y;

    maskingBounds.size.width = maskBounds.size.width;
    maskingBounds.size.height = maskBounds.size.height;

    CGAffineTransform userSpaceTransform = [IJSVGPaint userSpaceTransformForPaint:paint];
    if (maskNode.contentUnits == IJSVGUnitUserSpaceOnUse) {
        maskingBounds.origin.x += maskBounds.origin.x;
        maskingBounds.origin.y += maskBounds.origin.y;
        maskingBounds = CGRectApplyAffineTransform(maskingBounds, userSpaceTransform);
    }

    if (maskNode.units == IJSVGUnitUserSpaceOnUse) {
        rect = CGRectApplyAffineTransform(rect, userSpaceTransform);
    }

    // Filters can paint outside the geometry used for mask units and placement.
    CGRect sourceBounds = [self filterCoverageBoundsForPaint:maskPaint];
    maskPaint.maskingSourceBounds = IJSVGRectIsFinite(sourceBounds) ? CGRectUnion(maskPaint.outerBoundingBox, sourceBounds) : maskPaint.outerBoundingBox;
    maskPaint.maskingBoundingBox = maskingBounds;
    maskPaint.maskingClippingRect = rect;
    maskPaint.referencingPaint = paint;
    [maskPaint prepareMaskCaching];
    return maskPaint;
}

- (NSArray<IJSVGPaint*>*)clipPaintsFromNode:(IJSVGClipPath*)node referencingPaint:(IJSVGPaint*)paint fromPaint:(IJSVGPaint*)fromPaint
{
    NSMutableArray<IJSVGPaint*>* paints = nil;
    paints = [[NSMutableArray alloc] init];
    IJSVGClipPath* refClipPath = node;
    __block IJSVGGroupPaint* groupPaint = nil;
    CGRect contentBounds = node.contentUnits == IJSVGUnitUserSpaceOnUse ? self.viewPort : paint.boundingBox;
    while (refClipPath != nil) {
        [self withUnitBounds:contentBounds
                     handler:^{
                         groupPaint = (IJSVGGroupPaint*)[self drawablePaintForNode:refClipPath];
                     }];
        if (groupPaint != nil) {
            groupPaint.referencingPaint = paint;
            [paints addObject:groupPaint];
        }
        refClipPath = refClipPath.clipPath;
    }
    CGRect clippingRect = [IJSVGPaint calculateFrameForChildren:paints];
    CGAffineTransform userSpaceTransform = [IJSVGPaint userSpaceTransformForPaint:paint];
    CGAffineTransform clippingTransform = CGAffineTransformIdentity;
    if (node.contentUnits == IJSVGUnitUserSpaceOnUse) {
        clippingRect = CGRectApplyAffineTransform(clippingRect, userSpaceTransform);
        clippingTransform = userSpaceTransform;
    }
    CGAffineTransform ident = CGAffineTransformMakeTranslation(-CGRectGetMinX(clippingRect), -CGRectGetMinY(clippingRect));
    clippingTransform = CGAffineTransformConcat(clippingTransform, ident);
    paint.clippingTransform = clippingTransform;
    paint.clippingBoundingBox = clippingRect;
    return paints;
}

// Collect paths from this group and any groups inside it.
- (void)recursivelyAddResolvedPathsForNodes:(NSArray<IJSVGNode*>*)nodes transform:(CGAffineTransform)transform toPath:(CGMutablePathRef)mutPath
{
    for (IJSVGNode* node in nodes) {
        if ((node.nodeTraits & IJSVGNodeTypeTraitText) != 0) {
            IJSVGTextLayout* layout = [self textLayoutForNode:(IJSVGText*)node];
            [self recursivelyAddResolvedPathsForNodes:layout.group.children transform:transform toPath:mutPath];
            continue;
        }
        if ((node.nodeTraits & IJSVGNodeTypeTraitPath) != 0 && [node matchesTraits:IJSVGNodeTraitPathed] == YES) {
            [self appendResolvedPathForPathNode:(IJSVGPath*)node transform:transform toPath:mutPath];
            continue;
        }
        if ((node.nodeTraits & IJSVGNodeTypeTraitGroup) != 0) {
            [self recursivelyAddResolvedPathsForNodes:((IJSVGGroup*)node).children transform:transform toPath:mutPath];
        }
    }
}

// Single explicit paths need no recursive geometry resolution. Identical
// geometry and placement can share the finished path, including across <use>.
- (CGPathRef)newSharedClipPathForNode:(IJSVGClipPath*)clip transform:(CGAffineTransform)transform
{
    if (clip.clipPath != nil || clip.children.count != 1) {
        return NULL;
    }
    IJSVGNode* child = clip.children.firstObject;

    // <use> introduces group wrappers around its referenced path. Their
    // transforms are already resolved into geometry by the parser.
    while ((child.nodeTraits & IJSVGNodeTypeTraitGroup) != 0 && (child.nodeTraits & IJSVGNodeTypeTraitText) == 0 && ((IJSVGGroup*)child).children.count == 1) {
        child = ((IJSVGGroup*)child).children.firstObject;
    }
    if ((child.nodeTraits & IJSVGNodeTypeTraitPath) == 0) {
        return NULL;
    }
    IJSVGPath* node = (IJSVGPath*)child;
    if (![node matchesTraits:IJSVGNodeTraitPathed] || (node.primitiveType != kIJSVGPrimitivePathTypePath && node.primitiveType != kIJSVGPrimitivePathTypePolygon && node.primitiveType != kIJSVGPrimitivePathTypePolyLine)) {
        return NULL;
    }
    if (node.pathUnits == IJSVGUnitObjectBoundingBox) {
        CGRect bounds = [self unitResolutionBoundsForNode:node];
        transform = CGAffineTransformConcat(CGAffineTransformMakeScale(bounds.size.width, bounds.size.height), transform);
    }
    for (IJSVGQuartzClipPath* cached in _sharedClipPaths) {
        if (CGAffineTransformEqualToTransform(cached.transform, transform) && CGPathEqualToPath(cached.source, node.path)) {
            return CGPathRetain(cached.path);
        }
    }
    CGPathRef path = CGPathCreateCopyByTransformingPath(node.path, &transform);

    // Bound comparisons and retained snapshots for documents with many unique
    // clips.
    if (path != NULL && _sharedClipPaths.count < 64) {
        IJSVGQuartzClipPath* cached = [[IJSVGQuartzClipPath alloc] init];
        cached.source = CGPathCreateCopy(node.path);
        cached.path = CGPathRetain(path);
        cached.transform = transform;
        [_sharedClipPaths addObject:cached];
    }
    return path;
}

// Combine the clip shapes in the same coordinate space as the paint.
- (CGPathRef)newClipPathFromNode:(IJSVGClipPath*)node fromPaint:(IJSVGPaint*)paint
{
    if (node.hasBasicShape) {
        CGAffineTransform transform = [IJSVGPaint userSpaceTransformForPaint:paint];
        CGRect fillBox = CGRectApplyAffineTransform(paint.boundingBox, transform);
        CGRect strokeBox = CGRectApplyAffineTransform(paint.outerBoundingBox, transform);
        CGRect viewBox = CGRectApplyAffineTransform(self.viewPort, transform);
        return [node newBasicShapePathWithFillBox:fillBox
                                        strokeBox:strokeBox
                                          viewBox:viewBox
                                   lengthResolver:^CGFloat(IJSVGUnitLength* length, CGFloat percentage) {
                                       return [self resolveCSSLength:length percentage:percentage node:paint.sourceNode];
                                   }];
    }
    CGAffineTransform transform = CGAffineTransformIdentity;
    if (node.contentUnits == IJSVGUnitUserSpaceOnUse) {
        transform = [IJSVGPaint userSpaceTransformForPaint:paint];
    } else {
        transform = CGAffineTransformMakeTranslation(paint.boundingBox.origin.x - paint.outerBoundingBox.origin.x, paint.boundingBox.origin.y - paint.outerBoundingBox.origin.y);
    }
    CGRect paintRect = paint.innerBoundingBox;
    CGAffineTransform paintTransform = CGAffineTransformMakeTranslation(CGRectGetMinX(paintRect), CGRectGetMinY(paintRect));
    transform = CGAffineTransformConcat(transform, paintTransform);
    CGRect contentBounds = node.contentUnits == IJSVGUnitUserSpaceOnUse ? self.viewPort : paint.boundingBox;
    __block CGPathRef sharedPath = NULL;
    [self withUnitBounds:contentBounds
                 handler:^{
                     sharedPath = [self newSharedClipPathForNode:node transform:transform];
                 }];
    if (sharedPath != NULL) {
        return sharedPath;
    }
    CGMutablePathRef mPath = CGPathCreateMutable();
    IJSVGClipPath* clipPath = node;
    while (clipPath != nil) {
        [self withUnitBounds:contentBounds
                     handler:^{
                         [self recursivelyAddResolvedPathsForNodes:clipPath.children transform:transform toPath:mPath];
                     }];
        clipPath = clipPath.clipPath;
    }
    return mPath;
}

// Draw a solid color, gradient or pattern while preserving the context
// settings.
- (void)drawPaint:(IJSVGNode*)paint boundingBox:(CGRect)boundingBox viewPort:(CGRect)viewPort region:(CGRect)region inContext:(CGContextRef)context
{
    CGContextSaveGState(context);
    if ((paint.nodeTraits & IJSVGNodeTypeTraitColor) != 0) {
        CGColorRef color = ((IJSVGColorNode*)paint).color;
        if (color != nil) {
            CGContextSetFillColorWithColor(context, color);
            CGContextFillRect(context, region);
        }
    } else if ((paint.nodeTraits & IJSVGNodeTypeTraitGradient) != 0) {
        IJSVGGradient* gradient = [self gradientByResolvingFontLengths:(IJSVGGradient*)paint];
        if (gradient.units == IJSVGUnitObjectBoundingBox) {
            CGContextTranslateCTM(context, boundingBox.origin.x, boundingBox.origin.y);
        }
        [gradient drawInContextRef:context bounds:gradient.units == IJSVGUnitObjectBoundingBox ? boundingBox : viewPort transform:CGAffineTransformIdentity];
    } else if ((paint.nodeTraits & IJSVGNodeTypeTraitPattern) != 0) {
        IJSVGGroupPaint* reference = IJSVGGroupPaint.paint;
        reference.boundingBox = boundingBox;
        reference.outerBoundingBox = boundingBox;
        reference.frame = boundingBox;
        [self withViewPort:viewPort
                unitBounds:boundingBox
                   handler:^{
                       IJSVGPatternPaint* pattern = [self drawableBasicPatternPaintForPaint:reference pattern:(IJSVGPattern*)paint];
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

- (IJSVGPaint*)applyFilter:(IJSVGFilter*)filter toPaint:(IJSVGPaint*)paint fromNode:(IJSVGGraphicsNode*)node
{
    if (filter == nil) {
        return paint;
    }
    _buildHasFilters = YES;

    if (filter.usesSourceRegion) {
        CGRect region = [self artworkBoundsForPaint:paint];
        region = CGRectOffset(region, paint.frame.origin.x, paint.frame.origin.y);
        if (CGRectIsNull(region) || CGRectIsInfinite(region) || CGRectIsEmpty(region)) {
            return paint;
        }
        filter = filter.copy;
        filter.usesSourceRegion = NO;
        if (filter.cssBlurRadius != nil) {
            CGFloat radius = [self resolveCSSLength:filter.cssBlurRadius percentage:0 node:node];
            CGFloat dx = filter.cssShadowX != nil ? [self resolveCSSLength:filter.cssShadowX percentage:0 node:node] : 0;
            CGFloat dy = filter.cssShadowY != nil ? [self resolveCSSLength:filter.cssShadowY percentage:0 node:node] : 0;
            if (!isfinite(radius) || !isfinite(dx) || !isfinite(dy)) {
                return paint;
            }
            radius = MAX(0, radius);
            if (radius == 0 && filter.cssShadowX == nil) {
                return paint;
            }
            IJSVGFilterPrimitive* primitive = filter.primitives.firstObject;
            NSMutableDictionary* parameters = primitive.parameters.mutableCopy;
            parameters[IJSVGAttributeStdDeviation] = @(radius).stringValue;
            if (filter.cssShadowX != nil) {
                parameters[IJSVGAttributeDX] = @(dx).stringValue;
                parameters[IJSVGAttributeDY] = @(dy).stringValue;
                if ([parameters[IJSVGAttributeFloodColor] caseInsensitiveCompare:IJSVGColorCurrentColorName] == NSOrderedSame) {
                    parameters[IJSVGAttributeFloodColor] = [IJSVGColor colorStringFromColor:[node resolvedPaintStyle].currentColor ?: IJSVGColor.blackColor];
                }
            }
            primitive.parameters = parameters;

            // Include the visible Gaussian tail and translated shadow without clipping the source.
            CGRect expanded = CGRectInset(region, -ceil(radius * 3), -ceil(radius * 3));
            region = filter.cssShadowX != nil ? CGRectUnion(region, CGRectOffset(expanded, dx, dy)) : expanded;
            filter.cssBlurRadius = nil;
            filter.cssShadowX = nil;
            filter.cssShadowY = nil;
        }
        filter.units = IJSVGUnitUserSpaceOnUse;
        filter.x = [IJSVGUnitLength unitWithFloat:region.origin.x];
        filter.y = [IJSVGUnitLength unitWithFloat:region.origin.y];
        filter.width = [IJSVGUnitLength unitWithFloat:region.size.width];
        filter.height = [IJSVGUnitLength unitWithFloat:region.size.height];
    }

    BOOL relative = [self hasFontRelativeRegion:filter];
    for (IJSVGFilterPrimitive* primitive in filter.primitives) {
        relative |= [self hasFontRelativeRegion:primitive];
    }
    if (relative) {
        filter = filter.copy;
        [self resolveRegionFontLengths:filter];
        for (IJSVGFilterPrimitive* primitive in filter.primitives) {
            [self resolveRegionFontLengths:primitive];
        }
    }

    if ((paint.paintTraits & IJSVGPaintTraitRoot) != 0) {
        // Filter root contents in viewBox coordinates.
        // Apply root opacity and clipping afterward.
        IJSVGRootPaint* rootPaint = (IJSVGRootPaint*)paint;
        IJSVGGroupPaint* source = IJSVGGroupPaint.paint;
        source.children = rootPaint.children;
        rootPaint.children = @[];
        source.boundingBox = [IJSVGPaint calculateBoundingBoxForChildren:source.children];
        source.outerBoundingBox = [IJSVGPaint calculateFrameForChildren:source.children];
        CGRect viewPort = rootPaint.viewBox != nil ? [rootPaint.viewBox computeValue:rootPaint.frame.size] : rootPaint.bounds;
        IJSVGFilterPaint* filtered = [IJSVGFilterPaint.alloc initWithSourcePaint:source filter:filter viewPort:viewPort];
        filtered.renderingOptions = _renderingOptions;
        filtered.sourceNode = node;
        filtered.cachesRenderedOutput = YES;
        _buildMayRequireBackdrop |= filtered.usesBackground;
        [rootPaint addChild:filtered];
        return rootPaint;
    }

    IJSVGFilterPaint* filtered = [IJSVGFilterPaint.alloc initWithSourcePaint:paint filter:filter viewPort:self.viewPort];
    filtered.renderingOptions = _renderingOptions;
    filtered.sourceNode = node;
    filtered.cachesRenderedOutput = YES;
    _buildMayRequireBackdrop |= filtered.usesBackground;
    return filtered;
}

#pragma mark Defaults

- (void)applyDefaultsToPaint:(IJSVGPaint*)paint fromNode:(IJSVGGraphicsNode*)node style:(const IJSVGResolvedPaintStyle*)style
{
    paint.sourceNode = node;
    paint.shapeRendering = (node.nodeTraits & IJSVGNodeTypeTraitPath) != 0 ? node.resolvedShapeRendering : IJSVGShapeRenderingUnspecified;
    paint.imageRendering = node.type == IJSVGNodeTypeImage ? node.resolvedImageRendering : IJSVGImageRenderingUnspecified;
    paint.viewPort = self.viewPort;
    paint.isolated = node.isolated;

    // Apply the mask.
    if (node.mask != nil) {
        paint.maskPaint = [self maskPaintFromNode:node.mask referencingPaint:paint fromPaint:nil];
    }

    // Apply the clip path.
    if (node.clipPath != nil) {
        IJSVGClipPath* clipPath = node.clipPath;
        CGPathRef path = [self newClipPathFromNode:clipPath fromPaint:paint];

        IJSVGWindingRule clipRule = node.clipRule;
        if (clipRule == IJSVGWindingRuleInherit) {
            clipRule = clipPath.computedClipRule;
        }

        paint.clipPath = path;
        paint.clipRule = clipRule;
        CGPathRelease(path);
    }

    // Set the opacity.
    CGFloat opacity = style != NULL ? style->opacity : node.opacity.value;
    if (opacity != 1.f) {
        paint.opacity = opacity;
    }

    // Set the blend mode.
    if (node.blendMode != IJSVGBlendModeNormal) {
        paint.blendingMode = (CGBlendMode)node.blendMode;
    }

    // Hide the paint when needed.
    // Visibility is inherited but descendants may override it. Keep containers
    // and geometry so hidden content still contributes to layout and bounds.
    BOOL hiddenGraphic = ((node.nodeTraits & IJSVGNodeTypeTraitPath) != 0 || (node.nodeTraits & IJSVGNodeTypeTraitImage) != 0) && (style != NULL ? style->visibility == IJSVGVisibilityHidden : node.visibilityHidden);
    paint.hiddenByVisibility = node.shouldRender && hiddenGraphic;
    if (node.shouldRender == NO || hiddenGraphic) {
        paint.hidden = YES;
    }
}

#pragma mark Transforms

- (IJSVGPaint*)applyTransforms:(NSArray<IJSVGTransform*>*)transforms toPaint:(IJSVGPaint*)paint fromNode:(IJSVGGraphicsNode*)node

{
    // Read the node position.
    CGRect unitBounds = [self unitResolutionBoundsForNode:node];
    CGFloat unitWidth = CGRectGetWidth(unitBounds);
    CGFloat unitHeight = CGRectGetHeight(unitBounds);
    CGFloat x = 0.f;
    CGFloat y = 0.f;

    BOOL shouldApplyImplicitOrigin = paint.treatImplicitOriginAsTransform == YES;
    if (shouldApplyImplicitOrigin == YES) {
        x = [self resolveLength:[self unit:node.x matchingNode:node] percentage:unitWidth node:node];
        y = [self resolveLength:[self unit:node.y matchingNode:node] percentage:unitHeight node:node];
    }

    // Skip the wrapper when the position and transform are unchanged.
    if (transforms.count == 0 && x == 0.f && y == 0.f) {
        return paint;
    }

    // Combine the transforms.
    CGAffineTransform identity = CGAffineTransformIdentity;
    if (x != 0.f || y != 0.f) {
        identity = CGAffineTransformTranslate(identity, x, y);
    }

    IJSVGGraphicsNode* referencingNode = nil;
    IJSVGUnitType contentUnits = [self contentUnitsForNode:node.parentNode referencingNode:&referencingNode];

    // Use one wrapper for all transforms to save memory.
    // Keep their original order.
    IJSVGTransformPaint* parentPaint = IJSVGTransformPaint.paint;
    for (IJSVGTransform* transform in transforms.reverseObjectEnumerator) {
        IJSVGTransform* resolvedTransform = [transform transformByApplyingUnits:contentUnits bounds:unitBounds];
        identity = CGAffineTransformConcat(identity, resolvedTransform.CGAffineTransform);
    }
    if (node.transformOrigin.count == 2 || node.transformBox != IJSVGTransformBoxUnspecified) {
        CGRect reference = (CGRect) { .origin = CGPointZero, .size = unitBounds.size };
        switch (node.transformBox) {
            case IJSVGTransformBoxFillBox:
            case IJSVGTransformBoxContentBox:
                reference = paint.boundingBox;
                break;
            case IJSVGTransformBoxStrokeBox:
            case IJSVGTransformBoxBorderBox:
                reference = paint.outerBoundingBox;
                break;
            case IJSVGTransformBoxUnspecified:
            case IJSVGTransformBoxViewBox:
                break;
        }
        if (IJSVGRectIsFinite(reference)) {
            CGPoint origin = reference.origin;
            if (node.transformOrigin.count == 2) {
                origin.x += [self resolveCSSLength:node.transformOrigin[0] percentage:reference.size.width node:node];
                origin.y += [self resolveCSSLength:node.transformOrigin[1] percentage:reference.size.height node:node];
            }

            // The implicit SVG x/y translation belongs inside the transform.
            identity = CGAffineTransformConcat(CGAffineTransformMakeTranslation(-origin.x, -origin.y), identity);
            identity = CGAffineTransformConcat(identity, CGAffineTransformMakeTranslation(origin.x, origin.y));
        }
    }
    parentPaint.affineTransform = identity;
    [parentPaint addChild:paint];
    parentPaint.outerBoundingBox = [IJSVGPaint calculateFrameForChildren:parentPaint.children];
    return parentPaint;
}

#pragma mark Images

- (IJSVGPaint*)drawablePaintForImageNode:(IJSVGImage*)image
{
    CGRect bounds = [self unitResolutionBoundsForNode:image];
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    BOOL autoWidth = image.width == nil || image.width.value < 0.f;
    BOOL autoHeight = image.height == nil || image.height.value < 0.f;
    CGSize intrinsic = image.intrinsicSize;
    IJSVGGraphicsNode* referencingNode = nil;
    BOOL objectUnits = image.parentNode != nil && [self contentUnitsForNode:image.parentNode referencingNode:&referencingNode] == IJSVGUnitObjectBoundingBox;
    CGFloat percentageWidth = objectUnits ? 1.f : width;
    CGFloat percentageHeight = objectUnits ? 1.f : height;
    CGFloat resolvedWidth = autoWidth ? intrinsic.width : [self resolveCSSLength:image.width percentage:percentageWidth node:image];
    CGFloat resolvedHeight = autoHeight ? intrinsic.height : [self resolveCSSLength:image.height percentage:percentageHeight node:image];
    if (autoWidth && !autoHeight && intrinsic.height > 0.f) {
        resolvedWidth = resolvedHeight * intrinsic.width / intrinsic.height;
    } else if (autoHeight && !autoWidth && intrinsic.width > 0.f) {
        resolvedHeight = resolvedWidth * intrinsic.height / intrinsic.width;
    }

    // Keep the resolved viewport on a copy for drawing and export. Explicit
    // zero dimensions must remain zero rather than falling back to the image.
    image = image.copy;
    image.width = [IJSVGUnitLength unitWithFloat:resolvedWidth];
    image.height = [IJSVGUnitLength unitWithFloat:resolvedHeight];
    [self resolveRegionFontLengths:image css:YES];
    CGRect frame = CGRectMake([self resolveLength:[self unit:image.x matchingNode:image] percentage:width node:image], [self resolveLength:[self unit:image.y matchingNode:image] percentage:height node:image], [self resolveLength:[self unit:image.width matchingNode:image] percentage:width node:image], [self resolveLength:[self unit:image.height matchingNode:image] percentage:height node:image]);
    IJSVGImagePaint* paint = [IJSVGImagePaint.alloc initWithImage:image];
    paint.frame = frame;
    return paint;
}

// Keep earlier artwork in a bitmap so filters can read the background.
// Use this for screen drawing and PDF output.
- (BOOL)paintRequiresBackdrop:(IJSVGPaint*)root
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
            if (((IJSVGFilterPaint*)paint).usesBackground) {
                return YES;
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

- (void)renderBackdropPaintInContext:(CGContextRef)ctx frame:(CGRect)frame
{
    // Include the display scale when mapping to pixels.
    // One pixel in the temporary image should match one output pixel.
    CGPoint origin = CGContextConvertPointToDeviceSpace(ctx, CGPointZero);
    CGPoint xAxis = CGContextConvertPointToDeviceSpace(ctx, CGPointMake(1, 0));
    CGPoint yAxis = CGContextConvertPointToDeviceSpace(ctx, CGPointMake(0, 1));
    CGAffineTransform transform = CGAffineTransformMake(xAxis.x - origin.x, xAxis.y - origin.y, yAxis.x - origin.x, yAxis.y - origin.y, origin.x, origin.y);
    CGRect bounds = CGRectIntegral(CGRectApplyAffineTransform(CGRectMake(0, 0, frame.size.width, frame.size.height), transform));
    if (!IJSVGRectIsFinite(bounds) || CGRectIsEmpty(bounds) || transform.a * transform.d - transform.b * transform.c == 0) {
        return;
    }

    // Limit memory use for large print and export sizes.
    // Keep full pixel detail for normal drawing.
    CGFloat scale = MIN(1.f, MIN(4096.f / bounds.size.width, 4096.f / bounds.size.height));
    size_t width = MAX(1, ceil(bounds.size.width * scale));
    size_t height = MAX(1, ceil(bounds.size.height * scale));
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (bitmap == NULL) {
        return;
    }
    CGContextSetInterpolationQuality(bitmap, CGContextGetInterpolationQuality(ctx));
    CGContextScaleCTM(bitmap, width / bounds.size.width, height / bounds.size.height);
    CGContextTranslateCTM(bitmap, -bounds.origin.x, -bounds.origin.y);
    CGContextConcatCTM(bitmap, transform);
    CGImageRef image = NULL;
    @try {
        [IJSVGFilterPaint renderPaint:_rootPaint inBitmapContext:bitmap];
        image = CGBitmapContextCreateImage(bitmap);
    } @finally {
        CGContextRelease(bitmap);
    }
    if (image != NULL) {
        CGContextSaveGState(ctx);
        CGContextConcatCTM(ctx, CGAffineTransformInvert(transform));
        CGContextDrawImage(ctx, bounds, image);
        CGContextRestoreGState(ctx);
        CGImageRelease(image);
    }
}

// Simple vector trees can resize by updating only stroke outlines. Effects and
// resource subtrees keep the full rebuild path because their bounds/caches may
// depend on stroke coverage.
- (BOOL)patternContentIsViewportIndependent:(IJSVGPaint*)root
{
    if (root == nil) {
        return YES;
    }
    NSMutableArray<IJSVGPaint*>* pending = [NSMutableArray arrayWithObject:root];
    NSMutableSet<IJSVGPaint*>* visited = [NSMutableSet set];
    while (pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if ([visited containsObject:paint]) {
            continue;
        }
        [visited addObject:paint];
        if (paint.maskPaint != nil || paint.clipPaints.count != 0 || (paint.paintTraits & IJSVGPaintTraitFilter) != 0 || (paint.sourceNode != nil && !CGRectIsNull(paint.sourceNode.backgroundRect))) {
            return NO;
        }
        if ((paint.paintTraits & IJSVGPaintTraitShape) != 0) {
            IJSVGShapePaint* shape = (IJSVGShapePaint*)paint;
            if (shape.nonScalingStroke || shape.strokeStyle.nonScalingStroke) {
                return NO;
            }
        }
        if ((paint.paintTraits & IJSVGPaintTraitPattern) != 0) {
            IJSVGPaint* content = ((IJSVGPatternPaint*)paint).pattern;
            if (content != nil) {
                [pending addObject:content];
            }
        }
        [pending addObjectsFromArray:paint.children];
    }
    return YES;
}

- (NSArray<IJSVGShapePaint*>*)viewportStrokeShapesForRoot:(IJSVGRootNode*)rootNode
{
    if (!_containsNonScalingStrokes || _containsText || rootNode.transforms.count != 0 || rootNode.viewBox == nil) {
        return nil;
    }
    NSMutableArray<IJSVGShapePaint*>* shapes = [NSMutableArray array];
    NSMutableArray<IJSVGPaint*>* pending = [NSMutableArray arrayWithObject:_rootPaint];
    while (pending.count != 0) {
        IJSVGPaint* paint = pending.lastObject;
        [pending removeLastObject];
        if (paint.maskPaint != nil || paint.clipPaints.count != 0 || (paint.paintTraits & IJSVGPaintTraitFilter) != 0 || ((paint.paintTraits & IJSVGPaintTraitPattern) != 0 && ![self patternContentIsViewportIndependent:((IJSVGPatternPaint*)paint).pattern]) || paint.sourceNode.markerStart != nil || paint.sourceNode.markerMid != nil || paint.sourceNode.markerEnd != nil || (paint.sourceNode != nil && !CGRectIsNull(paint.sourceNode.backgroundRect))) {
            return nil;
        }
        if ((paint.paintTraits & IJSVGPaintTraitShape) != 0) {
            IJSVGShapePaint* shape = (IJSVGShapePaint*)paint;
            if (shape.strokeStyle.nonScalingStroke) {
                [shapes addObject:shape];
            }
        }
        [pending addObjectsFromArray:paint.children];
    }
    return shapes.copy;
}

- (BOOL)updateStrokeViewportFromSize:(CGSize)previousSize toSize:(CGSize)size
{
    if (_viewportStrokeShapes == nil) {
        _viewportStrokeShapes = [self viewportStrokeShapesForRoot:_rootNode];
        if (_viewportStrokeShapes == nil) {
            return NO;
        }
    }
    CGAffineTransform previous = IJSVGViewBoxComputeTransform([[self.lengthFontResolver rectByResolvingFontLengths:_rootNode.viewBox node:_rootNode] computeValue:previousSize], (CGRect) { CGPointZero, previousSize }, _rootNode.viewBoxAlignment, _rootNode.viewBoxMeetOrSlice);
    CGAffineTransform next = IJSVGViewBoxComputeTransform([[self.lengthFontResolver rectByResolvingFontLengths:_rootNode.viewBox node:_rootNode] computeValue:size], (CGRect) { CGPointZero, size }, _rootNode.viewBoxAlignment, _rootNode.viewBoxMeetOrSlice);
    previous.tx = previous.ty = next.tx = next.ty = 0;
    CGFloat determinant = previous.a * previous.d - previous.b * previous.c;
    if (!isfinite(determinant) || determinant == 0) {
        return NO;
    }

    if (_viewportStrokeTransforms == nil) {
        NSMutableData* data = [NSMutableData dataWithLength:_viewportStrokeShapes.count * sizeof(CGAffineTransform)];
        CGAffineTransform* transforms = data.mutableBytes;
        CGAffineTransform inverse = CGAffineTransformInvert(previous);
        for (NSUInteger index = 0; index < _viewportStrokeShapes.count; index++) {
            transforms[index] = CGAffineTransformConcat(_viewportStrokeShapes[index].strokeStyle.strokeHostTransform, inverse);
        }
        _viewportStrokeTransforms = data;
    }

    // Use the original geometry map each time, avoiding cumulative rounding
    // drift during long resize/zoom sessions.
    const CGAffineTransform* transforms = _viewportStrokeTransforms.bytes;
    for (NSUInteger index = 0; index < _viewportStrokeShapes.count; index++) {
        IJSVGShapePaint* shape = _viewportStrokeShapes[index];
        IJSVGShapePaint* stroke = shape.strokeStyle;
        stroke.strokeHostTransform = CGAffineTransformConcat(transforms[index], next);
        if (shape.strokePaint != stroke) {
            CGPathRef outline = [self newCachedPathFromStrokedShapePaint:stroke];
            shape.strokePaint.clipPath = outline;
            CGPathRelease(outline);
        }
    }
    return YES;
}

- (CGRect)measureRegionPaint:(IJSVGPaint*)paint transform:(CGAffineTransform)transform clip:(CGRect)clip outerRoot:(IJSVGRootNode*)outerRoot recordBounds:(BOOL)recordBounds order:(NSMutableArray<IJSVGPaint*>*)order insideAnchor:(BOOL)insideAnchor
{
    if (paint.hidden || paint.opacity <= 0.f) {
        return CGRectNull;
    }
    BOOL collectingLocal = order != nil && !recordBounds;
    IJSVGRegionPaintInfo* info = [_regionPaints objectForKey:paint];

    // Translation preserves the measured bounds of an entire subtree.
    // Other transforms must still measure leaves to avoid enlarged bounds.
    BOOL rootPaint = (paint.paintTraits & IJSVGPaintTraitRoot) != 0;
    BOOL cacheLocal = order == nil && info != nil && CGRectIsInfinite(clip) && transform.a == 1 && transform.b == 0 && transform.c == 0 && transform.d == 1 && (!rootPaint || ((IJSVGRootPaint*)paint).sourceNode != outerRoot);
    if (cacheLocal && info.hasLocalBounds) {
        return CGRectOffset(info.localBounds, transform.tx, transform.ty);
    }
    if (!collectingLocal && paint.clipPath != NULL) {
        clip = CGRectIntersection(clip, CGRectApplyAffineTransform(CGPathGetPathBoundingBox(paint.clipPath), transform));
    }
    CGAffineTransform childrenTransform = transform;
    if (rootPaint) {
        IJSVGRootPaint* root = (IJSVGRootPaint*)paint;
        if (root.sourceNode != outerRoot) {
            CGRect viewport = IJSVGPaintGetBoundingBoxBounds(root);
            if (!collectingLocal && root.sourceNode.overflowVisibility == IJSVGOverflowVisibilityHidden) {
                clip = CGRectIntersection(clip, CGRectApplyAffineTransform(viewport, transform));
            }
            if (root.viewBox != nil) {
                CGRect viewBox = [root.viewBox computeValue:root.frame.size];
                childrenTransform = CGAffineTransformConcat(IJSVGViewBoxComputeTransform(viewBox, viewport, root.viewBoxAlignment, root.viewBoxMeetOrSlice), transform);
            }
        }
    }
    if (CGRectIsEmpty(clip)) {
        return CGRectNull;
    }
    BOOL anchor = info.node.type == IJSVGNodeTypeAnchor;
    if (info != nil && order != nil) {
        info.inactiveAnchor = insideAnchor;
        [order addObject:paint];
    }
    CGRect bounds = CGRectNull;
    for (IJSVGPaint* child in paint.children) {
        CGAffineTransform placement = CGAffineTransformConcat(child.placementTransform, childrenTransform);
        bounds = CGRectUnion(bounds, [self measureRegionPaint:child transform:placement clip:clip outerRoot:outerRoot recordBounds:recordBounds order:order insideAnchor:insideAnchor || anchor]);
    }
    if (!collectingLocal && !rootPaint && paint.children.count == 0) {
        CGRect local;

        // Internal fill and stroke geometry stays fixed during one region query.
        // Cache before applying the transform or any ancestor clipping.
        BOOL cacheArtwork = _regionArtworkBounds != nil && !CGRectIsInfinite(clip);
        NSValue* measured = cacheArtwork ? [_regionArtworkBounds objectForKey:paint] : nil;
        if (measured != nil) {
            [measured getValue:&local size:sizeof(local)];
        } else {
            local = [self artworkBoundsForPaint:paint];
            if (cacheArtwork) {
                [_regionArtworkBounds setObject:[NSValue valueWithBytes:&local objCType:@encode(CGRect)] forKey:paint];
            }
        }
        if (!CGRectIsNull(local) && !CGRectIsInfinite(local)) {
            bounds = CGRectUnion(bounds, CGRectApplyAffineTransform(local, transform));
        }
    }
    bounds = CGRectIntersection(bounds, clip);
    if (recordBounds) {
        info.measuredBounds = bounds;
    }
    if (cacheLocal) {
        info.localBounds = CGRectOffset(bounds, -transform.tx, -transform.ty);
        info.hasLocalBounds = YES;
    }
    return bounds;
}

- (NSArray<IJSVGRegion*>*)regionsForRootNode:(IJSVGRootNode*)rootNode inRect:(CGRect)rect coordinateSpace:(IJSVGRegionCoordinateSpace)coordinateSpace nodeTypes:(NSArray<NSNumber*>*)nodeTypes matchingNode:(IJSVGNode*)matchingNode identifier:(NSString*)identifier
{
    if (coordinateSpace > IJSVGRegionCoordinateSpaceDestination || (nodeTypes != nil && nodeTypes.count == 0)) {
        return @[];
    }
    CGRect frame = [self renderFrameForRootNode:rootNode viewport:rect];
    BOOL previousGeometry = _resolvingGeometryOnly;
    BOOL previousMeasurements = _resolvingMeasurements;
    _resolvingGeometryOnly = YES;
    _resolvingMeasurements = YES;
    _regionArtworkBounds = coordinateSpace == IJSVGRegionCoordinateSpaceLocal ? [NSMapTable strongToStrongObjectsMapTable] : nil;
    _regionStyles = [NSMapTable strongToStrongObjectsMapTable];
    _regionUnitNodes = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
    _regionPaints = [NSMapTable strongToStrongObjectsMapTable];
    _regionTextNodes = [NSMapTable strongToStrongObjectsMapTable];
    @try {
        IJSVGRootPaint* root = [self rootPaintForRootNode:rootNode viewportSize:frame.size];
        root.frame = frame;
        BOOL destination = coordinateSpace == IJSVGRegionCoordinateSpaceDestination;
        IJSVGRootNode* outerRoot = destination ? nil : rootNode;
        CGAffineTransform transform = destination ? CGAffineTransformMakeTranslation(rect.origin.x, rect.origin.y) : CGAffineTransformIdentity;
        CGRect clip = destination ? rect : CGRectInfinite;
        NSMutableArray<IJSVGPaint*>* order = [NSMutableArray array];
        [self measureRegionPaint:root transform:transform clip:clip outerRoot:outerRoot recordBounds:coordinateSpace != IJSVGRegionCoordinateSpaceLocal order:order insideAnchor:NO];
        NSMutableArray<IJSVGRegion*>* regions = [NSMutableArray array];
        NSMutableDictionary<id<NSCopying>, NSNumber*>* instances = [NSMutableDictionary dictionary];
        for (IJSVGPaint* paint in order) {
            IJSVGRegionPaintInfo* info = [_regionPaints objectForKey:paint];
            IJSVGNode* node = info.node;
            id<NSCopying> key = node.identifier ?: [NSValue valueWithNonretainedObject:node];
            NSUInteger instanceIndex = [instances[key] unsignedIntegerValue];
            instances[key] = @(instanceIndex + 1);
            if ((matchingNode != nil && node != matchingNode) || (identifier != nil && ![node.identifier isEqualToString:identifier]) || (nodeTypes != nil && ![nodeTypes containsObject:@(node.type)])) {
                continue;
            }
            CGRect bounds = info.measuredBounds;
            if (coordinateSpace == IJSVGRegionCoordinateSpaceLocal) {
                IJSVGPaint* local = info.localPaint;
                BOOL viewport = (local.paintTraits & IJSVGPaintTraitRoot) != 0;
                bounds = [self measureRegionPaint:local transform:viewport ? CGAffineTransformIdentity : local.placementTransform clip:CGRectInfinite outerRoot:viewport ? (IJSVGRootNode*)node : nil recordBounds:NO order:nil insideAnchor:NO];
            }
            if (CGRectIsEmpty(bounds) || !IJSVGRectIsFinite(bounds)) {
                continue;
            }
            NSString* value = nil;
            if (node.type == IJSVGNodeTypeAnchor && !info.inactiveAnchor) {
                value = ((id<IJSVGReferenceNode>)node).reference.href;
            }
            [regions addObject:[[IJSVGRegion alloc] initWithRect:bounds type:node.type value:value node:node coordinateSpace:coordinateSpace instanceIndex:instanceIndex]];
        }
        return regions.copy;
    } @finally {
        _resolvingGeometryOnly = previousGeometry;
        _resolvingMeasurements = previousMeasurements;
        CFRelease(_regionUnitNodes);
        _regionUnitNodes = NULL;
        _regionStyles = nil;
        _regionArtworkBounds = nil;
        _regionPaints = nil;
        _regionTextNodes = nil;
    }
}

- (CGRect)renderFrameForRootNode:(IJSVGRootNode*)rootNode viewport:(CGRect)viewPort
{
    CGRect frame = viewPort;
    if (!_renderingOptions.ignoreIntrinsicSize && rootNode.intrinsicSize != nil) {
        CGSize size = [self.lengthFontResolver resolveSize:rootNode.intrinsicSize percentage:viewPort.size node:rootNode];
        if (size.width != 0.f) {
            frame.size.width = size.width;
        }
        if (size.height != 0.f) {
            frame.size.height = size.height;
        }
    }
    return frame;
}

- (void)renderNode:(IJSVGRootNode*)rootNode inContext:(CGContextRef)ctx viewPort:(CGRect)viewPort backingScale:(CGFloat)backingScale
{
    if (ctx == NULL || rootNode == nil || !IJSVGRectIsFinite(viewPort) || CGRectIsEmpty(viewPort)) {
        return;
    }
    CGRect frame = [self renderFrameForRootNode:rootNode viewport:viewPort];
    CGAffineTransform outputTransform = CGContextGetUserSpaceToDeviceSpaceTransform(ctx);
    outputTransform.tx = 0;
    outputTransform.ty = 0;
    BOOL viewportChanged = !CGSizeEqualToSize(frame.size, _textRenderFrameSize);
    BOOL textScaleChanged = (_containsText && !CGAffineTransformEqualToTransform(outputTransform, _textRenderTransform)) || ((_containsText || _containsNonScalingStrokes) && viewportChanged);

    if (textScaleChanged && !_containsText && _rootPaint != nil && _rootNode == rootNode && CGSizeEqualToSize(_clientSize, rootNode.clientSize) && [self updateStrokeViewportFromSize:_textRenderFrameSize toSize:frame.size]) {
        _textRenderFrameSize = frame.size;
        textScaleChanged = NO;
    }

    if (_rootPaint == nil || _rootNode != rootNode || !CGSizeEqualToSize(_clientSize, rootNode.clientSize) || textScaleChanged) {
        _backingScale = backingScale;
        _textRenderTransform = outputTransform;
        _textRenderFrameSize = frame.size;
        _textTransform = outputTransform;
        _textBuildRoot = rootNode;
        _containsText = NO;
        _containsNonScalingStrokes = NO;
        _buildHasFilters = NO;
        _buildMayRequireBackdrop = NO;
        @try {
            _rootPaint = [self rootPaintForRootNode:rootNode];
        } @finally {
            _textTransform = CGAffineTransformIdentity;
            _textBuildRoot = nil;
        }
        _batchableFilters = _buildHasFilters ? [IJSVGFilterPaint batchableFiltersForPaint:_rootPaint] : nil;

        // Ordinary filters need no backdrop scan through the complete paint tree.
        // When a potential reader was built, still check whether it is reachable.
        _requiresBackdrop = _buildMayRequireBackdrop && [self paintRequiresBackdrop:_rootPaint];
        _viewportStrokeShapes = nil;
        _viewportStrokeTransforms = nil;
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
                               if (self->_requiresBackdrop) {
                                   [self renderBackdropPaintInContext:ctx frame:frame];
                               } else if (self->_batchableFilters == nil || ![IJSVGFilterPaint renderBatchedPaints:self->_batchableFilters inContext:ctx drawingBlock:drawingBlock]) {
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
    _hasGeometryBounds = NO;
    _outlinePaths = nil;
    _hasEffectsBounds = NO;
    _rootPaint = nil;
    _viewportStrokeShapes = nil;
    _viewportStrokeTransforms = nil;
    _batchableFilters = nil;
    _geometryMeasurementPaint = nil;
    _effectsMeasurementPaint = nil;
}

- (void)setRenderingOptions:(IJSVGRenderingOptions*)options
{
    _renderingOptions = options.copy;
    _lengthFontResolver = nil;
    _hasGeometryBounds = NO;
    _outlinePaths = nil;
    _hasEffectsBounds = NO;
    _rootPaint = nil;
    _viewportStrokeShapes = nil;
    _viewportStrokeTransforms = nil;
    _batchableFilters = nil;
    _geometryMeasurementPaint = nil;
    _effectsMeasurementPaint = nil;
}

@end
