//
//  IJSVGGradient.m
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGStyle.h>
#import <IJSVG/IJSVGUtils.h>

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
    if(function->reflect && fmod(fabs(cycle), 2.f) >= 1.f) {
        position = 1.f - position;
    }
    NSUInteger upper = 0;
    while(upper < function->count && function->stops[upper].offset <= position) {
        upper++;
    }
    NSUInteger lower = upper == 0 ? 0 : upper - 1;
    upper = MIN(upper, function->count - 1);
    IJSVGSpreadStop first = function->stops[lower];
    IJSVGSpreadStop last = function->stops[upper];
    CGFloat fraction = last.offset > first.offset ?
        MAX(0.f, MIN(1.f, (position - first.offset) / (last.offset - first.offset))) : 0.f;
    for(NSUInteger channel = 0; channel < 4; channel++) {
        output[channel] = first.components[channel] +
            fraction * (last.components[channel] - first.components[channel]);
    }
}

static CGGradientRef IJSVGCreateSpreadGradient(IJSVGSpreadFunction* function)
{
    CGFloat firstCycle = floor(function->minimum);
    CGFloat lastCycle = floor(function->maximum);
    CGFloat cycles = lastCycle - firstCycle + 1.f;
    // Keep storage bounded for subpixel periods. The function shading below
    // handles those without allocating one set of stops for every repetition.
    if(cycles * (function->count + 2) > 65536.f) {
        return NULL;
    }
    NSUInteger capacity = (NSUInteger)cycles * (function->count + 2) + 2;
    CGFloat* components = calloc(capacity * 4, sizeof(CGFloat));
    CGFloat* locations = calloc(capacity, sizeof(CGFloat));
    if(components == NULL || locations == NULL) {
        free(components);
        free(locations);
        return NULL;
    }
    CGFloat input = 0.f;
    IJSVGEvaluateSpread(function, &input, components);
    NSUInteger count = 1;
    CGFloat extent = function->maximum - function->minimum;
    for(NSUInteger cycleIndex = 0; cycleIndex < (NSUInteger)cycles; cycleIndex++) {
        CGFloat cycle = firstCycle + cycleIndex;
        BOOL reversed = function->reflect && fmod(fabs(cycle), 2.f) >= 1.f;
        for(NSUInteger index = 0; index < function->count + 2; index++) {
            // Explicit endpoint stops preserve padding before/after the
            // supplied stops, and the discontinuity between repeated cycles.
            NSUInteger stopIndex = index == 0 ? 0 : MIN(index - 1, function->count - 1);
            CGFloat offset = index == 0 ? 0.f :
                (index == function->count + 1 ? 1.f : function->stops[stopIndex].offset);
            if(reversed) {
                stopIndex = function->count - 1 - stopIndex;
                offset = index == 0 ? 0.f :
                    (index == function->count + 1 ? 1.f : 1.f - function->stops[stopIndex].offset);
            }
            CGFloat position = cycle + offset;
            if(position < function->minimum || position > function->maximum) {
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
    CGGradientRef gradient = CGGradientCreateWithColorComponents(
        IJSVGColor.defaultColorSpace.CGColorSpace, components, locations, count);
    free(components);
    free(locations);
    return gradient;
}

@implementation IJSVGGradient

- (void)parseSpreadMethod:(NSXMLElement*)element
{
    const char* value = [element attributeForName:IJSVGAttributeSpreadMethod].stringValue.UTF8String;
    self.spreadMethod = IJSVGGradientSpreadMethodPad;
    if(value != NULL) {
        if(IJSVGCharBufferCompare(value, "reflect")) {
            self.spreadMethod = IJSVGGradientSpreadMethodReflect;
        } else if(IJSVGCharBufferCompare(value, "repeat")) {
            self.spreadMethod = IJSVGGradientSpreadMethodRepeat;
        }
    }
}

- (BOOL)drawSpreadInContext:(CGContextRef)ctx
                startPoint:(CGPoint)start
                  endPoint:(CGPoint)end
               startRadius:(CGFloat)startRadius
                 endRadius:(CGFloat)endRadius
                    radial:(BOOL)radial
{
    if(self.spreadMethod == IJSVGGradientSpreadMethodPad || self.colors.count == 0) {
        return NO;
    }
    CGRect clip = CGContextGetClipBoundingBox(ctx);
    if(CGRectIsEmpty(clip) || CGRectIsInfinite(clip)) {
        return YES;
    }
    CGPoint delta = CGPointMake(end.x - start.x, end.y - start.y);
    CGFloat lengthSquared = delta.x * delta.x + delta.y * delta.y;
    CGFloat radiusDelta = endRadius - startRadius;
    CGFloat minimum = CGFLOAT_MAX;
    CGFloat maximum = -CGFLOAT_MAX;
    CGFloat distance = 0.f;
    CGPoint corners[] = {
        CGPointMake(CGRectGetMinX(clip), CGRectGetMinY(clip)),
        CGPointMake(CGRectGetMaxX(clip), CGRectGetMinY(clip)),
        CGPointMake(CGRectGetMinX(clip), CGRectGetMaxY(clip)),
        CGPointMake(CGRectGetMaxX(clip), CGRectGetMaxY(clip))
    };
    for(NSUInteger index = 0; index < 4; index++) {
        CGPoint point = CGPointMake(corners[index].x - start.x, corners[index].y - start.y);
        distance = MAX(distance, hypot(point.x, point.y));
        if(!radial && lengthSquared > 0.f) {
            CGFloat position = (point.x * delta.x + point.y * delta.y) / lengthSquared;
            minimum = MIN(minimum, position);
            maximum = MAX(maximum, position);
        }
    }
    if(radial) {
        // Bound both roots of |P - (F + tD)|² = (fr + t(r-fr))².
        // This also covers displaced focal circles and shrinking gradients.
        CGFloat coefficient = fabs(lengthSquared - radiusDelta * radiusDelta);
        if(coefficient == 0.f) {
            // Tangent cones can have an unbounded parameter over a finite clip.
            return NO;
        }
        CGFloat linear = 2.f * (distance * sqrt(lengthSquared) + fabs(startRadius * radiusDelta));
        CGFloat constant = distance * distance + startRadius * startRadius;
        CGFloat bound = (linear + sqrt(linear * linear + 4.f * coefficient * constant)) /
            (2.f * coefficient);
        minimum = -bound;
        maximum = bound;
        if(radiusDelta > 0.f) {
            minimum = MAX(minimum, -startRadius / radiusDelta);
        } else if(radiusDelta < 0.f) {
            maximum = MIN(maximum, -startRadius / radiusDelta);
        }
    } else if(lengthSquared == 0.f) {
        // SVG defines coincident linear endpoints as the final stop color.
        CGContextSetFillColorWithColor(ctx, self.colors.lastObject.CGColor);
        CGContextFillRect(ctx, clip);
        return YES;
    }
    if(!isfinite(minimum) || !isfinite(maximum) || maximum <= minimum) {
        return NO;
    }
    NSUInteger count = MIN(self.numberOfStops, self.colors.count);
    if(count == 0) {
        return YES;
    }
    IJSVGSpreadFunction* data = calloc(1, sizeof(IJSVGSpreadFunction) + count * sizeof(IJSVGSpreadStop));
    if(data == NULL) {
        return NO;
    }
    data->minimum = minimum;
    data->maximum = maximum;
    data->reflect = self.spreadMethod == IJSVGGradientSpreadMethodReflect;
    data->count = count;
    CGFloat previous = 0.f;
    for(NSUInteger index = 0; index < count; index++) {
        CGFloat offset = self.locations != NULL ? self.locations[index] :
            (count > 1 ? (CGFloat)index / (count - 1) : 0.f);
        data->stops[index].offset = previous = MAX(previous, MIN(1.f, offset));
        NSColor* color = [self.colors[index] colorUsingColorSpace:IJSVGColor.defaultColorSpace];
        [color getRed:&data->stops[index].components[0]
                green:&data->stops[index].components[1]
                 blue:&data->stops[index].components[2]
                alpha:&data->stops[index].components[3]];
    }
    CGPoint first = CGPointMake(start.x + minimum * delta.x, start.y + minimum * delta.y);
    CGPoint last = CGPointMake(start.x + maximum * delta.x, start.y + maximum * delta.y);
    CGGradientRef expanded = IJSVGCreateSpreadGradient(data);
    if(expanded != NULL) {
        if(radial) {
            CGContextDrawRadialGradient(ctx, expanded, first,
                MAX(0.f, startRadius + minimum * radiusDelta), last,
                MAX(0.f, startRadius + maximum * radiusDelta), 0);
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
    if(function == NULL) {
        free(data);
        return NO;
    }
    CGColorSpaceRef space = IJSVGColor.defaultColorSpace.CGColorSpace;
    CGShadingRef shading = radial ? CGShadingCreateRadial(space, first,
        MAX(0.f, startRadius + minimum * radiusDelta), last,
        MAX(0.f, startRadius + maximum * radiusDelta), function, NO, NO) :
        CGShadingCreateAxial(space, first, last, function, NO, NO);
    if(shading != NULL) {
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
    if(_CGGradient != NULL) {
        CGGradientRelease(_CGGradient);
        _CGGradient = NULL;
    }
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
    [storage addBits:[super allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeGradientUnits];
    [storage setBit:IJSVGNodeAttributeGradientTransform];
    return storage;
}

- (void)dealloc
{
    if(_locations != NULL) {
        (void)free(_locations), _locations = NULL;
    }
    [self _invalidateCGGradient];
}

- (void)applyPropertiesFromNode:(IJSVGGradient*)node
{
    [super applyPropertiesFromNode:node];
    self.numberOfStops = node.numberOfStops;
    self.spreadMethod = node.spreadMethod;
    self.colors = node.colors.copy;
    if(node.numberOfStops > 0 && node.locations != NULL) {
        size_t length = sizeof(CGFloat)*node.numberOfStops;
        self.locations = (CGFloat*)malloc(length);
        memcpy(self.locations, node.locations, length);
    } else {
        self.locations = NULL;
    }
    self.x1 = node.x1.copy;
    self.x2 = node.x2.copy;
    self.y1 = node.y1.copy;
    self.y2 = node.y2.copy;
}

- (BOOL)containsRelativeUnits
{
    return self.x1.isRelativeUnit == YES || self.x2.isRelativeUnit == YES ||
        self.y1.isRelativeUnit == YES || self.y2.isRelativeUnit == YES ||
        [super containsRelativeUnits] == YES;
}

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style
                              matchingTraits:(IJSVGColorUsageTraits)traits
{
    IJSVGTraitedColorStorage* storage = [[IJSVGTraitedColorStorage alloc] init];
    for(NSColor* color in self.colors) {
        NSColor* replacement = [style.colors colorForColor:color
                                            matchingTraits:IJSVGColorUsageTraitGradientStop];
        IJSVGTraitedColor* traited = nil;
        traited = [IJSVGTraitedColor colorWithColor:replacement ?: color
                                             traits:IJSVGColorUsageTraitGradientStop];
        [storage addColor:traited];
    }
    return storage;
}

- (void)setColors:(NSArray<NSColor*>*)colors
{
    _colors = colors;
    [self _invalidateCGGradient];
}

- (void)setLocations:(CGFloat*)locations
{
    if(_locations != NULL) {
        (void)free(_locations), _locations = NULL;
    }
    _locations = locations;
    [self _invalidateCGGradient];
}

+ (CGFloat*)computeColorStops:(IJSVGGradient*)gradient
                       colors:(NSArray**)someColors
{
    NSUInteger childCount = gradient.children.count;
    NSMutableArray* colors = [[NSMutableArray alloc] initWithCapacity:childCount];
    CGFloat* stopsParams = NULL;
    if(childCount != 0) {
        stopsParams = (CGFloat*)malloc(childCount * sizeof(CGFloat));
    }
    
    NSUInteger i = 0;
    for(IJSVGNode* stopNode in gradient.children) {
        if(stopNode.type != IJSVGNodeTypeStop) {
            continue;
        }
        NSColor* color = ((IJSVGColorNode*)(stopNode.fill)).color;
        CGFloat opacity = stopNode.fillOpacity.value;
        CGFloat offset = stopNode.offset.value;
        stopsParams[i++] = offset;
        if(color == nil) {
            color = [IJSVGColor colorFromHEXInteger:0x000000];
            if(opacity != 1.f) {
                color = [IJSVGColor changeAlphaOnColor:color
                                                    to:opacity];
            }
        }
        [colors addObject:color];
    }
    if(i == 0 && stopsParams != NULL) {
        (void)free(stopsParams), stopsParams = NULL;
    }
    *someColors = (NSArray*)colors;
    return stopsParams;
}

- (CGGradientRef)CGGradient
{
    // store it in the cache
    if(_CGGradient != nil) {
        return _CGGradient;
    }

    // actually create the gradient
    NSInteger num = self.numberOfStops;
    CFMutableArrayRef colors = CFArrayCreateMutable(kCFAllocatorDefault, (CFIndex)num,
        &kCFTypeArrayCallBacks);
    for (NSColor* color in _colors) {
        CFArrayAppendValue(colors, color.CGColor);
    }
    CGGradientRef result = CGGradientCreateWithColors(IJSVGColor.defaultColorSpace.CGColorSpace,
        colors, _locations);
    CFRelease(colors);
    return _CGGradient = result;
}

- (void)drawInContextRef:(CGContextRef)ctx
                  bounds:(NSRect)objectRect
               transform:(CGAffineTransform)absoluteTransform
{
}

@end
