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
#import <IJSVGStyleSheetUtils.h>

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

@implementation IJSVGStyleSheetSelectorRecord

- (BOOL)selectorIsEmpty
{
    return !_selectorHasContent;
}

- (NSUInteger)selectorIndexOfType:(BOOL)ofType fromEnd:(BOOL)fromEnd
{
    // XML records are immutable after construction; each sibling position is
    // computed once instead of walking a wide sibling list for every rule.
    NSUInteger index = ofType ? _typeIndex : _childIndex;
    NSUInteger count = ofType ? _typeCount : _childCount;
    return fromEnd ? MAX(count, 1) - MAX(index, 1) + 1 : MAX(index, 1);
}

@end

@implementation IJSVGNode (IJSVGStyleSheetSelectorNode)

- (id<IJSVGStyleSheetSelectorNode>)selectorParent
{
    return self.parentNode;
}

- (id<IJSVGStyleSheetSelectorNode>)selectorPreviousSibling
{
    IJSVGGroup* group = (IJSVGGroup*)self.parentNode;
    if (![group isKindOfClass:IJSVGGroup.class]) {
        return nil;
    }
    NSUInteger index = [group.children indexOfObjectIdenticalTo:self];
    return index == NSNotFound || index == 0 ? nil : group.children[index - 1];
}

- (id<IJSVGStyleSheetSelectorNode>)selectorNextSibling
{
    IJSVGGroup* group = (IJSVGGroup*)self.parentNode;
    if (![group isKindOfClass:IJSVGGroup.class]) {
        return nil;
    }
    NSUInteger index = [group.children indexOfObjectIdenticalTo:self];
    return index == NSNotFound || index + 1 >= group.children.count ? nil : group.children[index + 1];
}

- (id<IJSVGStyleSheetSelectorNode>)selectorFirstChild
{
    return [self isKindOfClass:IJSVGGroup.class] ? ((IJSVGGroup*)self).children.firstObject : nil;
}

- (BOOL)selectorIsEmpty
{
    // Parsed SVGs always use XML records, which also preserve text and CDATA.
    return self.selectorFirstChild == nil;
}

