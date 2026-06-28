//
//  IJSVGParserUtils.m
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGParserUtils.h>
#import <IJSVG/IJSVGTransform.h>
#import <string.h>

BOOL IJSVGAttributeMaskContains(uint64_t mask, IJSVGNodeAttribute attribute)
{
    return (mask & (1ULL << attribute)) != 0;
}

NSString* IJSVGAttributeValue(
    NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength],
    IJSVGNodeAttribute attribute)
{
    return attributeValues[attribute];
}

BOOL IJSVGAttributeHasValue(
    NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength],
    IJSVGNodeAttribute attribute,
    NSString* __autoreleasing* value)
{
    NSString* attributeValue = IJSVGAttributeValue(attributeValues, attribute);
    if(attributeValue.length == 0) {
        return NO;
    }
    if(value != NULL) {
        *value = attributeValue;
    }
    return YES;
}

void IJSVGStoreStyleAttributes(
    IJSVGStyleSheetStyle* style,
    uint64_t activeAttributes,
    NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength],
    uint64_t* presentAttributes)
{
    NSDictionary* properties = style.properties;
    for(NSString* key in properties) {
        NSUInteger attribute = IJSVGNodeAttributeForName(key);
        if(attribute == NSNotFound || IJSVGAttributeMaskContains(activeAttributes, attribute) == NO) {
            continue;
        }
        NSString* value = properties[key];
        if(value.length == 0) {
            continue;
        }
        attributeValues[attribute] = value;
        *presentAttributes |= (1ULL << attribute);
    }
}

void IJSVGApplyTransformAttribute(IJSVGNode* node, NSString* value)
{
    NSMutableArray<IJSVGTransform*>* transforms =
        [IJSVGTransform transformsForString:value].mutableCopy;
    if(transforms == nil) {
        transforms = [[NSMutableArray alloc] init];
    }
    if(node.transforms != nil) {
        [transforms addObjectsFromArray:node.transforms];
    }
    node.transforms = transforms;
}

static inline BOOL IJSVGAttributeNameEquals(const char* name, size_t length,
                                            const char* expected)
{
    return expected[length] == '\0' && memcmp(name, expected, length) == 0;
}

