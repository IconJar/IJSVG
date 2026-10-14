//
//  IJSVGNodeParsing.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import <IJSVG/IJSVGClipPath.h>
#import <IJSVG/IJSVGForeignObject.h>
#import <IJSVG/IJSVGMask.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVGNodeParsing.h>
#import <IJSVGSwitch.h>

BOOL IJSVGParserAttributeHasValue(NSString* __unsafe_unretained const* values, IJSVGNodeAttribute attribute, NSString* __strong* value)
{
    NSString* __unsafe_unretained candidate = values[attribute];
    if (candidate == nil || candidate.length == 0) {
        return NO;
    }
    *value = candidate;
    return YES;
}

void IJSVGParseColorAttributes(IJSVGNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeColor, &value)) {
        NSString* keyword = value.lowercaseString;
        if ([keyword isEqualToString:@"initial"]) {
            node.currentColor = IJSVGColor.blackColor;
        } else if ([keyword isEqualToString:@"currentcolor"] || [keyword isEqualToString:@"inherit"] || [keyword isEqualToString:@"unset"]) {
            node.currentColor = nil;
        } else if ([keyword isEqualToString:@"transparent"]) {
            node.currentColor = IJSVGColor.clearColor;
        } else {
            node.currentColor = [IJSVGColor colorFromString:value];
        }
    }
}

void IJSVGParseDisplayAttributes(IJSVGNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeVisibility, &value)) {
        NSString* keyword = value.lowercaseString;
        if ([keyword isEqualToString:@"hidden"] || [keyword isEqualToString:@"collapse"]) {
            node.visibility = IJSVGVisibilityHidden;
        } else if ([keyword isEqualToString:@"visible"] || [keyword isEqualToString:@"initial"]) {
            node.visibility = IJSVGVisibilityVisible;
        } else {
            node.visibility = IJSVGVisibilityInherit;
        }
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeDisplay, &value)) {
        if ([value caseInsensitiveCompare:IJSVGStringNone] == NSOrderedSame) {
            node.shouldRender = NO;
        }
    }
}

static void IJSVGStoreInheritedGeometry(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context, IJSVGStyleSheetStyle* declarations);

void IJSVGParseTextStyleAttributes(IJSVGNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    if (context->textAttributes != 0) {
        IJSVGApplyTextAttributes(node, attributeValues, context->textAttributes);
    }
}

void IJSVGParseGeometryInheritance(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context)
{
    if (context->style != nil) {
        IJSVGStoreInheritedGeometry(node, context, context->style);
    }
    if (context->inlineStyle != nil) {
        IJSVGStoreInheritedGeometry(node, context, context->inlineStyle);
    }
}

// CSS path data may be inherited through graphical containers.
void IJSVGParsePathAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    IJSVGParser* parser = context->parser;
    IJSVGStyleSheetStyle* styleSheet = context->style;
    IJSVGStyleSheetStyle* nodeStyle = context->inlineStyle;
    NSString* pathValue = IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeD);
    if (pathValue != nil) {
        BOOL cssPath = [nodeStyle property:IJSVGAttributeD] != nil || [styleSheet property:IJSVGAttributeD] != nil;
        [parser applyPathValue:pathValue toNode:node css:cssPath fallback:context->attributePathData];
    }
}

static inline IJSVGUnitLength* IJSVGCachedGeometryLength(IJSVGNodeParsingContext* context, NSString* value, IJSVGNodeAttribute attribute)
{
    if (context->cachedGeometryLengths == nil) {
        return IJSVGGeometryLengthFromString(value, attribute) ?: IJSVGGeometryInitialLength(attribute);
    }
    NSNumber* key = @(attribute);
    if ([context->cachedGeometryValues[key] isEqualToString:value]) {
        return context->cachedGeometryLengths[key];
    }
    IJSVGUnitLength* length = IJSVGGeometryLengthFromString(value, attribute) ?: IJSVGGeometryInitialLength(attribute);
    context->cachedGeometryValues[key] = value;
    context->cachedGeometryLengths[key] = length;
    return length;
}

