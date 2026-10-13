//
//  IJSVGText.m
//  IJSVG
//
//  Created by Curtis Hard on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColorNode.h>
#import <IJSVG/IJSVGStyle.h>
#import <IJSVG/IJSVGText.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGTextAttributeValue

@end

@implementation IJSVGText

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeText;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _textContent = @[];
        _positioning = @{};
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGText* copy = [super copyWithZone:zone];
    NSMutableArray<id>* content = [NSMutableArray arrayWithCapacity:self.textContent.count];
    for (id item in self.textContent) {
        if ([item isKindOfClass:IJSVGText.class]) {
            // Point mixed text content at the copied children.
            NSUInteger index = [self.children indexOfObjectIdenticalTo:item];
            if (index != NSNotFound) {
                [content addObject:copy.children[index]];
            }
        } else {
            [content addObject:[item copy]];
        }
    }
    copy.textContent = content;
    copy.positioning = self.positioning;
    copy.textPath = self.textPath.copy;
    copy.isTextPath = self.isTextPath;
    return copy;
}

// Identifies direct text runs without counting child span containers.
- (BOOL)hasTextContent
{
    for (id item in self.textContent) {
        if ([item isKindOfClass:NSString.class] && [item length] != 0) {
            return YES;
        }
    }
    return NO;
}

// Text strokes use the same visibility rules as path strokes.
- (void)computeTraits
{
    [super computeTraits];
    [self removeTraits:IJSVGNodeTraitStroked];
    if (!self.hasTextContent || self.stroke == nil) {
        return;
    }
    if ([self.stroke isKindOfClass:IJSVGColorNode.class] && ((IJSVGColorNode*)self.stroke).isNoneOrTransparent) {
        return;
    }
    [self addTraits:IJSVGNodeTraitStroked];
}

// Includes direct text paints alongside colors collected from child spans.
- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style
{
    IJSVGTraitedColorStorage* storage = [super colorsWithStyle:style];
    if (!self.shouldRender || !self.hasTextContent) {
        return storage;
    }
    IJSVGNode* fill = self.fill;
    if (fill == nil) {
        fill = [[IJSVGColorNode alloc] initWithColor:style.fillColor ?: NSColor.blackColor];
    }
    [storage unionColorStorage:[fill colorsWithStyle:style matchingTraits:IJSVGColorUsageTraitFill]];
    if ([self matchesTraits:IJSVGNodeTraitStroked]) {
        [storage unionColorStorage:[self.stroke colorsWithStyle:style matchingTraits:IJSVGColorUsageTraitStroke]];
    }
    return storage;
}

- (BOOL)containsRelativeUnits
{
    // Text layout depends on viewport percentages and inherited font metrics.
    return YES;
}

@end

#pragma mark - Parsing

@implementation IJSVGText (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
    [attributes setBit:IJSVGNodeAttributeX];
    [attributes setBit:IJSVGNodeAttributeY];
    [attributes setBit:IJSVGNodeAttributeDX];
    [attributes setBit:IJSVGNodeAttributeDY];
    [attributes setBit:IJSVGNodeAttributeRotate];
    [attributes setBit:IJSVGNodeAttributeTextLength];
    [attributes setBit:IJSVGNodeAttributeLengthAdjust];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
    IJSVGParsePathAttributes(self, context);
    NSMutableDictionary<NSString*, IJSVGTextAttributeValue*>* positioning = nil;
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeX, IJSVGAttributeX, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeY, IJSVGAttributeY, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeDX, IJSVGAttributeDX, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeDY, IJSVGAttributeDY, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeRotate, IJSVGAttributeRotate, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeTextLength, IJSVGAttributeTextLength, &positioning);
    IJSVGReadTextPositionAttribute(context->values, IJSVGNodeAttributeLengthAdjust, IJSVGAttributeLengthAdjust, &positioning);
    self.positioning = positioning ?: @{};
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
}

@end
