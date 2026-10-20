//
//  IJSVGStyleSheetSelector.m
//  IJSVG
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGStyleSheetSelector.h>
#import <IJSVGParserUtils.h>
#import <IJSVGStyleSheetUtils.h>
#import <IJSVGXML.h>

// Saturate each component independently: ten classes must never equal one ID.
#define SPECIFICITY_BITS 21
#define SPECIFICITY_MASK ((1UL << SPECIFICITY_BITS) - 1)
#define SPECIFICITY_TAG 1UL
#define SPECIFICITY_CLASS (1UL << SPECIFICITY_BITS)
#define SPECIFICITY_IDENTIFIER (1UL << (2 * SPECIFICITY_BITS))

static NSUInteger IJSVGSelectorAddSpecificity(NSUInteger lhs, NSUInteger rhs)
{
    NSUInteger result = 0;
    for (NSUInteger shift = 0; shift <= 2 * SPECIFICITY_BITS; shift += SPECIFICITY_BITS) {
        result |= MIN(((lhs >> shift) & SPECIFICITY_MASK) + ((rhs >> shift) & SPECIFICITY_MASK), SPECIFICITY_MASK) << shift;
    }
    return result;
}

static id<IJSVGStyleSheetSelectorNode> IJSVGSelectorNext(id<IJSVGStyleSheetSelectorNode> node)
{
    return [node respondsToSelector:@selector(selectorNextSibling)] ? node.selectorNextSibling : nil;
}

static id<IJSVGStyleSheetSelectorNode> IJSVGSelectorFirstChild(id<IJSVGStyleSheetSelectorNode> node)
{
    return [node respondsToSelector:@selector(selectorFirstChild)] ? node.selectorFirstChild : nil;
}

typedef NS_ENUM(uint8_t, IJSVGSelectorAttributeOperator) {
    IJSVGSelectorAttributeExists,
    IJSVGSelectorAttributeEquals,
    IJSVGSelectorAttributeIncludes,
    IJSVGSelectorAttributeDash,
    IJSVGSelectorAttributePrefix,
    IJSVGSelectorAttributeSuffix,
    IJSVGSelectorAttributeSubstring
};

@interface IJSVGStyleSheetAttributeSelector : NSObject {
@public
    NSString* name;
    NSString* namespaceURI;
    NSString* value;
    IJSVGSelectorAttributeOperator operation;
    BOOL insensitive;
    IJSVGNodeAttribute identifier;
    const char* nameBytes;
    const char* namespaceBytes;
    const char* valueBytes;
    NSUInteger valueLength;
}
@end

@implementation IJSVGStyleSheetAttributeSelector
@end

static unsigned char IJSVGSelectorFoldASCII(unsigned char c)
{
    return c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c;
}

static BOOL IJSVGSelectorBytesEqual(const char* lhs, const char* rhs, NSUInteger count, BOOL insensitive)
{
    if (!insensitive) {
        return memcmp(lhs, rhs, count) == 0;
    }
    for (NSUInteger index = 0; index < count; index++) {
        if (IJSVGSelectorFoldASCII(lhs[index]) != IJSVGSelectorFoldASCII(rhs[index])) {
            return NO;
        }
    }
    return YES;
}

static BOOL IJSVGSelectorAttributeMatches(IJSVGStyleSheetAttributeSelector* __unsafe_unretained selector, IJSVGXMLAttribute* attribute)
{
    BOOL sameName = selector->identifier != IJSVGNodeAttributeUnknown && attribute->identifier != IJSVGNodeAttributeUnknown
        ? selector->identifier == attribute->identifier
        : strcmp(selector->nameBytes, attribute->name) == 0;
    if (!sameName || (selector->namespaceBytes != NULL && strcmp(selector->namespaceBytes, attribute->uri ?: "") != 0)) {
        return NO;
    }
    if (selector->operation == IJSVGSelectorAttributeExists) {
        return YES;
    }
    const char* actual = IJSVGXMLAttributeBytes(attribute);
    const char* expected = selector->valueBytes;
    NSUInteger length = attribute->value.length;
    NSUInteger count = selector->valueLength;
    BOOL insensitive = selector->insensitive;
    switch (selector->operation) {
        case IJSVGSelectorAttributeEquals:
            return length == count && IJSVGSelectorBytesEqual(actual, expected, count, insensitive);
        case IJSVGSelectorAttributeDash:
            return length >= count && (length == count || actual[count] == '-') && IJSVGSelectorBytesEqual(actual, expected, count, insensitive);
        case IJSVGSelectorAttributePrefix:
            return count != 0 && length >= count && IJSVGSelectorBytesEqual(actual, expected, count, insensitive);
        case IJSVGSelectorAttributeSuffix:
            return count != 0 && length >= count && IJSVGSelectorBytesEqual(actual + length - count, expected, count, insensitive);
        case IJSVGSelectorAttributeSubstring:
            if (count != 0 && length >= count) {
                for (NSUInteger index = 0; index <= length - count; index++) {
                    if (IJSVGSelectorBytesEqual(actual + index, expected, count, insensitive)) {
                        return YES;
                    }
                }
            }
            return NO;
        case IJSVGSelectorAttributeIncludes:
            if (count == 0) {
                return NO;
            }
            for (NSUInteger index = 0; index < count; index++) {
                if (IJSVGStyleSheetCharIsWhitespace(expected[index])) {
                    return NO;
                }
            }
            for (NSUInteger index = 0; index < length;) {
                index = IJSVGStyleSheetIndexBySkippingWhitespace(actual, index, length);
                NSUInteger start = index;
                while (index < length && !IJSVGStyleSheetCharIsWhitespace(actual[index])) {
                    index++;
                }
                if (index - start == count && IJSVGSelectorBytesEqual(actual + start, expected, count, insensitive)) {
                    return YES;
                }
            }
            return NO;
        case IJSVGSelectorAttributeExists:
            return YES;
    }
}

static NSString* IJSVGSelectorConsumeValue(const char* bytes, NSUInteger length, NSUInteger* cursor)
{
    if (*cursor >= length) {
        return nil;
    }
    if (bytes[*cursor] == '\'' || bytes[*cursor] == '"') {
        NSUInteger start = *cursor;
        return IJSVGStyleSheetSkipQuotedString(bytes, length, cursor) ? IJSVGStyleSheetDecodeString(bytes, start, *cursor) : nil;
    }
    return IJSVGStyleSheetConsumeIdentifier(bytes, length, cursor);
}