NSUInteger IJSVGNodeAttributeForName(NSString* name)
{
    const char* attributeName = name.UTF8String;
    if(attributeName == NULL) {
        return NSNotFound;
    }

    size_t length = strlen(attributeName);
    switch(length) {
        case 1: {
            char c = attributeName[0];
            if(c == 'd') {
                return IJSVGNodeAttributeD;
            }
            if(c == 'x') {
                return IJSVGNodeAttributeX;
            }
            if(c == 'y') {
                return IJSVGNodeAttributeY;
            }
            if(c == 'r') {
                return IJSVGNodeAttributeR;
            }
            break;
        }
        case 2: {
            char c = attributeName[0];
            if(c == 'i' && IJSVGAttributeNameEquals(attributeName, length, "id")) {
                return IJSVGNodeAttributeID;
            }
            if(c == 'c') {
                if(IJSVGAttributeNameEquals(attributeName, length, "cx")) {
                    return IJSVGNodeAttributeCX;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "cy")) {
                    return IJSVGNodeAttributeCY;
                }
            }
            if(c == 'f') {
                if(IJSVGAttributeNameEquals(attributeName, length, "fx")) {
                    return IJSVGNodeAttributeFX;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "fy")) {
                    return IJSVGNodeAttributeFY;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "fr")) {
                    return IJSVGNodeAttributeFR;
                }
            }
            if(c == 'r') {
                if(IJSVGAttributeNameEquals(attributeName, length, "rx")) {
                    return IJSVGNodeAttributeRX;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "ry")) {
                    return IJSVGNodeAttributeRY;
                }
            }
            if(c == 'x') {
                if(IJSVGAttributeNameEquals(attributeName, length, "x1")) {
                    return IJSVGNodeAttributeX1;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "x2")) {
                    return IJSVGNodeAttributeX2;
                }
            }
            if(c == 'y') {
                if(IJSVGAttributeNameEquals(attributeName, length, "y1")) {
                    return IJSVGNodeAttributeY1;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "y2")) {
                    return IJSVGNodeAttributeY2;
                }
            }
            break;
        }
        case 4: {
            char c = attributeName[0];
            if(c == 'f' && IJSVGAttributeNameEquals(attributeName, length, "fill")) {
                return IJSVGNodeAttributeFill;
            }
            if(c == 'h' && IJSVGAttributeNameEquals(attributeName, length, "href")) {
                return IJSVGNodeAttributeHref;
            }
            if(c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "mask")) {
                return IJSVGNodeAttributeMask;
            }
            break;
        }
        case 5: {
            char c = attributeName[0];
            if(c == 'c' && IJSVGAttributeNameEquals(attributeName, length, "class")) {
                return IJSVGNodeAttributeClass;
            }
            if(c == 's' && IJSVGAttributeNameEquals(attributeName, length, "style")) {
                return IJSVGNodeAttributeStyle;
            }
            if(c == 'w' && IJSVGAttributeNameEquals(attributeName, length, "width")) {
                return IJSVGNodeAttributeWidth;
            }
            if(c == 'x' && IJSVGAttributeNameEquals(attributeName, length, "xmlns")) {
                return IJSVGNodeAttributeXMLNS;
            }
            break;
        }
        case 6: {
            char c = attributeName[0];
            if(c == 'h' && IJSVGAttributeNameEquals(attributeName, length, "height")) {
                return IJSVGNodeAttributeHeight;
            }
            if(c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "marker")) {
                return IJSVGNodeAttributeMarker;
            }
            if(c == 'o' && IJSVGAttributeNameEquals(attributeName, length, "offset")) {
                return IJSVGNodeAttributeOffset;
            }
            if(c == 'p' && IJSVGAttributeNameEquals(attributeName, length, "points")) {
                return IJSVGNodeAttributePoints;
            }
            if(c == 's' && IJSVGAttributeNameEquals(attributeName, length, "stroke")) {
                return IJSVGNodeAttributeStroke;
            }
            break;
        }
        case 7: {
            char c = attributeName[0];
            if(c == 'd' && IJSVGAttributeNameEquals(attributeName, length, "display")) {
                return IJSVGNodeAttributeDisplay;
            }
            if(c == 'o' && IJSVGAttributeNameEquals(attributeName, length, "opacity")) {
                return IJSVGNodeAttributeOpacity;
            }
            if(c == 'v') {
                if(IJSVGAttributeNameEquals(attributeName, length, "version")) {
                    return IJSVGNodeAttributeVersion;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "viewBox")) {
                    return IJSVGNodeAttributeViewBox;
                }
            }
            break;
        }
        case 8: {
            if(IJSVGAttributeNameEquals(attributeName, length, "overflow")) {
                return IJSVGNodeAttributeOverflow;
            }
            break;
        }
        case 9: {
            char c = attributeName[0];
            if(c == 'c') {
                if(IJSVGAttributeNameEquals(attributeName, length, "clip-path")) {
                    return IJSVGNodeAttributeClipPath;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "clip-rule")) {
                    return IJSVGNodeAttributeClipRule;
                }
            }
            if(c == 'f' && IJSVGAttributeNameEquals(attributeName, length, "fill-rule")) {
                return IJSVGNodeAttributeFillRule;
            }
            if(c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "maskUnits")) {
                return IJSVGNodeAttributeMaskUnits;
            }
            if(c == 't' && IJSVGAttributeNameEquals(attributeName, length, "transform")) {
                return IJSVGNodeAttributeTransform;
            }
            break;
        }
        case 10: {
            char c = attributeName[0];
            if(c == 's' && IJSVGAttributeNameEquals(attributeName, length, "stop-color")) {
                return IJSVGNodeAttributeStopColor;
            }
            if(c == 'x' && IJSVGAttributeNameEquals(attributeName, length, "xlink:href")) {
                return IJSVGNodeAttributeXLink;
            }
            break;
        }
        case 11: {
            if(IJSVGAttributeNameEquals(attributeName, length, "xmlns:xlink")) {
                return IJSVGNodeAttributeXMLNSXlink;
            }
            break;
        }
        case 12: {
            char c = attributeName[0];
            if(c == 'f' && IJSVGAttributeNameEquals(attributeName, length, "fill-opacity")) {
                return IJSVGNodeAttributeFillOpacity;
            }
            if(c == 'p' && IJSVGAttributeNameEquals(attributeName, length, "patternUnits")) {
                return IJSVGNodeAttributePatternUnits;
            }
            if(c == 's') {
                if(IJSVGAttributeNameEquals(attributeName, length, "stroke-width")) {
                    return IJSVGNodeAttributeStrokeWidth;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "stop-opacity")) {
                    return IJSVGNodeAttributeStopOpacity;
                }
            }
            break;
        }
        case 13: {
            char c = attributeName[0];
            if(c == 'c' && IJSVGAttributeNameEquals(attributeName, length, "clipPathUnits")) {
                return IJSVGNodeAttributeClipPathUnits;
            }
            if(c == 'g' && IJSVGAttributeNameEquals(attributeName, length, "gradientUnits")) {
                return IJSVGNodeAttributeGradientUnits;
            }
            break;
        }
        case 14: {
            char c = attributeName[0];
            if(c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "mix-blend-mode")) {
                return IJSVGNodeAttributeBlendMode;
            }
            if(c == 's') {
                if(IJSVGAttributeNameEquals(attributeName, length, "stroke-linecap")) {
                    return IJSVGNodeAttributeStrokeLineCap;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "stroke-opacity")) {
                    return IJSVGNodeAttributeStrokeOpacity;
                }
            }
            break;
        }
        case 15: {
            if(IJSVGAttributeNameEquals(attributeName, length, "stroke-linejoin")) {
                return IJSVGNodeAttributeStrokeLineJoin;
            }
            break;
        }
        case 16: {
            char c = attributeName[0];
            if(c == 'm' && IJSVGAttributeNameEquals(attributeName, length, "maskContentUnits")) {
                return IJSVGNodeAttributeMaskContentUnits;
            }
            if(c == 'p' && IJSVGAttributeNameEquals(attributeName, length, "patternTransform")) {
                return IJSVGNodeAttributePatternTransform;
            }
            if(c == 's' && IJSVGAttributeNameEquals(attributeName, length, "stroke-dasharray")) {
                return IJSVGNodeAttributeStrokeDashArray;
            }
            break;
        }
        case 17: {
            char c = attributeName[0];
            if(c == 'g' && IJSVGAttributeNameEquals(attributeName, length, "gradientTransform")) {
                return IJSVGNodeAttributeGradientTransform;
            }
            if(c == 's') {
                if(IJSVGAttributeNameEquals(attributeName, length, "stroke-dashoffset")) {
                    return IJSVGNodeAttributeStrokeDashOffset;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "stroke-miterlimit")) {
                    return IJSVGNodeAttributeStrokeMiterLimit;
                }
            }
            break;
        }
        case 19: {
            char c = attributeName[0];
            if(c == 'p') {
                if(IJSVGAttributeNameEquals(attributeName, length, "patternContentUnits")) {
                    return IJSVGNodeAttributePatternContentUnits;
                }
                if(IJSVGAttributeNameEquals(attributeName, length, "preserveAspectRatio")) {
                    return IJSVGNodeAttributePreserveAspectRatio;
                }
            }
            break;
        }
    }

    static NSDictionary<NSString*, NSNumber*>* attributes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        attributes = @{
            IJSVGAttributeVersion: @(IJSVGNodeAttributeVersion),
            IJSVGAttributeXMLNS: @(IJSVGNodeAttributeXMLNS),
            IJSVGAttributeXMLNSXlink: @(IJSVGNodeAttributeXMLNSXlink),
            IJSVGAttributeViewBox: @(IJSVGNodeAttributeViewBox),
            IJSVGAttributePreserveAspectRatio: @(IJSVGNodeAttributePreserveAspectRatio),
            IJSVGAttributeID: @(IJSVGNodeAttributeID),
            IJSVGAttributeClass: @(IJSVGNodeAttributeClass),
            IJSVGAttributeX: @(IJSVGNodeAttributeX),
            IJSVGAttributeY: @(IJSVGNodeAttributeY),
            IJSVGAttributeWidth: @(IJSVGNodeAttributeWidth),
            IJSVGAttributeHeight: @(IJSVGNodeAttributeHeight),
            IJSVGAttributeOpacity: @(IJSVGNodeAttributeOpacity),
            IJSVGAttributeStrokeOpacity: @(IJSVGNodeAttributeStrokeOpacity),
            IJSVGAttributeStrokeWidth: @(IJSVGNodeAttributeStrokeWidth),
            IJSVGAttributeStrokeDashOffset: @(IJSVGNodeAttributeStrokeDashOffset),
            IJSVGAttributeFillOpacity: @(IJSVGNodeAttributeFillOpacity),
            IJSVGAttributeClipPath: @(IJSVGNodeAttributeClipPath),
            IJSVGAttributeClipPathUnits: @(IJSVGNodeAttributeClipPathUnits),
            IJSVGAttributeClipRule: @(IJSVGNodeAttributeClipRule),
            IJSVGAttributeMask: @(IJSVGNodeAttributeMask),
            IJSVGAttributeGradientUnits: @(IJSVGNodeAttributeGradientUnits),
            IJSVGAttributePatternUnits: @(IJSVGNodeAttributePatternUnits),
            IJSVGAttributePatternContentUnits: @(IJSVGNodeAttributePatternContentUnits),
            IJSVGAttributePatternTransform: @(IJSVGNodeAttributePatternTransform),
            IJSVGAttributeMaskUnits: @(IJSVGNodeAttributeMaskUnits),
            IJSVGAttributeMaskContentUnits: @(IJSVGNodeAttributeMaskContentUnits),
            IJSVGAttributeTransform: @(IJSVGNodeAttributeTransform),
            IJSVGAttributeGradientTransform: @(IJSVGNodeAttributeGradientTransform),
            IJSVGAttributeStrokeLineCap: @(IJSVGNodeAttributeStrokeLineCap),
            IJSVGAttributeStrokeLineJoin: @(IJSVGNodeAttributeStrokeLineJoin),
            IJSVGAttributeStroke: @(IJSVGNodeAttributeStroke),
            IJSVGAttributeStrokeDashArray: @(IJSVGNodeAttributeStrokeDashArray),
            IJSVGAttributeStrokeMiterLimit: @(IJSVGNodeAttributeStrokeMiterLimit),
            IJSVGAttributeFill: @(IJSVGNodeAttributeFill),
            IJSVGAttributeFillRule: @(IJSVGNodeAttributeFillRule),
            IJSVGAttributeBlendMode: @(IJSVGNodeAttributeBlendMode),
            IJSVGAttributeDisplay: @(IJSVGNodeAttributeDisplay),
            IJSVGAttributeStyle: @(IJSVGNodeAttributeStyle),
            IJSVGAttributeD: @(IJSVGNodeAttributeD),
            IJSVGAttributeXLink: @(IJSVGNodeAttributeXLink),
            IJSVGAttributeX1: @(IJSVGNodeAttributeX1),
            IJSVGAttributeX2: @(IJSVGNodeAttributeX2),
            IJSVGAttributeY1: @(IJSVGNodeAttributeY1),
            IJSVGAttributeY2: @(IJSVGNodeAttributeY2),
            IJSVGAttributeRX: @(IJSVGNodeAttributeRX),
            IJSVGAttributeRY: @(IJSVGNodeAttributeRY),
            IJSVGAttributeCX: @(IJSVGNodeAttributeCX),
            IJSVGAttributeCY: @(IJSVGNodeAttributeCY),
            IJSVGAttributeR: @(IJSVGNodeAttributeR),
            IJSVGAttributeFX: @(IJSVGNodeAttributeFX),
            IJSVGAttributeFY: @(IJSVGNodeAttributeFY),
            IJSVGAttributeFR: @(IJSVGNodeAttributeFR),
            IJSVGAttributePoints: @(IJSVGNodeAttributePoints),
            IJSVGAttributeOffset: @(IJSVGNodeAttributeOffset),
            IJSVGAttributeStopColor: @(IJSVGNodeAttributeStopColor),
            IJSVGAttributeStopOpacity: @(IJSVGNodeAttributeStopOpacity),
            IJSVGAttributeHref: @(IJSVGNodeAttributeHref),
            IJSVGAttributeOverflow: @(IJSVGNodeAttributeOverflow),
            IJSVGAttributeMarker: @(IJSVGNodeAttributeMarker)
        };
    });
    NSNumber* attribute = attributes[name];
    return attribute == nil ? NSNotFound : attribute.unsignedIntegerValue;
}