// The caller supplies exactly one supported geometry property. CSS only
// properties on ancestors are retained separately for explicit inheritance.
BOOL IJSVGReadGeometryLength(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context, IJSVGNodeAttribute attribute, IJSVGUnitLength* __strong* usedLength)
{
    IJSVGUnitLength* length = context->geometryLengths[@(attribute)];
    if (length == nil) {
        NSString* value = context->values[attribute];
        if (value == nil) {
            return NO;
        }
        length = IJSVGCachedGeometryLength(context, value, attribute);
        if (length.inherit) {
            length = node.styleParent.geometryLengths[@(attribute)] ?: IJSVGGeometryInitialLength(attribute);
        }
        if (context->geometryLengths == nil) {
            context->geometryLengths = [[NSMutableDictionary alloc] init];
        }
        context->geometryOwner = node;
        context->geometryLengths[@(attribute)] = length;
    }
    *usedLength = length.type == IJSVGUnitLengthTypeAuto ? nil : length;
    return YES;
}

static void IJSVGStoreInheritedGeometry(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context, IJSVGStyleSheetStyle* declarations)
{
    if (!declarations.hasGeometryProperties) {
        return;
    }
    for (NSString* name in declarations.properties) {
        NSUInteger attribute = IJSVGNodeAttributeForName(name);
        if (!IJSVGAttributeIsGeometryProperty(attribute) || context->geometryLengths[@(attribute)] != nil) {
            continue;
        }
        NSString* value = [context->inlineStyle property:name];
        if (value == nil || ([context->style isPropertyImportant:name] && ![context->inlineStyle isPropertyImportant:name])) {
            value = [context->style property:name];
        }
        if (value == nil) {
            continue;
        }
        IJSVGUnitLength* length = IJSVGCachedGeometryLength(context, value, attribute);
        if (length.inherit) {
            length = node.styleParent.geometryLengths[@(attribute)] ?: IJSVGGeometryInitialLength(attribute);
        }
        if (context->geometryLengths == nil) {
            context->geometryLengths = [[NSMutableDictionary alloc] init];
        }
        context->geometryOwner = node;
        context->geometryLengths[@(attribute)] = length;
    }
}

void IJSVGParsePathLengthAttributes(IJSVGPath* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePathLength, &value)) {
        NSArray<IJSVGUnitLength*>* lengths = IJSVGUnitLengthsFromString(value);
        if (lengths.count == 1 && lengths.firstObject.originalType == IJSVGUnitLengthTypeNumber) {
            node.pathLength = @(lengths.firstObject.value);
        }
    }
}

void IJSVGParseBackgroundAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeEnableBackground, &value)) {
        IJSVGApplyBackgroundAttribute(node, value);
    }
}

void IJSVGParseFilterColorInterpolation(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeColorInterpolationFilters, &value)) {
        node.filterColorInterpolation = IJSVGColorInterpolationForString(value);
    }
}

void IJSVGParsePaintAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    IJSVGParser* parser = context->parser;
    IJSVGXMLNode* element = context->element;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeOpacity, &value)) {
        node.opacity = [IJSVGUnitLength unitWithString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeOpacity, &value)) {
        node.strokeOpacity = [IJSVGUnitLength unitWithString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeWidth, &value)) {
        node.strokeWidth = IJSVGLengthFromString(value, NO);
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeDashOffset, &value)) {
        node.strokeDashOffset = IJSVGLengthFromString(value, YES);
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeMiterLimit, &value)) {
        node.strokeMiterLimit = [IJSVGUnitLength unitWithString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeLineCap, &value)) {
        node.lineCapStyle = [IJSVGUtils lineCapStyleForString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeLineJoin, &value)) {
        node.lineJoinStyle = [IJSVGUtils lineJoinStyleForString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStroke, &value)) {
        NSString* fillIdentifier = [IJSVGUtils defURL:value];
        if (fillIdentifier != nil) {
            [parser applyPaintReference:fillIdentifier node:node element:element stroke:YES];
        } else {
            IJSVGColorNode* colorNode = [parser colorPaintForValue:value];
            node.stroke = colorNode;
        }
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeStrokeDashArray, &value)) {
        if ([value isEqualToString:IJSVGStringNone]) {
            node.strokeDashArrayCount = 0;
            node.strokeDashLengths = nil;
        } else {
            NSArray<IJSVGUnitLength*>* lengths = IJSVGUnitLengthsFromString(value);
            if (lengths != nil) {
                CGFloat* params = malloc(lengths.count * sizeof(CGFloat));
                for (NSUInteger index = 0; index < lengths.count; index++) {
                    params[index] = lengths[index].value;
                }
                node.strokeDashArray = params;
                node.strokeDashArrayCount = lengths.count;
                node.strokeDashLengths = lengths;
            }
        }
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeFill, &value)) {
        NSString* fillIdentifier = [IJSVGUtils defURL:value];
        if (fillIdentifier != nil) {
            [parser applyPaintReference:fillIdentifier node:node element:element stroke:NO];
        } else {
            IJSVGColorNode* colorNode = [parser colorPaintForValue:value];
            node.fill = colorNode;
        }
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeFillOpacity, &value)) {
        node.fillOpacity = [IJSVGUnitLength unitWithString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeVectorEffect, &value)) {
        node.vectorEffect = [IJSVGUtils vectorEffectForString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePaintOrder, &value)) {
        node.paintOrder = IJSVGPaintOrderFromString(value);
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeIsolation, &value)) {
        node.isolated = IJSVGIsolationFromString(value, node.parentNode.isolated);
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeBlendMode, &value)) {
        node.blendMode = [IJSVGUtils blendModeForString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeFillRule, &value)) {
        node.windingRule = [IJSVGUtils windingRuleForString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeClipRule, &value)) {
        node.clipRule = [IJSVGUtils windingRuleForString:value];
    }
}

void IJSVGParseEffectsAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context)
{
    IJSVGNodeDeferredAttributes* attributes = context->deferredAttributes;
    IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeMask, &attributes->mask);
    IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeClipPath, &attributes->clipPath);
    IJSVGParserAttributeHasValue(context->values, IJSVGNodeAttributeFilter, &attributes->filter);
}

void IJSVGApplyDeferredAttributes(const IJSVGNodeDeferredAttributes* attributes, IJSVGNode* node, IJSVGParser* parser, IJSVGXMLNode* element)
{
    IJSVGGraphicsNode* graphics = (IJSVGGraphicsNode*)node;
    if (attributes->mask != nil) {
        NSString* identifier = [IJSVGUtils defURL:attributes->mask];
        if (identifier != nil) {
            graphics.mask = (id)[parser computeDetachedNodeWithIdentifier:identifier referencingNode:graphics element:element];
        }
    }
    if (attributes->clipPath != nil) {
        NSString* identifier = [IJSVGUtils defURL:attributes->clipPath];
        if (identifier != nil) {
            graphics.clipPath = (id)[parser computeDetachedNodeWithIdentifier:identifier referencingNode:graphics element:element];
        } else {
            graphics.clipPath = [IJSVGClipPath clipPathWithBasicShape:attributes->clipPath];
        }
    }
    if (attributes->filter != nil) {
        graphics.filters = [parser filtersForValue:attributes->filter referencingNode:graphics element:element];
    }
    if (attributes->markerStart != nil || attributes->markerMid != nil || attributes->markerEnd != nil) {
        [parser applyMarkerStart:attributes->markerStart mid:attributes->markerMid end:attributes->markerEnd toNode:graphics element:element];
    }
}

static IJSVGTransformBox IJSVGTransformBoxFromString(NSString* value)
{
    if ([value isEqualToString:@"fill-box"]) {
        return IJSVGTransformBoxFillBox;
    }
    if ([value isEqualToString:@"stroke-box"]) {
        return IJSVGTransformBoxStrokeBox;
    }
    if ([value isEqualToString:@"content-box"]) {
        return IJSVGTransformBoxContentBox;
    }
    if ([value isEqualToString:@"border-box"]) {
        return IJSVGTransformBoxBorderBox;
    }

    // The view box is also the initial value. This property does not inherit.
    return IJSVGTransformBoxViewBox;
}

void IJSVGParseTransformAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    IJSVGParser* parser = context->parser;
    IJSVGStyleSheetStyle* styleSheet = context->style;
    IJSVGStyleSheetStyle* nodeStyle = context->inlineStyle;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeTransformOrigin, &value)) {
        if ([value isEqualToString:@"inherit"]) {
            node.transformOrigin = node.styleParent.transformOrigin;
        } else {
            node.transformOrigin = IJSVGTransformOriginFromString(([@[ @"initial", @"unset" ] containsObject:value.lowercaseString]) ? @"center" : value);
        }
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeTransformBox, &value)) {
        NSString* keyword = value.lowercaseString;
        node.transformBox = [keyword isEqualToString:@"inherit"] ? node.styleParent.transformBox : IJSVGTransformBoxFromString(keyword);
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeTransform, &value)) {
        BOOL css = [nodeStyle property:IJSVGAttributeTransform] != nil || [styleSheet property:IJSVGAttributeTransform] != nil;
        IJSVGApplyParsedTransforms(node, [parser parsedTransformsForValue:value allowCSSUnits:css]);
    }
}

void IJSVGParseViewportAttributes(IJSVGViewportNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeOverflow, &value)) {
        if ([value caseInsensitiveCompare:@"hidden"] == NSOrderedSame || [value caseInsensitiveCompare:@"scroll"] == NSOrderedSame || [value caseInsensitiveCompare:@"clip"] == NSOrderedSame) {
            node.overflowVisibility = IJSVGOverflowVisibilityHidden;
        } else if ([value caseInsensitiveCompare:@"visible"] == NSOrderedSame || [value caseInsensitiveCompare:IJSVGStringAuto] == NSOrderedSame || [value caseInsensitiveCompare:@"initial"] == NSOrderedSame || [value caseInsensitiveCompare:@"unset"] == NSOrderedSame) {
            node.overflowVisibility = IJSVGOverflowVisibilityVisible;
        } else if ([value caseInsensitiveCompare:@"inherit"] == NSOrderedSame) {
            node.overflowVisibility = node.parentNode != nil ? node.parentNode.overflowVisibility : IJSVGOverflowVisibilityVisible;
        }
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeViewBox, &value)) {
        CGFloat* floats = [IJSVGUtils parseViewBox:value];
        node.viewBox = [IJSVGUnitRect rectWithX:floats[0] y:floats[1] width:floats[2] height:floats[3]];
        ((void)free(floats)), floats = NULL;
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePreserveAspectRatio, &value)) {
        IJSVGViewBoxMeetOrSlice meetOrSlice;
        IJSVGViewBoxAlignment alignment = [IJSVGViewBox alignmentForString:value meetOrSlice:&meetOrSlice];
        node.viewBoxAlignment = alignment;
        node.viewBoxMeetOrSlice = meetOrSlice;
    }
}

void IJSVGParseAspectRatioAttributes(IJSVGViewportNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePreserveAspectRatio, &value)) {
        IJSVGViewBoxMeetOrSlice meetOrSlice;
        IJSVGViewBoxAlignment alignment = [IJSVGViewBox alignmentForString:value meetOrSlice:&meetOrSlice];
        node.viewBoxAlignment = alignment;
        node.viewBoxMeetOrSlice = meetOrSlice;
    }
}

void IJSVGParseOverflowAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeOverflow, &value)) {
        if ([value caseInsensitiveCompare:@"hidden"] == NSOrderedSame || [value caseInsensitiveCompare:@"scroll"] == NSOrderedSame || [value caseInsensitiveCompare:@"clip"] == NSOrderedSame) {
            node.overflowVisibility = IJSVGOverflowVisibilityHidden;
        } else if ([value caseInsensitiveCompare:@"visible"] == NSOrderedSame || [value caseInsensitiveCompare:IJSVGStringAuto] == NSOrderedSame || [value caseInsensitiveCompare:@"initial"] == NSOrderedSame || [value caseInsensitiveCompare:@"unset"] == NSOrderedSame) {
            node.overflowVisibility = IJSVGOverflowVisibilityVisible;
        } else if ([value caseInsensitiveCompare:@"inherit"] == NSOrderedSame) {
            node.overflowVisibility = node.parentNode != nil ? node.parentNode.overflowVisibility : IJSVGOverflowVisibilityVisible;
        }
    }
}