// A nil namespace means any namespace. An empty string means no namespace.
static BOOL IJSVGSelectorConsumeQualifiedName(const char* bytes, NSUInteger length, NSUInteger* cursor, NSDictionary* namespaces, BOOL attribute, NSString* __strong* name, NSString* __strong* uri)
{
    NSString* first = nil;
    BOOL wildcard = *cursor < length && bytes[*cursor] == '*';
    if (wildcard) {
        (*cursor)++;
        first = @"*";
    } else if (*cursor < length && bytes[*cursor] != '|') {
        first = IJSVGStyleSheetConsumeIdentifier(bytes, length, cursor);
        if (first == nil) {
            return NO;
        }
    }
    if (*cursor < length && bytes[*cursor] == '|'
        && (*cursor + 1 == length || (bytes[*cursor + 1] != '|' && bytes[*cursor + 1] != '='))) {
        (*cursor)++;
        *uri = first == nil ? @"" : (wildcard ? nil : namespaces[first]);
        if (first != nil && !wildcard && *uri == nil) {
            return NO;
        }
        if (!attribute && *cursor < length && bytes[*cursor] == '*') {
            (*cursor)++;
            *name = nil;
            return YES;
        }
        *name = IJSVGStyleSheetConsumeIdentifier(bytes, length, cursor);
        return *name != nil;
    }
    if (first == nil || (attribute && wildcard)) {
        return NO;
    }
    *name = wildcard ? nil : first;
    *uri = attribute ? @"" : namespaces[@""];
    return YES;
}

static IJSVGStyleSheetAttributeSelector* IJSVGSelectorConsumeAttribute(const char* bytes, NSUInteger length, NSUInteger* cursor, NSDictionary* namespaces)
{
    *cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, *cursor + 1, length);
    IJSVGStyleSheetAttributeSelector* result = [[IJSVGStyleSheetAttributeSelector alloc] init];
    if (!IJSVGSelectorConsumeQualifiedName(bytes, length, cursor, namespaces, YES, &result->name, &result->namespaceURI)) {
        return nil;
    }
    result->nameBytes = result->name.UTF8String;
    result->namespaceBytes = result->namespaceURI.UTF8String;
    result->identifier = IJSVGNodeAttributeForBytes(result->nameBytes, strlen(result->nameBytes));
    *cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, *cursor, length);
    if (*cursor == length) {
        return nil;
    }
    char c = bytes[(*cursor)++];
    if (c == ']') {
        return result;
    }
    switch (c) {
        case '=':
            result->operation = IJSVGSelectorAttributeEquals;
            break;
        case '~':
            result->operation = IJSVGSelectorAttributeIncludes;
            break;
        case '|':
            result->operation = IJSVGSelectorAttributeDash;
            break;
        case '^':
            result->operation = IJSVGSelectorAttributePrefix;
            break;
        case '$':
            result->operation = IJSVGSelectorAttributeSuffix;
            break;
        case '*':
            result->operation = IJSVGSelectorAttributeSubstring;
            break;
        default:
            return nil;
    }
    if (c != '=' && (*cursor == length || bytes[(*cursor)++] != '=')) {
        return nil;
    }
    *cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, *cursor, length);
    result->value = IJSVGSelectorConsumeValue(bytes, length, cursor);
    if (result->value == nil) {
        return nil;
    }
    result->valueBytes = result->value.UTF8String;
    result->valueLength = [result->value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    *cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, *cursor, length);
    if (*cursor < length && bytes[*cursor] != ']') {
        char flag[8] = { 0 };
        if (!IJSVGStyleSheetConsumeASCIIIdentifier(bytes, length, cursor, flag, sizeof(flag)) || strlen(flag) != 1) {
            return nil;
        }
        c = IJSVGSelectorFoldASCII(flag[0]);
        if (c != 'i' && c != 's') {
            return nil;
        }
        result->insensitive = c == 'i';
        *cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, *cursor, length);
    }
    return *cursor < length && bytes[(*cursor)++] == ']' ? result : nil;
}

// RFC 4647 extended filtering, including singleton boundaries and wildcards.
static BOOL IJSVGSelectorLanguageMatches(const char* language, const char* range)
{
    if (*range == '\0') {
        return *language == '\0';
    }
    if (*language == '\0') {
        return NO;
    }
    NSUInteger r = strcspn(range, "-"), l = strcspn(language, "-");
    if (!(r == 1 && *range == '*') && (r != l || !IJSVGSelectorBytesEqual(language, range, r, YES))) {
        return NO;
    }
    range += r;
    language += l;
    while (*range != '\0') {
        range++;
        r = strcspn(range, "-");
        if (r == 1 && *range == '*') {
            range += r;
            continue;
        }
        BOOL found = NO;
        while (*language != '\0') {
            language++;
            l = strcspn(language, "-");
            if (r == l && IJSVGSelectorBytesEqual(language, range, r, YES)) {
                found = YES;
                language += l;
                break;
            }
            if (l == 1) {
                return NO;
            }
            language += l;
        }
        if (!found) {
            return NO;
        }
        range += r;
    }
    return YES;
}

@interface IJSVGSelectorFilteredPositions : NSObject {
@public
    NSMapTable* positions;
    NSUInteger count;
}
@end

@implementation IJSVGSelectorFilteredPositions
@end

@interface IJSVGStyleSheetSelectorRecord ()
@property (nonatomic, strong) NSMapTable* filteredPositions;
@end

@implementation IJSVGStyleSheetSelectorRecord

- (IJSVGStyleSheetSelectorNodeKind)selectorNodeKind
{
    return IJSVGStyleSheetSelectorNodeKindXMLRecord;
}

- (IJSVGXMLAttributeList)selectorAttributes
{
    if (_selectorAttributeOverlay != NULL) {
        return (IJSVGXMLAttributeList) { .overlay = _selectorAttributeOverlay, .count = _selectorAttributeCount };
    }
    return _selectorElement != NULL ? IJSVGXMLAttributes(_selectorElement) : (IJSVGXMLAttributeList) { 0 };
}

- (BOOL)selectorMatchesAttribute:(IJSVGStyleSheetAttributeSelector*)selector
{
    IJSVGXMLAttributeList list = [self selectorAttributes];
    for (NSUInteger index = 0; index < list.count; index++) {
        IJSVGXMLAttribute* attribute = list.overlay != NULL ? list.overlay[index] : list.first + index;
        if (IJSVGSelectorAttributeMatches(selector, attribute)) {
            return YES;
        }
    }
    return NO;
}

