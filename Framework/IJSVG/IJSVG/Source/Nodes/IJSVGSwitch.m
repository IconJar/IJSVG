//
//  IJSVGSwitch.m
//  IJSVG
//
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGSwitch.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGUtils.h>
#import <ctype.h>
#import <string.h>

static BOOL IJSVGSwitchLanguageMatches(const char* languages,
                                       const char* preferred)
{
    size_t preferredLength = strlen(preferred);
    const char* cursor = languages;
    while(*cursor != '\0') {
        const char* start = cursor;
        while(*cursor != '\0' && *cursor != ',') {
            cursor++;
        }
        const char* end = cursor;
        while(start < end && isspace((unsigned char)*start)) {
            start++;
        }
        while(end > start && isspace((unsigned char)end[-1])) {
            end--;
        }
        size_t length = (size_t)(end - start);
        if(length != 0 && length <= preferredLength &&
           (length == preferredLength || preferred[length] == '-')) {
            size_t index = 0;
            while(index < length && IJSVGCharToLower(start[index]) == IJSVGCharToLower(preferred[index])) {
                index++;
            }
            if(index == length) {
                return YES;
            }
        }
        if(*cursor == ',') {
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

+ (NSXMLElement*)selectedChildInElement:(NSXMLElement*)element
                     preferredLanguages:(NSArray<NSString*>*)preferredLanguages
{
    for(NSXMLNode* child in element.children) {
        if(child.kind != NSXMLElementKind ||
           [IJSVGNode typeForString:child.localName kind:child.kind] == IJSVGNodeTypeStyle) {
            continue;
        }
        NSXMLElement* candidate = (NSXMLElement*)child;
        // No extension languages are implemented. An explicitly empty
        // requiredExtensions also fails conditional processing.
        if([candidate attributeForName:IJSVGAttributeRequiredExtensions] != nil) {
            continue;
        }
        NSString* languages = [candidate attributeForName:IJSVGAttributeSystemLanguage].stringValue;
        if(languages == nil) {
            return candidate;
        }
        const char* bytes = languages.UTF8String;
        if(bytes == NULL || strlen(bytes) != [languages lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
            continue;
        }
        for(NSString* preferred in preferredLanguages) {
            const char* preference = preferred.UTF8String;
            if(preference != NULL && strlen(preference) == [preferred lengthOfBytesUsingEncoding:NSUTF8StringEncoding] &&
               IJSVGSwitchLanguageMatches(bytes, preference)) {
                return candidate;
            }
        }
    }
    return nil;
}

@end
