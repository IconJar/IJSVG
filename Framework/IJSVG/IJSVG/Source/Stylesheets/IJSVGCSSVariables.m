//
//  IJSVGCSSVariables.m
//  IJSVG
//
//  Created by Curtis Hard on 12/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGCSSVariables.h>
#import <IJSVGCSSParser.h>
#import <IJSVGStyleSheetUtils.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGUtils.h>

enum {
    IJSVGCSSVariableMaximumDepth = 64,
    IJSVGCSSVariableMaximumBytes = 65536
};

typedef struct {
    __unsafe_unretained NSDictionary* declarations;
    __unsafe_unretained NSDictionary* inherited;
    __unsafe_unretained NSMutableDictionary* computed;
    __unsafe_unretained NSMutableSet* cyclic;
    __unsafe_unretained NSString* stack[IJSVGCSSVariableMaximumDepth];
    NSUInteger depth;
} IJSVGCSSVariableContext;

BOOL IJSVGCSSValueMayContainVariables(NSString* value)
{
    const char* bytes = value.UTF8String;
    if(bytes == NULL) {
        return NO;
    }
    for(const char* cursor = bytes; *(cursor += strcspn(cursor, "vV\\")) != '\0'; cursor++) {
        if(*cursor == '\\' || ((cursor[1] == 'a' || cursor[1] == 'A') &&
            (cursor[2] == 'r' || cursor[2] == 'R') && cursor[3] == '(')) {
            return YES;
        }
    }
    return NO;
}

NSString* IJSVGCSSResolvedPaintValue(NSString* value, NSUInteger attribute)
{
    if(value == nil || (attribute != IJSVGNodeAttributeFill && attribute != IJSVGNodeAttributeStroke)) {
        return value;
    }
    switch(IJSVGCSSWideKeywordFromString(value)) {
        case IJSVGCSSWideKeywordInitial:
            return attribute == IJSVGNodeAttributeFill ? @"black" : @"none";
        case IJSVGCSSWideKeywordInherit:
        case IJSVGCSSWideKeywordUnset:
        case IJSVGCSSWideKeywordRevert:
        case IJSVGCSSWideKeywordRevertLayer:
            return nil;
        case IJSVGCSSWideKeywordUnknown:
            break;
    }
    const char* bytes = value.UTF8String;
    if([IJSVGColor colorFromString:value] != nil || [IJSVGUtils defURL:value] != nil ||
       [IJSVGColor isNoneOrTransparent:value] ||
       IJSVGCharBufferCaseInsensitiveCompare(bytes, "currentColor") ||
       IJSVGCharBufferCaseInsensitiveCompare(bytes, "context-fill") ||
       IJSVGCharBufferCaseInsensitiveCompare(bytes, "context-stroke")) {
        return value;
    }
    return nil;
}

static NSString* IJSVGCSSVariableName(const IJSVGCSSComponents* components, NSUInteger index)
{
    const IJSVGCSSComponent* token = components->values + index;
    NSUInteger cursor = token->offset;
    NSString* name;
    if(memchr(components->bytes + cursor, '\\', token->length) == NULL) {
        name = IJSVGStyleSheetStringFromUTF8Bytes(components->bytes, cursor,
                                                  cursor + token->length);
    } else {
        name = IJSVGStyleSheetConsumeIdentifier(components->bytes,
                                                cursor + token->length, &cursor);
    }
    return name.length > 2 && [name hasPrefix:@"--"] ? name : nil;
}