- (const char*)selectorLanguage
{
    IJSVGXMLAttributeList list = [self selectorAttributes];
    const char* language = NULL;
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&list); attribute != NULL; attribute = IJSVGXMLNextAttribute(&list)) {
        if (strcmp(attribute->name, "lang") != 0) {
            continue;
        }
        if (attribute->uri != NULL && strcmp(attribute->uri, "http://www.w3.org/XML/1998/namespace") == 0) {
            return IJSVGXMLAttributeBytes(attribute);
        }
        if (attribute->uri == NULL || attribute->uri[0] == '\0') {
            language = IJSVGXMLAttributeBytes(attribute);
        }
    }
    return language;
}

- (BOOL)selectorIsEmpty
{
    return !_selectorHasContent;
}

- (NSUInteger)selectorIndexOfType:(BOOL)ofType fromEnd:(BOOL)fromEnd
{
    // XML records are immutable after construction. Each sibling position is
    // computed once instead of walking a wide sibling list for every rule.
    NSUInteger index = ofType ? _typeIndex : _childIndex;
    NSUInteger count = ofType ? _typeCount : _childCount;
    return fromEnd ? MAX(count, 1) - MAX(index, 1) + 1 : MAX(index, 1);
}

@end

@implementation IJSVGNode (IJSVGStyleSheetSelectorNode)

- (IJSVGStyleSheetSelectorNodeKind)selectorNodeKind
{
    return IJSVGStyleSheetSelectorNodeKindRenderNode;
}

- (id<IJSVGStyleSheetSelectorNode>)selectorParent
{
    return self.parentNode;
}

- (id<IJSVGStyleSheetSelectorNode>)selectorPreviousSibling
{
    IJSVGGroup* group = (IJSVGGroup*)self.parentNode;
    if ((group.nodeTraits & IJSVGNodeTypeTraitGroup) == 0) {
        return nil;
    }
    NSUInteger index = [group.children indexOfObjectIdenticalTo:self];
    return index == NSNotFound || index == 0 ? nil : group.children[index - 1];
}

- (id<IJSVGStyleSheetSelectorNode>)selectorNextSibling
{
    IJSVGGroup* group = (IJSVGGroup*)self.parentNode;
    if ((group.nodeTraits & IJSVGNodeTypeTraitGroup) == 0) {
        return nil;
    }
    NSUInteger index = [group.children indexOfObjectIdenticalTo:self];
    return index == NSNotFound || index + 1 >= group.children.count ? nil : group.children[index + 1];
}

- (id<IJSVGStyleSheetSelectorNode>)selectorFirstChild
{
    return (self.nodeTraits & IJSVGNodeTypeTraitGroup) != 0 ? ((IJSVGGroup*)self).children.firstObject : nil;
}

- (BOOL)selectorIsEmpty
{
    // Parsed SVGs always use XML records, which also preserve text and CDATA.
    return self.selectorFirstChild == nil;
}

- (NSUInteger)selectorIndexOfType:(BOOL)ofType fromEnd:(BOOL)fromEnd
{
    IJSVGGroup* group = (IJSVGGroup*)self.parentNode;
    if ((group.nodeTraits & IJSVGNodeTypeTraitGroup) == 0) {
        return 1;
    }
    NSUInteger index = 0;
    NSEnumerator* enumerator = fromEnd ? group.children.reverseObjectEnumerator : group.children.objectEnumerator;
    for (IJSVGNode* sibling in enumerator) {
        if (!ofType || [sibling.name isEqualToString:self.name]) {
            index++;
        }
        if (sibling == self) {
            return index;
        }
    }
    return 0;
}

@end

@interface IJSVGStyleSheetPseudoClass : NSObject {
@public
    IJSVGSelectorPseudoKind kind;
    NSInteger a;
    NSInteger b;
    BOOL ofType;
    BOOL fromEnd;
    BOOL only;
    NSArray<IJSVGStyleSheetSelector*>* selectors;
    NSArray<NSString*>* languages;
}
@end

@implementation IJSVGStyleSheetPseudoClass
@end

@interface IJSVGStyleSheetSelector ()
@property (nonatomic) IJSVGStyleSheetSelectorCombinator relativeCombinator;
@property (nonatomic) BOOL needsSelectorTree;
@property (nonatomic) BOOL usesScope;
@property (nonatomic) BOOL relative;
@property (nonatomic, copy) NSArray<IJSVGStyleSheetSelector*>* parentSelectors;
@property (nonatomic, strong) NSArray<IJSVGStyleSheetSelectorRaw*>* matchSelectors;
@property (nonatomic, copy) NSDictionary<NSString*, NSString*>* namespaces;
- (instancetype)initWithString:(NSString*)string depth:(NSUInteger)depth insideHas:(BOOL)insideHas relative:(BOOL)relative namespaces:(NSDictionary*)namespaces parentSelectors:(NSArray<IJSVGStyleSheetSelector*>*)parentSelectors;
- (BOOL)compileAtDepth:(NSUInteger)depth insideHas:(BOOL)insideHas;
- (BOOL)matchesNode:(id<IJSVGStyleSheetSelectorNode>)node scope:(id<IJSVGStyleSheetSelectorNode>)scope;
- (BOOL)matchesRelativeTo:(id<IJSVGStyleSheetSelectorNode>)anchor scope:(id<IJSVGStyleSheetSelectorNode>)scope;
@end

// Split only at outer commas. A comma in :is(), an escape, or a quoted
// unsupported selector must not turn into an unrelated stylesheet rule.
static NSArray<NSString*>* IJSVGSelectorListParts(NSString* string)
{
    const char* bytes = string.UTF8String;
    if (bytes == NULL) {
        return nil;
    }
    NSUInteger length = strlen(bytes), start = 0, depth = 0;
    NSMutableArray* parts = [NSMutableArray array];
    char quote = 0;
    BOOL escaped = NO;
    for (NSUInteger index = 0; index < length; index++) {
        char c = bytes[index];
        if (IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
            continue;
        }
        if (c == '(' || c == '[') {
            depth++;
        } else if (c == ')' || c == ']') {
            if (depth == 0) {
                return nil;
            }
            depth--;
        } else if (c == ',' && depth == 0) {
            [parts addObject:IJSVGStyleSheetStringFromUTF8Bytes(bytes, start, index) ?: @""];
            start = index + 1;
        }
    }
    if (depth != 0 || quote != 0 || escaped) {
        return nil;
    }
    [parts addObject:IJSVGStyleSheetStringFromUTF8Bytes(bytes, start, length) ?: @""];
    return parts;
}

