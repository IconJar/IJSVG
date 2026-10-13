//
//  IJSVGSwitch.m
//  IJSVG
//
//  Created by Curtis Hard on 10/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGNodeParsing.h>
#import <IJSVGSwitch.h>
#import <ctype.h>
#import <string.h>

static BOOL IJSVGSwitchLanguageMatches(const char* languages, const char* preferred)
{
    size_t preferredLength = strlen(preferred);
    const char* cursor = languages;
    while (*cursor != '\0') {
        const char* start = cursor;
        while (*cursor != '\0' && *cursor != ',') {
            cursor++;
        }
        const char* end = cursor;
        while (start < end && isspace((unsigned char)*start)) {
            start++;
        }
        while (end > start && isspace((unsigned char)end[-1])) {
            end--;
        }
        size_t length = (size_t)(end - start);
        if (length != 0 && length <= preferredLength && (length == preferredLength || preferred[length] == '-')) {
            size_t index = 0;
            while (index < length && IJSVGCharToLower(start[index]) == IJSVGCharToLower(preferred[index])) {
                index++;
            }
            if (index == length) {
                return YES;
            }
        }
        if (*cursor == ',') {
            cursor++;
        }
    }
    return NO;
}

@implementation IJSVGSwitch

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeSwitch;
}

+ (NSXMLElement*)selectedChildInElement:(NSXMLElement*)element preferredLanguages:(NSArray<NSString*>*)preferredLanguages
{
    for (NSXMLNode* child in element.children) {
        if (child.kind != NSXMLElementKind || IJSVGNodeTypeForString(child.localName, child.kind) == IJSVGNodeTypeStyle) {
            continue;
        }
        NSXMLElement* candidate = (NSXMLElement*)child;

        // No extension languages are implemented. An explicitly empty
        // requiredExtensions also fails conditional processing.
        if ([candidate attributeForName:IJSVGAttributeRequiredExtensions] != nil) {
            continue;
        }
        NSString* languages = [candidate attributeForName:IJSVGAttributeSystemLanguage].stringValue;
        if (languages == nil) {
            return candidate;
        }
        const char* bytes = languages.UTF8String;
        if (bytes == NULL || strlen(bytes) != [languages lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
            continue;
        }
        for (NSString* preferred in preferredLanguages) {
            const char* preference = preferred.UTF8String;
            if (preference != NULL && strlen(preference) == [preferred lengthOfBytesUsingEncoding:NSUTF8StringEncoding] && IJSVGSwitchLanguageMatches(bytes, preference)) {
                return candidate;
            }
        }
    }
    return nil;
}

+ (IJSVGXMLNode*)selectedChildInXML:(IJSVGXMLNode*)element preferredLanguages:(NSArray<NSString*>*)preferredLanguages
{
    for (IJSVGXMLNode* child = IJSVGXMLFirstChild(element); child != NULL; child = IJSVGXMLNext(child)) {
        if (IJSVGXMLKind(child) != NSXMLElementKind || IJSVGXMLType(child) == IJSVGNodeTypeStyle) {
            continue;
        }
        IJSVGXMLNode* candidate = (IJSVGXMLNode*)child;

        // No extension languages are implemented. An explicitly empty
        // requiredExtensions also fails conditional processing.
        if (IJSVGXMLAttributeForIdentifier(candidate, IJSVGNodeAttributeRequiredExtensions) != nil) {
            continue;
        }
        NSString* languages = IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(candidate, IJSVGNodeAttributeSystemLanguage));
        if (languages == nil) {
            return candidate;
        }
        const char* bytes = languages.UTF8String;
        if (bytes == NULL || strlen(bytes) != [languages lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
            continue;
        }
        for (NSString* preferred in preferredLanguages) {
            const char* preference = preferred.UTF8String;
            if (preference != NULL && strlen(preference) == [preferred lengthOfBytesUsingEncoding:NSUTF8StringEncoding] && IJSVGSwitchLanguageMatches(bytes, preference)) {
                return candidate;
            }
        }
    }
    return nil;
}

@end

#pragma mark - Parsing

@implementation IJSVGSwitch (Parsing)

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