static BOOL IJSVGCSSVariableArguments(const IJSVGCSSComponents* components,
                                      NSUInteger index, NSUInteger* fallback)
{
    const IJSVGCSSComponent* function = components->values + index;
    if(index + 1 == function->next ||
       components->values[index + 1].kind != IJSVGCSSComponentIdentifier) {
        return NO;
    }
    const IJSVGCSSComponent* identifier = components->values + index + 1;
    const char* name = components->bytes + identifier->offset;
    if(memchr(name, '\\', identifier->length) != NULL) {
        if(IJSVGCSSVariableName(components, index + 1) == nil) {
            return NO;
        }
    } else if(identifier->length <= 2 || name[0] != '-' || name[1] != '-') {
        return NO;
    }
    NSUInteger next = components->values[index + 1].next;
    *fallback = NSNotFound;
    if(next < function->next) {
        const IJSVGCSSComponent* comma = components->values + next;
        if(comma->kind != IJSVGCSSComponentDelimiter || comma->symbol != IJSVGCSSSymbolComma) {
            return NO;
        }
        *fallback = next;
        for(NSUInteger child = next + 1; child < function->next; child = components->values[child].next) {
            const IJSVGCSSComponent* token = components->values + child;
            if(token->kind == IJSVGCSSComponentDelimiter && (token->symbol == '!' || token->symbol == ';')) {
                return NO;
            }
        }
    }
    return YES;
}

static IJSVGCSSVariableSyntax IJSVGCSSValidateVariableComponents(const IJSVGCSSComponents* components)
{
    IJSVGCSSVariableSyntax result = IJSVGCSSVariableSyntaxLiteral;
    for(NSUInteger index = 0; index < components->count; index++) {
        const IJSVGCSSComponent* token = components->values + index;
        if(token->kind == IJSVGCSSComponentFunction && token->function == IJSVGCSSFunctionVar) {
            NSUInteger fallback;
            if(!IJSVGCSSVariableArguments(components, index, &fallback)) {
                return IJSVGCSSVariableSyntaxInvalid;
            }
            result = IJSVGCSSVariableSyntaxReferences;
        }
    }
    for(NSUInteger index = 0; index < components->count; index = components->values[index].next) {
        const IJSVGCSSComponent* token = components->values + index;
        if(token->kind == IJSVGCSSComponentDelimiter &&
           (token->symbol == '!' || token->symbol == ';')) {
            return IJSVGCSSVariableSyntaxInvalid;
        }
    }
    return result;
}

IJSVGCSSVariableSyntax IJSVGCSSValidateVariables(NSString* value)
{
    IJSVGStringBytes source = IJSVGStringGetBytes(value);
    IJSVGCSSComponents components;
    IJSVGCSSVariableSyntax result = IJSVGCSSVariableSyntaxInvalid;
    if(IJSVGCSSComponentsCreate(source.bytes, source.length, &components)) {
        result = IJSVGCSSValidateVariableComponents(&components);
    }
    IJSVGCSSComponentsRelease(&components);
    return result;
}

typedef struct {
    char* bytes;
    NSUInteger length;
    NSUInteger capacity;
    char storage[512];
} IJSVGCSSVariableBuffer;

static BOOL IJSVGCSSVariableBufferReserve(IJSVGCSSVariableBuffer* output, NSUInteger length)
{
    if(length > IJSVGCSSVariableMaximumBytes - output->length) {
        return NO;
    }
    NSUInteger required = output->length + length;
    if(required <= output->capacity) {
        return YES;
    }
    NSUInteger capacity = MIN(IJSVGCSSVariableMaximumBytes, MAX(required, output->capacity * 2));
    char* bytes = malloc(capacity);
    if(bytes == NULL) {
        return NO;
    }
    memcpy(bytes, output->bytes, output->length);
    if(output->bytes != output->storage) {
        free(output->bytes);
    }
    output->bytes = bytes;
    output->capacity = capacity;
    return YES;
}

static BOOL IJSVGCSSVariableAppend(IJSVGCSSVariableBuffer* output, const char* bytes,
    NSUInteger length)
{
    if(length == 0) {
        return YES;
    }
    if(!IJSVGCSSVariableBufferReserve(output, length)) {
        return NO;
    }
    memcpy(output->bytes + output->length, bytes, length);
    output->length += length;
    return YES;
}

static BOOL IJSVGCSSVariableTokenCharacter(char value)
{
    return (value >= 'a' && value <= 'z') || (value >= 'A' && value <= 'Z') ||
        (value >= '0' && value <= '9') || (unsigned char)value >= 0x80 ||
        value == '-' || value == '_' || value == '.' || value == '+' ||
        value == '#' || value == '%' || value == '\\';
}

