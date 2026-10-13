//
//  IJSVGDefinitions.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGDefinitions.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGDefinitions

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeDef;
}

@end

#pragma mark - Parsing

@implementation IJSVGDefinitions (Parsing)

+ (void)consumeElement:(NSXMLElement*)element parser:(IJSVGParser*)parser parentNode:(IJSVGGraphicsNode*)parentNode recursive:(BOOL)recursive
{
    if (element.childCount == 0) {
        return;
    }
    for (NSXMLElement* childElement in element.children) {
        IJSVGNodeType type = IJSVGNodeTypeForString(childElement.localName, childElement.kind);

        // we can exit early, not a node we know of
        if (type == IJSVGNodeTypeNotFound) {
            continue;
        }

        // we always want style elements to be passed
        NSString* identifier = nil;
        for (NSXMLNode* attribute in childElement.attributes) {
            if ([attribute.name isEqualToString:IJSVGAttributeID]) {
                identifier = attribute.stringValue;
                break;
            }
        }
        if (identifier != nil) {
            [parser detachElement:childElement withIdentifier:identifier];
        }

        if (type == IJSVGNodeTypeStyle) {
            [parser parseStyleElement:childElement parentNode:parentNode];
        } else {
            // only run this if recursive or it can be slow or incorrect
            // when parsing the tree with ids that are the same
            if (recursive == YES && childElement.childCount != 0) {
                [parser parseDefElement:childElement parentNode:parentNode recursive:recursive];
            }
        }
    }
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGContainerAttributes();
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
