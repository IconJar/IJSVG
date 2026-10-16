//
//  IJSVGGradient.m
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGStop.h>
#import <IJSVG/IJSVGStyle.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGGradientStops.h>
#import <IJSVGNodeParsing.h>
#import <IJSVGXML.h>
#include <string.h>

typedef struct {
    CGFloat offset;
    CGFloat components[4];
} IJSVGSpreadStop;

typedef struct {
    CGFloat minimum;
    CGFloat maximum;
    BOOL reflect;
    NSUInteger count;
    IJSVGSpreadStop stops[];
} IJSVGSpreadFunction;

static void IJSVGEvaluateSpread(void* info, const CGFloat* input, CGFloat* output)
{
    IJSVGSpreadFunction* function = info;
    CGFloat position = function->minimum + input[0] * (function->maximum - function->minimum);
    CGFloat cycle = floor(position);
    position -= cycle;
    if (function->reflect && fmod(fabs(cycle), 2.f) >= 1.f) {
        position = 1.f - position;
    }
    NSUInteger upper = 0;
    while (upper < function->count && function->stops[upper].offset <= position) {
        upper++;
    }
    NSUInteger lower = upper == 0 ? 0 : upper - 1;
    upper = MIN(upper, function->count - 1);
    IJSVGSpreadStop first = function->stops[lower];
    IJSVGSpreadStop last = function->stops[upper];
    CGFloat fraction = last.offset > first.offset ? MAX(0.f, MIN(1.f, (position - first.offset) / (last.offset - first.offset))) : 0.f;
    for (NSUInteger channel = 0; channel < 4; channel++) {
        output[channel] = first.components[channel] + fraction * (last.components[channel] - first.components[channel]);
    }
}

static void IJSVGLinearizeGradientComponents(CGFloat* components)
{
    for (NSUInteger channel = 0; channel < 3; channel++) {
        CGFloat value = components[channel];
        components[channel] = value <= .04045 ? value / 12.92 : pow((value + .055) / 1.055, 2.4);
    }
}

static CGGradientRef IJSVGCreateSpreadGradient(IJSVGSpreadFunction* function, CGColorSpaceRef colorSpace)
{
    CGFloat firstCycle = floor(function->minimum);
    CGFloat lastCycle = floor(function->maximum);
    CGFloat cycles = lastCycle - firstCycle + 1.f;

    // Keep storage bounded for subpixel periods. The function shading below
    // handles those without allocating one set of stops for every repetition.
    if (cycles * (function->count + 2) > 65536.f) {
        return NULL;
    }
    NSUInteger capacity = (NSUInteger)cycles * (function->count + 2) + 2;
    CGFloat* components = calloc(capacity * 4, sizeof(CGFloat));
    CGFloat* locations = calloc(capacity, sizeof(CGFloat));
    if (components == NULL || locations == NULL) {
        free(components);
        free(locations);
        return NULL;
    }
    CGFloat input = 0.f;
    IJSVGEvaluateSpread(function, &input, components);
    NSUInteger count = 1;
    CGFloat extent = function->maximum - function->minimum;
    for (NSUInteger cycleIndex = 0; cycleIndex < (NSUInteger)cycles; cycleIndex++) {
        CGFloat cycle = firstCycle + cycleIndex;
        BOOL reversed = function->reflect && fmod(fabs(cycle), 2.f) >= 1.f;
        for (NSUInteger index = 0; index < function->count + 2; index++) {
            // Explicit endpoint stops preserve padding before/after the
            // supplied stops, and the discontinuity between repeated cycles.
            NSUInteger stopIndex = index == 0 ? 0 : MIN(index - 1, function->count - 1);
            CGFloat offset = index == 0 ? 0.f : (index == function->count + 1 ? 1.f : function->stops[stopIndex].offset);
            if (reversed) {
                stopIndex = function->count - 1 - stopIndex;
                offset = index == 0 ? 0.f : (index == function->count + 1 ? 1.f : 1.f - function->stops[stopIndex].offset);
            }
            CGFloat position = cycle + offset;
            if (position < function->minimum || position > function->maximum) {
                continue;
            }
            locations[count] = (position - function->minimum) / extent;
            memcpy(components + count * 4, function->stops[stopIndex].components, 4 * sizeof(CGFloat));
            count++;
        }
    }
    input = 1.f;
    IJSVGEvaluateSpread(function, &input, components + count * 4);
    locations[count++] = 1.f;
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, count);
    free(components);
    free(locations);
    return gradient;
}

