//
//  IJSVGFilterGraph+Outlines.m
//  IJSVG
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGParser.h>
#import <IJSVGFilterContext.h>
#import <IJSVGFilterGraph+Outlines.h>
#import <IJSVGFilterSIMD.h>
#import <IJSVGFloodFilterEffect.h>
#import <simd/simd.h>

@implementation IJSVGFilterGraph (Outlines)

// ARC containers own intermediate paths. Only the final result is retained for
// the caller. The graph operates before paint placement, so objectBoundingBox
// units, offsets and anisotropic blurs are transformed together with the
// filtered node.
static CGPathRef IJSVGOutlineClip(CGPathRef path, CGRect region)
{
    if (!IJSVGFilterValidRect(region)) {
        return CGPathCreateMutable();
    }
    if (CGRectContainsRect(region, CGPathGetPathBoundingBox(path))) {
        return CGPathCreateCopy(path);
    }
    CGPathRef clip = CGPathCreateWithRect(region, NULL);
    CGPathRef result = CGPathCreateCopyByIntersectingPath(path, clip, false);
    CGPathRelease(clip);
    return result;
}

typedef struct {
    NSUInteger first;
    NSUInteger last;
} IJSVGOutlinePointRange;

static NSUInteger IJSVGOutlineFurthestPoint(const simd_double2* points, IJSVGOutlinePointRange range, CGFloat tolerance)
{
    simd_double2 start = points[range.first];
    simd_double2 direction = points[range.last] - start;
    double lengthSquared = simd_length_squared(direction);
    double furthestDistance = tolerance * tolerance;
    NSUInteger furthest = range.first;
    for (NSUInteger index = range.first + 1; index < range.last; index++) {
        simd_double2 offset = points[index] - start;
        double fraction = lengthSquared > 0 ? simd_dot(offset, direction) / lengthSquared : 0;
        simd_double2 error = offset - direction * fmax(0, fmin(1, fraction));
        double distance = simd_length_squared(error);
        if (distance > furthestDistance) {
            furthestDistance = distance;
            furthest = index;
        }
    }
    return furthest;
}

static BOOL IJSVGOutlineAppendSimplifiedContour(CGMutablePathRef output, NSData* data, CGFloat tolerance)
{
    NSUInteger count = data.length / sizeof(simd_double2);
    if (count == 0) {
        return YES;
    }
    const simd_double2* points = data.bytes;
    BOOL* retained = calloc(count, sizeof(BOOL));
    IJSVGOutlinePointRange* stack = malloc(count * sizeof(IJSVGOutlinePointRange));
    if (retained == NULL || stack == NULL) {
        free(retained);
        free(stack);
        return NO;
    }
    retained[0] = retained[count - 1] = YES;
    NSUInteger pending = 1;
    NSUInteger retainedCount = 2;
    stack[0] = (IJSVGOutlinePointRange) { 0, count - 1 };
    while (pending != 0) {
        IJSVGOutlinePointRange range = stack[--pending];
        NSUInteger furthest = IJSVGOutlineFurthestPoint(points, range, tolerance);
        if (furthest != range.first) {
            retained[furthest] = YES;
            retainedCount++;
            stack[pending++] = (IJSVGOutlinePointRange) { range.first, furthest };
            stack[pending++] = (IJSVGOutlinePointRange) { furthest, range.last };
        }
    }

    // Keep tiny contours intact so simplification cannot erase their blur
    // coverage.
    CGPathMoveToPoint(output, NULL, points[0].x, points[0].y);
    for (NSUInteger index = 1; index < count; index++) {
        if (retainedCount < 4 || retained[index]) {
            CGPathAddLineToPoint(output, NULL, points[index].x, points[index].y);
        }
    }
    CGPathCloseSubpath(output);
    free(retained);
    free(stack);
    return YES;
}

