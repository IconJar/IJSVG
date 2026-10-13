//
//  IJSVGQuartzRenderer+Outlines.m
//  IJSVG
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUtils.h>
#import <IJSVGFilterGraph+Outlines.h>
#import <IJSVGFilterPaint.h>
#import <IJSVGGradientPaint.h>
#import <IJSVGGroupPaint.h>
#import <IJSVGImagePaint.h>
#import <IJSVGPaint.h>
#import <IJSVGPatternPaint.h>
#import <IJSVGQuartzRenderer+Outlines.h>
#import <IJSVGRootPaint.h>
#import <IJSVGShapePaint.h>
#import <IJSVGTransformPaint.h>
#import <simd/simd.h>

@interface IJSVGQuartzRenderer (OutlineGeometry)

- (IJSVGRootPaint*)measurementPaintForRootNode:(IJSVGRootNode*)rootNode includingFilters:(BOOL)includingFilters;

- (NSMutableDictionary<NSNumber*, id>*)outlinePathCache;

- (BOOL)outlineFilterModesSharePaint;

- (CGRect)artworkBoundsForPaint:(IJSVGPaint*)paint;

@end

@interface IJSVGOutlineFilterPlacement : NSObject

@property (nonatomic, strong) IJSVGFilterPaint* paint;
@property (nonatomic, assign) CGAffineTransform transform;
@property (nonatomic, assign) CGPathRef result;
@property (nonatomic, assign) BOOL covered;

@end

@implementation IJSVGOutlineFilterPlacement

- (void)dealloc
{
    CGPathRelease(_result);
}

@end

@implementation IJSVGQuartzRenderer (Outlines)

// An actual painted rectangle covers every path whose control bounds it
// contains. Run this only after all paints were visited so unsupported content
// still fails.
static NSArray<id>* IJSVGOutlineRemoveCoveredPaths(NSArray<id>* paths)
{
    id coveringPath = nil;
    CGRect coveringRect = CGRectNull;
    CGFloat largestArea = 0;
    for (id item in paths) {
        CGRect rect;
        if (CGPathIsRect((__bridge CGPathRef)item, &rect)) {
            CGFloat area = rect.size.width * rect.size.height;
            if (area > largestArea) {
                largestArea = area;
                coveringRect = rect;
                coveringPath = item;
            }
        }
    }
    if (coveringPath == nil) {
        return paths;
    }
    NSMutableArray<id>* remaining = [[NSMutableArray alloc] initWithObjects:coveringPath, nil];
    for (id item in paths) {
        if (item != coveringPath && !CGRectContainsRect(coveringRect, CGPathGetBoundingBox((__bridge CGPathRef)item))) {
            [remaining addObject:item];
        }
    }
    return remaining;
}

static _Thread_local BOOL IJSVGOutlineWorkerActive;

static NSUInteger IJSVGOutlineWorkerCount(NSUInteger count)
{
    static NSUInteger limit;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        limit = MAX(1, MIN((NSUInteger)NSProcessInfo.processInfo.activeProcessorCount, 8));
    });
    return !IJSVGOutlineWorkerActive && count >= 2 ? MIN(count, limit) : 1;
}

static void IJSVGOutlinePerformWork(NSUInteger workers, void (^work)(size_t))
{
    void (^perform)(size_t) = ^(size_t worker) {
        @autoreleasepool {
            BOOL wasActive = IJSVGOutlineWorkerActive;
            IJSVGOutlineWorkerActive = YES;
            work(worker);
            IJSVGOutlineWorkerActive = wasActive;
        }
    };
    if (workers > 1) {
        dispatch_apply(workers, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), perform);
    } else {
        perform(0);
    }
}

typedef struct {
    CGPathRef path;
    simd_double2 minimum;
    simd_double2 maximum;
    NSUInteger order;
    BOOL empty;
} IJSVGOutlinePathEntry;

static IJSVGOutlinePathEntry IJSVGOutlineEntry(CGPathRef path, NSUInteger order)
{
    CGRect bounds = CGPathGetBoundingBox(path);
    return (IJSVGOutlinePathEntry) { .path = path, .minimum = { CGRectGetMinX(bounds), CGRectGetMinY(bounds) }, .maximum = { CGRectGetMaxX(bounds), CGRectGetMaxY(bounds) }, .order = order, .empty = path == NULL || CGPathIsEmpty(path) };
}