static NSArray<IJSVGStyleSheetSelector*>* IJSVGSelectorParseList(NSString* string, BOOL forgiving, NSUInteger depth, BOOL insideHas, BOOL relative, NSDictionary* namespaces, NSArray<IJSVGStyleSheetSelector*>* parentSelectors)
{
    NSArray* parts = IJSVGSelectorListParts(string);
    if (parts == nil || depth > 64) {
        return nil;
    }
    NSMutableArray* result = [NSMutableArray array];
    for (NSString* part in parts) {
        IJSVGStyleSheetSelector* item = [[IJSVGStyleSheetSelector alloc] initWithString:part depth:depth insideHas:insideHas relative:relative namespaces:namespaces parentSelectors:parentSelectors];
        if (item == nil && !forgiving) {
            return nil;
        }
        if (item != nil) {
            [result addObject:item];
        }
    }
    return result;
}

static BOOL IJSVGSelectorConsumeInteger(const char* bytes, NSUInteger length, NSUInteger* cursor, BOOL negative, NSInteger* value)
{
    NSUInteger start = *cursor;
    NSUInteger magnitude = 0;
    NSUInteger limit = (NSUInteger)NSIntegerMax + (negative ? 1 : 0);
    while (*cursor < length && bytes[*cursor] >= '0' && bytes[*cursor] <= '9') {
        NSUInteger digit = bytes[(*cursor)++] - '0';
        if (magnitude > (limit - digit) / 10) {
            return NO;
        }
        magnitude = magnitude * 10 + digit;
    }
    if (*cursor == start) {
        return NO;
    }
    *value = negative ? (magnitude == (NSUInteger)NSIntegerMax + 1 ? NSIntegerMin : -(NSInteger)magnitude) : (NSInteger)magnitude;
    return YES;
}

static BOOL IJSVGSelectorParseNth(NSString* argument, IJSVGStyleSheetPseudoClass* pseudo, NSUInteger depth, BOOL insideHas, NSDictionary* namespaces, NSArray<IJSVGStyleSheetSelector*>* parentSelectors)
{
    const char* bytes = argument.UTF8String;
    NSUInteger length = strlen(bytes);
    NSUInteger cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, 0, length);
    if (cursor + 3 <= length && strncasecmp(bytes + cursor, "odd", 3) == 0) {
        pseudo->a = 2;
        pseudo->b = 1;
        cursor += 3;
    } else if (cursor + 4 <= length && strncasecmp(bytes + cursor, "even", 4) == 0) {
        pseudo->a = 2;
        cursor += 4;
    } else {
        BOOL negative = cursor < length && bytes[cursor] == '-';
        if (cursor < length && (bytes[cursor] == '-' || bytes[cursor] == '+')) {
            cursor++;
        }
        NSInteger coefficient = negative ? -1 : 1;
        BOOL hasDigits = cursor < length && bytes[cursor] >= '0' && bytes[cursor] <= '9';
        if (hasDigits && !IJSVGSelectorConsumeInteger(bytes, length, &cursor, negative, &coefficient)) {
            return NO;
        }
        if (cursor < length && (bytes[cursor] == 'n' || bytes[cursor] == 'N')) {
            cursor++;
            pseudo->a = coefficient;
            NSUInteger afterN = cursor;
            cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
            if (cursor < length && (bytes[cursor] == '+' || bytes[cursor] == '-')) {
                negative = bytes[cursor++] == '-';
                cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
                if (!IJSVGSelectorConsumeInteger(bytes, length, &cursor, negative, &pseudo->b)) {
                    return NO;
                }
            } else {
                cursor = afterN;
            }
        } else if (hasDigits) {
            pseudo->b = coefficient;
        } else {
            return NO;
        }
    }
    NSUInteger end = cursor;
    cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
    if (cursor == length) {
        return YES;
    }

    // Selectors 4 permits a strict selector list after "of" for child indexing.
    if (pseudo->ofType || cursor == end || cursor + 2 >= length || strncasecmp(bytes + cursor, "of", 2) != 0 || !IJSVGStyleSheetCharIsWhitespace(bytes[cursor + 2])) {
        return NO;
    }
    NSString* filter = IJSVGStyleSheetStringFromUTF8Bytes(bytes, cursor + 2, length);
    pseudo->selectors = IJSVGSelectorParseList(filter, NO, depth + 1, insideHas, NO, namespaces, parentSelectors);
    return pseudo->selectors.count != 0;
}

static BOOL IJSVGSelectorMatchesAny(NSArray<IJSVGStyleSheetSelector*>* selectors, id<IJSVGStyleSheetSelectorNode> node, id<IJSVGStyleSheetSelectorNode> scope)
{
    for (IJSVGStyleSheetSelector* item in selectors) {
        if ([item matchesNode:node scope:scope]) {
            return YES;
        }
    }
    return NO;
}