static CGPathRef IJSVGOutlineSimplifyPolygon(CGPathRef polygon, CGFloat tolerance)
{
    CGMutablePathRef result = CGPathCreateMutable();
    NSMutableData* points = [[NSMutableData alloc] init];
    __block BOOL complete = YES;
    void (^finish)(void) = ^{
        if (points.length != 0) {
            simd_double2 first = *(const simd_double2*)points.bytes;
            [points appendBytes:&first length:sizeof(first)];
            complete &= IJSVGOutlineAppendSimplifiedContour(result, points, tolerance);
            points.length = 0;
        }
    };
    CGPathApplyWithBlock(polygon, ^(const CGPathElement* element) {
        if (element->type == kCGPathElementMoveToPoint) {
            finish();
        }
        if (element->type == kCGPathElementMoveToPoint || element->type == kCGPathElementAddLineToPoint) {
            simd_double2 point = { element->points[0].x, element->points[0].y };
            [points appendBytes:&point length:sizeof(point)];
        } else if (element->type == kCGPathElementCloseSubpath) {
            finish();
        }
    });
    finish();
    if (!complete) {
        CGPathRelease(result);
        return NULL;
    }
    return result;
}

static CGPathRef IJSVGOutlineBlur(CGPathRef path, CGSize deviation)
{
    if (CGPathIsEmpty(path) || (deviation.width == 0 && deviation.height == 0)) {
        return CGPathCreateCopy(path);
    }

    // A round dilation enclosing the rectangular kernel support at three sigma.
    // A small positive axis keeps a blur in one dimension conservative.
    CGFloat x = MAX(deviation.width * 3, 1e-6);
    CGFloat y = MAX(deviation.height * 3, 1e-6);
    if (!isfinite(x) || !isfinite(y)) {
        return NULL;
    }
    CGAffineTransform normalize = CGAffineTransformMakeScale(1 / x, 1 / y);
    CGPathRef scaled = CGPathCreateCopyByTransformingPath(path, &normalize);
    CGPathRef closed = scaled == NULL ? NULL : CGPathCreateCopyByNormalizing(scaled, false);

    // Flatten only the approximate filter envelope with error limited to 0.15
    // sigma. Add the simplification and both flattening error bounds to preserve
    // coverage.
    const CGFloat tolerance = 0.05;
    CGPathRef polygonSource = closed == NULL ? NULL : CGPathCreateCopyByFlattening(closed, tolerance);
    CGPathRef flattened = polygonSource == NULL ? NULL : IJSVGOutlineSimplifyPolygon(polygonSource, tolerance);
    CGPathRelease(polygonSource);
    CGPathRelease(closed);
    if (flattened == NULL) {
        CGPathRelease(scaled);
        return NULL;
    }
    CGPathRef edge = CGPathCreateCopyByStrokingPath(flattened, NULL, 2 * (M_SQRT2 + 3 * tolerance), kCGLineCapRound, kCGLineJoinRound, 0);
    CGPathRef polygon = edge == NULL ? NULL : CGPathCreateCopyByFlattening(edge, tolerance);
    CGPathRef expanded = polygon == NULL ? NULL : CGPathCreateCopyByUnioningPath(flattened, polygon, false);
    CGPathRelease(polygon);
    CGPathRelease(flattened);
    CGAffineTransform restore = CGAffineTransformMakeScale(x, y);
    CGPathRef result = expanded == NULL ? NULL : CGPathCreateCopyByTransformingPath(expanded, &restore);
    CGPathRelease(scaled);
    CGPathRelease(edge);
    CGPathRelease(expanded);
    return result;
}

- (CGSize)outlinePrimitiveUnits
{
    return self.filter.contentUnits == IJSVGUnitObjectBoundingBox ? self.boundingBox.size : CGSizeMake(1, 1);
}

