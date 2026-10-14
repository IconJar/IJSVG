//
//  IJSVGClipPath.m
//  IJSVG
//
//  Created by Curtis Hard on 29/05/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGClipPath.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGText.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGCSSParser.h>
#import <IJSVGNodeParsing.h>
#import <IJSVGParserUtils.h>
#import <ctype.h>

typedef NS_ENUM(NSUInteger, IJSVGClipShape) {
    IJSVGClipShapeNone,
    IJSVGClipShapeBox,
    IJSVGClipShapeCircle,
    IJSVGClipShapeEllipse
};

typedef NS_ENUM(NSUInteger, IJSVGClipReferenceBox) {
    IJSVGClipReferenceBoxStroke,
    IJSVGClipReferenceBoxFill,
    IJSVGClipReferenceBoxView
};

@interface IJSVGClipPath ()
@property (nonatomic, assign) IJSVGClipShape basicShape;
@property (nonatomic, assign) IJSVGClipReferenceBox referenceBox;
@property (nonatomic, copy) NSArray<IJSVGUnitLength*>* shapePosition;
@property (nonatomic, strong) IJSVGUnitLength* shapeRadiusX;
@property (nonatomic, strong) IJSVGUnitLength* shapeRadiusY;
@property (nonatomic, assign) BOOL farthestX;
@property (nonatomic, assign) BOOL farthestY;
@end

static char* IJSVGClipTrim(char* value)
{
    while (isspace((unsigned char)*value)) {
        value++;
    }
    char* end = value + strlen(value);
    while (end > value && isspace((unsigned char)end[-1])) {
        *--end = '\0';
    }
    return value;
}

static BOOL IJSVGClipParseReferenceBox(const char* value, IJSVGClipReferenceBox* box)
{
    if (IJSVGCharBufferCaseInsensitiveCompare(value, "fill-box") || IJSVGCharBufferCaseInsensitiveCompare(value, "content-box") || IJSVGCharBufferCaseInsensitiveCompare(value, "padding-box")) {
        *box = IJSVGClipReferenceBoxFill;
    } else if (IJSVGCharBufferCaseInsensitiveCompare(value, "stroke-box") || IJSVGCharBufferCaseInsensitiveCompare(value, "border-box") || IJSVGCharBufferCaseInsensitiveCompare(value, "margin-box")) {
        *box = IJSVGClipReferenceBoxStroke;
    } else if (IJSVGCharBufferCaseInsensitiveCompare(value, "view-box")) {
        *box = IJSVGClipReferenceBoxView;
    } else {
        return NO;
    }
    return YES;
}

typedef NS_ENUM(uint8_t, IJSVGClipArgument) {
    IJSVGClipArgumentRadius,
    IJSVGClipArgumentPosition,
    IJSVGClipArgumentClosestSide,
    IJSVGClipArgumentFarthestSide
};

static IJSVGClipArgument IJSVGClipArgumentForName(const char* name)
{
    switch (IJSVGCharToLower(name[0])) {
        case 'a': {
            if (IJSVGCharBufferCaseInsensitiveCompare(name, "at")) {
                return IJSVGClipArgumentPosition;
            }
            break;
        }
        case 'c': {
            if (IJSVGCharBufferCaseInsensitiveCompare(name, "closest-side")) {
                return IJSVGClipArgumentClosestSide;
            }
            break;
        }
        case 'f': {
            if (IJSVGCharBufferCaseInsensitiveCompare(name, "farthest-side")) {
                return IJSVGClipArgumentFarthestSide;
            }
            break;
        }
        default: {
            break;
        }
    }
    return IJSVGClipArgumentRadius;
}

static CGFloat IJSVGClipSideRadius(CGFloat position, CGFloat dimension, BOOL farthest)
{
    CGFloat start = fabs(position);
    CGFloat end = fabs(dimension - position);
    return farthest ? MAX(start, end) : MIN(start, end);
}

static BOOL IJSVGClipPathSupportsNode(IJSVGNode* node)
{
    if ([node matchesTraits:IJSVGNodeTraitPathed] || [node isKindOfClass:IJSVGText.class]) {
        return YES;
    }
    if (node.type != IJSVGNodeTypeUse) {
        return NO;
    }
    for (IJSVGNode* child in ((IJSVGGroup*)node).children) {
        if (!IJSVGClipPathSupportsNode(child)) {
            return NO;
        }
    }
    return YES;
}

@implementation IJSVGClipPath

+ (instancetype)clipPathWithBasicShape:(NSString*)value
{
    IJSVGStringBytes source = IJSVGStringGetBytes(value);
    const char* bytes = source.bytes;
    if (bytes == NULL || strlen(bytes) != source.length) {
        return nil;
    }
    char* buffer = strdup(bytes);
    if (buffer == NULL) {
        return nil;
    }
    IJSVGClipPath* clipPath = [self clipPathWithShapeBuffer:buffer];
    free(buffer);
    return clipPath;
}

