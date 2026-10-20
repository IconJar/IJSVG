//
//  IJSVGStyleSheet.m
//  IJSVG
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGStyleSheet.h>
#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVGByteCache.h>
#import <IJSVGCSSParser.h>
#import <IJSVGStyleSheetUtils.h>

@interface IJSVGStyleSheetLayer : NSObject
@property (nonatomic) NSUInteger depth;
@property (nonatomic, strong) NSMutableArray<IJSVGStyleSheetLayer*>* children;
@property (nonatomic, strong) NSMutableDictionary<NSString*, IJSVGStyleSheetLayer*>* namedChildren;
@property (nonatomic, strong) NSMutableArray<IJSVGStyleSheetRule*>* rules;
- (NSUInteger)assignOrderStartingAt:(NSUInteger)order;
@end

@implementation IJSVGStyleSheetLayer

- (instancetype)init
{
    if ((self = [super init]) != nil) {
        _children = [[NSMutableArray alloc] init];
        _namedChildren = [[NSMutableDictionary alloc] init];
        _rules = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSUInteger)assignOrderStartingAt:(NSUInteger)order
{
    // Direct declarations form the final, implicit sublayer of each parent.
    for (IJSVGStyleSheetLayer* child in _children) {
        order = [child assignOrderStartingAt:order];
    }
    for (IJSVGStyleSheetRule* rule in _rules) {
        rule.layerOrder = order;
    }
    return order + 1;
}

@end

// Parse the entire prelude before registering any names: an invalid list must
// not reserve an order for its otherwise valid entries. An empty block name
// denotes a fresh anonymous layer. A statement must contain at least one name.
static NSArray<NSArray<NSString*>*>* IJSVGStyleSheetLayerNames(const char* bytes, NSUInteger length, BOOL statement)
{
    NSUInteger cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, 0, length);
    if (cursor == length || bytes[cursor++] != '@') {
        return nil;
    }
    char keyword[16] = { 0 };
    if (!IJSVGStyleSheetConsumeASCIIIdentifier(bytes, length, &cursor, keyword, sizeof(keyword)) || strcasecmp(keyword, "layer") != 0) {
        return nil;
    }
    cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
    if (cursor == length) {
        return statement ? nil : @[];
    }
    NSMutableArray* names = [[NSMutableArray alloc] init];
    while (cursor < length) {
        NSMutableArray* components = [[NSMutableArray alloc] init];
        while (YES) {
            NSString* name = IJSVGStyleSheetConsumeIdentifier(bytes, length, &cursor);
            NSString* folded = name.lowercaseString;
            if (name == nil || [folded isEqualToString:@"initial"] || [folded isEqualToString:@"inherit"]
                || [folded isEqualToString:@"unset"] || [folded isEqualToString:@"revert"]
                || [folded isEqualToString:@"revert-layer"] || components.count == 64) {
                return nil;
            }
            [components addObject:name];
            if (cursor == length || bytes[cursor] != '.') {
                break;
            }
            cursor++;
        }
        [names addObject:components];
        cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
        if (cursor == length) {
            return names;
        }
        if (!statement || bytes[cursor++] != ',') {
            return nil;
        }
        cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
        if (cursor == length) {
            return nil;
        }
    }
    return nil;
}

// Entries borrow strings and styles from the stylesheet. Only deferred variable
// resolution retains an owner array and a snapshot of this buffer.
typedef struct {
    __unsafe_unretained NSString* property;
    __unsafe_unretained IJSVGStyleSheetStyle* style;
    NSUInteger specificity;
    NSUInteger layerOrder;
    NSUInteger sourceIndex;
    BOOL important;
} IJSVGStyleSheetDeclaration;

typedef struct {
    IJSVGStyleSheetDeclaration* entries;
    IJSVGStyleSheetDeclaration* inlineEntries;
    NSUInteger count;
    NSUInteger capacity;
    BOOL deferred;
} IJSVGStyleSheetDeclarations;