- (CGPathRef)newOffsetOutline:(CGPathRef)path primitive:(IJSVGFilterPrimitive*)primitive defaultValue:(CGFloat)value
{
    CGSize units = self.outlinePrimitiveUnits;
    CGFloat dx = [primitive numberForParameter:IJSVGAttributeDX defaultValue:value] * units.width;
    CGFloat dy = [primitive numberForParameter:IJSVGAttributeDY defaultValue:value] * units.height;
    if (!isfinite(dx) || !isfinite(dy)) {
        return NULL;
    }
    CGAffineTransform offset = CGAffineTransformMakeTranslation(dx, dy);
    return CGPathCreateCopyByTransformingPath(path, &offset);
}

- (BOOL)outlineFloodIsVisible:(IJSVGFilterPrimitive*)primitive
{
    CGFloat opacity = [IJSVGFloodFilterEffect opacityForPrimitive:primitive];
    CGColorRef color = [IJSVGFloodFilterEffect colorForPrimitive:primitive];
    color = [IJSVGColor computeColorSpace:color] ?: IJSVGColor.blackColor;
    return CGColorGetAlpha(color) * IJSVGFilterClamp(opacity) > 0;
}

- (CGPathRef)newBlurOutline:(CGPathRef)path primitive:(IJSVGFilterPrimitive*)primitive
{
    BOOL shadow = primitive.type == IJSVGNodeTypeFilterDropShadow;
    if (shadow && ![self outlineFloodIsVisible:primitive]) {
        return CGPathCreateCopy(path);
    }
    CGSize fallback = shadow ? CGSizeMake(2, 2) : CGSizeZero;
    CGSize deviation = [primitive pairForParameter:IJSVGAttributeStdDeviation defaultValue:fallback];
    if (deviation.width < 0 || deviation.height < 0) {
        deviation = fallback;
    }
    if (!shadow && (primitive.edgeMode == IJSVGFilterEdgeModeWrap || primitive.edgeMode == IJSVGFilterEdgeModeDuplicate)) {
        return NULL;
    }
    CGSize units = self.outlinePrimitiveUnits;
    deviation.width *= units.width;
    deviation.height *= units.height;
    CGPathRef blurred = IJSVGOutlineBlur(path, deviation);
    if (!shadow || blurred == NULL) {
        return blurred;
    }
    CGPathRef translated = [self newOffsetOutline:blurred primitive:primitive defaultValue:2];
    CGPathRelease(blurred);
    CGPathRef result = translated == NULL ? NULL : CGPathCreateCopyByUnioningPath(path, translated, false);
    CGPathRelease(translated);
    return result;
}

- (CGPathRef)newColorMatrixOutline:(CGPathRef)path primitive:(IJSVGFilterPrimitive*)primitive region:(CGRect)region
{
    NSArray<NSNumber*>* values = [primitive numbersForParameter:IJSVGAttributeValues];

    // Alpha depending on colour remains inside the input coverage.
    // A positive constant alpha can generate coverage throughout the region.
    BOOL matrix = primitive.colorMatrixType == IJSVGFilterColorMatrixTypeMatrix && values.count == 20;
    if (matrix && values[19].doubleValue > 0) {
        return CGPathCreateWithRect(region, NULL);
    }
    if (matrix && values[15].doubleValue <= 0 && values[16].doubleValue <= 0 && values[17].doubleValue <= 0 && values[18].doubleValue <= 0 && values[19].doubleValue <= 0) {
        return CGPathCreateMutable();
    }
    return CGPathCreateCopy(path);
}

- (CGPathRef)newArithmeticOutline:(CGPathRef)input other:(CGPathRef)other primitive:(IJSVGFilterPrimitive*)primitive region:(CGRect)region
{
    CGFloat k1 = [primitive numberForParameter:IJSVGAttributeK1 defaultValue:0];
    CGFloat k2 = [primitive numberForParameter:IJSVGAttributeK2 defaultValue:0];
    CGFloat k3 = [primitive numberForParameter:IJSVGAttributeK3 defaultValue:0];
    CGFloat k4 = [primitive numberForParameter:IJSVGAttributeK4 defaultValue:0];
    if (k4 > 0) {
        return CGPathCreateWithRect(region, NULL);
    }
    if (k1 <= 0 && k2 <= 0 && k3 <= 0) {
        return CGPathCreateMutable();
    }
    if (k1 <= 0 && k2 <= 0) {
        return CGPathCreateCopy(other);
    }
    if (k1 <= 0 && k3 <= 0) {
        return CGPathCreateCopy(input);
    }
    return CGPathCreateCopyByUnioningPath(input, other, false);
}

