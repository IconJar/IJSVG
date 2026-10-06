//
//  IJSVGTextPathMetrics.m
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTextPathMetrics.h>
#import <math.h>
#import <stdlib.h>

// Adaptive subdivision produces a distance table once per referenced path.
typedef struct {
    CGPoint a;
    CGPoint b;
    CGFloat start;
    CGFloat length;
} IJSVGTextPathSegment;

typedef struct {
    IJSVGTextPathSegment* segments;
    NSUInteger count;
    NSUInteger capacity;
    CGPoint current;
    CGPoint start;
    CGFloat length;
    NSUInteger subpaths;
    BOOL closed;
} IJSVGTextPathBuilder;

@interface IJSVGTextPathMetrics () {
    NSData* _segments;
    const IJSVGTextPathSegment* _segmentBytes;
    NSUInteger _segmentCount;
}

@end

static CGPoint IJSVGTextMidpoint(CGPoint a, CGPoint b)
{
    return CGPointMake((a.x + b.x) * .5, (a.y + b.y) * .5);
}

static void IJSVGTextPathAddLine(IJSVGTextPathBuilder* builder, CGPoint end)
{
    CGPoint current = builder->current;
    CGFloat length = hypot(end.x - current.x, end.y - current.y);
    if(length > 0 && isfinite(length)) {
        IJSVGTextPathSegment segment = { current, end, builder->length, length };
        if(builder->count == builder->capacity) {
            NSUInteger maximum = SIZE_MAX / sizeof(IJSVGTextPathSegment);
            if(builder->capacity > maximum / 2) {
                free(builder->segments);
                builder->segments = NULL;
                [NSException raise:NSMallocException
                            format:@"Text path segment capacity overflow"];
            }
            NSUInteger capacity = builder->capacity == 0 ? 64 : builder->capacity * 2;
            IJSVGTextPathSegment* segments = realloc(builder->segments,
                                                     capacity * sizeof(IJSVGTextPathSegment));
            if(segments == NULL) {
                free(builder->segments);
                builder->segments = NULL;
                [NSException raise:NSMallocException
                            format:@"Unable to allocate text path segments"];
            }
            builder->segments = segments;
            builder->capacity = capacity;
        }
        builder->segments[builder->count++] = segment;
        builder->length += length;
    }
    builder->current = end;
}

static void IJSVGTextPathAddCurve(IJSVGTextPathBuilder* builder, CGPoint a,
                                  CGPoint b, CGPoint c, CGPoint d,
                                  NSUInteger depth)
{
    CGFloat chord = hypot(d.x - a.x, d.y - a.y);
    CGFloat firstEdge = hypot(b.x - a.x, b.y - a.y);
    CGFloat middleEdge = hypot(c.x - b.x, c.y - b.y);
    CGFloat lastEdge = hypot(d.x - c.x, d.y - c.y);
    CGFloat polygon = firstEdge + middleEdge + lastEdge;
    // Stop splitting once the curve is close enough to a straight line.
    if(depth == 16 || polygon - chord <= .00001) {
        IJSVGTextPathAddLine(builder, d);
        return;
    }
    CGPoint ab = IJSVGTextMidpoint(a, b), bc = IJSVGTextMidpoint(b, c);
    CGPoint cd = IJSVGTextMidpoint(c, d);
    CGPoint abc = IJSVGTextMidpoint(ab, bc), bcd = IJSVGTextMidpoint(bc, cd);
    CGPoint middle = IJSVGTextMidpoint(abc, bcd);
    IJSVGTextPathAddCurve(builder, a, ab, abc, middle, depth + 1);
    IJSVGTextPathAddCurve(builder, middle, bcd, cd, d, depth + 1);
}

static void IJSVGTextPathApply(void* context, const CGPathElement* element)
{
    IJSVGTextPathBuilder* builder = context;
    CGPoint* p = element->points;
    switch(element->type) {
        case kCGPathElementMoveToPoint:
            builder->current = builder->start = p[0];
            builder->subpaths++;
            break;
        case kCGPathElementAddLineToPoint:
            IJSVGTextPathAddLine(builder, p[0]);
            break;
        case kCGPathElementAddQuadCurveToPoint: {
            CGPoint a = builder->current;
            CGPoint b = CGPointMake(a.x + (p[0].x - a.x) * 2. / 3.,
                                    a.y + (p[0].y - a.y) * 2. / 3.);
            CGPoint c = CGPointMake(p[1].x + (p[0].x - p[1].x) * 2. / 3.,
                                    p[1].y + (p[0].y - p[1].y) * 2. / 3.);
            IJSVGTextPathAddCurve(builder, a, b, c, p[1], 0);
            break;
        }
        case kCGPathElementAddCurveToPoint:
            IJSVGTextPathAddCurve(builder, builder->current, p[0], p[1], p[2],
                                  0);
            break;
        case kCGPathElementCloseSubpath:
            IJSVGTextPathAddLine(builder, builder->start);
            builder->closed = YES;
            break;
    }
}

@implementation IJSVGTextPathMetrics

- (instancetype)initWithPath:(CGPathRef)path
{
    if((self = [super init])) {
        IJSVGTextPathBuilder builder = { 0 };
        if(path != NULL) {
            CGPathApply(path, &builder, IJSVGTextPathApply);
        }
        NSUInteger length = builder.count * sizeof(IJSVGTextPathSegment);
        // Give back unused space after the segment table is complete.
        if(builder.count != 0 && builder.count < builder.capacity) {
            void* segments = realloc(builder.segments, length);
            if(segments != NULL) {
                builder.segments = segments;
            }
        }
        // Let NSData own the buffer without copying the segments.
        _segments = [[NSData alloc] initWithBytesNoCopy:builder.segments
                                                 length:length
                                           freeWhenDone:YES];
        _segmentBytes = _segments.bytes;
        _segmentCount = builder.count;
        _length = builder.length;
        _closed = builder.closed && builder.subpaths == 1;
    }
    return self;
}

- (BOOL)pointAt:(CGFloat)distance
          point:(CGPoint*)point
        tangent:(CGPoint*)tangent
{
    NSUInteger count = _segmentCount;
    if(count == 0 || !isfinite(distance)) {
        return NO;
    }
    distance = MAX(0, MIN(_length, distance));
    const IJSVGTextPathSegment* segments = _segmentBytes;
    // Find the segment containing this distance along the path.
    NSUInteger low = 0, high = count;
    while(low + 1 < high) {
        NSUInteger mid = (low + high) / 2;
        if(segments[mid].start <= distance) {
            low = mid;
        } else {
            high = mid;
        }
    }
    IJSVGTextPathSegment s = segments[low];
    CGFloat t = (distance - s.start) / s.length;
    *tangent = CGPointMake((s.b.x - s.a.x) / s.length,
                           (s.b.y - s.a.y) / s.length);
    *point = CGPointMake(s.a.x + (s.b.x - s.a.x) * t,
                         s.a.y + (s.b.y - s.a.y) * t);
    return YES;
}

@end

