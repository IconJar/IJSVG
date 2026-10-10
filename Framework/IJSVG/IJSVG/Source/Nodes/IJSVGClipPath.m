//
//  IJSVGClipPath.m
//  IJSVG
//
//  Created by Curtis Hard on 29/05/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGClipPath.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGText.h>
#import <IJSVGParserUtils.h>
#import <ctype.h>
#import <IJSVG/IJSVGUtils.h>

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
    while(isspace((unsigned char)*value)) {
        value++;
    }
    char* end = value + strlen(value);
    while(end > value && isspace((unsigned char)end[-1])) {
        *--end = '\0';
    }
    return value;
}

static BOOL IJSVGClipParseReferenceBox(const char* value, IJSVGClipReferenceBox* box)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "fill-box") || IJSVGCharBufferCaseInsensitiveCompare(value, "content-box") ||
        IJSVGCharBufferCaseInsensitiveCompare(value, "padding-box")) {
        *box = IJSVGClipReferenceBoxFill;
    } else if(IJSVGCharBufferCaseInsensitiveCompare(value, "stroke-box") || IJSVGCharBufferCaseInsensitiveCompare(value, "border-box") ||
        IJSVGCharBufferCaseInsensitiveCompare(value, "margin-box")) {
        *box = IJSVGClipReferenceBoxStroke;
    } else if(IJSVGCharBufferCaseInsensitiveCompare(value, "view-box")) {
        *box = IJSVGClipReferenceBoxView;
    } else {
        return NO;
    }
    return YES;
}

static CGFloat IJSVGClipSideRadius(CGFloat position, CGFloat dimension, BOOL farthest)
{
    CGFloat start = fabs(position);
    CGFloat end = fabs(dimension - position);
    return farthest ? MAX(start, end) : MIN(start, end);
}


static BOOL IJSVGClipPathSupportsNode(IJSVGNode* node)
{
    if([node matchesTraits:IJSVGNodeTraitPathed] || [node isKindOfClass:IJSVGText.class]) {
        return YES;
    }
    if(node.type != IJSVGNodeTypeUse) {
        return NO;
    }
    for(IJSVGNode* child in ((IJSVGGroup*)node).children) {
        if(!IJSVGClipPathSupportsNode(child)) {
            return NO;
        }
    }
    return YES;
}

@implementation IJSVGClipPath

