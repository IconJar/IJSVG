//
//  IJSVGStyleSheetSelector.m
//  IJSVGExample
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

static BOOL IJSVGStyleSheetIsSiblingCombinator(IJSVGStyleSheetSelectorCombinator combinator)
{
    return combinator == IJSVGStyleSheetSelectorCombinatorNextSibling ||
        combinator == IJSVGStyleSheetSelectorCombinatorPrecededSibling;
}

static IJSVGNode* IJSVGStyleSheetPreviousNode(IJSVGNode* node)
{
    IJSVGGroup* group = (IJSVGGroup*)node.parentNode;
    if([group isKindOfClass:[IJSVGGroup class]] == NO) {
        return nil;
    }

    NSInteger currentIndex = [group.children indexOfObject:node];
    if(currentIndex == NSNotFound || currentIndex == 0) {
        return nil;
    }
    return group.children[currentIndex - 1];
}

static IJSVGStyleSheetSelectorRaw* IJSVGStyleSheetNextSelector(IJSVGStyleSheetSelectorRaw* aSelector,
                                                               NSArray<IJSVGStyleSheetSelectorRaw*>* rawSelectors)
{
    NSInteger index = [rawSelectors indexOfObject:aSelector];
    if(index == NSNotFound || index == rawSelectors.count - 1) {
        return nil;
    }
    return rawSelectors[index + 1];
}

static BOOL IJSVGStyleSheetMatchSelector(IJSVGNode* node, IJSVGStyleSheetSelectorRaw* rawSelector)
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

- (BOOL)_matches:(IJSVGNode*)aNode
        selector:(IJSVGStyleSheetSelectorRaw*)rawSelector
{
    IJSVGStyleSheetSelectorRaw* aSelector = rawSelector;

    while(aSelector != nil) {
        IJSVGStyleSheetSelectorRaw* nextSelector = IJSVGStyleSheetNextSelector(aSelector, _rawSelectors);
        if(nextSelector == nil) {
            return YES;
        }

        if(IJSVGStyleSheetIsSiblingCombinator(aSelector.combinator)) {
            if(aSelector.combinator == IJSVGStyleSheetSelectorCombinatorNextSibling) {
                IJSVGNode* previousNode = IJSVGStyleSheetPreviousNode(aNode);
                if(IJSVGStyleSheetMatchSelector(previousNode, nextSelector) == NO) {
                    return NO;
                }

                aSelector = nextSelector;
                aNode = previousNode;
                continue;
            }

            if(aSelector.combinator == IJSVGStyleSheetSelectorCombinatorPrecededSibling) {
                IJSVGGroup* parentNode = (IJSVGGroup*)aNode.parentNode;
                if([parentNode isKindOfClass:[IJSVGGroup class]] == NO) {
                    return NO;
                }

                NSOrderedSet* nodes = parentNode.children;
                NSInteger index = [nodes indexOfObject:aNode];
                if(index == NSNotFound || index == 0) {
                    return NO;
                }

                BOOL found = NO;
                for(NSInteger i = index - 1; i >= 0; i--) {
                    IJSVGNode* childNode = nodes[i];
                    if(IJSVGStyleSheetMatchSelector(childNode, nextSelector) == YES) {
                        found = YES;
                        aSelector = nextSelector;
                        aNode = childNode;
                        break;
                    }
                }

                if(found == NO) {
                    return NO;
                }
                continue;
            }
        }

        if(aSelector.combinator == IJSVGStyleSheetSelectorCombinatorDescendant) {
            IJSVGNode* parentNode = aNode.parentNode;
            while(parentNode != nil) {
                if(IJSVGStyleSheetMatchSelector(parentNode, nextSelector) == YES) {
                    aSelector = nextSelector;
                    aNode = parentNode;
                    break;
                }
                parentNode = parentNode.parentNode;
            }

            if(parentNode == nil) {
                return NO;
            }
            continue;
        }

        if(aSelector.combinator == IJSVGStyleSheetSelectorCombinatorDirectDescendant) {
            IJSVGGroup* parentNode = (IJSVGGroup*)aNode.parentNode;
            if([parentNode isKindOfClass:[IJSVGGroup class]] == NO) {
                return NO;
            }

            if(IJSVGStyleSheetMatchSelector(parentNode, nextSelector) == NO ||
               [parentNode.children containsObject:aNode] == NO) {
                return NO;
            }

            aSelector = nextSelector;
            aNode = parentNode;
            continue;
        }

        return NO;
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

- (BOOL)matchesNode:(IJSVGNode*)node
{
    IJSVGStyleSheetSelectorRaw* sel = _rawSelectors.firstObject;
    if(IJSVGStyleSheetMatchSelector(node, sel) == YES &&
       (IJSVGStyleSheetNextSelector(sel, _rawSelectors) == nil ||
        [self _matches:node selector:sel] == YES)) {
        return YES;
    }
    return NO;
}

@end