static int IJSVGOutlineCompareEntries(const void* left, const void* right)
{
    const IJSVGOutlinePathEntry* a = left;
    const IJSVGOutlinePathEntry* b = right;
    double delta = (a->minimum.x + a->maximum.x) - (b->minimum.x + b->maximum.x);
    if (delta < 0) {
        return -1;
    }
    if (delta > 0) {
        return 1;
    }
    return a->order < b->order ? -1 : a->order > b->order ? 1
                                                          : 0;
}

static IJSVGOutlinePathEntry IJSVGOutlineJoinEntries(IJSVGOutlinePathEntry a, IJSVGOutlinePathEntry b)
{
    if (a.empty || b.empty) {
        IJSVGOutlinePathEntry result = a.empty ? b : a;
        result.path = CGPathCreateCopy(result.path);
        return result;
    }
    if (simd_any(a.minimum > b.maximum) || simd_any(b.minimum > a.maximum)) {
        CGMutablePathRef combined = CGPathCreateMutableCopy(a.path);
        CGPathAddPath(combined, NULL, b.path);
        a.path = combined;
        a.minimum = simd_min(a.minimum, b.minimum);
        a.maximum = simd_max(a.maximum, b.maximum);
        return a;
    }
    return IJSVGOutlineEntry(CGPathCreateCopyByUnioningPath(a.path, b.path, false), a.order);
}

static BOOL IJSVGOutlineUnionEntries(const IJSVGOutlinePathEntry* input, IJSVGOutlinePathEntry* output, NSUInteger count)
{
    NSUInteger pairs = (count + 1) / 2;
    NSUInteger workers = IJSVGOutlineWorkerCount(pairs);
    IJSVGOutlinePerformWork(workers, ^(size_t worker) {
        for (NSUInteger index = worker; index < pairs; index += workers) {
            NSUInteger offset = index * 2;
            if (offset + 1 == count) {
                output[index] = input[offset];
                output[index].path = CGPathCreateCopy(input[offset].path);
            } else {
                output[index] = IJSVGOutlineJoinEntries(input[offset], input[offset + 1]);
            }
        }
    });
    BOOL complete = YES;
    for (NSUInteger index = 0; index < pairs; index++) {
        complete &= output[index].path != NULL;
    }
    return complete;
}

static void IJSVGOutlineReleaseEntries(IJSVGOutlinePathEntry* entries, NSUInteger count)
{
    for (NSUInteger index = 0; index < count; index++) {
        CGPathRelease(entries[index].path);
        entries[index].path = NULL;
    }
}

// Cache bounds once and use SIMD to reject disjoint pairs before native unions.
// Workers own separate output slots and preserve a deterministic spatial order.
static CGPathRef IJSVGOutlineUnion(NSArray<id>* paths)
{
    paths = IJSVGOutlineRemoveCoveredPaths(paths);
    NSUInteger count = paths.count;
    if (count == 0) {
        return CGPathCreateMutable();
    }
    if (count == 1) {
        return CGPathCreateCopy((__bridge CGPathRef)paths.firstObject);
    }
    IJSVGOutlinePathEntry* first = calloc(count, sizeof(IJSVGOutlinePathEntry));
    IJSVGOutlinePathEntry* second = calloc((count + 1) / 2, sizeof(IJSVGOutlinePathEntry));
    if (first == NULL || second == NULL) {
        free(first);
        free(second);
        return NULL;
    }
    for (NSUInteger index = 0; index < count; index++) {
        first[index] = IJSVGOutlineEntry(CGPathRetain((__bridge CGPathRef)paths[index]), index);
    }
    if (count > 16) {
        qsort(first, count, sizeof(IJSVGOutlinePathEntry), IJSVGOutlineCompareEntries);
    }
    IJSVGOutlinePathEntry* input = first;
    IJSVGOutlinePathEntry* output = second;
    while (count > 1) {
        BOOL complete = IJSVGOutlineUnionEntries(input, output, count);
        IJSVGOutlineReleaseEntries(input, count);
        count = (count + 1) / 2;
        if (!complete) {
            IJSVGOutlineReleaseEntries(output, count);
            free(first);
            free(second);
            return NULL;
        }
        IJSVGOutlinePathEntry* previous = input;
        input = output;
        output = previous;
    }
    CGPathRef result = input[0].path;
    free(first);
    free(second);
    return result;
}

