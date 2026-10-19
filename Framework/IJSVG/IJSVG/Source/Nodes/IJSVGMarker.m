//
//  IJSVGMarker.m
//  IJSVG
//
//  Created by Curtis Hard on 09/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGCommandParser.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGMarker

- (IJSVGNodeTypeTraits)nodeTraits
{
    return IJSVGNodeTypeTraitPaint | IJSVGNodeTypeTraitGraphics | IJSVGNodeTypeTraitViewport | IJSVGNodeTypeTraitGroup | IJSVGNodeTypeTraitMarker;
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeMarker;
}

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        _refX = IJSVGZeroUnitLength;
        _refY = IJSVGZeroUnitLength;
        _markerWidth = IJSVGThreeUnitLength;
        _markerHeight = IJSVGThreeUnitLength;
        _markerUnits = IJSVGMarkerUnitsStrokeWidth;
        _orientType = IJSVGMarkerOrientTypeAngle;
        self.overflowVisibility = IJSVGOverflowVisibilityHidden;
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGMarker* marker = [super copyWithZone:zone];
    marker.refX = _refX.copy;
    marker.refY = _refY.copy;
    marker.markerWidth = _markerWidth.copy;
    marker.markerHeight = _markerHeight.copy;
    marker.markerUnits = _markerUnits;
    marker.orientType = _orientType;
    marker.orientAngle = _orientAngle;
    return marker;
}

@end

@implementation IJSVGMarkerPosition
@end

@interface IJSVGMarkerSegment : NSObject

@property (nonatomic, assign) CGPoint start;
@property (nonatomic, assign) CGPoint end;
@property (nonatomic, assign) CGPoint outgoing;
@property (nonatomic, assign) CGPoint incoming;

@end

@implementation IJSVGMarkerSegment
@end

@interface IJSVGMarkerSubpath : NSObject

@property (nonatomic, assign) CGPoint start;
@property (nonatomic, assign) BOOL closed;
@property (nonatomic, strong) NSMutableArray<IJSVGMarkerSegment*>* segments;

@end
@implementation IJSVGMarkerSubpath

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        _segments = [[NSMutableArray alloc] init];
    }
    return self;
}

@end

static CGPoint IJSVGMarkerVector(CGPoint from, CGPoint to)
{
    return CGPointMake(to.x - from.x, to.y - from.y);
}

static BOOL IJSVGMarkerVectorIsZero(CGPoint vector)
{
    return vector.x == 0 && vector.y == 0;
}

static IJSVGMarkerSegment* IJSVGMarkerSegmentForElement(const CGPathElement* element, CGPoint start, CGPoint subpathStart)
{
    IJSVGMarkerSegment* segment = [[IJSVGMarkerSegment alloc] init];
    segment.start = start;
    switch (element->type) {
        case kCGPathElementAddLineToPoint:
            segment.end = element->points[0];
            segment.outgoing = segment.incoming = IJSVGMarkerVector(start, segment.end);
            break;
        case kCGPathElementCloseSubpath:
            segment.end = subpathStart;
            segment.outgoing = segment.incoming = IJSVGMarkerVector(start, subpathStart);
            break;
        case kCGPathElementAddQuadCurveToPoint:
            segment.end = element->points[1];
            segment.outgoing = IJSVGMarkerVector(start, element->points[0]);
            segment.incoming = IJSVGMarkerVector(element->points[0], segment.end);
            if (IJSVGMarkerVectorIsZero(segment.outgoing)) {
                segment.outgoing = IJSVGMarkerVector(start, segment.end);
            }
            if (IJSVGMarkerVectorIsZero(segment.incoming)) {
                segment.incoming = IJSVGMarkerVector(start, segment.end);
            }
            break;
        case kCGPathElementAddCurveToPoint:
            segment.end = element->points[2];
            segment.outgoing = IJSVGMarkerVector(start, element->points[0]);
            if (IJSVGMarkerVectorIsZero(segment.outgoing)) {
                segment.outgoing = IJSVGMarkerVector(start, element->points[1]);
            }
            if (IJSVGMarkerVectorIsZero(segment.outgoing)) {
                segment.outgoing = IJSVGMarkerVector(start, segment.end);
            }
            segment.incoming = IJSVGMarkerVector(element->points[1], segment.end);
            if (IJSVGMarkerVectorIsZero(segment.incoming)) {
                segment.incoming = IJSVGMarkerVector(element->points[0], segment.end);
            }
            if (IJSVGMarkerVectorIsZero(segment.incoming)) {
                segment.incoming = IJSVGMarkerVector(start, segment.end);
            }
            break;
        default:
            return nil;
    }
    return segment;
}