static void IJSVGStyleSheetAppendDeclarations(IJSVGStyleSheetDeclarations* buffer, IJSVGStyleSheetRule* rule, NSUInteger specificity)
{
    IJSVGStyleSheetStyle* style = rule.style;
    NSDictionary<NSString*, NSString*>* properties = style.properties;
    NSUInteger maximum = SIZE_MAX / sizeof(*buffer->entries);
    if (properties.count > maximum - buffer->count) {
        [NSException raise:NSMallocException format:@"Too many CSS declarations"];
    }
    NSUInteger required = buffer->count + properties.count;
    if (required > buffer->capacity) {
        NSUInteger capacity = MAX(required, buffer->capacity > maximum / 2 ? maximum : buffer->capacity * 2);
        BOOL inlineStorage = buffer->entries == buffer->inlineEntries;
        IJSVGStyleSheetDeclaration* entries = inlineStorage ? malloc(capacity * sizeof(*entries)) : realloc(buffer->entries, capacity * sizeof(*entries));
        if (entries == NULL) {
            [NSException raise:NSMallocException format:@"Unable to allocate CSS declarations"];
        }
        if (inlineStorage) {
            memcpy(entries, buffer->entries, buffer->count * sizeof(*entries));
        }
        buffer->entries = entries;
        buffer->capacity = capacity;
    }
    NSUInteger layerOrder = rule.layerOrder;
    NSUInteger sourceIndex = rule.sourceIndex;
    buffer->deferred |= style.hasVariableProperties;
    for (NSString* property in properties) {
        buffer->entries[buffer->count++] = (IJSVGStyleSheetDeclaration) { property, style, specificity, layerOrder, sourceIndex, [style isPropertyImportant:property] };
    }
}

static int IJSVGStyleSheetCompareDeclarations(const void* left, const void* right)
{
    const IJSVGStyleSheetDeclaration* a = left;
    const IJSVGStyleSheetDeclaration* b = right;
    if (a->property != b->property) {
        CFComparisonResult order = CFStringCompare((__bridge CFStringRef)a->property, (__bridge CFStringRef)b->property, 0);
        if (order != kCFCompareEqualTo) {
            return order < 0 ? -1 : 1;
        }
    }
    if (a->important != b->important) {
        return a->important ? -1 : 1;
    }
    if (a->layerOrder != b->layerOrder) {
        return (a->layerOrder < b->layerOrder) == a->important ? -1 : 1;
    }
    if (a->specificity != b->specificity) {
        return a->specificity > b->specificity ? -1 : 1;
    }
    return a->sourceIndex == b->sourceIndex ? 0 : (a->sourceIndex > b->sourceIndex ? -1 : 1);
}

// The contiguous range for each property is ordered by cascade precedence. Rollback
// excludes the interval between the normal and important declarations of a layer.
static IJSVGStyleSheetStyle* IJSVGStyleSheetResolveDeclarations(const IJSVGStyleSheetDeclaration* entries, NSUInteger count, NSDictionary<NSString*, id>* variables, NSArray<IJSVGStyleSheetStyle*>* owners)
{
    IJSVGStyleSheetStyle* result = [[IJSVGStyleSheetStyle alloc] init];
    NSMapTable<IJSVGStyleSheetStyle*, IJSVGStyleSheetStyle*>* resolved = owners != nil ? [NSMapTable strongToStrongObjectsMapTable] : nil;
    NSUInteger index = 0;
    while (index < count) {
        NSString* property = entries[index].property;
        NSUInteger end = index + 1;
        while (end < count && (entries[end].property == property || [entries[end].property isEqualToString:property])) {
            end++;
        }
        BOOL limited = NO;
        NSUInteger limit = NSUIntegerMax;
        for (NSUInteger candidate = index; candidate < end; candidate++) {
            const IJSVGStyleSheetDeclaration* entry = entries + candidate;
            if (limited && entry->layerOrder >= limit) {
                continue;
            }
            IJSVGStyleSheetStyle* source = entry->style;
            if (resolved != nil) {
                IJSVGStyleSheetStyle* cached = [resolved objectForKey:source];
                if (cached == nil) {
                    cached = [source styleByResolvingVariables:variables];
                    [resolved setObject:cached forKey:source];
                }
                source = cached;
            }
            if (IJSVGCSSWideKeywordFromString([source property:property]) != IJSVGCSSWideKeywordRevertLayer) {
                [result copyProperty:property fromStyle:source];
                break;
            }
            limited = YES;
            limit = entry->layerOrder;
            if (entry->important) {
                [result suppressNormalInlineProperty:property];
            }
        }
        index = end;
    }
    return result;
}

