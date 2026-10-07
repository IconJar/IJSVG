//
//  IJSVGStyleSheetSelector.m
//  IJSVG
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetSelector.h>
#import <IJSVG/IJSVGStyleSheetUtils.h>
#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGGroup.h>

#define SPECIFICITY_TAG 1
#define SPECIFICITY_CLASS 10
#define SPECIFICITY_IDENTIFIER 100

@implementation IJSVGStyleSheetSelectorRecord
@end

@implementation IJSVGNode (IJSVGStyleSheetSelectorNode)

- (id<IJSVGStyleSheetSelectorNode>)selectorParent
{
    return self.parentNode;
}

- (id<IJSVGStyleSheetSelectorNode>)selectorPreviousSibling
{
    IJSVGGroup* group = (IJSVGGroup*)self.parentNode;
    if(![group isKindOfClass:IJSVGGroup.class]) {
        return nil;
    }
    NSUInteger index = [group.children indexOfObjectIdenticalTo:self];
    return index == NSNotFound || index == 0 ? nil : group.children[index - 1];
}

@end

static BOOL IJSVGStyleSheetMatchSelector(id<IJSVGStyleSheetSelectorNode> node,
                                         IJSVGStyleSheetSelectorRaw* rawSelector)
{
    if(node == nil || rawSelector == nil) {
        return NO;
    }

    // Return no if the tag is set but does not match the node.
    if(rawSelector.tag != nil &&
       [rawSelector.tag isEqualToString:node.name] == NO) {
        return NO;
    }

    if(rawSelector.classes.count != 0) {
        for(NSString* className in rawSelector.classes) {
            if([node.classNameList containsObject:className] == NO) {
                return NO;
            }
        }
    }

    if(rawSelector.identifier != nil &&
       [rawSelector.identifier isEqualToString:node.identifier] == NO) {
        return NO;
    }

    return YES;
}

@implementation IJSVGStyleSheetSelector

- (BOOL)requiresSelectorTree
{
    return _rawSelectors.count > 1;
}

- (IJSVGStyleSheetSelectorRaw*)matchingSelector
{
    return _rawSelectors.firstObject;
}

- (BOOL)_matches:(id<IJSVGStyleSheetSelectorNode>)node
{
    for(NSUInteger index = 0; index + 1 < _rawSelectors.count; index++) {
        IJSVGStyleSheetSelectorRaw* selector = _rawSelectors[index];
        IJSVGStyleSheetSelectorRaw* next = _rawSelectors[index + 1];
        switch(selector.combinator) {
            case IJSVGStyleSheetSelectorCombinatorNextSibling:
                node = node.selectorPreviousSibling;
                break;
            case IJSVGStyleSheetSelectorCombinatorPrecededSibling:
                if([node isKindOfClass:IJSVGNode.class]) {
                    // Render nodes store siblings in an array. Find the starting index once,
                    // then scan backwards for a match.
                    IJSVGGroup* parent = (IJSVGGroup*)node.selectorParent;
                    NSArray<IJSVGNode*>* siblings = [parent isKindOfClass:IJSVGGroup.class] ? parent.children : nil;
                    NSUInteger siblingIndex = siblings != nil ? [siblings indexOfObjectIdenticalTo:(IJSVGNode*)node] : NSNotFound;
                    node = nil;
                    while(siblingIndex != NSNotFound && siblingIndex > 0) {
                        IJSVGNode* sibling = siblings[--siblingIndex];
                        if(IJSVGStyleSheetMatchSelector(sibling, next)) {
                            node = sibling;
                            break;
                        }
                    }
                } else {
                    node = node.selectorPreviousSibling;
                    while(node != nil && !IJSVGStyleSheetMatchSelector(node, next)) {
                        node = node.selectorPreviousSibling;
                    }
                }
                break;
            case IJSVGStyleSheetSelectorCombinatorDescendant:
                node = node.selectorParent;
                while(node != nil && !IJSVGStyleSheetMatchSelector(node, next)) {
                    node = node.selectorParent;
                }
                break;
            case IJSVGStyleSheetSelectorCombinatorDirectDescendant:
                if([node isKindOfClass:IJSVGNode.class]) {
                    IJSVGGroup* parent = (IJSVGGroup*)node.selectorParent;
                    if(![parent isKindOfClass:IJSVGGroup.class] ||
                       ![parent.children containsObject:(IJSVGNode*)node]) {
                        return NO;
                    }
                }
                node = node.selectorParent;
                break;
            default:
                return NO;
        }
        if(!IJSVGStyleSheetMatchSelector(node, next)) {
            return NO;
        }
    }
    return YES;
}

- (id)initWithSelectorString:(NSString*)string
{
    if((self = [super init]) != nil) {
        selector = string.copy;
        _rawSelectors = [[NSMutableArray alloc] init];

        if([self _compile] == NO) {
            return nil;
        }
        [self _calculate];
    }
    return self;
}

- (void)_calculate
{
    for(IJSVGStyleSheetSelectorRaw* rawSelector in _rawSelectors) {
        if(rawSelector.tag != nil) {
            _specificity += SPECIFICITY_TAG;
        }

        if(rawSelector.identifier != nil) {
            _specificity += SPECIFICITY_IDENTIFIER;
        }

        _specificity += (rawSelector.classes.count * SPECIFICITY_CLASS);
    }
}