// Find a direction through zero length segments without crossing a moveto.
static CGPoint IJSVGMarkerDirection(IJSVGMarkerSubpath* subpath, NSInteger index, BOOL incoming)
{
    NSInteger count = subpath.segments.count;
    for (NSInteger step = 0; step < count; step++, index += incoming ? -1 : 1) {
        if (index < 0 || index >= count) {
            if (!subpath.closed) {
                break;
            }
            index = (index + count) % count;
        }
        IJSVGMarkerSegment* segment = subpath.segments[index];
        CGPoint vector = incoming ? segment.incoming : segment.outgoing;
        if (!IJSVGMarkerVectorIsZero(vector)) {
            return vector;
        }
    }
    return CGPointZero;
}

static void IJSVGMarkerResolveDirections(IJSVGMarkerSubpath* subpath)
{
    CGPoint incoming = subpath.closed ? IJSVGMarkerDirection(subpath, -1, YES) : CGPointZero;
    for (IJSVGMarkerSegment* segment in subpath.segments) {
        if (IJSVGMarkerVectorIsZero(segment.incoming)) {
            segment.incoming = incoming;
        } else {
            incoming = segment.incoming;
        }
    }
    CGPoint outgoing = subpath.closed ? IJSVGMarkerDirection(subpath, 0, NO) : CGPointZero;
    for (IJSVGMarkerSegment* segment in subpath.segments.reverseObjectEnumerator) {
        if (IJSVGMarkerVectorIsZero(segment.outgoing)) {
            segment.outgoing = outgoing;
        } else {
            outgoing = segment.outgoing;
        }
    }
}

static CGFloat IJSVGMarkerAngle(CGPoint incoming, CGPoint outgoing)
{
    if (IJSVGMarkerVectorIsZero(incoming)) {
        incoming = outgoing;
    }
    if (IJSVGMarkerVectorIsZero(outgoing)) {
        outgoing = incoming;
    }
    CGFloat a = atan2(incoming.y, incoming.x);
    CGFloat b = atan2(outgoing.y, outgoing.x);
    CGFloat difference = b - a;
    if (difference > M_PI) {
        difference -= 2 * M_PI;
    }
    if (difference < -M_PI) {
        difference += 2 * M_PI;
    }
    return (a + difference * .5) * 180 / M_PI;
}

NSArray<IJSVGMarkerPosition*>* IJSVGMarkerPositions(CGPathRef path, NSString* sourceData)
{
    NSMutableArray<IJSVGMarkerSubpath*>* subpaths = [[NSMutableArray alloc] init];
    __block IJSVGMarkerSubpath* subpath = nil;
    __block CGPoint current = CGPointZero;
    void (^move)(CGPoint) = ^(CGPoint point) {
        subpath = [[IJSVGMarkerSubpath alloc] init];
        subpath.start = current = point;
        [subpaths addObject:subpath];
    };
    if (sourceData != nil) {
        IJSVGEnumeratePathDataSegments(sourceData, ^(char command, CGPathRef segmentPath) {
            if (command == 'm') {
                move(CGPathGetCurrentPoint(segmentPath));
                return;
            }
            if (subpath == nil) {
                move(CGPointZero);
            }
            __block CGPoint point = current;
            __block IJSVGMarkerSegment* combined = nil;
            __block BOOL arcHasCurve = NO;
            CGPathApplyWithBlock(segmentPath, ^(const CGPathElement* element) {
                if (element->type == kCGPathElementMoveToPoint) {
                    point = element->points[0];
                    return;
                }
                IJSVGMarkerSegment* part = IJSVGMarkerSegmentForElement(element, point, subpath.start);
                if (part == nil) {
                    return;
                }
                if (combined == nil) {
                    combined = part;
                } else {
                    combined.end = part.end;
                    combined.incoming = part.incoming;
                }

                // CGPathAddRelativeArc may insert a zero length connecting line.
                // Its direction is not the arcs start tangent.
                if (command == 'a' && element->type == kCGPathElementAddCurveToPoint && !arcHasCurve) {
                    combined.outgoing = part.outgoing;
                    arcHasCurve = YES;
                }
                point = part.end;
            });
            if (combined != nil) {
                [subpath.segments addObject:combined];
                current = combined.end;
                subpath.closed = command == 'z';
            }
        });
    } else {
        CGPathApplyWithBlock(path, ^(const CGPathElement* element) {
            if (element->type == kCGPathElementMoveToPoint) {
                move(element->points[0]);
                return;
            }
            if (subpath == nil) {
                move(CGPointZero);
            }
            IJSVGMarkerSegment* segment = IJSVGMarkerSegmentForElement(element, current, subpath.start);
            if (segment != nil) {
                [subpath.segments addObject:segment];
                current = segment.end;
                subpath.closed = element->type == kCGPathElementCloseSubpath;
            }
        });
    }

    NSUInteger positionCount = 0;
    for (IJSVGMarkerSubpath* part in subpaths) {
        positionCount += part.segments.count + 1;
    }
    if (positionCount == 1) {
        positionCount = 2;
    }
    NSMutableArray<IJSVGMarkerPosition*>* positions = [[NSMutableArray alloc] initWithCapacity:positionCount];
    for (IJSVGMarkerSubpath* part in subpaths) {
        NSUInteger count = part.segments.count;
        IJSVGMarkerResolveDirections(part);
        for (NSUInteger index = 0; index <= count; index++) {
            IJSVGMarkerPosition* position = [[IJSVGMarkerPosition alloc] init];
            position.point = index == 0 ? part.start : part.segments[index - 1].end;
            CGPoint incoming = index > 0 ? part.segments[index - 1].incoming : (part.closed ? part.segments.lastObject.incoming : CGPointZero);
            CGPoint outgoing = index < count ? part.segments[index].outgoing : (part.closed ? part.segments.firstObject.outgoing : CGPointZero);
            position.angle = IJSVGMarkerAngle(incoming, outgoing);
            position.type = IJSVGMarkerPositionMid;
            [positions addObject:position];
        }
    }
    positions.firstObject.type = IJSVGMarkerPositionStart;
    if (positions.count == 1) {
        // A single vertex can carry both start and end markers.
        IJSVGMarkerPosition* end = [[IJSVGMarkerPosition alloc] init];
        end.point = positions.firstObject.point;
        end.angle = positions.firstObject.angle;
        [positions addObject:end];
    }
    positions.lastObject.type = IJSVGMarkerPositionEnd;
    return positions;
}

