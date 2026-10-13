//
//  IJSVGDefinitions.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
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

+ (void)consumeElement:(IJSVGXMLNode*)element parser:(IJSVGParser*)parser parentNode:(IJSVGGraphicsNode*)parentNode recursive:(BOOL)recursive
{
    if (IJSVGXMLChildCount(element) == 0) {
        return;
    }
    for (IJSVGXMLNode* childElement = IJSVGXMLFirstChild(element); childElement != NULL; childElement = IJSVGXMLNext(childElement)) {
        IJSVGNodeType type = IJSVGNodeTypeForString(IJSVGXMLLocalName(childElement), IJSVGXMLKind(childElement));

        // we can exit early, not a node we know of
        if (type == IJSVGNodeTypeNotFound) {
            continue;
        }

        // we always want style elements to be passed
        NSString* identifier = nil;
        IJSVGXMLAttributeList childElementAttributeIterator = IJSVGXMLAttributes(childElement);
        for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&childElementAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&childElementAttributeIterator)) {
            if (attribute->identifier == IJSVGNodeAttributeID) {
                identifier = IJSVGXMLAttributeValue(attribute);
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
            if (recursive == YES && IJSVGXMLChildCount(childElement) != 0) {
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