- (CGPathRef)newCompositeOutline:(CGPathRef)input other:(CGPathRef)other primitive:(IJSVGFilterPrimitive*)primitive region:(CGRect)region
{
    switch (primitive.compositeOperator) {
        case IJSVGFilterCompositeOperatorIn:
            return CGPathCreateCopyByIntersectingPath(input, other, false);
        case IJSVGFilterCompositeOperatorOut:

            // Subtracting approximate coverage could remove real pixels.
            return CGPathCreateCopy(input);
        case IJSVGFilterCompositeOperatorAtop:
            return CGPathCreateCopy(other);
        case IJSVGFilterCompositeOperatorArithmetic:
            return [self newArithmeticOutline:input other:other primitive:primitive region:region];
        default:
            return CGPathCreateCopyByUnioningPath(input, other, false);
    }
}

- (CGPathRef)newMergedOutline:(IJSVGFilterPrimitive*)primitive inputNamed:(id (^)(NSString*))inputNamed
{
    id merged = CFBridgingRelease(CGPathCreateMutable());
    for (IJSVGFilterPrimitive* child in primitive.children) {
        id item = inputNamed(child.input);
        if (item == nil) {
            return NULL;
        }
        merged = CFBridgingRelease(CGPathCreateCopyByUnioningPath((__bridge CGPathRef)merged, (__bridge CGPathRef)item, false));
        if (merged == nil) {
            return NULL;
        }
    }
    return CGPathCreateCopy((__bridge CGPathRef)merged);
}

- (CGPathRef)newOutlineForPrimitive:(IJSVGFilterPrimitive*)primitive region:(CGRect)region inputNamed:(id (^)(NSString*))inputNamed
{
    id input = inputNamed(primitive.input);
    id other = inputNamed(primitive.input2);
    if (input == nil || other == nil) {
        return NULL;
    }
    CGPathRef a = (__bridge CGPathRef)input;
    CGPathRef b = (__bridge CGPathRef)other;
    switch (primitive.type) {
        case IJSVGNodeTypeFilterGaussianBlur:
        case IJSVGNodeTypeFilterDropShadow:
            return [self newBlurOutline:a primitive:primitive];
        case IJSVGNodeTypeFilterOffset:
            return [self newOffsetOutline:a primitive:primitive defaultValue:0];
        case IJSVGNodeTypeFilterFlood:
            return [self outlineFloodIsVisible:primitive] ? CGPathCreateWithRect(region, NULL) : CGPathCreateMutable();
        case IJSVGNodeTypeFilterColorMatrix:
            return [self newColorMatrixOutline:a primitive:primitive region:region];
        case IJSVGNodeTypeFilterBlend:
            return CGPathCreateCopyByUnioningPath(a, b, false);
        case IJSVGNodeTypeFilterComposite:
            return [self newCompositeOutline:a other:b primitive:primitive region:region];
        case IJSVGNodeTypeFilterMerge:
            return [self newMergedOutline:primitive inputNamed:inputNamed];
        default:
            return NULL;
    }
}