// Integrate x dy minus y dx exactly for a cubic using Gaussian quadrature.
// Subtract the contour origin first to avoid cancellation at large coordinates.
static CGFloat IJSVGOutlineCubicArea(CGPoint origin, CGPoint p0, CGPoint p1, CGPoint p2, CGPoint p3)
{
    simd_double2 offset = { origin.x, origin.y };
    simd_double2 a = (simd_double2) { p0.x, p0.y } - offset;
    simd_double2 b = (simd_double2) { p1.x, p1.y } - offset;
    simd_double2 c = (simd_double2) { p2.x, p2.y } - offset;
    simd_double2 d = (simd_double2) { p3.x, p3.y } - offset;
    const CGFloat nodes[] = { 0.1127016653792583, 0.5, 0.8872983346207417 };
    const CGFloat weights[] = { 5.0 / 18, 4.0 / 9, 5.0 / 18 };
    CGFloat area = 0;
    for (NSUInteger index = 0; index < 3; index++) {
        CGFloat t = nodes[index], u = 1 - t;
        simd_double2 position = u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d;
        simd_double2 derivative = 3 * u * u * (b - a) + 6 * u * t * (c - b) + 3 * t * t * (d - c);
        area += weights[index] * (position.x * derivative.y - position.y * derivative.x);
    }
    return area;
}

static CGFloat IJSVGOutlineSegmentArea(CGPoint origin, CGPoint current, const CGPathElement* element)
{
    CGPoint* p = element->points;
    if (element->type == kCGPathElementAddLineToPoint) {
        return (current.x - origin.x) * (p[0].y - origin.y) - (current.y - origin.y) * (p[0].x - origin.x);
    }
    if (element->type == kCGPathElementAddQuadCurveToPoint) {
        CGPoint c1 = CGPointMake(current.x + (p[0].x - current.x) * 2 / 3, current.y + (p[0].y - current.y) * 2 / 3);
        CGPoint c2 = CGPointMake(p[1].x + (p[0].x - p[1].x) * 2 / 3, p[1].y + (p[0].y - p[1].y) * 2 / 3);
        return IJSVGOutlineCubicArea(origin, current, c1, c2, p[1]);
    }
    return IJSVGOutlineCubicArea(origin, current, p[0], p[1], p[2]);
}

// Normalization gives outer contours one orientation and holes the opposite.
// Remove hole contours only after clipping and union. Keep the original curves.
static CGPathRef IJSVGOutlineFillHoles(CGPathRef path)
{
    NSMutableArray<id>* boundaries = [[NSMutableArray alloc] init];
    NSMutableArray<NSNumber*>* areas = [[NSMutableArray alloc] init];
    __block CGMutablePathRef boundary = CGPathCreateMutable();
    __block CGPoint origin = CGPointZero, current = CGPointZero;
    __block CGFloat area = 0, totalArea = 0;
    void (^finish)(void) = ^{
        if (!CGPathIsEmpty(boundary)) {
            CGPathCloseSubpath(boundary);
            [boundaries addObject:CFBridgingRelease(CGPathCreateCopy(boundary))];
            [areas addObject:@(area)];
            totalArea += area;
        }
        CGPathRelease(boundary);
        boundary = CGPathCreateMutable();
        area = 0;
    };
    CGPathApplyWithBlock(path, ^(const CGPathElement* element) {
        CGPoint* p = element->points;
        switch (element->type) {
            case kCGPathElementMoveToPoint:
                finish();
                origin = current = p[0];
                CGPathMoveToPoint(boundary, NULL, p[0].x, p[0].y);
                break;
            case kCGPathElementAddLineToPoint:
                area += IJSVGOutlineSegmentArea(origin, current, element);
                current = p[0];
                CGPathAddLineToPoint(boundary, NULL, p[0].x, p[0].y);
                break;
            case kCGPathElementAddQuadCurveToPoint:
                area += IJSVGOutlineSegmentArea(origin, current, element);
                current = p[1];
                CGPathAddQuadCurveToPoint(boundary, NULL, p[0].x, p[0].y, p[1].x, p[1].y);
                break;
            case kCGPathElementAddCurveToPoint:
                area += IJSVGOutlineSegmentArea(origin, current, element);
                current = p[2];
                CGPathAddCurveToPoint(boundary, NULL, p[0].x, p[0].y, p[1].x, p[1].y, p[2].x, p[2].y);
                break;
            case kCGPathElementCloseSubpath:
                finish();
                break;
        }
    });
    finish();
    CGPathRelease(boundary);
    if (boundaries.count < 2) {
        return CGPathCreateCopy(path);
    }
    if (!isfinite(totalArea) || totalArea == 0) {
        return NULL;
    }
    CGMutablePathRef filled = CGPathCreateMutable();
    NSUInteger retained = 0;
    for (NSUInteger index = 0; index < boundaries.count; index++) {
        if ((areas[index].doubleValue > 0) == (totalArea > 0)) {
            CGPathAddPath(filled, NULL, (__bridge CGPathRef)boundaries[index]);
            retained++;
        }
    }
    CGPathRef result = retained == boundaries.count ? CGPathCreateCopy(path) : CGPathCreateCopyByNormalizing(filled, false);
    CGPathRelease(filled);
    return result;
}

