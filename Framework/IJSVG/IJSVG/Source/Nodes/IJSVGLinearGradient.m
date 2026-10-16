//
//  IJSVGLinearGradient.m
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGNodeParsing.h>
#import <IJSVGXML.h>

static IJSVGUnitLength* IJSVGLinearGradientCoordinate(IJSVGXMLAttribute* attribute, IJSVGUnitType units, BOOL endPoint)
{
    IJSVGUnitLength* length = IJSVGUnitLengthFromXMLAttribute(attribute, units);
    if (length == nil) {
        if (endPoint) {
            return IJSVGOnePercentageUnitLength;
        }
        return units == IJSVGUnitObjectBoundingBox ? IJSVGZeroBoundingBoxUnitLength : IJSVGZeroUnitLength;
    }
    return length;
}

@implementation IJSVGLinearGradient

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeLinearGradient;
}

#pragma mark - Parsing

+ (void)parseGeometryFromAttributes:(IJSVGXMLAttributeList)attributes gradient:(IJSVGLinearGradient*)aGradient
{
    IJSVGXMLAttribute* values[4] = { NULL };
    IJSVGXMLAttributeList attributeIterator = attributes;
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&attributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&attributeIterator)) {
        switch (attribute->identifier) {
            case IJSVGNodeAttributeX1:
                values[0] = attribute;
                break;
            case IJSVGNodeAttributeX2:
                values[1] = attribute;
                break;
            case IJSVGNodeAttributeY1:
                values[2] = attribute;
                break;
            case IJSVGNodeAttributeY2:
                values[3] = attribute;
                break;
            default:
                break;
        }
    }
    IJSVGUnitType units = aGradient.units;
    aGradient.x1 = IJSVGLinearGradientCoordinate(values[0], units, NO);
    aGradient.x2 = IJSVGLinearGradientCoordinate(values[1], units, YES);
    aGradient.y1 = IJSVGLinearGradientCoordinate(values[2], units, NO);
    aGradient.y2 = IJSVGLinearGradientCoordinate(values[3], units, NO);

    [aGradient parseSpreadMethodFromAttributes:attributes];
}

#pragma mark - Drawing

- (void)drawInContextRef:(CGContextRef)ctx bounds:(CGRect)objectRect transform:(CGAffineTransform)absoluteTransform
{
    BOOL inUserSpace = self.units == IJSVGUnitUserSpaceOnUse;

    CGPoint gradientStartPoint = CGPointZero;
    CGPoint gradientEndPoint = CGPointZero;
    CGRect boundingBox = objectRect;

    // make sure we apply the absolute position to
    // transform us back into the correct space
    CGFloat width = CGRectGetWidth(boundingBox);
    CGFloat height = CGRectGetHeight(boundingBox);

    if (inUserSpace == YES) {
        CGContextConcatCTM(ctx, absoluteTransform);
    } else {
        width = 1.f;
        height = 1.f;
        CGContextConcatCTM(ctx, CGAffineTransformMakeScale(boundingBox.size.width, boundingBox.size.height));
    }

    gradientStartPoint = CGPointMake([self.x1 computeValue:width], [self.y1 computeValue:height]);
    gradientEndPoint = CGPointMake([self.x2 computeValue:width], [self.y2 computeValue:height]);

    // concat the gradient transform into the context
    IJSVGConcatTransformsCTM(ctx, self.transforms);

    if ([self drawSpreadInContext:ctx startPoint:gradientStartPoint endPoint:gradientEndPoint startRadius:0.f endRadius:0.f radial:NO]) {
        return;
    }

    // draw the gradient
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    CGContextDrawLinearGradient(ctx, self.CGGradient, gradientStartPoint, gradientEndPoint, options);
}

@end

#pragma mark - Parsing

@implementation IJSVGLinearGradient (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    [attributes setBit:IJSVGNodeAttributeGradientUnits];
    [attributes setBit:IJSVGNodeAttributeGradientTransform];
    [attributes setBit:IJSVGNodeAttributeX1];
    [attributes setBit:IJSVGNodeAttributeY1];
    [attributes setBit:IJSVGNodeAttributeX2];
    [attributes setBit:IJSVGNodeAttributeY2];
    [attributes setBit:IJSVGNodeAttributeHref];
    [attributes setBit:IJSVGNodeAttributeXLink];
    IJSVGAddTextStyleAttributes(attributes);
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    if (self.reference == nil) {
        self.reference = context->reference;
    }
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGradientAttributes(self, context);
}

@end