void IJSVGParseGradientAttributes(IJSVGGradient* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    IJSVGParser* parser = context->parser;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeGradientUnits, &value)) {
        node.units = [IJSVGUtils unitTypeForString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeGradientTransform, &value)) {
        IJSVGApplyParsedTransforms(node, [parser parsedTransformsForValue:value allowCSSUnits:NO]);
    }
}

void IJSVGParseMaskAttributes(IJSVGMask* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeMaskType, &value)) {
        node.maskType = [value caseInsensitiveCompare:@"alpha"] == NSOrderedSame ? IJSVGMaskTypeAlpha : IJSVGMaskTypeLuminance;
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeMaskUnits, &value)) {
        node.units = [IJSVGUtils unitTypeForString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeMaskContentUnits, &value)) {
        node.contentUnits = [IJSVGUtils unitTypeForString:value];
    }
}

void IJSVGParsePatternAttributes(IJSVGPattern* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    IJSVGParser* parser = context->parser;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePatternUnits, &value)) {
        node.units = [IJSVGUtils unitTypeForString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePatternContentUnits, &value)) {
        node.contentUnits = [IJSVGUtils unitTypeForString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePatternTransform, &value)) {
        IJSVGApplyParsedTransforms(node, [parser parsedTransformsForValue:value allowCSSUnits:NO]);
    }
}

void IJSVGParseClipAttributes(IJSVGClipPath* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeClipPathUnits, &value)) {
        node.contentUnits = [IJSVGUtils unitTypeForString:value];
    }
}

void IJSVGParseFilterAttributes(IJSVGFilter* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeFilterUnits, &value)) {
        node.units = [IJSVGUtils unitTypeForString:value];
    }
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributePrimitiveUnits, &value)) {
        node.contentUnits = [IJSVGUtils unitTypeForString:value];
    }
}

void IJSVGParseRootAttributes(IJSVGRootNode* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    NSString* value = nil;
    if (IJSVGParserAttributeHasValue(attributeValues, IJSVGNodeAttributeBackgroundColor, &value)) {
        node.backgroundColor = [value caseInsensitiveCompare:@"currentColor"] == NSOrderedSame ? node.currentColor : [IJSVGColor colorFromString:value];
    }
}

void IJSVGParseSymbolAttributes(IJSVGSymbol* node, IJSVGNodeParsingContext* context)
{
    NSString* __unsafe_unretained* attributeValues = context->values;
    IJSVGSymbol* symbol = node;
    symbol.refX = IJSVGSymbolReferenceFromString(IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeRefX), IJSVGNodeAttributeRefX);
    symbol.refY = IJSVGSymbolReferenceFromString(IJSVGAttributeValue(attributeValues, IJSVGNodeAttributeRefY), IJSVGNodeAttributeRefY);
}

void IJSVGParseMarkersAttributes(IJSVGGraphicsNode* node, IJSVGNodeParsingContext* context)
{
    IJSVGNodeDeferredAttributes* attributes = context->deferredAttributes;
    attributes->markerStart = context->values[IJSVGNodeAttributeMarkerStart];
    attributes->markerMid = context->values[IJSVGNodeAttributeMarkerMid];
    attributes->markerEnd = context->values[IJSVGNodeAttributeMarkerEnd];
}

IJSVGBitFlags* IJSVGCommonAttributes(void)
{
    IJSVGBitFlags* attributes = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
    [attributes setBit:IJSVGNodeAttributeID];
    [attributes setBit:IJSVGNodeAttributeClass];
    [attributes setBit:IJSVGNodeAttributeStyle];
    [attributes setBit:IJSVGNodeAttributeColor];
    return attributes;
}

void IJSVGAddTextStyleAttributes(IJSVGBitFlags* attributes)
{
    // Font relative geometry and text styles can inherit through non text
    // ancestors.
    for (IJSVGNodeAttribute attribute = IJSVGNodeAttributeFont; attribute <= IJSVGNodeAttributeFontSizeAdjust; attribute++) {
        [attributes setBit:(int)attribute];
    }
    [attributes setBit:IJSVGNodeAttributeTextRendering];
}