+ (instancetype)clipPathWithBasicShape:(NSString*)value
{
    const char* bytes = value.UTF8String;
    if(bytes == NULL || strlen(bytes) != [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return nil;
    }
    char* buffer = strdup(bytes);
    if(buffer == NULL) {
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
    char* opening = strchr(value, '(');
    if(opening == NULL) {
        if(!IJSVGClipParseReferenceBox(value, &box)) {
            return nil;
        }
        clipPath.basicShape = IJSVGClipShapeBox;
        clipPath.referenceBox = box;
        return clipPath;
    }
    char* closing = strchr(opening, ')');
    if(closing == NULL || strchr(opening + 1, '(') != NULL) {
        return nil;
    }
    *opening = '\0';
    *closing = '\0';
    char* name = IJSVGClipTrim(value);
    char* suffix = IJSVGClipTrim(closing + 1);
    char* separator = name;
    while(*separator != '\0' && !isspace((unsigned char)*separator)) {
        separator++;
    }
    BOOL hasPrefix = *separator != '\0';
    if(hasPrefix) {
        *separator = '\0';
        if(!IJSVGClipParseReferenceBox(name, &box) || *suffix != '\0') {
            return nil;
        }
        name = IJSVGClipTrim(separator + 1);
    } else if(*suffix != '\0' && !IJSVGClipParseReferenceBox(suffix, &box)) {
        return nil;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(name, "circle")) {
        clipPath.basicShape = IJSVGClipShapeCircle;
    } else if(IJSVGCharBufferCaseInsensitiveCompare(name, "ellipse")) {
        clipPath.basicShape = IJSVGClipShapeEllipse;
    } else {
        return nil;
    }
    clipPath.referenceBox = box;
    clipPath.shapePosition = IJSVGTransformOriginFromString(@"center");
    char* cursor = opening + 1;
    NSUInteger radiusCount = 0;
    while(*cursor != '\0') {
        while(isspace((unsigned char)*cursor)) {
            cursor++;
        }
        if(*cursor == '\0') {
            break;
        }
        char* token = cursor;
        while(*cursor != '\0' && !isspace((unsigned char)*cursor)) {
            cursor++;
        }
        if(*cursor != '\0') {
            *cursor++ = '\0';
        }
        if(IJSVGCharBufferCaseInsensitiveCompare(token, "at")) {
            // A shape position has no transform-origin depth component.
            NSUInteger positionCount = 0;
            BOOL inToken = NO;
            for(const char* position = cursor; *position != '\0'; position++) {
                BOOL whitespace = isspace((unsigned char)*position);
                if(!whitespace && !inToken) {
                    positionCount++;
                }
                inToken = !whitespace;
            }
            if(positionCount > 2) {
                return nil;
            }
            NSArray* position = IJSVGTransformOriginFromString([NSString stringWithUTF8String:cursor]);
            if(position.count != 2) {
                return nil;
            }
            clipPath.shapePosition = position;
            break;
        }
        if(radiusCount >= (clipPath.basicShape == IJSVGClipShapeCircle ? 1 : 2)) {
            return nil;
        }
        BOOL farthest = IJSVGCharBufferCaseInsensitiveCompare(token, "farthest-side");
        BOOL closest = IJSVGCharBufferCaseInsensitiveCompare(token, "closest-side");
        IJSVGUnitLength* radius = nil;
        if(!farthest && !closest) {
            radius = IJSVGGeometryLengthFromString([NSString stringWithUTF8String:token], IJSVGNodeAttributeR);
            if(radius == nil) {
                return nil;
            }
        }
        if(radiusCount == 0) {
            clipPath.shapeRadiusX = radius;
            clipPath.farthestX = farthest;
        } else {
            clipPath.shapeRadiusY = radius;
            clipPath.farthestY = farthest;
        }
        radiusCount++;
    }
    if(clipPath.basicShape == IJSVGClipShapeEllipse && radiusCount == 1) {
        return nil;
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

- (CGPathRef)newBasicShapePathWithFillBox:(CGRect)fillBox
                               strokeBox:(CGRect)strokeBox
                                 viewBox:(CGRect)viewBox
                          lengthResolver:(CGFloat (^)(IJSVGUnitLength* length, CGFloat percentage))resolver
{
    CGRect box = _referenceBox == IJSVGClipReferenceBoxFill ? fillBox :
        (_referenceBox == IJSVGClipReferenceBoxView ? viewBox : strokeBox);
    if(_basicShape == IJSVGClipShapeBox) {
        return CGPathCreateWithRect(box, NULL);
    }
    CGFloat x = resolver(_shapePosition[0], box.size.width);
    CGFloat y = resolver(_shapePosition[1], box.size.height);
    CGFloat rx;
    CGFloat ry;
    if(_basicShape == IJSVGClipShapeCircle) {
        if(_shapeRadiusX != nil) {
            rx = resolver(_shapeRadiusX, hypot(box.size.width, box.size.height) / M_SQRT2);
        } else {
            CGFloat horizontal = IJSVGClipSideRadius(x, box.size.width, _farthestX);
            CGFloat vertical = IJSVGClipSideRadius(y, box.size.height, _farthestX);
            rx = _farthestX ? MAX(horizontal, vertical) : MIN(horizontal, vertical);
        }
        ry = rx;
    } else {
        rx = _shapeRadiusX != nil ? resolver(_shapeRadiusX, box.size.width) :
            IJSVGClipSideRadius(x, box.size.width, _farthestX);
        ry = _shapeRadiusY != nil ? resolver(_shapeRadiusY, box.size.height) :
            IJSVGClipSideRadius(y, box.size.height, _farthestY);
    }
    if(!isfinite(rx) || !isfinite(ry) || !isfinite(x) || !isfinite(y) || rx <= 0.f || ry <= 0.f) {
        return CGPathCreateMutable();
    }
    CGRect ellipse = CGRectMake(box.origin.x + x - rx, box.origin.y + y - ry,
                                rx * 2.f, ry * 2.f);
    return CGPathCreateWithEllipseInRect(ellipse, NULL);
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeClipPath;
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
    [storage addBits:[super allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeX];
    [storage setBit:IJSVGNodeAttributeY];
    [storage setBit:IJSVGNodeAttributeWidth];
    [storage setBit:IJSVGNodeAttributeHeight];
    [storage setBit:IJSVGNodeAttributeClipPathUnits];
    [storage setBit:IJSVGNodeAttributeClipRule];
    return storage;
}

- (void)setDefaults
{
    self.units = IJSVGUnitObjectBoundingBox;
    self.contentUnits = IJSVGUnitUserSpaceOnUse;
    self.windingRule = IJSVGWindingRuleNonZero;
    self.overflowVisibility = IJSVGOverflowVisibilityHidden;
    self.fill = [IJSVGColorNode colorNodeWithColor:NSColor.whiteColor];
}

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds
{
    IJSVGNode* node = nil;
    IJSVGUnitType units = [self contentUnitsWithReferencingNode:&node];
    if(units == IJSVGUnitUserSpaceOnUse) {
        *bounds = node.rootNode.bounds;
    } else {
        *bounds = node.parentNode.bounds;
    }
    return units;
}

- (void)postProcess
{
    for(IJSVGNode* child in self.children.copy) {
        if(!IJSVGClipPathSupportsNode(child)) {
            [self removeChild:child];
        }
    }
}

- (IJSVGWindingRule)computedClipRule
{
    // find the first use of a clipRule that is useful
    __block IJSVGWindingRule rule = IJSVGWindingRuleInherit;
    __weak IJSVGClipPath* weakSelf = self;
    IJSVGNodeWalkHandler handler = ^(IJSVGNode *node, BOOL *allowChildNodes,
                                     BOOL *stop) {
        if(node == weakSelf) {
            return;
        }
        IJSVGWindingRule clipRule = node.clipRule;
        if(clipRule != IJSVGWindingRuleInherit) {
            rule = clipRule;
            *stop = YES;
        }
    };
    [IJSVGNode walkNodeTree:self
                    handler:handler];
    return rule;
}

@end