static BOOL IJSVGSelectorMatchPseudo(IJSVGStyleSheetPseudoClass* pseudo, id<IJSVGStyleSheetSelectorNode> node, id<IJSVGStyleSheetSelectorNode> scope)
{
    switch (pseudo->kind) {
        case IJSVGSelectorPseudoRoot:
            return node.selectorParent == nil;
        case IJSVGSelectorPseudoScope:
            return node == scope;
        case IJSVGSelectorPseudoEmpty:
            return [node respondsToSelector:@selector(selectorIsEmpty)] && node.selectorIsEmpty;
        case IJSVGSelectorPseudoIs:
        case IJSVGSelectorPseudoWhere:
            return IJSVGSelectorMatchesAny(pseudo->selectors, node, scope);
        case IJSVGSelectorPseudoNot:
            return !IJSVGSelectorMatchesAny(pseudo->selectors, node, scope);
        case IJSVGSelectorPseudoHas:
            for (IJSVGStyleSheetSelector* item in pseudo->selectors) {
                if ([item matchesRelativeTo:node scope:scope]) {
                    return YES;
                }
            }
            return NO;
        case IJSVGSelectorPseudoLang: {
            const char* language = NULL;
            for (id<IJSVGStyleSheetSelectorNode> ancestor = node; ancestor != nil; ancestor = ancestor.selectorParent) {
                if ([ancestor respondsToSelector:@selector(selectorLanguage)] && (language = [ancestor selectorLanguage]) != NULL) {
                    break;
                }
            }
            for (NSString* range in pseudo->languages) {
                if (IJSVGSelectorLanguageMatches(language ?: "", range.UTF8String)) {
                    return YES;
                }
            }
            return NO;
        }
        case IJSVGSelectorPseudoNth:
            break;
    }

    NSUInteger position = 0;
    if (pseudo->selectors != nil) {
        if (!IJSVGSelectorMatchesAny(pseudo->selectors, node, scope)) {
            return NO;
        }

        // Immutable XML siblings share one filter pass for each nth selector.
        // Render nodes retain the uncached path because callers can mutate them.
        id<IJSVGStyleSheetSelectorNode> parentNode = node.selectorParent;
        if (node.selectorNodeKind == IJSVGStyleSheetSelectorNodeKindXMLRecord && parentNode.selectorNodeKind == IJSVGStyleSheetSelectorNodeKindXMLRecord) {
            IJSVGStyleSheetSelectorRecord* parent = (IJSVGStyleSheetSelectorRecord*)parentNode;
            if (parent.filteredPositions == nil) {
                parent.filteredPositions = [NSMapTable strongToStrongObjectsMapTable];
            }
            IJSVGSelectorFilteredPositions* filtered = [parent.filteredPositions objectForKey:pseudo];
            if (filtered == nil) {
                filtered = [[IJSVGSelectorFilteredPositions alloc] init];
                filtered->positions = [NSMapTable weakToStrongObjectsMapTable];
                for (id<IJSVGStyleSheetSelectorNode> sibling = parent.selectorFirstChild; sibling != nil; sibling = IJSVGSelectorNext(sibling)) {
                    if (IJSVGSelectorMatchesAny(pseudo->selectors, sibling, scope)) {
                        [filtered->positions setObject:@(++filtered->count) forKey:sibling];
                    }
                }
                [parent.filteredPositions setObject:filtered forKey:pseudo];
            }
            position = [[filtered->positions objectForKey:node] unsignedIntegerValue];
            if (position != 0 && pseudo->fromEnd) {
                position = filtered->count - position + 1;
            }
        } else {
            position = 1;
            id<IJSVGStyleSheetSelectorNode> sibling = pseudo->fromEnd ? IJSVGSelectorNext(node) : node.selectorPreviousSibling;
            while (sibling != nil) {
                if (IJSVGSelectorMatchesAny(pseudo->selectors, sibling, scope)) {
                    position++;
                }
                sibling = pseudo->fromEnd ? IJSVGSelectorNext(sibling) : sibling.selectorPreviousSibling;
            }
        }
    } else if ([node respondsToSelector:@selector(selectorIndexOfType:fromEnd:)]) {
        position = [node selectorIndexOfType:pseudo->ofType fromEnd:pseudo->fromEnd];
        if (pseudo->only && [node selectorIndexOfType:pseudo->ofType fromEnd:YES] != 1) {
            return NO;
        }
    }
    if (position == 0) {
        return NO;
    }

    // Widen before subtraction so even NSIntegerMin coefficients are safe.
    __int128 difference = (__int128)position - pseudo->b;
    return pseudo->a == 0 ? difference == 0 : difference % pseudo->a == 0 && difference / pseudo->a >= 0;
}

static BOOL IJSVGStyleSheetMatchSelector(id<IJSVGStyleSheetSelectorNode> node, IJSVGStyleSheetSelectorRaw* raw, id<IJSVGStyleSheetSelectorNode> scope)
{
    if (node == nil || raw == nil) {
        return NO;
    }
    if (raw.namespaceURI != nil && (![node respondsToSelector:@selector(namespaceURI)] || ![raw.namespaceURI isEqualToString:node.namespaceURI ?: @""])) {
        return NO;
    }
    if (raw.tag != nil && ![raw.tag isEqualToString:node.name]) {
        return NO;
    }
    if (raw.identifier != nil && ![raw.identifier isEqualToString:node.identifier]) {
        return NO;
    }
    for (NSString* identifier in raw.identifiers) {
        if (![identifier isEqualToString:node.identifier]) {
            return NO;
        }
    }
    for (NSString* className in raw.classes) {
        if (![node.classNameList containsObject:className]) {
            return NO;
        }
    }
    for (IJSVGStyleSheetAttributeSelector* attribute in raw.attributes) {
        if (![node respondsToSelector:@selector(selectorMatchesAttribute:)] || ![node selectorMatchesAttribute:attribute]) {
            return NO;
        }
    }
    if (raw.rootCount != 0 && node.selectorParent != nil) {
        return NO;
    }
    if (raw.nestingCount != 0 && !(raw.nestingSelectors != nil ? IJSVGSelectorMatchesAny(raw.nestingSelectors, node, scope) : node == scope)) {
        return NO;
    }
    for (IJSVGStyleSheetPseudoClass* pseudo in raw.pseudoClasses) {
        if (!IJSVGSelectorMatchPseudo(pseudo, node, scope)) {
            return NO;
        }
    }
    return YES;
}

@implementation IJSVGStyleSheetSelector

+ (NSArray<IJSVGStyleSheetSelector*>*)selectorsWithString:(NSString*)string forgiving:(BOOL)forgiving
{
    return IJSVGSelectorParseList(string, forgiving, 0, NO, NO, nil, nil);
}

+ (NSArray<IJSVGStyleSheetSelector*>*)selectorsWithString:(NSString*)string namespaces:(NSDictionary<NSString*, NSString*>*)namespaces
{
    return IJSVGSelectorParseList(string, NO, 0, NO, NO, namespaces, nil);
}