IJSVGBitFlags* IJSVGGraphicsAttributes(void)
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    [attributes setBit:IJSVGNodeAttributeFill];
    [attributes setBit:IJSVGNodeAttributeFillOpacity];
    [attributes setBit:IJSVGNodeAttributeFillRule];
    [attributes setBit:IJSVGNodeAttributeStroke];
    [attributes setBit:IJSVGNodeAttributeStrokeWidth];
    [attributes setBit:IJSVGNodeAttributeStrokeOpacity];
    [attributes setBit:IJSVGNodeAttributeStrokeLineCap];
    [attributes setBit:IJSVGNodeAttributeStrokeLineJoin];
    [attributes setBit:IJSVGNodeAttributeStrokeDashArray];
    [attributes setBit:IJSVGNodeAttributeStrokeDashOffset];
    [attributes setBit:IJSVGNodeAttributeStrokeMiterLimit];
    [attributes setBit:IJSVGNodeAttributeClipPath];
    [attributes setBit:IJSVGNodeAttributeMask];
    [attributes setBit:IJSVGNodeAttributeFilter];
    [attributes setBit:IJSVGNodeAttributeOpacity];
    [attributes setBit:IJSVGNodeAttributeBlendMode];
    [attributes setBit:IJSVGNodeAttributeIsolation];
    [attributes setBit:IJSVGNodeAttributePaintOrder];
    [attributes setBit:IJSVGNodeAttributeVectorEffect];
    [attributes setBit:IJSVGNodeAttributeMarker];
    [attributes setBit:IJSVGNodeAttributeMarkerStart];
    [attributes setBit:IJSVGNodeAttributeMarkerMid];
    [attributes setBit:IJSVGNodeAttributeMarkerEnd];
    [attributes setBit:IJSVGNodeAttributeColorInterpolationFilters];
    [attributes setBit:IJSVGNodeAttributeEnableBackground];
    [attributes setBit:IJSVGNodeAttributeTransform];
    [attributes setBit:IJSVGNodeAttributeTransformOrigin];
    [attributes setBit:IJSVGNodeAttributeTransformBox];
    [attributes setBit:IJSVGNodeAttributeVisibility];
    [attributes setBit:IJSVGNodeAttributeDisplay];
    [attributes setBit:IJSVGNodeAttributeClipRule];
    IJSVGAddTextStyleAttributes(attributes);
    return attributes;
}

IJSVGBitFlags* IJSVGContainerAttributes(void)
{
    IJSVGBitFlags* attributes = IJSVGGraphicsAttributes();

    // CSS path data and geometry can be explicitly inherited by descendants.
    [attributes setBit:IJSVGNodeAttributeD];
    [attributes setBit:IJSVGNodeAttributeX];
    [attributes setBit:IJSVGNodeAttributeY];
    [attributes setBit:IJSVGNodeAttributeOverflow];
    return attributes;
}