static IJSVGStyleSheetStyle* IJSVGStyleSheetResolveBuffer(IJSVGStyleSheetDeclarations* buffer)
{
    qsort(buffer->entries, buffer->count, sizeof(*buffer->entries), IJSVGStyleSheetCompareDeclarations);
    IJSVGStyleSheetStyle* result = IJSVGStyleSheetResolveDeclarations(buffer->entries, buffer->count, nil, nil);
    if (buffer->deferred) {
        // The block may outlive both the stack buffer and its stylesheet.
        NSData* storage = [NSData dataWithBytes:buffer->entries length:buffer->count * sizeof(*buffer->entries)];
        NSMutableArray<IJSVGStyleSheetStyle*>* owners = [[NSMutableArray alloc] init];
        for (NSUInteger index = 0; index < buffer->count; index++) {
            [owners addObject:buffer->entries[index].style];
        }
        result.layerResolver = ^IJSVGStyleSheetStyle*(NSDictionary<NSString*, id>* variables) {
            return IJSVGStyleSheetResolveDeclarations(storage.bytes, storage.length / sizeof(IJSVGStyleSheetDeclaration), variables, owners);
        };
    }
    return result;
}

static void IJSVGStyleSheetIndexRule(NSMutableDictionary<NSString*, NSMutableIndexSet*>* index, NSSet<NSString*>* names, NSUInteger ruleIndex)
{
    for (NSString* name in names) {
        NSMutableIndexSet* entries = index[name];
        if (entries == nil) {
            entries = [[NSMutableIndexSet alloc] init];
            index[name] = entries;
        }
        [entries addIndex:ruleIndex];
    }
}