- (NSUInteger)selectorIndexOfType:(BOOL)ofType fromEnd:(BOOL)fromEnd
{
    IJSVGGroup* group = (IJSVGGroup*)self.parentNode;
    if (![group isKindOfClass:IJSVGGroup.class]) {
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
}
@end

@implementation IJSVGStyleSheetPseudoClass
@end

@interface IJSVGStyleSheetSelector ()
@property (nonatomic) IJSVGStyleSheetSelectorCombinator relativeCombinator;
@property (nonatomic) BOOL needsSelectorTree;
@property (nonatomic) BOOL usesScope;
@property (nonatomic) BOOL relative;
- (instancetype)initWithString:(NSString*)string depth:(NSUInteger)depth insideHas:(BOOL)insideHas relative:(BOOL)relative;
- (BOOL)compileAtDepth:(NSUInteger)depth insideHas:(BOOL)insideHas;
- (BOOL)matchesNode:(id<IJSVGStyleSheetSelectorNode>)node scope:(id<IJSVGStyleSheetSelectorNode>)scope;
- (BOOL)matchesRelativeTo:(id<IJSVGStyleSheetSelectorNode>)anchor scope:(id<IJSVGStyleSheetSelectorNode>)scope;
@end

// Split only at top-level commas; a comma in :is(), an escape, or a quoted
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

static NSArray<IJSVGStyleSheetSelector*>* IJSVGSelectorParseList(NSString* string, BOOL forgiving, NSUInteger depth, BOOL insideHas, BOOL relative)
{
    NSArray* parts = IJSVGSelectorListParts(string);
    if (parts == nil || depth > 64) {
        return nil;
    }
    NSMutableArray* result = [NSMutableArray array];
    for (NSString* part in parts) {
        IJSVGStyleSheetSelector* item = [[IJSVGStyleSheetSelector alloc] initWithString:part depth:depth insideHas:insideHas relative:relative];
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

static BOOL IJSVGSelectorParseNth(NSString* argument, IJSVGStyleSheetPseudoClass* pseudo, NSUInteger depth, BOOL insideHas)
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
    pseudo->selectors = IJSVGSelectorParseList(filter, NO, depth + 1, insideHas, NO);
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
        case IJSVGSelectorPseudoNth:
            break;
    }

    NSUInteger position = 0;
    if (pseudo->selectors != nil) {
        if (!IJSVGSelectorMatchesAny(pseudo->selectors, node, scope)) {
            return NO;
        }
        position = 1;
        id<IJSVGStyleSheetSelectorNode> sibling = pseudo->fromEnd ? IJSVGSelectorNext(node) : node.selectorPreviousSibling;
        while (sibling != nil) {
            if (IJSVGSelectorMatchesAny(pseudo->selectors, sibling, scope)) {
                position++;
            }
            sibling = pseudo->fromEnd ? IJSVGSelectorNext(sibling) : sibling.selectorPreviousSibling;
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
    if (raw.rootCount != 0 && node.selectorParent != nil) {
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
    return IJSVGSelectorParseList(string, forgiving, 0, NO, NO);
}

- (id)initWithSelectorString:(NSString*)string
{
    return [self initWithString:string depth:0 insideHas:NO relative:NO];
}

- (instancetype)initWithString:(NSString*)string depth:(NSUInteger)depth insideHas:(BOOL)insideHas relative:(BOOL)relative
{
    if ((self = [super init]) != nil) {
        if (depth > 64) {
            return nil;
        }
        selector = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
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
            for (IJSVGStyleSheetPseudoClass* pseudo in raw.pseudoClasses) {
                _needsSelectorTree |= pseudo->kind <= IJSVGSelectorPseudoNth || pseudo->kind == IJSVGSelectorPseudoHas;
                _usesScope |= pseudo->kind == IJSVGSelectorPseudoScope;
                for (IJSVGStyleSheetSelector* nested in pseudo->selectors) {
                    _needsSelectorTree |= nested.requiresSelectorTree;
                    _usesScope |= nested.usesScope;
                }
            }
        }
        [self calculateSpecificity];
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
            + MIN(raw.classCount, SPECIFICITY_MASK) * SPECIFICITY_CLASS;
        _specificity = IJSVGSelectorAddSpecificity(_specificity, own);
        for (IJSVGStyleSheetPseudoClass* pseudo in raw.pseudoClasses) {
            if (pseudo->kind == IJSVGSelectorPseudoWhere) {
                continue;
            }
            NSUInteger nested = 0;
            for (IJSVGStyleSheetSelector* item in pseudo->selectors) {
                nested = MAX(nested, item.specificity);
            }
            if (pseudo->kind <= IJSVGSelectorPseudoNth) {
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
        case IJSVGSelectorPseudoNth:
            if (argument != nil) {
                return IJSVGSelectorParseNth(argument, pseudo, depth, insideHas) ? pseudo : nil;
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
            pseudo->selectors = IJSVGSelectorParseList(argument, (flags & IJSVGSelectorPseudoForgiving) != 0, depth + 1, insideHas || has, has);
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
        if (bytes[cursor] == '*') {
            hasSelector = YES;
            cursor++;
        } else if (bytes[cursor] != '.' && bytes[cursor] != '#' && bytes[cursor] != ':') {
            raw.tag = IJSVGStyleSheetConsumeIdentifier(bytes, length, &cursor);
            hasSelector = raw.tag != nil;
        }
        while (cursor < length && (bytes[cursor] == '.' || bytes[cursor] == '#' || bytes[cursor] == ':')) {
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
    IJSVGStyleSheetSelectorRaw* raw = _rawSelectors[index];
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