+ (NSArray<IJSVGStyleSheetSelector*>*)selectorsWithString:(NSString*)string namespaces:(NSDictionary<NSString*, NSString*>*)namespaces parentSelectors:(NSArray<IJSVGStyleSheetSelector*>*)parents
{
    NSArray<NSString*>* parts = IJSVGSelectorListParts(string);
    if (parts == nil || parents.count == 0) {
        return nil;
    }
    NSMutableArray* result = [NSMutableArray array];
    for (NSString* part in parts) {
        if ([part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length == 0) {
            return nil;
        }
        const char* bytes = part.UTF8String;
        NSUInteger length = strlen(bytes), brackets = 0;
        char quote = 0;
        BOOL escaped = NO, explicitNesting = NO;
        for (NSUInteger index = 0; index < length; index++) {
            char c = bytes[index];
            if (IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
                continue;
            }
            if (c == '[') {
                brackets++;
            } else if (c == ']' && brackets != 0) {
                brackets--;
            } else if (c == '&' && brackets == 0) {
                explicitNesting = YES;
            }
        }

        // Only the outer list of the rule gets an implicit parent anchor. A leading
        // combinator needs it even when another ampersand occurs later.
        NSUInteger start = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, 0, length);
        BOOL relative = IJSVGStyleSheetCharIsCombinator(bytes[start])
            || IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(bytes, start, length);
        NSString* nested = explicitNesting && !relative ? part : [@"& " stringByAppendingString:part];
        IJSVGStyleSheetSelector* item = [[self alloc] initWithString:nested depth:0 insideHas:NO relative:NO namespaces:namespaces parentSelectors:parents];
        if (item == nil) {
            return nil;
        }
        [result addObject:item];
    }
    return result;
}

- (id)initWithSelectorString:(NSString*)string
{
    return [self initWithString:string depth:0 insideHas:NO relative:NO namespaces:nil parentSelectors:nil];
}

- (instancetype)initWithString:(NSString*)string depth:(NSUInteger)depth insideHas:(BOOL)insideHas relative:(BOOL)relative namespaces:(NSDictionary*)namespaces parentSelectors:(NSArray<IJSVGStyleSheetSelector*>*)parentSelectors
{
    if ((self = [super init]) != nil) {
        if (depth > 64) {
            return nil;
        }
        selector = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        _namespaces = [namespaces copy];
        _parentSelectors = [parentSelectors copy];
        _relative = relative;
        _relativeCombinator = IJSVGStyleSheetSelectorCombinatorDescendant;
        if (relative) {
            if (selector.length == 0) {
                return nil;
            }
            char first = selector.UTF8String[0];
            if (IJSVGStyleSheetCharIsCombinator(first)) {
                _relativeCombinator = IJSVGStyleSheetCombinatorForChar(first);
            }
            selector = [@"* " stringByAppendingString:selector];
        }
        _rawSelectors = [NSMutableArray array];
        if (![self compileAtDepth:depth insideHas:insideHas]) {
            return nil;
        }
        _needsSelectorTree = _rawSelectors.count > 1;
        for (IJSVGStyleSheetSelectorRaw* raw in _rawSelectors) {
            _needsSelectorTree |= raw.attributes.count != 0 || raw.namespaceURI != nil || raw.nestingCount != 0;
            _usesScope |= raw.nestingCount != 0 && raw.nestingSelectors == nil;
            for (IJSVGStyleSheetSelector* parent in raw.nestingSelectors) {
                _usesScope |= parent.usesScope;
            }
            for (IJSVGStyleSheetPseudoClass* pseudo in raw.pseudoClasses) {
                _needsSelectorTree |= pseudo->kind <= IJSVGSelectorPseudoNth || pseudo->kind == IJSVGSelectorPseudoHas || pseudo->kind == IJSVGSelectorPseudoLang;
                _usesScope |= pseudo->kind == IJSVGSelectorPseudoScope;
                for (IJSVGStyleSheetSelector* nested in pseudo->selectors) {
                    _needsSelectorTree |= nested.requiresSelectorTree;
                    _usesScope |= nested.usesScope;
                }
            }
        }
        [self calculateSpecificity];

        // A bare & matching one compound can use that compound directly.
        // Keep the original selectors for specificity and namespace processing.
        // The matching array only bypasses redundant traversal of the parent list.
        NSMutableArray* matches = nil;
        for (NSUInteger index = 0; index < _rawSelectors.count; index++) {
            IJSVGStyleSheetSelectorRaw* raw = _rawSelectors[index];
            if (raw.nestingCount == 0 || raw.nestingSelectors.count != 1
                || raw.explicitType || raw.namespaceURI != nil || raw.tag != nil
                || raw.identifiers.count != 0 || raw.classes.count != 0
                || raw.attributes.count != 0 || raw.pseudoClasses.count != 0 || raw.rootCount != 0) {
                continue;
            }
            IJSVGStyleSheetSelector* parent = raw.nestingSelectors.firstObject;
            if (parent.relative || parent.matchSelectors.count != 1) {
                continue;
            }
            IJSVGStyleSheetSelectorRaw* replacement = parent.matchSelectors.firstObject;
            if (index + 1 != _rawSelectors.count && raw.combinator != replacement.combinator) {
                continue;
            }
            if (matches == nil) {
                matches = [_rawSelectors mutableCopy];
            }
            matches[index] = replacement;
        }
        _matchSelectors = matches ?: _rawSelectors;
    }
    return self;
}

- (BOOL)requiresSelectorTree
{
    return _needsSelectorTree;
}

- (IJSVGStyleSheetSelectorRaw*)matchingSelector
{
    return _rawSelectors.firstObject;
}

- (void)calculateSpecificity
{
    for (IJSVGStyleSheetSelectorRaw* raw in _rawSelectors) {
        NSUInteger own = (raw.tag != nil ? SPECIFICITY_TAG : 0)
            + MIN(raw.identifiers.count, SPECIFICITY_MASK) * SPECIFICITY_IDENTIFIER
            + MIN(raw.classCount + raw.attributes.count, SPECIFICITY_MASK) * SPECIFICITY_CLASS;
        _specificity = IJSVGSelectorAddSpecificity(_specificity, own);
        NSUInteger parentSpecificity = 0;
        for (IJSVGStyleSheetSelector* parent in raw.nestingSelectors) {
            parentSpecificity = MAX(parentSpecificity, parent.specificity);
        }
        for (NSUInteger index = 0; index < raw.nestingCount; index++) {
            _specificity = IJSVGSelectorAddSpecificity(_specificity, parentSpecificity);
        }
        for (IJSVGStyleSheetPseudoClass* pseudo in raw.pseudoClasses) {
            if (pseudo->kind == IJSVGSelectorPseudoWhere) {
                continue;
            }
            NSUInteger nested = 0;
            for (IJSVGStyleSheetSelector* item in pseudo->selectors) {
                nested = MAX(nested, item.specificity);
            }
            if (pseudo->kind <= IJSVGSelectorPseudoNth || pseudo->kind == IJSVGSelectorPseudoLang) {
                nested = IJSVGSelectorAddSpecificity(nested, SPECIFICITY_CLASS);
            }
            _specificity = IJSVGSelectorAddSpecificity(_specificity, nested);
        }
    }
}

