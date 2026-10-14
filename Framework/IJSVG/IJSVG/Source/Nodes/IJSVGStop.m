//
//  IJSVGStop.m
//  IJSVG
//
//  Created by Curtis Hard on 05/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStop.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGStop

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeStop;
}

- (void)applyPropertiesFromNode:(IJSVGNode*)source
{
    [super applyPropertiesFromNode:source];
    if ([source isKindOfClass:IJSVGStop.class]) {
        self.offset = ((IJSVGStop*)source).offset.copy;
    }
}

@end

#pragma mark - Parsing

@implementation IJSVGStop (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    [attributes setBit:IJSVGNodeAttributeOffset];
    [attributes setBit:IJSVGNodeAttributeStopColor];
    [attributes setBit:IJSVGNodeAttributeStopOpacity];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    [self consumeOffset:context->values[IJSVGNodeAttributeOffset] color:context->values[IJSVGNodeAttributeStopColor] opacity:context->values[IJSVGNodeAttributeStopOpacity] parser:context->parser];
}

- (void)consumeXMLAttributes:(IJSVGXMLAttributeList)attributes parser:(IJSVGParser*)parser
{
    IJSVGXMLAttribute* colorAttribute = NULL;
    IJSVGXMLAttributeList iterator = attributes;
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&iterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&iterator)) {
        if (attribute->value.length == 0) {
            continue;
        }
        switch (attribute->identifier) {
            case IJSVGNodeAttributeOffset:
                self.offset = IJSVGUnitLengthFromXMLAttribute(attribute, IJSVGUnitUserSpaceOnUse);
                break;
            case IJSVGNodeAttributeStopOpacity:
                self.fillOpacity = IJSVGUnitLengthFromXMLAttribute(attribute, IJSVGUnitUserSpaceOnUse);
                break;
            case IJSVGNodeAttributeStopColor:
                colorAttribute = attribute;
                break;
            default:
                break;
        }
    }
    if (colorAttribute == NULL) {
        return;
    }
    const char* bytes = IJSVGXMLAttributeBytes(colorAttribute);
    if (bytes[0] != '#') {
        [self consumeOffset:nil color:IJSVGXMLAttributeValue(colorAttribute) opacity:nil parser:parser];
        return;
    }
    CGColorRef color = [parser parsedStopColorForAttribute:colorAttribute];
    if (color == nil) {
        [self consumeOffset:nil color:IJSVGXMLAttributeValue(colorAttribute) opacity:nil parser:parser];
        return;
    }
    IJSVGColorNode* fill = (IJSVGColorNode*)[IJSVGColorNode colorNodeWithColor:color];
    CGFloat opacity = self.fillOpacity.value;
    if (opacity != 1.f) {
        fill.color = [IJSVGColor changeAlphaOnColor:color to:opacity];
    }
    self.fill = fill;
}

- (void)consumeOffset:(NSString*)offset color:(NSString*)stopColor opacity:(NSString*)opacityValue parser:(IJSVGParser*)parser
{
    IJSVGStop* node = self;
    NSString* value = nil;
    if (offset.length != 0) {
        value = offset;
        node.offset = [IJSVGUnitLength unitWithString:value];
    }
    if (opacityValue.length != 0) {
        value = opacityValue;
        node.fillOpacity = [IJSVGUnitLength unitWithString:value];
    }

    if (stopColor.length != 0) {
        value = stopColor;
        CGColorRef color = [value caseInsensitiveCompare:IJSVGColorCurrentColorName] == NSOrderedSame ? node.currentColor : [parser parsedStopColorForValue:value];
        IJSVGColorNode* colorNode = (IJSVGColorNode*)[IJSVGColorNode colorNodeWithColor:color];
        if (color == nil) {
            colorNode.isNoneOrTransparent = [IJSVGColor isNoneOrTransparent:value];
        } else {
            CGFloat opacity = node.fillOpacity.value;
            if (opacity != 1.f) {
                colorNode.color = [IJSVGColor changeAlphaOnColor:color to:opacity];
            }
        }
        node.fill = colorNode;
    }
}

@end