static BOOL IJSVGCSSVariableAppendBoundary(IJSVGCSSVariableBuffer* output, const char* bytes,
                                           NSUInteger length)
{
    if(output->length != 0 && length != 0) {
        char previous = output->bytes[output->length - 1];
        if(IJSVGCSSVariableTokenCharacter(previous) &&
           (IJSVGCSSVariableTokenCharacter(bytes[0]) || bytes[0] == '(')) {
            if(!IJSVGCSSVariableAppend(output, "/**/", 4)) {
                return NO;
            }
        }
    }
    return IJSVGCSSVariableAppend(output, bytes, length);
}

static BOOL IJSVGCSSVariableSubstitute(const IJSVGCSSComponents* components,
                                        NSUInteger first, NSUInteger end,
                                        NSUInteger start, NSUInteger finish,
                                        NSDictionary* properties, IJSVGCSSVariableBuffer* output,
                                        BOOL boundary);

static BOOL IJSVGCSSVariableAppendReference(const IJSVGCSSComponents* components,
                                             NSUInteger index, NSDictionary* properties,
                                             IJSVGCSSVariableBuffer* output)
{
    const IJSVGCSSComponent* token = components->values + index;
    NSString* name = IJSVGCSSVariableName(components, index + 1);
    id value = properties[name];
    if(value != nil && value != NSNull.null) {
        IJSVGStringBytes replacement = IJSVGStringGetBytes(value);
        return IJSVGCSSVariableAppendBoundary(output, replacement.bytes, replacement.length);
    }
    NSUInteger fallback = components->values[index + 1].next;
    if(fallback == token->next) {
        return NO;
    }
    const IJSVGCSSComponent* comma = components->values + fallback;
    return IJSVGCSSVariableSubstitute(components, fallback + 1, token->next,
                                       comma->offset + comma->length,
                                       token->offset + token->length - 1,
                                       properties, output, YES);
}

static BOOL IJSVGCSSVariableSubstitute(const IJSVGCSSComponents* components,
                                        NSUInteger first, NSUInteger end,
                                        NSUInteger start, NSUInteger finish,
                                        NSDictionary* properties, IJSVGCSSVariableBuffer* output,
                                        BOOL boundary)
{
    NSUInteger marker = start;
    for(NSUInteger index = first; index < end;) {
        const IJSVGCSSComponent* token = components->values + index;
        if(token->kind != IJSVGCSSComponentFunction || token->function != IJSVGCSSFunctionVar) {
            index++;
            continue;
        }
        NSUInteger length = token->offset - marker;
        BOOL appended = boundary
            ? IJSVGCSSVariableAppendBoundary(output, components->bytes + marker, length)
            : IJSVGCSSVariableAppend(output, components->bytes + marker, length);
        if(!appended || !IJSVGCSSVariableAppendReference(components, index, properties, output)) {
            return NO;
        }
        marker = token->offset + token->length;
        index = token->next;
        boundary = YES;
    }
    return boundary ? IJSVGCSSVariableAppendBoundary(output, components->bytes + marker, finish - marker)
        : IJSVGCSSVariableAppend(output, components->bytes + marker, finish - marker);
}

static NSString* IJSVGCSSVariableExpand(const IJSVGCSSComponents* components,
                                        NSUInteger length, NSDictionary* properties)
{
    IJSVGCSSVariableBuffer output;
    output.bytes = output.storage;
    output.length = 0;
    output.capacity = sizeof(output.storage);
    NSString* result = nil;
    if(IJSVGCSSVariableSubstitute(components, 0, components->count, 0,
        length, properties, &output, NO)) {
        result = [[NSString alloc] initWithBytes:output.bytes
                                        length:output.length
                                      encoding:NSUTF8StringEncoding];
    }
    if(output.bytes != output.storage) {
        free(output.bytes);
    }
    return result;
}

static id IJSVGCSSVariableResolve(IJSVGCSSVariableContext* context, NSString* name);