static void IJSVGStyleSheetParseNamespace(NSString* statement, NSMutableDictionary<NSString*, NSString*>* namespaces)
{
    const char* bytes = statement.UTF8String;
    NSUInteger length = strlen(bytes);
    NSUInteger cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, 0, length);
    if (cursor == length || bytes[cursor++] != '@') {
        return;
    }
    char keyword[16] = { 0 };
    if (!IJSVGStyleSheetConsumeASCIIIdentifier(bytes, length, &cursor, keyword, sizeof(keyword)) || strcasecmp(keyword, "namespace") != 0) {
        return;
    }
    cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
    NSString* prefix = @"";
    NSUInteger valueStart = cursor;
    NSString* identifier = IJSVGStyleSheetConsumeIdentifier(bytes, length, &cursor);
    if (identifier != nil && !(strcasecmp(identifier.UTF8String, "url") == 0 && cursor < length && bytes[cursor] == '(')) {
        prefix = identifier;
        cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
        valueStart = cursor;
    } else {
        cursor = valueStart;
    }
    BOOL url = cursor + 4 <= length && strncasecmp(bytes + cursor, "url(", 4) == 0;
    if (url) {
        cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor + 4, length);
    }
    NSString* uri = nil;
    if (cursor < length && (bytes[cursor] == '\'' || bytes[cursor] == '"')) {
        NSUInteger start = cursor;
        if (!IJSVGStyleSheetSkipQuotedString(bytes, length, &cursor)) {
            return;
        }
        uri = IJSVGStyleSheetDecodeString(bytes, start, cursor);
    } else if (url) {
        NSUInteger start = cursor;
        while (cursor < length && bytes[cursor] != ')' && !IJSVGStyleSheetCharIsWhitespace(bytes[cursor])) {
            if (bytes[cursor] == '\'' || bytes[cursor] == '"' || bytes[cursor] == '(' || (unsigned char)bytes[cursor] < 0x20) {
                return;
            }
            if (bytes[cursor] == '\\') {
                if (!IJSVGStyleSheetSkipEscape(bytes, length, &cursor, NO)) {
                    return;
                }
            } else {
                cursor++;
            }
        }

        // Decode URL escapes using the same CSS string decoder.
        NSString* value = IJSVGStyleSheetStringFromUTF8Bytes(bytes, start, cursor);
        NSString* quoted = [NSString stringWithFormat:@"\"%@\"", value];
        uri = IJSVGStyleSheetDecodeString(quoted.UTF8String, 0, [quoted lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    }
    cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
    if (url) {
        if (cursor == length || bytes[cursor++] != ')') {
            return;
        }
        cursor = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
    }
    if (uri != nil && cursor == length) {
        namespaces[prefix] = uri;
    }
}

@implementation IJSVGStyleSheet {
    NSMutableDictionary<NSString*, NSMutableIndexSet*>* _identifierRules;
    NSMutableDictionary<NSString*, NSMutableIndexSet*>* _classRules;
    NSMutableDictionary<NSString*, NSMutableIndexSet*>* _tagRules;
    NSMutableIndexSet* _universalRules;
    IJSVGStyleSheetLayer* _layerRoot;
    IJSVGStyleSheetLayer* _currentLayer;
    BOOL _layerOrderDirty;
    BOOL _hasCascadeDependentRules;
}

- (IJSVGStyleSheetLayer*)registerLayerWithName:(NSArray<NSString*>*)components
{
    if (_currentLayer.depth + MAX(components.count, 1UL) > 64) {
        return nil;
    }
    if (_layerRoot == nil) {
        _layerRoot = [[IJSVGStyleSheetLayer alloc] init];
    }
    IJSVGStyleSheetLayer* parent = _currentLayer ?: _layerRoot;
    if (components.count == 0) {
        IJSVGStyleSheetLayer* anonymous = [[IJSVGStyleSheetLayer alloc] init];
        anonymous.depth = parent.depth + 1;
        [parent.children addObject:anonymous];
        _layerOrderDirty = YES;
        return anonymous;
    }
    for (NSString* name in components) {
        IJSVGStyleSheetLayer* child = parent.namedChildren[name];
        if (child == nil) {
            child = [[IJSVGStyleSheetLayer alloc] init];
            child.depth = parent.depth + 1;
            parent.namedChildren[name] = child;
            [parent.children addObject:child];
            _layerOrderDirty = YES;
        }
        parent = child;
    }
    return parent;
}

- (void)parseLayerStatement:(const char*)bytes length:(NSUInteger)length
{
    NSArray<NSArray<NSString*>*>* names = IJSVGStyleSheetLayerNames(bytes, length, YES);
    for (NSArray* components in names) {
        if (_currentLayer.depth + components.count > 64) {
            return;
        }
    }
    for (NSArray* components in names) {
        [self registerLayerWithName:components];
    }
}

- (BOOL)mayAffectAttributes:(IJSVGBitFlags*)attributes
{
    for (IJSVGStyleSheetRule* rule in _rules) {
        if (rule.style.hasCustomProperties) {
            return YES;
        }
        NSUInteger count = 0;
        const IJSVGStyleSheetAttribute* entries = [rule.style attributesWithCount:&count];
        for (NSUInteger index = 0; index < count; index++) {
            if ([attributes bitIsSet:(int)entries[index].attribute]) {
                return YES;
            }
        }
    }
    return NO;
}

- (NSUInteger)ruleCount
{
    return _rules.count;
}

- (id)init
{
    if ((self = [super init]) != nil) {
        _selectors = [[NSMutableDictionary alloc] init];
        _rules = [[NSMutableArray alloc] init];
        _identifierRules = [[NSMutableDictionary alloc] init];
        _classRules = [[NSMutableDictionary alloc] init];
        _tagRules = [[NSMutableDictionary alloc] init];
        _universalRules = [[NSMutableIndexSet alloc] init];
    }
    return self;
}

- (NSArray<IJSVGStyleSheetSelector*>*)selectorsWithSelectorString:(NSString*)string namespaces:(NSDictionary*)namespaces
{
    if (string == nil) {
        return nil;
    }
    NSArray<IJSVGStyleSheetSelector*>* selectors = _selectors[string];
    if (selectors == nil) {
        // Ordinary rule lists are strict. Only :is() and :where() forgive invalid entries.
        selectors = [IJSVGStyleSheetSelector selectorsWithString:string namespaces:namespaces] ?: @[];
        _selectors[string] = selectors;
    }
    return selectors;
}

- (void)parseStyleBlock:(NSString*)string
{
    [self parseStyleBlock:string viewport:CGSizeZero];
}

- (void)parseStyleBlock:(NSString*)string viewport:(CGSize)viewport
{
    NSString* cleanString = IJSVGStyleSheetStringByRemovingCSSComments(string);
    const char* chars = cleanString.UTF8String;
    if (chars == NULL) {
        return;
    }

    NSUInteger length = strlen(chars);
    if (length == 0) {
        return;
    }

    // Namespace bindings are local to this style element, including cache entries.
    [_selectors removeAllObjects];
    NSMutableDictionary* namespaces = [[NSMutableDictionary alloc] init];
    IJSVGMediaEnvironment environment = { viewport, IJSVGMediaTypeScreen };

    // Conditions share one immutable environment for this parse. Keep the cache
    // local so another style block or viewport cannot reuse stale results.
    IJSVGByteCache* mediaMatches = NULL;
    [self parseStyleBytes:chars length:length namespaces:namespaces environment:environment mediaMatches:&mediaMatches nesting:0];
    IJSVGByteCacheDestroy(mediaMatches);

    // Resolve priorities before exposing the stylesheet to node matching.
    if (_layerOrderDirty) {
        [_layerRoot assignOrderStartingAt:0];
        _layerOrderDirty = NO;
    }
}

- (void)parseStyleBytes:(const char*)chars length:(NSUInteger)length namespaces:(NSMutableDictionary*)namespaces environment:(IJSVGMediaEnvironment)environment mediaMatches:(IJSVGByteCache**)mediaMatches nesting:(NSUInteger)nesting
{
    // Bound recursion for untrusted stylesheets. Namespace declarations are only
    // allowed at the top level. Nested media rules inherit the existing bindings.
    if (nesting > 64) {
        return;
    }
    BOOL allowsNamespaces = nesting == 0;
    NSUInteger depth = 0;
    NSUInteger marker = 0;
    NSUInteger parenDepth = 0;
    char quote = 0;
    BOOL escaped = NO;
    NSUInteger preludeStart = 0;
    NSUInteger preludeLength = 0;

    for (NSUInteger i = 0; i < length; i++) {
        if (quote == 0 && !escaped) {
            i += strcspn(chars + i, ";{}()[]'\"\\");
            if (i >= length) {
                break;
            }
        }
        char c = chars[i];

        if (IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
            continue;
        }

        if (c == ';' && depth == 0 && parenDepth == 0) {
            [self parseLayerStatement:chars + marker length:i - marker];
            if (allowsNamespaces) {
                IJSVGStyleSheetParseNamespace(IJSVGStyleSheetStringFromUTF8Bytes(chars, marker, i), namespaces);
            }
            marker = i + 1;
            continue;
        }

        if (c == '(' || c == '[') {
            parenDepth += 1;
            continue;
        }

        if ((c == ')' || c == ']') && parenDepth != 0) {
            parenDepth -= 1;
            continue;
        }

        if (c == '{' && parenDepth == 0) {
            if (depth == 0) {
                allowsNamespaces = NO;
                preludeStart = IJSVGStyleSheetIndexBySkippingWhitespace(chars, marker, i);
                NSUInteger preludeEnd = i;
                while (preludeEnd > preludeStart && IJSVGStyleSheetCharIsWhitespace(chars[preludeEnd - 1])) {
                    preludeEnd--;
                }
                preludeLength = preludeEnd - preludeStart;
                marker = i + 1;
            }
            depth += 1;
            continue;
        }

        if (c == '}' && parenDepth == 0) {
            if (depth == 0) {
                marker = i + 1;
                continue;
            }
            if (depth == 1) {
                [self parseRuleBody:chars + marker length:i - marker prelude:chars + preludeStart preludeLength:preludeLength namespaces:namespaces environment:environment mediaMatches:mediaMatches nesting:nesting];
                marker = i + 1;
            }
            depth--;
        }
    }
}

- (BOOL)mediaRuleMatches:(const char*)bytes length:(NSUInteger)length environment:(IJSVGMediaEnvironment)environment cache:(IJSVGByteCache**)cache
{
    CFTypeRef cached = IJSVGByteCacheGetValue(*cache, bytes, length);
    if (cached != NULL) {
        return cached == kCFBooleanTrue;
    }

    // Ordinary stylesheets never allocate bucket storage for the cache.
    if (*cache == NULL) {
        *cache = IJSVGByteCacheCreate(256, 64 * 1024);
    }
    NSUInteger cursor = 1;
    char keyword[16] = { 0 };
    BOOL matches = NO;
    if (IJSVGStyleSheetConsumeASCIIIdentifier(bytes, length, &cursor, keyword, sizeof(keyword)) && strcasecmp(keyword, "media") == 0) {
        IJSVGMediaQuery* query = IJSVGMediaQueryCreateFromCleanBytes(bytes + cursor, length - cursor);
        matches = IJSVGMediaQueryMatches(query, environment);
        IJSVGMediaQueryRelease(query);
    }

    IJSVGByteCacheSetValue(*cache, bytes, length, matches ? kCFBooleanTrue : kCFBooleanFalse);
    return matches;
}

- (void)parseRuleBody:(const char*)chars length:(NSUInteger)length prelude:(const char*)prelude preludeLength:(NSUInteger)preludeLength namespaces:(NSMutableDictionary*)namespaces environment:(IJSVGMediaEnvironment)environment mediaMatches:(IJSVGByteCache**)mediaMatches nesting:(NSUInteger)nesting
{
    if (preludeLength != 0 && prelude[0] == '@') {
        NSArray* layerNames = IJSVGStyleSheetLayerNames(prelude, preludeLength, NO);
        if (layerNames != nil) {
            IJSVGStyleSheetLayer* previous = _currentLayer;
            IJSVGStyleSheetLayer* layer = [self registerLayerWithName:layerNames.firstObject ?: @[]];
            if (layer != nil) {
                _currentLayer = layer;
                [self parseStyleBytes:chars length:length namespaces:namespaces environment:environment mediaMatches:mediaMatches nesting:nesting + 1];
                _currentLayer = previous;
            }
        } else if ([self mediaRuleMatches:prelude length:preludeLength environment:environment cache:mediaMatches]) {
            [self parseStyleBytes:chars length:length namespaces:namespaces environment:environment mediaMatches:mediaMatches nesting:nesting + 1];
        }
        return;
    }

    NSString* selector = IJSVGStyleSheetStringFromUTF8Bytes(prelude, 0, preludeLength);
    NSArray<IJSVGStyleSheetSelector*>* selectors = [self selectorsWithSelectorString:selector namespaces:namespaces];
    if (length == 0 || selectors.count == 0) {
        return;
    }
    [self parseNestedStyleBytes:chars length:length selectors:selectors namespaces:namespaces environment:environment mediaMatches:mediaMatches nesting:nesting];
}

- (void)addDeclarationBytes:(const char*)bytes length:(NSUInteger)length selectors:(NSArray<IJSVGStyleSheetSelector*>*)selectors
{
    if (IJSVGStyleSheetIndexBySkippingWhitespace(bytes, 0, length) == length) {
        return;
    }
    IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleBytes:bytes length:length];
    if (style.properties.count != 0) {
        [self addParsedStyle:style withSelectors:selectors];
    }
}