- (BOOL)outlineBoundsIncludeAllCoverage:(IJSVGPaint*)paint
{
    if ([paint isKindOfClass:IJSVGFilterPaint.class]) {
        return YES;
    }
    if ([paint isKindOfClass:IJSVGRootPaint.class]) {
        return NO;
    }
    for (IJSVGPaint* child in paint.children) {
        if (![self outlineBoundsIncludeAllCoverage:child]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)outlinePaintIsCovered:(IJSVGPaint*)paint transform:(CGAffineTransform)transform paths:(NSArray<id>*)paths
{
    if (paths.count == 0) {
        return NO;
    }
    CGRect rectangle;
    if (!CGPathIsRect((__bridge CGPathRef)paths.firstObject, &rectangle) || ![self outlineBoundsIncludeAllCoverage:paint]) {
        return NO;
    }
    CGRect bounds = [self artworkBoundsForPaint:paint];
    return !CGRectIsNull(bounds) && !CGRectIsInfinite(bounds) && CGRectContainsRect(rectangle, CGRectApplyAffineTransform(bounds, transform));
}

- (CGFloat)outlineRectangleAreaForPaint:(IJSVGPaint*)paint transform:(CGAffineTransform)transform
{
    if (paint.hidden || paint.opacity <= 0) {
        return 0;
    }
    BOOL structural = paint.class == IJSVGGroupPaint.class || paint.class == IJSVGTransformPaint.class;
    if ((structural || [paint isKindOfClass:IJSVGShapePaint.class]) && paint.children.count == 1) {
        IJSVGPaint* child = paint.children.firstObject;
        return [self outlineRectangleAreaForPaint:child transform:CGAffineTransformConcat(child.placementTransform, transform)];
    }
    if ([paint isKindOfClass:IJSVGShapePaint.class]) {
        IJSVGShapePaint* shape = (IJSVGShapePaint*)paint;
        CGRect rectangle;
        if (shape.fillColor != NULL && CGColorGetAlpha(shape.fillColor) > 0 && CGPathIsRect(shape.path, &rectangle)) {
            return rectangle.size.width * rectangle.size.height * fabs(transform.a * transform.d - transform.b * transform.c);
        }
    }
    return 0;
}

- (CGAffineTransform)outlinePlacementForChild:(IJSVGPaint*)child parent:(IJSVGPaint*)parent transform:(CGAffineTransform)transform
{
    // A filter translates its source frame. The wrapper owns the node transform.
    CGAffineTransform placement = [parent isKindOfClass:IJSVGFilterPaint.class] ? CGAffineTransformMakeTranslation(child.frame.origin.x, child.frame.origin.y) : child.placementTransform;
    return CGAffineTransformConcat(placement, transform);
}

- (BOOL)appendPlacedChildOutlinesForPaint:(IJSVGPaint*)paint transform:(CGAffineTransform)transform paths:(NSMutableArray<id>*)paths pendingFilters:(NSMutableArray<IJSVGOutlineFilterPlacement*>*)pending
{
    NSArray<IJSVGPaint*>* children = paint.children;
    NSUInteger first = 0;
    CGFloat largestArea = 0;
    if (children.count > 1) {
        for (NSUInteger index = 0; index < children.count; index++) {
            CGAffineTransform placement = [self outlinePlacementForChild:children[index] parent:paint transform:transform];
            CGFloat area = [self outlineRectangleAreaForPaint:children[index] transform:placement];
            if (area > largestArea) {
                largestArea = area;
                first = index;
            }
        }
    }

    // Prioritize a background rectangle without sorting or copying the child
    // list.
    for (NSUInteger index = 0; index < children.count; index++) {
        NSUInteger position = index == 0 ? first : index <= first ? index - 1
                                                                  : index;
        IJSVGPaint* child = children[position];
        CGAffineTransform placement = [self outlinePlacementForChild:child parent:paint transform:transform];
        if (![self appendOutlineForPaint:child transform:placement paths:paths pendingFilters:pending]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)appendOutlineForPaint:(IJSVGPaint*)paint transform:(CGAffineTransform)transform paths:(NSMutableArray<id>*)paths pendingFilters:(NSMutableArray<IJSVGOutlineFilterPlacement*>*)pending
{
    if (paint.hidden || paint.opacity <= 0 || [self outlinePaintIsCovered:paint transform:transform paths:paths]) {
        return YES;
    }

    // Structural wrappers can share one union with their parent.
    BOOL structural = paint.class == IJSVGGroupPaint.class || paint.class == IJSVGTransformPaint.class;
    if (structural && paint.clipPath == NULL && paint.maskPaint == nil && paint.blendingMode <= kCGBlendModeLuminosity) {
        return [self appendPlacedChildOutlinesForPaint:paint transform:transform paths:paths pendingFilters:pending];
    }
    if (pending != nil && [paint isKindOfClass:IJSVGFilterPaint.class]) {
        NSArray<IJSVGFilterPrimitive*>* primitives = ((IJSVGFilterPaint*)paint).filterMetadata.primitives;

        // Containment pays for itself on expanding filters, not cheap inner
        // shadows.
        if (primitives.count == 1 && (primitives[0].type == IJSVGNodeTypeFilterGaussianBlur || primitives[0].type == IJSVGNodeTypeFilterDropShadow)) {
            IJSVGOutlineFilterPlacement* placement = [[IJSVGOutlineFilterPlacement alloc] init];
            placement.paint = (IJSVGFilterPaint*)paint;
            placement.transform = transform;
            [pending addObject:placement];
            return YES;
        }
    }
    CGPathRef local = [self newOutlineForPaint:paint outerRoot:NO];
    if (local == NULL) {
        return NO;
    }
    if (CGPathIsEmpty(local)) {
        CGPathRelease(local);
        return YES;
    }
    CGPathRef placed = CGPathCreateCopyByTransformingPath(local, &transform);
    CGPathRelease(local);
    if (placed == NULL) {
        return NO;
    }
    [paths addObject:CFBridgingRelease(placed)];
    return YES;
}

// The whole filter region bounds its output, including nested effects.
// Subtraction checks actual coverage and preserves holes in the covering path.
- (BOOL)filterOutlineIsCovered:(IJSVGFilterPaint*)paint transform:(CGAffineTransform)transform byPath:(CGPathRef)covering
{
    IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
    graph.boundingBox = paint.boundingBox;
    graph.viewPort = paint.viewPort;
    CGRect region = [graph regionForNode:paint.filter units:paint.filter.units defaultRegion:CGRectZero];
    if (CGRectIsEmpty(region)) {
        return YES;
    }
    CGRect bounds = CGRectApplyAffineTransform(region, transform);
    if (!CGRectContainsRect(CGPathGetBoundingBox(covering), bounds)) {
        return NO;
    }
    CGRect rectangle;
    if (CGPathIsRect(covering, &rectangle) && CGRectContainsRect(rectangle, bounds)) {
        return YES;
    }
    CGPathRef candidate = CGPathCreateWithRect(region, &transform);
    CGPathRef uncovered = candidate == NULL ? NULL : CGPathCreateCopyBySubtractingPath(candidate, covering, false);
    BOOL covered = uncovered != NULL && CGPathIsEmpty(uncovered);
    CGPathRelease(candidate);
    CGPathRelease(uncovered);
    return covered;
}

- (CGPathRef)newPlacedFilterOutline:(IJSVGOutlineFilterPlacement*)item
{
    CGPathRef clipped = [self newOutlineForPaint:item.paint outerRoot:NO];
    if (clipped == NULL) {
        return NULL;
    }
    CGAffineTransform transform = item.transform;
    CGPathRef placed = CGPathCreateCopyByTransformingPath(clipped, &transform);
    CGPathRelease(clipped);
    return placed;
}

- (BOOL)appendPreparedFilterOutlines:(NSArray<IJSVGOutlineFilterPlacement*>*)pending paths:(NSMutableArray<id>*)paths
{
    NSUInteger workers = pending.count >= 4 ? IJSVGOutlineWorkerCount(pending.count) : 1;
    void (^expand)(size_t) = ^(size_t worker) {
        @autoreleasepool {
            for (NSUInteger index = worker; index < pending.count; index += workers) {
                IJSVGOutlineFilterPlacement* item = pending[index];
                item.result = [self newPlacedFilterOutline:item];
            }
        }
    };

    // Resolve the paint tree before workers expand independent filter sources.
    IJSVGOutlinePerformWork(workers, expand);
    for (IJSVGOutlineFilterPlacement* item in pending) {
        if (item.result == NULL) {
            return NO;
        }
        [paths addObject:(__bridge id)item.result];
    }
    return YES;
}

- (void)markCoveredFilterOutlines:(NSArray<IJSVGOutlineFilterPlacement*>*)pending byPath:(CGPathRef)covering
{
    NSUInteger workers = pending.count >= 4 ? IJSVGOutlineWorkerCount(pending.count) : 1;
    void (^check)(size_t) = ^(size_t worker) {
        @autoreleasepool {
            for (NSUInteger index = worker; index < pending.count; index += workers) {
                IJSVGOutlineFilterPlacement* item = pending[index];
                item.covered = [self filterOutlineIsCovered:item.paint transform:item.transform byPath:covering];
            }
        }
    };
    IJSVGOutlinePerformWork(workers, check);
}

- (BOOL)appendPendingFilterOutlines:(NSArray<IJSVGOutlineFilterPlacement*>*)pending paths:(NSMutableArray<id>*)paths
{
    if (pending.count == 0) {
        return YES;
    }
    CGPathRef covering = IJSVGOutlineUnion(paths);
    if (covering == NULL) {
        return NO;
    }
    [paths removeAllObjects];
    [paths addObject:CFBridgingRelease(covering)];
    [self markCoveredFilterOutlines:pending byPath:covering];
    NSMutableArray<IJSVGOutlineFilterPlacement*>* prepared = [[NSMutableArray alloc] initWithCapacity:pending.count];
    for (IJSVGOutlineFilterPlacement* item in pending) {
        if (item.covered) {
            continue;
        }
        [prepared addObject:item];
    }
    return [self appendPreparedFilterOutlines:prepared paths:paths];
}

- (BOOL)appendChildOutlinesForPaint:(IJSVGPaint*)paint paths:(NSMutableArray<id>*)paths
{
    NSMutableArray<IJSVGOutlineFilterPlacement*>* pending = [[NSMutableArray alloc] init];
    if (![self appendPlacedChildOutlinesForPaint:paint transform:CGAffineTransformIdentity paths:paths pendingFilters:pending]) {
        return NO;
    }
    return [self appendPendingFilterOutlines:pending paths:paths];
}

- (BOOL)appendShapeOutline:(IJSVGShapePaint*)shape paths:(NSMutableArray<id>*)paths
{
    if (shape.path == NULL) {
        return YES;
    }
    BOOL visibleFill = shape.fillColor != NULL && CGColorGetAlpha(shape.fillColor) > 0;
    for (NSColor* color in shape.fillGradient.colors) {
        visibleFill |= color.alphaComponent > 0;
    }
    if (visibleFill) {
        CGPathRef fill = shape.fillRule == IJSVGWindingRuleEvenOdd ? CGPathCreateCopyByNormalizing(shape.path, true) : CGPathCreateCopy(shape.path);
        if (fill == NULL) {
            return NO;
        }
        [paths addObject:CFBridgingRelease(fill)];
    }
    if (shape.strokeColor != NULL && CGColorGetAlpha(shape.strokeColor) > 0 && shape.lineWidth > 0) {
        CGPathRef stroke = [self.class newPathFromStrokedShapePaint:shape];
        if (stroke == NULL) {
            return NO;
        }
        [paths addObject:CFBridgingRelease(stroke)];
    }
    return YES;
}

- (BOOL)appendGradientOutline:(IJSVGGradientPaint*)paint paths:(NSMutableArray<id>*)paths
{
    BOOL visible = NO;
    for (NSColor* color in paint.gradient.colors) {
        visible |= color.alphaComponent > 0;
    }
    if (!visible) {
        return YES;
    }
    if (paint.clipPath == NULL) {
        return NO;
    }
    CGPathRef coverage = paint.clipRule == IJSVGWindingRuleEvenOdd ? CGPathCreateCopyByNormalizing(paint.clipPath, true) : CGPathCreateCopy(paint.clipPath);
    if (coverage == NULL) {
        return NO;
    }
    [paths addObject:CFBridgingRelease(coverage)];
    return YES;
}

- (CGAffineTransform)outlineViewportTransform:(IJSVGRootPaint*)root
{
    if (root.viewBox == nil) {
        return CGAffineTransformIdentity;
    }
    CGRect viewBox = [root.viewBox computeValue:root.frame.size];
    return IJSVGViewBoxComputeTransform(viewBox, IJSVGPaintGetBoundingBoxBounds(root), root.viewBoxAlignment, root.viewBoxMeetOrSlice);
}

- (BOOL)appendOwnOutlineForPaint:(IJSVGPaint*)paint paths:(NSMutableArray<id>*)paths
{
    if ([paint isKindOfClass:IJSVGShapePaint.class]) {
        return [self appendShapeOutline:(IJSVGShapePaint*)paint paths:paths];
    }
    if ([paint isKindOfClass:IJSVGGradientPaint.class]) {
        return [self appendGradientOutline:(IJSVGGradientPaint*)paint paths:paths];
    }
    if ([paint isKindOfClass:IJSVGRootPaint.class]) {
        IJSVGRootPaint* root = (IJSVGRootPaint*)paint;
        if (root.backgroundColor.alphaComponent > 0) {
            CGRect bounds = IJSVGPaintGetBoundingBoxBounds(root);
            CGAffineTransform inverse = CGAffineTransformInvert([self outlineViewportTransform:root]);
            CGPathRef background = CGPathCreateWithRect(CGRectApplyAffineTransform(bounds, inverse), NULL);
            if (background == NULL) {
                return NO;
            }
            [paths addObject:CFBridgingRelease(background)];
        }
    }
    return YES;
}

- (CGPathRef)newFilteredOutline:(CGPathRef)outline paint:(IJSVGFilterPaint*)paint
{
    IJSVGFilterGraph* graph = [[IJSVGFilterGraph alloc] init];
    graph.filter = paint.filter;
    graph.resolvedMetadata = paint.filterMetadata;
    graph.boundingBox = paint.boundingBox;
    graph.viewPort = paint.viewPort;
    return [graph newOutlineForSourcePath:outline backgroundIsEmpty:!paint.usesBackground];
}

- (CGPathRef)newViewportOutline:(CGPathRef)outline root:(IJSVGRootPaint*)root
{
    CGAffineTransform transform = [self outlineViewportTransform:root];
    CGPathRef placed = CGPathCreateCopyByTransformingPath(outline, &transform);
    if (placed == NULL || root.sourceNode.overflowVisibility != IJSVGOverflowVisibilityHidden) {
        return placed;
    }
    CGPathRef clip = CGPathCreateWithRect(IJSVGPaintGetBoundingBoxBounds(root), NULL);
    CGPathRef clipped = clip == NULL ? NULL : CGPathCreateCopyByIntersectingPath(placed, clip, false);
    CGPathRelease(clip);
    CGPathRelease(placed);
    return clipped;
}

- (CGPathRef)newClippedOutline:(CGPathRef)outline paint:(IJSVGPaint*)paint
{
    // Gradient coverage is already its resolved clip.
    BOOL gradientCoverage = [paint isKindOfClass:IJSVGGradientPaint.class] && paint.children.count == 0;
    if (paint.clipPath == NULL || gradientCoverage) {
        return CGPathCreateCopy(outline);
    }
    CGPathRef clip = paint.clipRule == IJSVGWindingRuleEvenOdd ? CGPathCreateCopyByNormalizing(paint.clipPath, true) : CGPathCreateCopy(paint.clipPath);
    CGPathRef clipped = clip == NULL ? NULL : CGPathCreateCopyByIntersectingPath(outline, clip, false);
    CGPathRelease(clip);
    return clipped;
}

- (CGPathRef)newSourceOutlineForPaint:(IJSVGPaint*)paint
{
    NSMutableArray<id>* paths = [[NSMutableArray alloc] init];
    if (![self appendChildOutlinesForPaint:paint paths:paths] || ![self appendOwnOutlineForPaint:paint paths:paths]) {
        return NULL;
    }
    return IJSVGOutlineUnion(paths);
}

- (CGPathRef)newOutlineForPaint:(IJSVGPaint*)paint outerRoot:(BOOL)outerRoot
{
    if (paint == nil || paint.hidden || paint.opacity <= 0 || (paint.clipPath != NULL && CGPathIsEmpty(paint.clipPath))) {
        return CGPathCreateMutable();
    }
    if (paint.maskPaint != nil || [paint isKindOfClass:IJSVGImagePaint.class] || [paint isKindOfClass:IJSVGPatternPaint.class] || paint.blendingMode > kCGBlendModeLuminosity) {
        return NULL;
    }
    CGPathRef outline = [self newSourceOutlineForPaint:paint];
    if (outline != NULL && [paint isKindOfClass:IJSVGFilterPaint.class]) {
        CGPathRef filtered = [self newFilteredOutline:outline paint:(IJSVGFilterPaint*)paint];
        CGPathRelease(outline);
        outline = filtered;
    }
    if (outline != NULL && !outerRoot && [paint isKindOfClass:IJSVGRootPaint.class]) {
        CGPathRef placed = [self newViewportOutline:outline root:(IJSVGRootPaint*)paint];
        CGPathRelease(outline);
        outline = placed;
    }
    if (outline == NULL) {
        return NULL;
    }
    CGPathRef clipped = [self newClippedOutline:outline paint:paint];
    CGPathRelease(outline);
    return clipped;
}

// Reject unsupported visible paints before constructing any expensive outlines.
- (BOOL)canOutlinePaint:(IJSVGPaint*)paint
{
    if (paint == nil || paint.hidden || paint.opacity <= 0 || (paint.clipPath != NULL && CGPathIsEmpty(paint.clipPath))) {
        return YES;
    }
    if (paint.maskPaint != nil || [paint isKindOfClass:IJSVGImagePaint.class] || [paint isKindOfClass:IJSVGPatternPaint.class] || paint.blendingMode > kCGBlendModeLuminosity) {
        return NO;
    }
    if ([paint isKindOfClass:IJSVGShapePaint.class]) {
        IJSVGShapePaint* shape = (IJSVGShapePaint*)paint;
        if (shape.strokeColor != NULL && CGColorGetAlpha(shape.strokeColor) > 0 && shape.lineWidth > 0) {
            // Resolve the lazy stroke flag before independent outline workers start.
            (void)shape.hasPointSubpaths;
        }
    }
    if ([paint isKindOfClass:IJSVGFilterPaint.class]) {
        IJSVGFilterPaint* filterPaint = (IJSVGFilterPaint*)paint;
        if (![IJSVGFilterGraph canOutlineMetadata:filterPaint.filterMetadata backgroundIsEmpty:!filterPaint.usesBackground]) {
            return NO;
        }
    }
    for (IJSVGPaint* child in paint.children) {
        if (![self canOutlinePaint:child]) {
            return NO;
        }
    }
    return YES;
}

- (CGPathRef)outlinePathForRootNode:(IJSVGRootNode*)rootNode includingFilterExtents:(BOOL)includingFilterExtents preservingHoles:(BOOL)preservingHoles
{
    IJSVGRootPaint* root = [self measurementPaintForRootNode:rootNode includingFilters:includingFilterExtents];
    NSNumber* key = @((includingFilterExtents ? 2 : 0) | (preservingHoles ? 1 : 0));
    NSMutableDictionary<NSNumber*, id>* cache = [self outlinePathCache];
    id cached = cache[key];
    if (cached == nil) {
        CGPathRef path;
        if (preservingHoles) {
            CGPathRef coverage = [self canOutlinePaint:root] ? [self newOutlineForPaint:root outerRoot:YES] : NULL;
            path = coverage == NULL ? NULL : CGPathCreateCopyByNormalizing(coverage, false);
            CGPathRelease(coverage);
        } else {
            // Share paint traversal and union between both hole modes.
            CGPathRef coverage = [self outlinePathForRootNode:rootNode includingFilterExtents:includingFilterExtents preservingHoles:YES];
            path = coverage == NULL ? NULL : IJSVGOutlineFillHoles(coverage);
        }
        cached = path == NULL ? NSNull.null : CFBridgingRelease(path);
        cache[key] = cached;

        // Keep separate mode entries while sharing identical resolved coverage.
        if ([self outlineFilterModesSharePaint]) {
            cache[@(key.unsignedIntegerValue ^ 2)] = cached;
        }
    }
    return cached == NSNull.null ? NULL : (__bridge CGPathRef)cached;
}

@end