@implementation IJSVGGradient {
    IJSVGGradientStops* _deferredStopData;
    IJSVGGradientStops* _sharedGradientStops;
    BOOL _gradientIsLinear;
}

// Render colors and locations are already available. Keep editable stop nodes
// out of the rendering path until a caller inspects or changes the children.
- (void)deferStops:(IJSVGGradientStops*)stops
{
    if (_deferredStopData != nil || [super children].count != 0) {
        [self materializeStops];
        [stops appendStopsToGradient:self];
        return;
    }
    _deferredStopData = stops;
}

- (void)shareGradientWithStops:(IJSVGGradientStops*)stops
{
    [self _invalidateCGGradient];
    _sharedGradientStops = stops;
}

- (void)materializeStops
{
    IJSVGGradientStops* stops = _deferredStopData;
    if (stops == nil) {
        return;
    }

    // Clear first: appending the new children enters addChild: again.
    _deferredStopData = nil;
    [stops appendStopsToGradient:self];
}

- (NSArray<IJSVGNode*>*)children
{
    [self materializeStops];
    return [super children];
}

- (void)addChild:(IJSVGNode*)child
{
    [self materializeStops];
    [super addChild:child];
}

- (void)removeChild:(IJSVGNode*)child
{
    [self materializeStops];
    [super removeChild:child];
}

#pragma mark - Parsing

- (void)parseSpreadMethodFromAttributes:(IJSVGXMLAttributeList)attributes
{
    self.spreadMethod = IJSVGGradientSpreadMethodPad;
    IJSVGXMLAttributeList attributeIterator = attributes;
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&attributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&attributeIterator)) {
        if (attribute->identifier != IJSVGNodeAttributeSpreadMethod) {
            continue;
        }
        const char* value = IJSVGXMLAttributeBytes(attribute);
        if (attribute->value.length == 7 && memcmp(value, "reflect", 7) == 0) {
            self.spreadMethod = IJSVGGradientSpreadMethodReflect;
        } else if (attribute->value.length == 6 && memcmp(value, "repeat", 6) == 0) {
            self.spreadMethod = IJSVGGradientSpreadMethodRepeat;
        }
        break;
    }
}

#pragma mark - Drawing