+ (instancetype)clipPathWithShapeBuffer:(char*)buffer
{
    char* value = IJSVGClipTrim(buffer);
    IJSVGClipPath* clipPath = [[self alloc] init];
    IJSVGClipReferenceBox box = IJSVGClipReferenceBoxStroke;
    IJSVGCSSComponents components;
    BOOL valid = IJSVGCSSComponentsCreate(value, strlen(value), &components);
    IJSVGCSSComponent function = { 0 };
    BOOL hasFunction = NO;
    for (NSUInteger index = 0; valid && index < components.count;) {
        const IJSVGCSSComponent* component = components.values + index;
        if (component->kind == IJSVGCSSComponentFunction) {
            if (hasFunction) {
                valid = NO;
                break;
            }
            function = *component;
            hasFunction = YES;
            for (NSUInteger child = index + 1; child < component->next; child++) {
                if (components.values[child].kind == IJSVGCSSComponentFunction) {
                    valid = NO;
                }
            }
        }
        index = component->next;
    }
    IJSVGCSSComponentsRelease(&components);
    if (!valid) {
        return nil;
    }
    if (!hasFunction) {
        if (!IJSVGClipParseReferenceBox(value, &box)) {
            return nil;
        }
        clipPath.basicShape = IJSVGClipShapeBox;
        clipPath.referenceBox = box;
        return clipPath;
    }
    char* opening = value + function.argumentOffset - 1;
    char* closing = value + function.argumentOffset + function.argumentLength;
    *opening = '\0';
    *closing = '\0';
    char* name = IJSVGClipTrim(value);
    char* suffix = IJSVGClipTrim(closing + 1);
    char* separator = name;
    while (*separator != '\0' && !isspace((unsigned char)*separator)) {
        separator++;
    }
    BOOL hasPrefix = *separator != '\0';
    if (hasPrefix) {
        *separator = '\0';
        if (!IJSVGClipParseReferenceBox(name, &box) || *suffix != '\0') {
            return nil;
        }
        name = IJSVGClipTrim(separator + 1);
    } else if (*suffix != '\0' && !IJSVGClipParseReferenceBox(suffix, &box)) {
        return nil;
    }
    if (function.function == IJSVGCSSFunctionCircle) {
        clipPath.basicShape = IJSVGClipShapeCircle;
    } else if (function.function == IJSVGCSSFunctionEllipse) {
        clipPath.basicShape = IJSVGClipShapeEllipse;
    } else {
        return nil;
    }
    clipPath.referenceBox = box;
    char* cursor = opening + 1;
    NSUInteger radiusCount = 0;
    while (*cursor != '\0') {
        while (isspace((unsigned char)*cursor)) {
            cursor++;
        }
        if (*cursor == '\0') {
            break;
        }
        char* token = cursor;
        while (*cursor != '\0' && !isspace((unsigned char)*cursor)) {
            cursor++;
        }
        if (*cursor != '\0') {
            *cursor++ = '\0';
        }
        IJSVGClipArgument argument = IJSVGClipArgumentForName(token);
        if (argument == IJSVGClipArgumentPosition) {
            NSArray<IJSVGUnitLength*>* position = IJSVGPositionFromBuffer(cursor, IJSVGPositionSyntaxBasicShape);
            if (position.count != 2) {
                return nil;
            }
            clipPath.shapePosition = position;
            break;
        }
        if (radiusCount >= (clipPath.basicShape == IJSVGClipShapeCircle ? 1 : 2)) {
            return nil;
        }
        BOOL farthest = argument == IJSVGClipArgumentFarthestSide;
        IJSVGUnitLength* radius = nil;
        if (argument == IJSVGClipArgumentRadius) {
            radius = IJSVGGeometryLengthFromString([NSString stringWithUTF8String:token], IJSVGNodeAttributeR);
            if (radius == nil) {
                return nil;
            }
        }
        if (radiusCount == 0) {
            clipPath.shapeRadiusX = radius;
            clipPath.farthestX = farthest;
        } else {
            clipPath.shapeRadiusY = radius;
            clipPath.farthestY = farthest;
        }
        radiusCount++;
    }
    if (clipPath.basicShape == IJSVGClipShapeEllipse && radiusCount == 1) {
        return nil;
    }
    if (clipPath.shapePosition == nil) {
        clipPath.shapePosition = @[ IJSVGHalfPercentageUnitLength, IJSVGHalfPercentageUnitLength ];
    }
    return clipPath;
}

- (BOOL)hasBasicShape
{
    return _basicShape != IJSVGClipShapeNone;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGClipPath* node = [super copyWithZone:zone];
    node.basicShape = _basicShape;
    node.referenceBox = _referenceBox;
    node.shapePosition = _shapePosition;
    node.shapeRadiusX = _shapeRadiusX.copy;
    node.shapeRadiusY = _shapeRadiusY.copy;
    node.farthestX = _farthestX;
    node.farthestY = _farthestY;
    return node;
}