- (void)parseNestedStyleBytes:(const char*)bytes length:(NSUInteger)length selectors:(NSArray<IJSVGStyleSheetSelector*>*)selectors namespaces:(NSMutableDictionary*)namespaces environment:(IJSVGMediaEnvironment)environment mediaMatches:(IJSVGByteCache**)mediaMatches nesting:(NSUInteger)nesting
{
    if (nesting > 64 || selectors.count == 0) {
        return;
    }

    // Preserve the path for declarations without nested rules for exported SVGs with flat styles.
    if (memchr(bytes, '{', length) == NULL && memchr(bytes, '@', length) == NULL) {
        [self addDeclarationBytes:bytes length:length selectors:selectors];
        return;
    }
    NSUInteger cursor = 0, declarations = 0;
    while (cursor < length) {
        NSUInteger start = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, cursor, length);
        cursor = start;
        if (start == length) {
            break;
        }
        BOOL atRule = bytes[start] == '@';

        // Custom property values may themselves contain arbitrary brace blocks.
        NSUInteger propertyEnd = start;
        NSString* property = IJSVGStyleSheetConsumeIdentifier(bytes, length, &propertyEnd);
        propertyEnd = IJSVGStyleSheetIndexBySkippingWhitespace(bytes, propertyEnd, length);
        BOOL custom = [property hasPrefix:@"--"] && propertyEnd < length && bytes[propertyEnd] == ':';
        NSUInteger components = 0, braces = 0;
        char quote = 0;
        BOOL escaped = NO;
        while (cursor < length) {
            char c = bytes[cursor++];
            if (IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
                continue;
            }
            if (c == '(' || c == '[') {
                components++;
            } else if ((c == ')' || c == ']') && components != 0) {
                components--;
            } else if (components == 0 && c == '{') {
                if (custom) {
                    braces++;
                    continue;
                }

                // Flush each declaration run in source order, including runs
                // following nested rules and declarations inside nested media.
                [self addDeclarationBytes:bytes + declarations length:start - declarations selectors:selectors];
                NSUInteger body = cursor, depth = 1;
                while (cursor < length && depth != 0) {
                    c = bytes[cursor++];
                    if (IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
                        continue;
                    }
                    if (c == '(' || c == '[') {
                        components++;
                    } else if ((c == ')' || c == ']') && components != 0) {
                        components--;
                    } else if (components == 0 && c == '{') {
                        depth++;
                    } else if (components == 0 && c == '}') {
                        depth--;
                    }
                }
                NSUInteger end = depth == 0 ? cursor - 1 : cursor;
                if (atRule) {
                    NSArray* layerNames = IJSVGStyleSheetLayerNames(bytes + start, body - start - 1, NO);
                    if (layerNames != nil) {
                        IJSVGStyleSheetLayer* previous = _currentLayer;
                        IJSVGStyleSheetLayer* layer = [self registerLayerWithName:layerNames.firstObject ?: @[]];
                        if (layer != nil) {
                            _currentLayer = layer;
                            [self parseNestedStyleBytes:bytes + body length:end - body selectors:selectors namespaces:namespaces environment:environment mediaMatches:mediaMatches nesting:nesting + 1];
                            _currentLayer = previous;
                        }
                    } else if ([self mediaRuleMatches:bytes + start length:body - start - 1 environment:environment cache:mediaMatches]) {
                        [self parseNestedStyleBytes:bytes + body length:end - body selectors:selectors namespaces:namespaces environment:environment mediaMatches:mediaMatches nesting:nesting + 1];
                    }
                } else {
                    NSString* prelude = IJSVGStyleSheetStringFromUTF8Bytes(bytes, start, body - 1);
                    NSArray* nested = [IJSVGStyleSheetSelector selectorsWithString:prelude namespaces:namespaces parentSelectors:selectors];
                    [self parseNestedStyleBytes:bytes + body length:end - body selectors:nested namespaces:namespaces environment:environment mediaMatches:mediaMatches nesting:nesting + 1];
                }
                declarations = cursor;
                break;
            } else if (components == 0 && c == '}' && braces != 0) {
                braces--;
            } else if (components == 0 && braces == 0 && c == ';') {
                if (atRule) {
                    [self parseLayerStatement:bytes + start length:cursor - start - 1];
                    [self addDeclarationBytes:bytes + declarations length:start - declarations selectors:selectors];
                    declarations = cursor;
                }
                break;
            }
        }
    }
    [self addDeclarationBytes:bytes + declarations length:length - declarations selectors:selectors];
}