- (BOOL)drawSpreadInContext:(CGContextRef)ctx startPoint:(CGPoint)start endPoint:(CGPoint)end startRadius:(CGFloat)startRadius endRadius:(CGFloat)endRadius radial:(BOOL)radial
{
    if (self.spreadMethod == IJSVGGradientSpreadMethodPad || self.colors.count == 0) {
        return NO;
    }
    CGRect clip = CGContextGetClipBoundingBox(ctx);
    if (CGRectIsEmpty(clip) || CGRectIsInfinite(clip)) {
        return YES;
    }
    CGPoint delta = CGPointMake(end.x - start.x, end.y - start.y);
    CGFloat lengthSquared = delta.x * delta.x + delta.y * delta.y;
    CGFloat radiusDelta = endRadius - startRadius;
    CGFloat minimum = CGFLOAT_MAX;
    CGFloat maximum = -CGFLOAT_MAX;
    CGFloat distance = 0.f;
    CGPoint corners[] = { CGPointMake(CGRectGetMinX(clip), CGRectGetMinY(clip)), CGPointMake(CGRectGetMaxX(clip), CGRectGetMinY(clip)), CGPointMake(CGRectGetMinX(clip), CGRectGetMaxY(clip)), CGPointMake(CGRectGetMaxX(clip), CGRectGetMaxY(clip)) };
    for (NSUInteger index = 0; index < 4; index++) {
        CGPoint point = CGPointMake(corners[index].x - start.x, corners[index].y - start.y);
        distance = MAX(distance, hypot(point.x, point.y));
        if (!radial && lengthSquared > 0.f) {
            CGFloat position = (point.x * delta.x + point.y * delta.y) / lengthSquared;
            minimum = MIN(minimum, position);
            maximum = MAX(maximum, position);
        }
    }
    if (radial) {
        // Bound both roots of the quadratic equation for the expanding gradient
        // circle. This also covers displaced focal circles and shrinking gradients.
        CGFloat coefficient = fabs(lengthSquared - radiusDelta * radiusDelta);
        if (coefficient == 0.f) {
            // Tangent cones can have an unbounded parameter over a finite clip.
            return NO;
        }
        CGFloat linear = 2.f * (distance * sqrt(lengthSquared) + fabs(startRadius * radiusDelta));
        CGFloat constant = distance * distance + startRadius * startRadius;
        CGFloat bound = (linear + sqrt(linear * linear + 4.f * coefficient * constant)) / (2.f * coefficient);
        minimum = -bound;
        maximum = bound;
        if (radiusDelta > 0.f) {
            minimum = MAX(minimum, -startRadius / radiusDelta);
        } else if (radiusDelta < 0.f) {
            maximum = MIN(maximum, -startRadius / radiusDelta);
        }
    } else if (lengthSquared == 0.f) {
        // SVG defines coincident linear endpoints as the final stop color.
        CGContextSetFillColorWithColor(ctx, (__bridge CGColorRef)self.colors.lastObject);
        CGContextFillRect(ctx, clip);
        return YES;
    }
    if (!isfinite(minimum) || !isfinite(maximum) || maximum <= minimum) {
        return NO;
    }
    NSUInteger count = MIN(self.numberOfStops, self.colors.count);
    if (count == 0) {
        return YES;
    }
    IJSVGSpreadFunction* data = calloc(1, sizeof(IJSVGSpreadFunction) + count * sizeof(IJSVGSpreadStop));
    if (data == NULL) {
        return NO;
    }
    data->minimum = minimum;
    data->maximum = maximum;
    data->reflect = self.spreadMethod == IJSVGGradientSpreadMethodReflect;
    data->count = count;
    BOOL linear = self.resolvedColorInterpolation == IJSVGColorInterpolationLinearRGB;
    CGColorSpaceRef colorSpace = linear ? IJSVGColor.linearRGBColorSpace : IJSVGColor.defaultColorSpace;
    CGFloat previous = 0.f;
    for (NSUInteger index = 0; index < count; index++) {
        CGFloat offset = self.locations != NULL ? self.locations[index] : (count > 1 ? (CGFloat)index / (count - 1) : 0.f);
        data->stops[index].offset = previous = MAX(previous, MIN(1.f, offset));
        CGColorRef color = [IJSVGColor computeColorSpace:(__bridge CGColorRef)self.colors[index]];
        if (color != NULL) {
            memcpy(data->stops[index].components, CGColorGetComponents(color), 4 * sizeof(CGFloat));
            if (linear) {
                IJSVGLinearizeGradientComponents(data->stops[index].components);
            }
        }
    }
    CGPoint first = CGPointMake(start.x + minimum * delta.x, start.y + minimum * delta.y);
    CGPoint last = CGPointMake(start.x + maximum * delta.x, start.y + maximum * delta.y);
    CGGradientRef expanded = IJSVGCreateSpreadGradient(data, colorSpace);
    if (expanded != NULL) {
        if (radial) {
            CGContextDrawRadialGradient(ctx, expanded, first, MAX(0.f, startRadius + minimum * radiusDelta), last, MAX(0.f, startRadius + maximum * radiusDelta), 0);
        } else {
            CGContextDrawLinearGradient(ctx, expanded, first, last, 0);
        }
        CGGradientRelease(expanded);
        free(data);
        return YES;
    }
    CGFloat domain[] = { 0.f, 1.f };
    CGFloat range[] = { 0.f, 1.f, 0.f, 1.f, 0.f, 1.f, 0.f, 1.f };
    CGFunctionCallbacks callbacks = { 0, IJSVGEvaluateSpread, free };
    CGFunctionRef function = CGFunctionCreate(data, 1, domain, 4, range, &callbacks);
    if (function == NULL) {
        free(data);
        return NO;
    }
    CGColorSpaceRef space = colorSpace;
    CGShadingRef shading = radial ? CGShadingCreateRadial(space, first, MAX(0.f, startRadius + minimum * radiusDelta), last, MAX(0.f, startRadius + maximum * radiusDelta), function, NO, NO) : CGShadingCreateAxial(space, first, last, function, NO, NO);
    if (shading != NULL) {
        CGContextDrawShading(ctx, shading);
        CGShadingRelease(shading);
    }
    CGFunctionRelease(function);
    return shading != NULL;
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeUnknown;
}