static NSString* IJSVGCSSVariableResolveValue(IJSVGCSSVariableContext* context,
                                              NSString* name, NSString* value)
{
    IJSVGStringBytes source = IJSVGStringGetBytes(value);
    IJSVGCSSComponents components;
    NSString* result = nil;
    IJSVGCSSVariableSyntax syntax = IJSVGCSSComponentsCreate(source.bytes, source.length, &components)
        ? IJSVGCSSValidateVariableComponents(&components) : IJSVGCSSVariableSyntaxInvalid;
    if(syntax == IJSVGCSSVariableSyntaxLiteral) {
        result = [value copy];
    } else if(syntax == IJSVGCSSVariableSyntaxReferences) {
        for(NSUInteger index = 0; index < components.count; index++) {
            const IJSVGCSSComponent* token = components.values + index;
            if(token->kind == IJSVGCSSComponentFunction && token->function == IJSVGCSSFunctionVar) {
                NSString* dependency = IJSVGCSSVariableName(&components, index + 1);
                id resolved = IJSVGCSSVariableResolve(context, dependency);
                if(context->declarations[dependency] == nil) {
                    context->computed[dependency] = resolved;
                }
            }
        }
        if(![context->cyclic containsObject:name]) {
            result = IJSVGCSSVariableExpand(&components, source.length,
                                            context->computed);
        }
    }
    IJSVGCSSComponentsRelease(&components);
    return result;
}

static id IJSVGCSSVariableResolve(IJSVGCSSVariableContext* context, NSString* name)
{
    id cached = context->computed[name];
    if(cached != nil) {
        return cached;
    }
    NSString* value = context->declarations[name];
    if(value == nil) {
        return context->inherited[name] ?: NSNull.null;
    }
    for(NSUInteger index = 0; index < context->depth; index++) {
        if([context->stack[index] isEqualToString:name]) {
            for(; index < context->depth; index++) {
                [context->cyclic addObject:context->stack[index]];
            }
            return NSNull.null;
        }
    }
    if(context->depth == IJSVGCSSVariableMaximumDepth) {
        return NSNull.null;
    }
    IJSVGCSSWideKeyword keyword = IJSVGCSSWideKeywordFromString(value);
    if(keyword != IJSVGCSSWideKeywordUnknown) {
        id result = keyword == IJSVGCSSWideKeywordInitial ? NSNull.null :
            (context->inherited[name] ?: NSNull.null);
        context->computed[name] = result;
        return result;
    }
    context->stack[context->depth++] = name;
    NSString* result = IJSVGCSSVariableResolveValue(context, name, value);
    context->depth--;
    context->computed[name] = result ?: NSNull.null;
    return context->computed[name];
}

NSDictionary<NSString*, id>* IJSVGCSSResolveCustomProperties(NSDictionary<NSString*, NSString*>* declarations,
                                                             NSDictionary<NSString*, id>* inherited)
{
    if(declarations.count == 0) {
        return inherited;
    }
    NSMutableDictionary* computed = [[NSMutableDictionary alloc] init];
    NSMutableSet* cyclic = [[NSMutableSet alloc] init];
    IJSVGCSSVariableContext context = { declarations, inherited, computed, cyclic, { nil }, 0 };
    for(NSString* name in declarations) {
        IJSVGCSSVariableResolve(&context, name);
    }
    if(inherited.count == 0) {
        return [computed copy];
    }
    NSMutableDictionary* result = [inherited mutableCopy];
    [result addEntriesFromDictionary:computed];
    return [result copy];
}

NSString* IJSVGCSSResolveVariables(NSString* value,
                                   NSDictionary<NSString*, id>* properties)
{
    IJSVGStringBytes source = IJSVGStringGetBytes(value);
    IJSVGCSSComponents components;
    NSString* result = nil;
    if(IJSVGCSSComponentsCreate(source.bytes, source.length, &components)) {
        switch(IJSVGCSSValidateVariableComponents(&components)) {
            case IJSVGCSSVariableSyntaxLiteral:
                result = [value copy];
                break;
            case IJSVGCSSVariableSyntaxReferences:
                result = IJSVGCSSVariableExpand(&components, source.length,
                                                properties);
                break;
            case IJSVGCSSVariableSyntaxInvalid:
                break;
        }
    }
    IJSVGCSSComponentsRelease(&components);
    return result;
}