- (IJSVGStyleSheetPseudoClass*)pseudoWithName:(const char*)name argument:(NSString*)argument depth:(NSUInteger)depth insideHas:(BOOL)insideHas
{
    IJSVGSelectorPseudoDescriptor descriptor = IJSVGSelectorPseudoForBytes(name, strlen(name));
    if (!descriptor.valid) {
        return nil;
    }
    IJSVGSelectorPseudoFlags flags = descriptor.flags;
    if ((argument != nil) != ((flags & IJSVGSelectorPseudoFunctional) != 0)) {
        return nil;
    }
    IJSVGStyleSheetPseudoClass* pseudo = [[IJSVGStyleSheetPseudoClass alloc] init];
    pseudo->kind = descriptor.kind;
    pseudo->ofType = (flags & IJSVGSelectorPseudoOfType) != 0;
    pseudo->fromEnd = (flags & IJSVGSelectorPseudoFromEnd) != 0;
    pseudo->only = (flags & IJSVGSelectorPseudoOnly) != 0;
    switch (pseudo->kind) {
        case IJSVGSelectorPseudoLang: {
            NSMutableArray* ranges = [[NSMutableArray alloc] init];
            for (NSString* part in IJSVGSelectorListParts(argument)) {
                const char* bytes = part.UTF8String;
                NSUInteger length = strlen(bytes);
                NSUInteger cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, 0, length);
                NSString* range = IJSVGSelectorConsumeValue(bytes, length, &cursor);
                if (range == nil || IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length) != length) {
                    return nil;
                }
                [ranges addObject:range];
            }
            if (ranges.count == 0) {
                return nil;
            }
            pseudo->languages = ranges;
            break;
        }
        case IJSVGSelectorPseudoNth:
            if (argument != nil) {
                return IJSVGSelectorParseNth(argument, pseudo, depth, insideHas, _namespaces, _parentSelectors) ? pseudo : nil;
            }
            pseudo->b = 1;
            break;
        case IJSVGSelectorPseudoIs:
        case IJSVGSelectorPseudoWhere:
        case IJSVGSelectorPseudoNot:
        case IJSVGSelectorPseudoHas: {
            BOOL has = pseudo->kind == IJSVGSelectorPseudoHas;
            if (has && insideHas) {
                return nil;
            }
            pseudo->selectors = IJSVGSelectorParseList(argument, (flags & IJSVGSelectorPseudoForgiving) != 0, depth + 1, insideHas || has, has, _namespaces, _parentSelectors);
            if (!has) {
                for (IJSVGStyleSheetSelector* nested in pseudo->selectors) {
                    if (!nested.matchingSelector.explicitType) {
                        nested.matchingSelector.namespaceURI = nil;
                    }
                }
            }
            if (pseudo->selectors == nil) {
                return nil;
            }
            break;
        }
        case IJSVGSelectorPseudoRoot:
        case IJSVGSelectorPseudoScope:
        case IJSVGSelectorPseudoEmpty:
            break;
    }
    return pseudo;
}

- (BOOL)compileAtDepth:(NSUInteger)depth insideHas:(BOOL)insideHas
{
    const char* bytes = selector.UTF8String;
    if (bytes == NULL || *bytes == '\0') {
        return NO;
    }
    NSUInteger length = strlen(bytes), cursor = 0;
    NSMutableArray* parsed = [NSMutableArray array];
    IJSVGStyleSheetSelectorCombinator combinator = IJSVGStyleSheetSelectorCombinatorDescendant;
    while (cursor < length) {
        IJSVGStyleSheetSelectorRaw* raw = IJSVGStyleSheetCreateRawSelector(combinator);
        NSMutableArray* pseudos = [NSMutableArray array];
        NSMutableArray* identifiers = [NSMutableArray array];
        BOOL hasSelector = NO;
        NSMutableArray* attributes = [[NSMutableArray alloc] init];
        raw.namespaceURI = _namespaces[@""];
        if (bytes[cursor] != '.' && bytes[cursor] != '#' && bytes[cursor] != ':' && bytes[cursor] != '[' && bytes[cursor] != '&') {
            NSString* tag = nil;
            NSString* uri = nil;
            if (!IJSVGSelectorConsumeQualifiedName(bytes, length, &cursor, _namespaces, NO, &tag, &uri)) {
                return NO;
            }
            raw.tag = tag;
            raw.namespaceURI = uri;
            raw.explicitType = YES;
            hasSelector = YES;
        }
        while (cursor < length && (bytes[cursor] == '.' || bytes[cursor] == '#' || bytes[cursor] == ':' || bytes[cursor] == '[' || bytes[cursor] == '&')) {
            if (bytes[cursor] == '&') {
                raw.nestingCount++;
                raw.nestingSelectors = _parentSelectors;
                cursor++;
                hasSelector = YES;
                continue;
            }
            if (bytes[cursor] == '[') {
                IJSVGStyleSheetAttributeSelector* attribute = IJSVGSelectorConsumeAttribute(bytes, length, &cursor, _namespaces);
                if (attribute == nil) {
                    return NO;
                }
                [attributes addObject:attribute];
                hasSelector = YES;
                continue;
            }
            char prefix = bytes[cursor++];
            NSString* name = nil;
            char pseudoName[32] = { 0 };
            if (prefix == ':') {
                if (!IJSVGStyleSheetConsumeASCIIIdentifier(bytes, length, &cursor, pseudoName, sizeof(pseudoName)) || pseudoName[0] == '\0') {
                    return NO;
                }
            } else {
                name = IJSVGStyleSheetConsumeIdentifier(bytes, length, &cursor);
                if (name == nil) {
                    return NO;
                }
            }
            hasSelector = YES;
            if (prefix == '.') {
                [raw addClassName:name];
                raw.classCount++;
            } else if (prefix == '#') {
                [identifiers addObject:name];
                raw.identifier = name;
            } else {
                NSString* argument = nil;
                if (cursor < length && bytes[cursor] == '(') {
                    NSUInteger start = ++cursor, nesting = 1;
                    char quote = 0;
                    BOOL escaped = NO;
                    while (cursor < length && nesting != 0) {
                        char c = bytes[cursor++];
                        if (IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
                            continue;
                        }
                        if (c == '(') {
                            nesting++;
                        } else if (c == ')') {
                            nesting--;
                        }
                    }
                    if (nesting != 0) {
                        return NO;
                    }
                    argument = IJSVGStyleSheetStringFromUTF8Bytes(bytes, start, cursor - 1) ?: @"";
                }
                IJSVGStyleSheetPseudoClass* pseudo = [self pseudoWithName:pseudoName argument:argument depth:depth insideHas:insideHas];
                if (pseudo == nil) {
                    return NO;
                }
                [pseudos addObject:pseudo];
            }
        }
        if (!hasSelector) {
            return NO;
        }
        if (raw.nestingCount != 0 && !raw.explicitType) {
            raw.namespaceURI = nil;
        }
        raw.attributes = attributes.count != 0 ? attributes : nil;
        raw.pseudoClasses = pseudos.count != 0 ? pseudos : nil;
        raw.identifiers = identifiers.count != 0 ? identifiers : nil;
        [parsed addObject:raw];
        NSUInteger end = cursor;
        cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
        if (cursor == length) {
            break;
        }
        if (IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(bytes, cursor, length)) {
            combinator = IJSVGStyleSheetSelectorCombinatorColumn;
            cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor + 2, length);
            if (cursor == length) {
                return NO;
            }
        } else if (IJSVGStyleSheetCharIsCombinator(bytes[cursor])) {
            combinator = IJSVGStyleSheetCombinatorForChar(bytes[cursor++]);
            cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
            if (cursor == length) {
                return NO;
            }
        } else if (cursor > end) {
            combinator = IJSVGStyleSheetSelectorCombinatorDescendant;
        } else {
            return NO;
        }
    }
    [_rawSelectors addObjectsFromArray:parsed.reverseObjectEnumerator.allObjects];
    return _rawSelectors.count != 0;
}