Class IJSVGNodeClassForType(IJSVGNodeType type)
{
    switch (type) {
        case IJSVGNodeTypeFont:
            return IJSVGFont.class;
        case IJSVGNodeTypeGlyph:
            return IJSVGGlyph.class;
        case IJSVGNodeTypeUnknown:
            return IJSVGUnknownNode.class;
        case IJSVGNodeTypeGroup:
            return IJSVGGroup.class;
        case IJSVGNodeTypePath:
            return IJSVGPath.class;
        case IJSVGNodeTypeDef:
            return IJSVGDefinitions.class;
        case IJSVGNodeTypeStop:
            return IJSVGStop.class;
        case IJSVGNodeTypeLinearGradient:
            return IJSVGLinearGradient.class;
        case IJSVGNodeTypeRadialGradient:
            return IJSVGRadialGradient.class;
        case IJSVGNodeTypeClipPath:
            return IJSVGClipPath.class;
        case IJSVGNodeTypeMask:
            return IJSVGMask.class;
        case IJSVGNodeTypeImage:
            return IJSVGImage.class;
        case IJSVGNodeTypePattern:
            return IJSVGPattern.class;
        case IJSVGNodeTypeSVG:
            return IJSVGRootNode.class;
        case IJSVGNodeTypeText:
            return IJSVGText.class;
        case IJSVGNodeTypeSwitch:
            return IJSVGSwitch.class;
        case IJSVGNodeTypeForeignObject:
            return IJSVGForeignObject.class;
        case IJSVGNodeTypeFilter:
            return IJSVGFilter.class;
        case IJSVGNodeTypeMarker:
            return IJSVGMarker.class;
        case IJSVGNodeTypeRect:
            return IJSVGRect.class;
        case IJSVGNodeTypeCircle:
            return IJSVGCircle.class;
        case IJSVGNodeTypeEllipse:
            return IJSVGEllipse.class;
        case IJSVGNodeTypeLine:
            return IJSVGLine.class;
        case IJSVGNodeTypePolygon:
            return IJSVGPolygon.class;
        case IJSVGNodeTypePolyline:
            return IJSVGPolyline.class;
        case IJSVGNodeTypeUse:
            return IJSVGUse.class;
        case IJSVGNodeTypeAnchor:
            return IJSVGAnchor.class;
        case IJSVGNodeTypeSymbol:
            return IJSVGSymbol.class;
        case IJSVGNodeTypeTextSpan:
            return IJSVGTextSpan.class;
        case IJSVGNodeTypeTextPath:
            return IJSVGTextPath.class;
        case IJSVGNodeTypeStyle:
            return IJSVGStyleNode.class;
        case IJSVGNodeTypeTitle:
            return IJSVGTitleNode.class;
        case IJSVGNodeTypeDesc:
            return IJSVGDescriptionNode.class;
        case IJSVGNodeTypeFilterBlend:
            return IJSVGFilterBlendPrimitive.class;
        case IJSVGNodeTypeFilterColorMatrix:
            return IJSVGFilterColorMatrixPrimitive.class;
        case IJSVGNodeTypeFilterComponentTransfer:
            return IJSVGFilterComponentTransferPrimitive.class;
        case IJSVGNodeTypeFilterComposite:
            return IJSVGFilterCompositePrimitive.class;
        case IJSVGNodeTypeFilterConvolveMatrix:
            return IJSVGFilterConvolveMatrixPrimitive.class;
        case IJSVGNodeTypeFilterDiffuseLighting:
            return IJSVGFilterDiffuseLightingPrimitive.class;
        case IJSVGNodeTypeFilterDisplacementMap:
            return IJSVGFilterDisplacementMapPrimitive.class;
        case IJSVGNodeTypeFilterFlood:
            return IJSVGFilterFloodPrimitive.class;
        case IJSVGNodeTypeFilterGaussianBlur:
            return IJSVGFilterGaussianBlurPrimitive.class;
        case IJSVGNodeTypeFilterImage:
            return IJSVGFilterImagePrimitive.class;
        case IJSVGNodeTypeFilterMerge:
            return IJSVGFilterMergePrimitive.class;
        case IJSVGNodeTypeFilterMorphology:
            return IJSVGFilterMorphologyPrimitive.class;
        case IJSVGNodeTypeFilterOffset:
            return IJSVGFilterOffsetPrimitive.class;
        case IJSVGNodeTypeFilterSpecularLighting:
            return IJSVGFilterSpecularLightingPrimitive.class;
        case IJSVGNodeTypeFilterTile:
            return IJSVGFilterTilePrimitive.class;
        case IJSVGNodeTypeFilterTurbulence:
            return IJSVGFilterTurbulencePrimitive.class;
        case IJSVGNodeTypeFilterDropShadow:
            return IJSVGFilterDropShadowPrimitive.class;
        case IJSVGNodeTypeFilterMergeNode:
            return IJSVGFilterMergeNodePrimitive.class;
        case IJSVGNodeTypeFilterFuncR:
            return IJSVGFilterFuncRPrimitive.class;
        case IJSVGNodeTypeFilterFuncG:
            return IJSVGFilterFuncGPrimitive.class;
        case IJSVGNodeTypeFilterFuncB:
            return IJSVGFilterFuncBPrimitive.class;
        case IJSVGNodeTypeFilterFuncA:
            return IJSVGFilterFuncAPrimitive.class;
        case IJSVGNodeTypeFilterDistantLight:
            return IJSVGFilterDistantLightPrimitive.class;
        case IJSVGNodeTypeFilterPointLight:
            return IJSVGFilterPointLightPrimitive.class;
        case IJSVGNodeTypeFilterSpotLight:
            return IJSVGFilterSpotLightPrimitive.class;
        default:
            return Nil;
    }
}