- (void)_invalidateCGGradient
{
    _sharedGradientStops = nil;
    if (_CGGradient != NULL) {
        CGGradientRelease(_CGGradient);
        _CGGradient = NULL;
    }
}

- (void)dealloc
{
    if (_locations != NULL) {
        (void)free(_locations), _locations = NULL;
    }
    [self _invalidateCGGradient];
}

- (void)applyPropertiesFromNode:(IJSVGGradient*)node
{
    [super applyPropertiesFromNode:node];

    // Group copying handles existing children. A deferred gradient has none
    // yet, so its copy can retain the immutable snapshot without expanding it.
    _deferredStopData = node->_deferredStopData;
    self.reference = node.reference;
    self.numberOfStops = node.numberOfStops;
    self.spreadMethod = node.spreadMethod;
    self.colors = node.colors.copy;
    if (node.numberOfStops > 0 && node.locations != NULL) {
        size_t length = sizeof(CGFloat) * node.numberOfStops;
        self.locations = (CGFloat*)malloc(length);
        memcpy(self.locations, node.locations, length);
    } else {
        self.locations = NULL;
    }
    _sharedGradientStops = node->_sharedGradientStops;
    _CGGradient = CGGradientRetain(node->_CGGradient);
    _gradientIsLinear = node->_gradientIsLinear;
    self.x1 = node.x1.copy;
    self.x2 = node.x2.copy;
    self.y1 = node.y1.copy;
    self.y2 = node.y2.copy;
}

- (BOOL)containsRelativeUnits
{
    return self.x1.isRelativeUnit == YES || self.x2.isRelativeUnit == YES || self.y1.isRelativeUnit == YES || self.y2.isRelativeUnit == YES || [super containsRelativeUnits] == YES;
}

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style matchingTraits:(IJSVGColorUsageTraits)traits
{
    IJSVGTraitedColorStorage* storage = [[IJSVGTraitedColorStorage alloc] init];
    for (id colorObject in self.colors) {
        CGColorRef color = (__bridge CGColorRef)colorObject;
        CGColorRef replacement = [style.colors colorForColor:color matchingTraits:IJSVGColorUsageTraitGradientStop];
        IJSVGTraitedColor* traited = nil;
        traited = [IJSVGTraitedColor colorWithColor:replacement ?: color traits:IJSVGColorUsageTraitGradientStop];
        [storage addColor:traited];
    }
    return storage;
}

- (void)setColors:(NSArray*)colors
{
    _colors = colors;
    [self _invalidateCGGradient];
}

- (void)setLocations:(CGFloat*)locations
{
    if (_locations == locations) {
        return;
    }
    if (_locations != NULL) {
        (void)free(_locations), _locations = NULL;
    }
    _locations = locations;
    [self _invalidateCGGradient];
}