- (void)addStyleRule:(NSString*)rule withSelectors:(NSArray<IJSVGStyleSheetSelector*>*)selectors
{
    [self addParsedStyle:[IJSVGStyleSheetStyle parseStyleString:rule] withSelectors:selectors];
}

- (void)addParsedStyle:(IJSVGStyleSheetStyle*)style withSelectors:(NSArray<IJSVGStyleSheetSelector*>*)selectors
{
    IJSVGStyleSheetRule* aRule = [[IJSVGStyleSheetRule alloc] init];
    aRule.style = style;
    _hasCascadeDependentRules |= style.hasCascadeDependentValues;
    aRule.selectors = selectors;
    aRule.sourceIndex = _rules.count;
    aRule.layerOrder = NSUIntegerMax;
    if (_currentLayer != nil) {
        [_currentLayer.rules addObject:aRule];
        _layerOrderDirty = YES;
    }

    for (IJSVGStyleSheetSelector* selector in selectors) {
        [aRule addMatchingSelector:selector];
        _requiresSelectorTree |= selector.requiresSelectorTree;
    }
    [_rules addObject:aRule];
    if (aRule.matchesUniversalSelector) {
        [_universalRules addIndex:aRule.sourceIndex];
    } else {
        IJSVGStyleSheetIndexRule(_identifierRules, aRule.matchingIdentifiers, aRule.sourceIndex);
        IJSVGStyleSheetIndexRule(_classRules, aRule.matchingClassNames, aRule.sourceIndex);
        IJSVGStyleSheetIndexRule(_tagRules, aRule.matchingTagNames, aRule.sourceIndex);
    }
}

