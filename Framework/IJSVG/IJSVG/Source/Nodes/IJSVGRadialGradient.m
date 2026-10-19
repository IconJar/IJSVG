//
//  IJSVGRadialGradient.m
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGRadialGradient.h>
#import <IJSVGNodeParsing.h>
#import <IJSVGXML.h>

@implementation IJSVGRadialGradient

- (IJSVGNodeTypeTraits)nodeTraits
{
    return IJSVGNodeTypeTraitPaint | IJSVGNodeTypeTraitGraphics | IJSVGNodeTypeTraitViewport | IJSVGNodeTypeTraitGroup | IJSVGNodeTypeTraitGradient | IJSVGNodeTypeTraitRadialGradient;
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeRadialGradient;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGRadialGradient* grad = [super copyWithZone:zone];
    grad.fx = _fx;
    grad.fy = _fy;
    grad.fr = _fr;
    grad.cx = _cx;
    grad.cy = _cy;
    grad.r = _r;
    return grad;
}

- (BOOL)containsRelativeUnits
{
    return _fx.isRelativeUnit == YES || _fy.isRelativeUnit == YES || _fr.isRelativeUnit == YES || _cx.isRelativeUnit == YES || _cy.isRelativeUnit == YES || _r.isRelativeUnit == YES || [super containsRelativeUnits] == YES;
}

#pragma mark - Parsing

+ (void)parseGeometryFromAttributes:(IJSVGXMLAttributeList)attributes gradient:(IJSVGRadialGradient*)gradient
{
    IJSVGXMLAttribute* values[6] = { NULL };
    IJSVGXMLAttributeList attributeIterator = attributes;
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&attributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&attributeIterator)) {
        switch (attribute->identifier) {
            case IJSVGNodeAttributeCX:
                values[0] = attribute;
                break;
            case IJSVGNodeAttributeCY:
                values[1] = attribute;
                break;
            case IJSVGNodeAttributeR:
                values[2] = attribute;
                break;
            case IJSVGNodeAttributeFX:
                values[3] = attribute;
                break;
            case IJSVGNodeAttributeFY:
                values[4] = attribute;
                break;
            case IJSVGNodeAttributeFR:
                values[5] = attribute;
                break;
            default:
                break;
        }
    }
    IJSVGUnitLength* lengths[6] = { nil };
    for (NSUInteger index = 0; index < 6; index++) {
        lengths[index] = IJSVGUnitLengthFromXMLAttribute(values[index], gradient.units);
    }
    gradient.cx = lengths[0] ?: IJSVGHalfPercentageUnitLength;
    gradient.cy = lengths[1] ?: IJSVGHalfPercentageUnitLength;
    gradient.r = lengths[2] ?: IJSVGHalfPercentageUnitLength;
    gradient.fx = lengths[3] ?: gradient.cx;
    gradient.fy = lengths[4] ?: gradient.cy;
    gradient.fr = lengths[5] ?: IJSVGZeroPercentageUnitLength;
    [gradient parseSpreadMethodFromAttributes:attributes];
}

#pragma mark - Drawing

- (void)drawInContextRef:(CGContextRef)ctx bounds:(CGRect)objectRect transform:(CGAffineTransform)absoluteTransform
{
    CGContextSaveGState(ctx);
    BOOL inUserSpace = self.units == IJSVGUnitUserSpaceOnUse;
    CGFloat radius = 0.f;
    CGPoint startPoint = CGPointZero;
    CGPoint gradientStartPoint = CGPointZero;
    CGPoint gradientEndPoint = CGPointZero;
    CGRect boundingBox = objectRect;

    // compute size based on percentages
    CGFloat width = 0.f;
    CGFloat height = 0.f;
    if (inUserSpace == YES) {
        width = CGRectGetWidth(boundingBox);
        height = CGRectGetHeight(boundingBox);
    } else {
        width = 1.f;
        height = 1.f;
    }

    CGFloat cx = [_cx computeValue:width];
    CGFloat cy = [_cy computeValue:height];
    startPoint = CGPointMake(cx, cy);
    CGFloat val = MIN(width, height);
    radius = [_r computeValue:val];
    CGFloat focalRadius = [_fr computeValue:val];

    CGFloat fx = [_fx computeValue:width];
    CGFloat fy = [_fy computeValue:height];

    gradientStartPoint = startPoint;
    gradientEndPoint = CGPointMake(fx, fy);

    // transform if width or height is not equal, this can only
    // be done if we are using objectBoundingBox
    if (inUserSpace == YES) {
        CGContextConcatCTM(ctx, absoluteTransform);
    } else {
        CGContextConcatCTM(ctx, CGAffineTransformMakeScale(CGRectGetWidth(boundingBox), CGRectGetHeight(boundingBox)));
    }

    // concat the gradient transform into the context
    IJSVGConcatTransformsCTM(ctx, self.transforms);

    if ([self drawSpreadInContext:ctx startPoint:gradientEndPoint endPoint:gradientStartPoint startRadius:focalRadius endRadius:radius radial:YES]) {
        CGContextRestoreGState(ctx);
        return;
    }

    // draw the gradient
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    CGContextDrawRadialGradient(ctx, self.CGGradient, gradientEndPoint, focalRadius, gradientStartPoint, radius, options);
    CGContextRestoreGState(ctx);
}

@end

#pragma mark - Parsing

@implementation IJSVGRadialGradient (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    [attributes setBit:IJSVGNodeAttributeGradientUnits];
    [attributes setBit:IJSVGNodeAttributeGradientTransform];
    [attributes setBit:IJSVGNodeAttributeCX];
    [attributes setBit:IJSVGNodeAttributeCY];
    [attributes setBit:IJSVGNodeAttributeR];
    [attributes setBit:IJSVGNodeAttributeFX];
    [attributes setBit:IJSVGNodeAttributeFY];
    [attributes setBit:IJSVGNodeAttributeFR];
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
