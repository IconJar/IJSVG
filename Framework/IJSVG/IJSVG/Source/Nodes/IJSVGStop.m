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
        NSColor* color = [value caseInsensitiveCompare:IJSVGColorCurrentColorName] == NSOrderedSame ? node.currentColor : [parser parsedStopColorForValue:value];
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