- (IJSVGStyleSheetStyle*)styleForNode:(id<IJSVGStyleSheetSelectorNode>)node
{
    if (_rules.count == 1 && !_hasCascadeDependentRules) {
        IJSVGStyleSheetRule* rule = _rules.firstObject;
        IJSVGStyleSheetSelector* selector = nil;
        return [rule matchesNode:node selector:&selector] ? rule.style : nil;
    }
    NSMutableIndexSet* candidates = [_universalRules mutableCopy];
    if (node.identifier != nil) {
        NSIndexSet* entries = _identifierRules[node.identifier];
        if (entries != nil) {
            [candidates addIndexes:entries];
        }
    }
    if (node.name != nil) {
        NSIndexSet* entries = _tagRules[node.name];
        if (entries != nil) {
            [candidates addIndexes:entries];
        }
    }
    for (NSString* className in node.classNameList) {
        NSIndexSet* entries = _classRules[className];
        if (entries != nil) {
            [candidates addIndexes:entries];
        }
    }
    IJSVGStyleSheetDeclaration inlineEntries[32];
    IJSVGStyleSheetDeclarations buffer = { inlineEntries, inlineEntries, 0, 32, NO };
    IJSVGStyleSheetRule* firstRule = nil;
    NSUInteger firstSpecificity = 0;
    @try {
        for (NSUInteger index = candidates.firstIndex; index != NSNotFound; index = [candidates indexGreaterThanIndex:index]) {
            IJSVGStyleSheetRule* rule = _rules[index];
            IJSVGStyleSheetSelector* selector = nil;
            if (![rule matchesNode:node selector:&selector]) {
                continue;
            }
            if (firstRule == nil) {
                firstRule = rule;
                firstSpecificity = selector.specificity;
                continue;
            }
            if (buffer.count == 0) {
                IJSVGStyleSheetAppendDeclarations(&buffer, firstRule, firstSpecificity);
            }
            IJSVGStyleSheetAppendDeclarations(&buffer, rule, selector.specificity);
        }
        if (buffer.count == 0) {
            if (!firstRule.style.hasCascadeDependentValues) {
                return firstRule.style;
            }
            IJSVGStyleSheetAppendDeclarations(&buffer, firstRule, firstSpecificity);
        }
        return IJSVGStyleSheetResolveBuffer(&buffer);
    } @finally {
        if (buffer.entries != buffer.inlineEntries) {
            free(buffer.entries);
        }
    }
}

@end