+ (CGFloat*)computeColorStops:(IJSVGGradient*)gradient colors:(NSArray**)someColors
{
    NSUInteger childCount = gradient.children.count;
    NSMutableArray* colors = [[NSMutableArray alloc] initWithCapacity:childCount];
    CGFloat* stopsParams = NULL;
    if (childCount != 0) {
        stopsParams = (CGFloat*)malloc(childCount * sizeof(CGFloat));
    }

    NSUInteger i = 0;
    for (IJSVGStop* stopNode in gradient.children) {
        if (stopNode.type != IJSVGNodeTypeStop) {
            continue;
        }
        CGColorRef color = ((IJSVGColorNode*)(stopNode.fill)).color;
        CGFloat offset = stopNode.offset.value;
        stopsParams[i++] = offset;
        if (color == nil) {
            CGFloat opacity = stopNode.fillOpacity.value;
            color = [IJSVGColor colorFromHEXInteger:0x000000];
            if (opacity != 1.f) {
                color = [IJSVGColor changeAlphaOnColor:color to:opacity];
            }
        }
        [colors addObject:(__bridge id)color];
    }
    if (i == 0 && stopsParams != NULL) {
        (void)free(stopsParams), stopsParams = NULL;
    }
    *someColors = (NSArray*)colors;
    return stopsParams;
}

#pragma mark - Parsing

- (void)parseColorStops
{
    NSArray* colors = nil;
    CGFloat* locations = [IJSVGGradient computeColorStops:self colors:&colors];
    self.colors = colors;
    self.locations = locations;
    self.numberOfStops = colors.count;
}

#pragma mark - Drawing

- (CGGradientRef)CGGradient
{
    BOOL linear = self.resolvedColorInterpolation == IJSVGColorInterpolationLinearRGB;

    // Parent interpolation can change without changing the stop data.
    if (_CGGradient != NULL && _gradientIsLinear != linear) {
        CGGradientRelease(_CGGradient);
        _CGGradient = NULL;
    }
    _gradientIsLinear = linear;
    if (_CGGradient != nil) {
        return _CGGradient;
    }

    if (_sharedGradientStops != nil) {
        return _CGGradient = CGGradientRetain([_sharedGradientStops CGGradientForGradient:self]);
    }
    return _CGGradient = [self newCGGradient];
}

- (CGGradientRef)newCGGradient
{
    NSUInteger count = _colors.count;
    if (count == 0) {
        return NULL;
    }
    BOOL linear = self.resolvedColorInterpolation == IJSVGColorInterpolationLinearRGB;
    CGColorSpaceRef colorSpace = linear ? IJSVGColor.linearRGBColorSpace : IJSVGColor.defaultColorSpace;
    CGFloat stackComponents[32];
    CGFloat* components = count <= 8 ? stackComponents : calloc(count, 4 * sizeof(CGFloat));
    if (components != NULL) {
        BOOL converted = YES;
        NSUInteger index = 0;
        for (id colorObject in _colors) {
            CGColorRef color = (__bridge CGColorRef)colorObject;
            CGColorRef rgb = [IJSVGColor computeColorSpace:color];
            if (rgb == nil) {
                converted = NO;
                break;
            }
            memcpy(components + index * 4, CGColorGetComponents(rgb), 4 * sizeof(CGFloat));
            if (linear) {
                IJSVGLinearizeGradientComponents(components + index * 4);
            }
            index++;
        }
        CGGradientRef gradient = converted ? CGGradientCreateWithColorComponents(colorSpace, components, _locations, count) : NULL;
        if (components != stackComponents) {
            free(components);
        }
        if (gradient != NULL) {
            return gradient;
        }
    }

    // Preserve the existing path for colors that cannot expose RGB components.
    NSInteger num = self.numberOfStops;
    CFMutableArrayRef colors = CFArrayCreateMutable(kCFAllocatorDefault, (CFIndex)num, &kCFTypeArrayCallBacks);
    for (id colorObject in _colors) {
        CGColorRef color = (__bridge CGColorRef)colorObject;
        CFArrayAppendValue(colors, color);
    }
    CGGradientRef result = CGGradientCreateWithColors(colorSpace, colors, _locations);
    CFRelease(colors);
    return result;
}

- (void)drawInContextRef:(CGContextRef)ctx bounds:(NSRect)objectRect transform:(CGAffineTransform)absoluteTransform
{
}

@end

#pragma mark - Parsing

@implementation IJSVGGradient (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    [attributes setBit:IJSVGNodeAttributeGradientUnits];
    [attributes setBit:IJSVGNodeAttributeGradientTransform];
    IJSVGAddTextStyleAttributes(attributes);
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGradientAttributes(self, context);
}

@end