- (CGPathRef)newBasicShapePathWithFillBox:(CGRect)fillBox strokeBox:(CGRect)strokeBox viewBox:(CGRect)viewBox lengthResolver:(CGFloat (^)(IJSVGUnitLength* length, CGFloat percentage))resolver
{
    CGRect box = _referenceBox == IJSVGClipReferenceBoxFill ? fillBox : (_referenceBox == IJSVGClipReferenceBoxView ? viewBox : strokeBox);
    if (_basicShape == IJSVGClipShapeBox) {
        return CGPathCreateWithRect(box, NULL);
    }
    CGFloat x = resolver(_shapePosition[0], box.size.width);
    CGFloat y = resolver(_shapePosition[1], box.size.height);
    CGFloat rx;
    CGFloat ry;
    if (_basicShape == IJSVGClipShapeCircle) {
        if (_shapeRadiusX != nil) {
            rx = resolver(_shapeRadiusX, hypot(box.size.width, box.size.height) / M_SQRT2);
        } else {
            CGFloat horizontal = IJSVGClipSideRadius(x, box.size.width, _farthestX);
            CGFloat vertical = IJSVGClipSideRadius(y, box.size.height, _farthestX);
            rx = _farthestX ? MAX(horizontal, vertical) : MIN(horizontal, vertical);
        }
        ry = rx;
    } else {
        rx = _shapeRadiusX != nil ? resolver(_shapeRadiusX, box.size.width) : IJSVGClipSideRadius(x, box.size.width, _farthestX);
        ry = _shapeRadiusY != nil ? resolver(_shapeRadiusY, box.size.height) : IJSVGClipSideRadius(y, box.size.height, _farthestY);
    }
    if (!isfinite(rx) || !isfinite(ry) || !isfinite(x) || !isfinite(y) || rx <= 0.f || ry <= 0.f) {
        return CGPathCreateMutable();
    }
    CGRect ellipse = CGRectMake(box.origin.x + x - rx, box.origin.y + y - ry, rx * 2.f, ry * 2.f);
    return CGPathCreateWithEllipseInRect(ellipse, NULL);
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeClipPath;
}

- (void)setDefaults
{
    [super setDefaults];
    self.units = IJSVGUnitObjectBoundingBox;
    self.contentUnits = IJSVGUnitUserSpaceOnUse;
    self.windingRule = IJSVGWindingRuleNonZero;
    self.overflowVisibility = IJSVGOverflowVisibilityHidden;
    self.fill = [IJSVGColorNode colorNodeWithColor:IJSVGColor.whiteColor];
}

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds
{
    IJSVGGraphicsNode* node = nil;
    IJSVGUnitType units = [self contentUnitsWithReferencingNode:&node];
    if (units == IJSVGUnitUserSpaceOnUse) {
        *bounds = node.rootNode.bounds;
    } else {
        *bounds = node.parentNode.bounds;
    }
    return units;
}

- (void)postProcess
{
    for (IJSVGNode* child in self.children.copy) {
        if (!IJSVGClipPathSupportsNode(child)) {
            [self removeChild:child];
        }
    }
}

- (IJSVGWindingRule)computedClipRule
{
    // find the first use of a clipRule that is useful
    __block IJSVGWindingRule rule = IJSVGWindingRuleInherit;
    __weak IJSVGClipPath* weakSelf = self;
    IJSVGNodeWalkHandler handler = ^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
        if (node == weakSelf || ![node isKindOfClass:IJSVGGraphicsNode.class]) {
            return;
        }
        IJSVGWindingRule clipRule = ((IJSVGGraphicsNode*)node).clipRule;
        if (clipRule != IJSVGWindingRuleInherit) {
            rule = clipRule;
            *stop = YES;
        }
    };
    [IJSVGNode walkNodeTree:self handler:handler];
    return rule;
}

@end

#pragma mark - Parsing

@implementation IJSVGClipPath (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeX];
    [attributes setBit:IJSVGNodeAttributeY];
    [attributes setBit:IJSVGNodeAttributeWidth];
    [attributes setBit:IJSVGNodeAttributeHeight];
    [attributes setBit:IJSVGNodeAttributeClipPathUnits];
    [attributes setBit:IJSVGNodeAttributeClipRule];
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
    if (IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeWidth, &geometryValue)) {
        IJSVGUnitLength* length = IJSVGDimensionFromString(geometryValue, self.type);
        if (length != nil) {
            self.width = length;
        }
    }
    if (IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeHeight, &geometryValue)) {
        IJSVGUnitLength* length = IJSVGDimensionFromString(geometryValue, self.type);
        if (length != nil) {
            self.height = length;
        }
    }
    IJSVGParseBackgroundAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    IJSVGParsePaintAttributes(self, context);
    IJSVGParseEffectsAttributes(self, context);
    IJSVGParseTransformAttributes(self, context);
    IJSVGParseDisplayAttributes(self, context);
    IJSVGParseOverflowAttributes(self, context);
    IJSVGParseMarkersAttributes(self, context);
    IJSVGParseClipAttributes(self, context);
}

@end
