//
//  IJSVGParserUtils.m
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGParserUtils.h>

BOOL IJSVGAttributeMaskContains(uint64_t mask, IJSVGNodeAttribute attribute)
{
    return (mask & (1ULL << attribute)) != 0;
}

NSUInteger IJSVGNodeAttributeForName(NSString* name)
{
    switch(name.length) {
        case 1: {
            unichar c = [name characterAtIndex:0];
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
            unichar c = [name characterAtIndex:0];
            if(c == 'i' && [name isEqualToString:IJSVGAttributeID]) {
                return IJSVGNodeAttributeID;
            }
            if(c == 'c') {
                if([name isEqualToString:IJSVGAttributeCX]) {
                    return IJSVGNodeAttributeCX;
                }
                if([name isEqualToString:IJSVGAttributeCY]) {
                    return IJSVGNodeAttributeCY;
                }
            }
            if(c == 'f') {
                if([name isEqualToString:IJSVGAttributeFX]) {
                    return IJSVGNodeAttributeFX;
                }
                if([name isEqualToString:IJSVGAttributeFY]) {
                    return IJSVGNodeAttributeFY;
                }
                if([name isEqualToString:IJSVGAttributeFR]) {
                    return IJSVGNodeAttributeFR;
                }
            }
            if(c == 'r') {
                if([name isEqualToString:IJSVGAttributeRX]) {
                    return IJSVGNodeAttributeRX;
                }
                if([name isEqualToString:IJSVGAttributeRY]) {
                    return IJSVGNodeAttributeRY;
                }
            }
            if(c == 'x') {
                if([name isEqualToString:IJSVGAttributeX1]) {
                    return IJSVGNodeAttributeX1;
                }
                if([name isEqualToString:IJSVGAttributeX2]) {
                    return IJSVGNodeAttributeX2;
                }
            }
            if(c == 'y') {
                if([name isEqualToString:IJSVGAttributeY1]) {
                    return IJSVGNodeAttributeY1;
                }
                if([name isEqualToString:IJSVGAttributeY2]) {
                    return IJSVGNodeAttributeY2;
                }
            }
            break;
        }
        case 4: {
            unichar c = [name characterAtIndex:0];
            if(c == 'f' && [name isEqualToString:IJSVGAttributeFill]) {
                return IJSVGNodeAttributeFill;
            }
            if(c == 'h' && [name isEqualToString:IJSVGAttributeHref]) {
                return IJSVGNodeAttributeHref;
            }
            break;
        }
        case 5: {
            unichar c = [name characterAtIndex:0];
            if(c == 'c' && [name isEqualToString:IJSVGAttributeClass]) {
                return IJSVGNodeAttributeClass;
            }
            if(c == 's' && [name isEqualToString:IJSVGAttributeStyle]) {
                return IJSVGNodeAttributeStyle;
            }
            if(c == 'w' && [name isEqualToString:IJSVGAttributeWidth]) {
                return IJSVGNodeAttributeWidth;
            }
            break;
        }
        case 6: {
            unichar c = [name characterAtIndex:0];
            if(c == 'h' && [name isEqualToString:IJSVGAttributeHeight]) {
                return IJSVGNodeAttributeHeight;
            }
            if(c == 'm' && [name isEqualToString:IJSVGAttributeMarker]) {
                return IJSVGNodeAttributeMarker;
            }
            if(c == 's' && [name isEqualToString:IJSVGAttributeStroke]) {
                return IJSVGNodeAttributeStroke;
            }
            break;
        }
        case 7: {
            unichar c = [name characterAtIndex:0];
            if(c == 'd' && [name isEqualToString:IJSVGAttributeDisplay]) {
                return IJSVGNodeAttributeDisplay;
            }
            if(c == 'o' && [name isEqualToString:IJSVGAttributeOpacity]) {
                return IJSVGNodeAttributeOpacity;
            }
            if(c == 'v' && [name isEqualToString:IJSVGAttributeViewBox]) {
                return IJSVGNodeAttributeViewBox;
            }
            break;
        }
        case 9: {
            unichar c = [name characterAtIndex:0];
            if(c == 'c' && [name isEqualToString:IJSVGAttributeClipPath]) {
                return IJSVGNodeAttributeClipPath;
            }
            if(c == 'f' && [name isEqualToString:IJSVGAttributeFillRule]) {
                return IJSVGNodeAttributeFillRule;
            }
            if(c == 't' && [name isEqualToString:IJSVGAttributeTransform]) {
                return IJSVGNodeAttributeTransform;
            }
            break;
        }
        case 10: {
            unichar c = [name characterAtIndex:0];
            if(c == 's' && [name isEqualToString:IJSVGAttributeStopColor]) {
                return IJSVGNodeAttributeStopColor;
            }
            if(c == 'x' && [name isEqualToString:IJSVGAttributeXLink]) {
                return IJSVGNodeAttributeXLink;
            }
            break;
        }
        case 12: {
            unichar c = [name characterAtIndex:0];
            if(c == 'f' && [name isEqualToString:IJSVGAttributeFillOpacity]) {
                return IJSVGNodeAttributeFillOpacity;
            }
            if(c == 's' && [name isEqualToString:IJSVGAttributeStrokeWidth]) {
                return IJSVGNodeAttributeStrokeWidth;
            }
            if(c == 's' && [name isEqualToString:IJSVGAttributeStopOpacity]) {
                return IJSVGNodeAttributeStopOpacity;
            }
            break;
        }
        case 14: {
            if([name isEqualToString:IJSVGAttributeStrokeOpacity]) {
                return IJSVGNodeAttributeStrokeOpacity;
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
            IJSVGAttributeUnicode: @(IJSVGNodeAttributeUnicode),
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