#pragma mark - Parsing

@implementation IJSVGMarker (Parsing)

- (IJSVGUnitLength*)markerLengthFromElement:(IJSVGXMLNode*)element attribute:(IJSVGNodeAttribute)attribute defaultValue:(IJSVGUnitLength*)defaultValue
{
    IJSVGXMLAttribute* value = IJSVGXMLAttributeForIdentifier(element, attribute);
    return value != NULL ? IJSVGUnitLengthFromXMLAttribute(value, IJSVGUnitUserSpaceOnUse) : defaultValue;
}

- (void)applyMarkerOrientation:(NSString*)orient toMarker:(IJSVGMarker*)marker
{
    marker.orientType = IJSVGMarkerOrientTypeFromString(orient);
    marker.orientAngle = IJSVGAngleFromString(orient);
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeViewBox];
    [attributes setBit:IJSVGNodeAttributePreserveAspectRatio];
    [attributes setBit:IJSVGNodeAttributeRefX];
    [attributes setBit:IJSVGNodeAttributeRefY];
    [attributes setBit:IJSVGNodeAttributeMarkerWidth];
    [attributes setBit:IJSVGNodeAttributeMarkerHeight];
    [attributes setBit:IJSVGNodeAttributeMarkerUnits];
    [attributes setBit:IJSVGNodeAttributeOrient];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
    IJSVGParsePathAttributes(self, context);
    NSString* geometryValue = nil;
    if (IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeX, &geometryValue)) {
        self.x = [IJSVGUnitLength unitWithString:geometryValue];
    }
    if (IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeY, &geometryValue)) {
        self.y = [IJSVGUnitLength unitWithString:geometryValue];
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
    self.refX = [self markerLengthFromElement:context->element attribute:IJSVGNodeAttributeRefX defaultValue:self.refX];
    self.refY = [self markerLengthFromElement:context->element attribute:IJSVGNodeAttributeRefY defaultValue:self.refY];
    self.markerWidth = [self markerLengthFromElement:context->element attribute:IJSVGNodeAttributeMarkerWidth defaultValue:self.markerWidth];
    self.markerHeight = [self markerLengthFromElement:context->element attribute:IJSVGNodeAttributeMarkerHeight defaultValue:self.markerHeight];
    IJSVGXMLAttribute* units = IJSVGXMLAttributeForIdentifier(context->element, IJSVGNodeAttributeMarkerUnits);
    self.markerUnits = IJSVGXMLAttributeEquals(units, "userSpaceOnUse") ? IJSVGMarkerUnitsUserSpaceOnUse : IJSVGMarkerUnitsStrokeWidth;
    IJSVGXMLAttribute* orientation = IJSVGXMLAttributeForIdentifier(context->element, IJSVGNodeAttributeOrient);
    if (IJSVGXMLAttributeEquals(orientation, "auto")) {
        self.orientType = IJSVGMarkerOrientTypeAuto;
        self.orientAngle = 0;
    } else if (IJSVGXMLAttributeEquals(orientation, "auto-start-reverse")) {
        self.orientType = IJSVGMarkerOrientTypeAutoStartReverse;
        self.orientAngle = 0;
    } else {
        IJSVGUnitLength* angle = orientation == NULL ? nil : IJSVGScalarLengthFromBytes(IJSVGXMLAttributeBytes(orientation), orientation->value.length, YES, IJSVGUnitUserSpaceOnUse);
        if (angle != nil && angle.originalType == IJSVGUnitLengthTypeNumber) {
            self.orientType = IJSVGMarkerOrientTypeAngle;
            self.orientAngle = angle.value;
        } else {
            [self applyMarkerOrientation:IJSVGXMLAttributeValue(orientation) toMarker:self];
        }
    }
    self.shouldRender = YES; // SVG 1.1: display does not apply to self.
}

@end