- (BOOL)validateSelector:(NSString*)string
{
    const char* chars = string.UTF8String;
    if(chars == NULL) {
        return NO;
    }

    for(NSUInteger i = 0, length = strlen(chars); i < length; i++) {
        if(IJSVGStyleSheetCharIsInvalidSelectorChar(chars[i]) == YES) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)_compile
{
    if(selector.length == 0 || [self validateSelector:selector] == NO) {
        return NO;
    }

    const char* chars = selector.UTF8String;
    if(chars == NULL) {
        return NO;
    }

    NSUInteger length = strlen(chars);
    NSMutableArray* parsedSelectors = [[NSMutableArray alloc] init];
    IJSVGStyleSheetSelectorCombinator pendingCombinator = IJSVGStyleSheetSelectorCombinatorDescendant;
    IJSVGStyleSheetSelectorRaw* rawSelector = IJSVGStyleSheetCreateRawSelector(pendingCombinator);
    BOOL hasUniversalSelector = NO;
    BOOL expectingSelectorAfterCombinator = NO;
    BOOL failed = NO;

    for(NSUInteger i = 0; i < length && failed == NO; i++) {
        char c = chars[i];

        if(IJSVGStyleSheetCharIsWhitespace(c) == YES) {
            NSUInteger next = IJSVGStyleSheetIndexBySkippingWhitespace(chars, i + 1, length);
            if(next < length &&
               (IJSVGStyleSheetCharIsCombinator(chars[next]) == YES ||
                IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(chars, next, length) == YES)) {
                i = next - 1;
                continue;
            }

            if(IJSVGStyleSheetSelectorCommitRawSelector(parsedSelectors, rawSelector, hasUniversalSelector) == YES) {
                pendingCombinator = IJSVGStyleSheetSelectorCombinatorDescendant;
                rawSelector = IJSVGStyleSheetCreateRawSelector(pendingCombinator);
                hasUniversalSelector = NO;
            }
            i = next - 1;
            continue;
        }

        if(IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(chars, i, length) == YES ||
           IJSVGStyleSheetCharIsCombinator(c) == YES) {
            if(IJSVGStyleSheetSelectorCommitRawSelector(parsedSelectors, rawSelector, hasUniversalSelector) == NO) {
                failed = YES;
                break;
            }

            pendingCombinator = IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(chars, i, length) == YES ?
                IJSVGStyleSheetSelectorCombinatorColumn : IJSVGStyleSheetCombinatorForChar(c);
            rawSelector = IJSVGStyleSheetCreateRawSelector(pendingCombinator);
            hasUniversalSelector = NO;
            expectingSelectorAfterCombinator = YES;

            NSUInteger next = i + (pendingCombinator == IJSVGStyleSheetSelectorCombinatorColumn ? 2 : 1);
            next = IJSVGStyleSheetIndexBySkippingWhitespace(chars, next, length);
            i = next - 1;
            continue;
        }

        if(c == '|') {
            failed = YES;
            break;
        }

        if(c == '*') {
            hasUniversalSelector = YES;
            expectingSelectorAfterCombinator = NO;
            continue;
        }

        if(c == '.' || c == '#') {
            NSUInteger start = i + 1;
            NSUInteger end = start;
            while(end < length && IJSVGStyleSheetCharEndsIdentifier(chars[end]) == NO) {
                end++;
            }

            NSString* value = IJSVGStyleSheetStringFromUTF8Bytes(chars, start, end);
            if(value.length == 0) {
                failed = YES;
                break;
            }

            if(c == '.') {
                [rawSelector addClassName:value];
            } else {
                rawSelector.identifier = value;
            }
            expectingSelectorAfterCombinator = NO;
            i = end - 1;
            continue;
        }

        NSUInteger start = i;
        NSUInteger end = start;
        while(end < length && IJSVGStyleSheetCharEndsIdentifier(chars[end]) == NO) {
            end++;
        }

        NSString* tag = IJSVGStyleSheetStringFromUTF8Bytes(chars, start, end);
        if(tag.length == 0) {
            failed = YES;
            break;
        }

        if(end < length && chars[end] == '|' &&
           IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(chars, end, length) == NO) {
            failed = YES;
            break;
        }

        rawSelector.tag = tag;
        expectingSelectorAfterCombinator = NO;
        i = end - 1;
    }

    if(expectingSelectorAfterCombinator == YES) {
        failed = YES;
    }

    if(failed == NO) {
        IJSVGStyleSheetSelectorCommitRawSelector(parsedSelectors, rawSelector, hasUniversalSelector);
    }

    if(failed == YES || parsedSelectors.count == 0) {
        return NO;
    }

    [_rawSelectors addObjectsFromArray:parsedSelectors.reverseObjectEnumerator.allObjects];
    return YES;
}

- (BOOL)matchesNode:(id<IJSVGStyleSheetSelectorNode>)node
{
    return IJSVGStyleSheetMatchSelector(node, _rawSelectors.firstObject) &&
        (_rawSelectors.count == 1 || [self _matches:node]);
}

@end
