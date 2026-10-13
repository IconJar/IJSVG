//
//  IJSVGParsing.m
//  IJSVG
//
//  Created by Curtis Hard on 04/02/2021.
//  Copyright © 2021 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGCSSParser.h>
#import <IJSVGStyleSheetUtils.h>

IJSVGParsingStringMethod* IJSVGParsingStringMethodCreate(void)
{
    IJSVGParsingStringMethod* method = (IJSVGParsingStringMethod*)malloc(sizeof(IJSVGParsingStringMethod));
    if (method == NULL) {
        return NULL;
    }
    method->name = NULL;
    method->parameters = NULL;
    return method;
}

void IJSVGParsingStringMethodRelease(IJSVGParsingStringMethod* stringMethod)
{
    if (stringMethod == NULL) {
        return;
    }
    if (stringMethod->name != NULL) {
        (void)free(stringMethod->name), stringMethod->name = NULL;
    }
    if (stringMethod->parameters != NULL) {
        (void)free(stringMethod->parameters), stringMethod->parameters = NULL;
    }
    if (stringMethod != NULL) {
        (void)free(stringMethod), stringMethod = NULL;
    }
}

void IJSVGParsingStringMethodsRelease(IJSVGParsingStringMethod** methods, NSUInteger count)
{
    for (int i = 0; i < count; i++) {
        IJSVGParsingStringMethodRelease(methods[i]);
    }
    (void)free(methods), methods = NULL;
}

IJSVGParsingStringMethod** IJSVGParsingMethodParseString(const char* string, NSUInteger* count)
{
    BOOL valid;
    return IJSVGParsingMethodParseStringWithValidation(string, count, &valid);
}

static char* IJSVGParsingCopyTrimmedBytes(const char* bytes, NSUInteger length)
{
    while (length != 0 && isspace((unsigned char)*bytes)) {
        bytes++;
        length--;
    }
    while (length != 0 && isspace((unsigned char)bytes[length - 1])) {
        length--;
    }
    return strndup(bytes, length);
}

IJSVGParsingStringMethod** IJSVGParsingMethodParseStringWithValidation(const char* string, NSUInteger* count, BOOL* valid)
{
    *count = 0;
    IJSVGCSSComponents components;
    *valid = IJSVGCSSComponentsCreateWithOptions(string, string == NULL ? 0 : strlen(string), IJSVGCSSParserOptionSVG, &components);
    IJSVGParsingStringMethod** methods = components.count == 0 ? NULL : malloc(components.count * sizeof(*methods));
    if (components.count != 0 && methods == NULL) {
        *valid = NO;
        IJSVGCSSComponentsRelease(&components);
        return NULL;
    }
    for (NSUInteger index = 0; index < components.count;) {
        const IJSVGCSSComponent* component = components.values + index;
        if (component->kind != IJSVGCSSComponentFunction || component->next <= index) {
            *valid = NO;
            break;
        }
        IJSVGParsingStringMethod* method = IJSVGParsingStringMethodCreate();
        if (method == NULL) {
            *valid = NO;
            break;
        }
        NSUInteger nameLength = component->argumentOffset - component->offset - 1;
        method->name = IJSVGParsingCopyTrimmedBytes(string + component->offset, nameLength);
        method->parameters = IJSVGParsingCopyTrimmedBytes(string + component->argumentOffset, component->argumentLength);
        if (method->name == NULL || method->parameters == NULL) {
            IJSVGParsingStringMethodRelease(method);
            *valid = NO;
            break;
        }
        methods[(*count)++] = method;
        index = component->next;
    }
    IJSVGCSSComponentsRelease(&components);
    return methods;
}

BOOL IJSVGParsingUnwrapArgument(const char* argument, const char** bytes, size_t* length, char* quote)
{
    *bytes = NULL;
    *length = 0;
    *quote = 0;
    if (argument == NULL) {
        return NO;
    }
    const char* start = argument;
    const char* end = start + strlen(start);
    while (start < end && isspace((unsigned char)*start)) {
        start++;
    }
    while (end > start && isspace((unsigned char)end[-1])) {
        end--;
    }
    if (start < end && (*start == '\'' || *start == '"')) {
        char delimiter = *start;
        if (end - start < 2 || end[-1] != delimiter) {
            return NO;
        }
        *quote = delimiter;
        start++;
        end--;
    }
    *bytes = start;
    *length = (size_t)(end - start);
    return YES;
}

@implementation IJSVGParsing

@end