+ (BOOL)canOutlineMetadata:(IJSVGFilterMetadata*)metadata backgroundIsEmpty:(BOOL)backgroundIsEmpty
{
    IJSVGFilterInputs names = metadata.inputs;
    if ((!backgroundIsEmpty && ((names & IJSVGFilterInputBackgroundImage) || (names & IJSVGFilterInputBackgroundAlpha))) || (names & IJSVGFilterInputFillPaint) || (names & IJSVGFilterInputStrokePaint)) {
        return NO;
    }
    for (IJSVGFilterPrimitive* primitive in metadata.primitives) {
        switch (primitive.type) {
            case IJSVGNodeTypeFilterGaussianBlur:
                if (primitive.edgeMode == IJSVGFilterEdgeModeWrap || primitive.edgeMode == IJSVGFilterEdgeModeDuplicate) {
                    return NO;
                }
                break;
            case IJSVGNodeTypeFilterDropShadow:
            case IJSVGNodeTypeFilterOffset:
            case IJSVGNodeTypeFilterFlood:
            case IJSVGNodeTypeFilterColorMatrix:
            case IJSVGNodeTypeFilterBlend:
            case IJSVGNodeTypeFilterComposite:
            case IJSVGNodeTypeFilterMerge:
                break;
            default:
                return NO;
        }
    }
    return YES;
}

- (CGPathRef)newOutlineForSourcePath:(CGPathRef)source backgroundIsEmpty:(BOOL)backgroundIsEmpty
{
    CGRect region = [self regionForNode:self.filter units:self.filter.units defaultRegion:CGRectZero];
    if (!IJSVGFilterValidRect(region)) {
        return CGPathCreateMutable();
    }
    id clippedSource = CFBridgingRelease(IJSVGOutlineClip(source, region));
    if (clippedSource == nil) {
        return NULL;
    }
    if (self.filter.preservesInnerShadowCoverage) {
        return CGPathCreateCopy((__bridge CGPathRef)clippedSource);
    }
    if (backgroundIsEmpty && IJSVGFilterSIMDUsesBackdropAddition(self.filter)) {
        IJSVGFilterPrimitive* primitive = self.filterPrimitives.firstObject;
        CGRect primitiveRegion = [self regionForNode:primitive units:self.filter.contentUnits defaultRegion:region];
        return IJSVGOutlineClip((__bridge CGPathRef)clippedSource, primitiveRegion);
    }
    NSMutableDictionary<NSString*, id>* results = [[NSMutableDictionary alloc] initWithCapacity:self.filterPrimitives.count];
    IJSVGFilterInputs inputNames = self.filterInputs;
    BOOL needsBackground = (inputNames & IJSVGFilterInputBackgroundImage) || (inputNames & IJSVGFilterInputBackgroundAlpha);
    id background = backgroundIsEmpty && needsBackground ? CFBridgingRelease(CGPathCreateMutable()) : nil;
    __block id output = clippedSource;
    id (^inputNamed)(NSString*) = ^id(NSString* name) {
        if (name.length == 0) {
            return output;
        }

        // Match the transparent backdrop supplied by the renderer outside a
        // background scope.
        if ([name isEqualToString:IJSVGStringBackgroundImage] || [name isEqualToString:IJSVGStringBackgroundAlpha]) {
            return background;
        }

        // These inputs require paint server sampling.
        if ([name isEqualToString:IJSVGStringFillPaint] || [name isEqualToString:IJSVGStringStrokePaint]) {
            return nil;
        }
        if ([name isEqualToString:IJSVGStringSourceGraphic] || [name isEqualToString:IJSVGStringSourceAlpha]) {
            return clippedSource;
        }
        return results[name] ?: output;
    };
    for (IJSVGFilterPrimitive* primitive in self.filterPrimitives) {
        CGPathRef next = [self newOutlineForPrimitive:primitive region:region inputNamed:inputNamed];
        if (next == NULL) {
            return NULL;
        }

        // Use the filter region as a conservative default for primitive subregions.
        // Explicit regions use the same unit resolver as rendered filters.
        CGRect primitiveRegion = [self regionForNode:primitive units:self.filter.contentUnits defaultRegion:region];
        output = CFBridgingRelease(IJSVGOutlineClip(next, CGRectIntersection(region, primitiveRegion)));
        CGPathRelease(next);
        if (output == nil) {
            return NULL;
        }
        if (primitive.result.length != 0) {
            results[primitive.result] = output;
        }
    }
    return CGPathCreateCopy((__bridge CGPathRef)output);
}

@end