// Backtrack through all eligible ancestors/siblings. A nearest partial match
// must not hide a farther ancestor that satisfies the rest of the selector.
- (BOOL)matchesNode:(id<IJSVGStyleSheetSelectorNode>)node atIndex:(NSUInteger)index scope:(id<IJSVGStyleSheetSelectorNode>)scope anchor:(id<IJSVGStyleSheetSelectorNode>)anchor
{
    // The implicit anchor of a relative selector is distinct from CSS :scope.
    if (_relative && index + 1 == _rawSelectors.count) {
        return node == anchor;
    }
    IJSVGStyleSheetSelectorRaw* raw = _matchSelectors[index];
    if (!IJSVGStyleSheetMatchSelector(node, raw, scope)) {
        return NO;
    }
    if (index + 1 == _rawSelectors.count) {
        return YES;
    }
    if (raw.combinator == IJSVGStyleSheetSelectorCombinatorColumn) {
        return NO;
    }
    BOOL sibling = raw.combinator == IJSVGStyleSheetSelectorCombinatorNextSibling || raw.combinator == IJSVGStyleSheetSelectorCombinatorPrecededSibling;
    BOOL single = raw.combinator == IJSVGStyleSheetSelectorCombinatorDirectDescendant || raw.combinator == IJSVGStyleSheetSelectorCombinatorNextSibling;
    id<IJSVGStyleSheetSelectorNode> candidate = sibling ? node.selectorPreviousSibling : node.selectorParent;
    while (candidate != nil) {
        if ([self matchesNode:candidate atIndex:index + 1 scope:scope anchor:anchor]) {
            return YES;
        }
        if (single) {
            break;
        }
        candidate = sibling ? candidate.selectorPreviousSibling : candidate.selectorParent;
    }
    return NO;
}

- (BOOL)matchesNode:(id<IJSVGStyleSheetSelectorNode>)node scope:(id<IJSVGStyleSheetSelectorNode>)scope
{
    return [self matchesNode:node atIndex:0 scope:scope anchor:nil];
}

- (BOOL)matchesNode:(id<IJSVGStyleSheetSelectorNode>)node
{
    id<IJSVGStyleSheetSelectorNode> root = node;
    if (_usesScope) {
        while (root.selectorParent != nil) {
            root = root.selectorParent;
        }
    }
    return [self matchesNode:node scope:root];
}

- (BOOL)matchesRelativeTo:(id<IJSVGStyleSheetSelectorNode>)anchor scope:(id<IJSVGStyleSheetSelectorNode>)scope
{
    BOOL siblings = _relativeCombinator == IJSVGStyleSheetSelectorCombinatorNextSibling || _relativeCombinator == IJSVGStyleSheetSelectorCombinatorPrecededSibling;
    id<IJSVGStyleSheetSelectorNode> first = siblings ? IJSVGSelectorNext(anchor) : IJSVGSelectorFirstChild(anchor);

    // A single relative compound cannot reach beyond its leading combinator.
    // Keep the full traversal for chains such as "+ rect + circle".
    if (_rawSelectors.count == 2 && _relativeCombinator != IJSVGStyleSheetSelectorCombinatorDescendant) {
        for (id<IJSVGStyleSheetSelectorNode> candidate = first; candidate != nil; candidate = IJSVGSelectorNext(candidate)) {
            if ([self matchesNode:candidate atIndex:0 scope:scope anchor:anchor]) {
                return YES;
            }
            if (_relativeCombinator == IJSVGStyleSheetSelectorCombinatorNextSibling) {
                break;
            }
        }
        return NO;
    }

    // Iterate subtrees without recursion or allocating a descendant array.
    for (id<IJSVGStyleSheetSelectorNode> branch = first; branch != nil; branch = IJSVGSelectorNext(branch)) {
        id<IJSVGStyleSheetSelectorNode> candidate = branch;
        while (candidate != nil) {
            if ([self matchesNode:candidate atIndex:0 scope:scope anchor:anchor]) {
                return YES;
            }
            id<IJSVGStyleSheetSelectorNode> child = IJSVGSelectorFirstChild(candidate);
            if (child != nil) {
                candidate = child;
                continue;
            }
            while (candidate != branch && IJSVGSelectorNext(candidate) == nil) {
                candidate = candidate.selectorParent;
            }
            candidate = candidate == branch ? nil : IJSVGSelectorNext(candidate);
        }
    }
    return NO;
}

@end
