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
#import <IJSVGStyleSheetUtils.h>

@interface IJSVGStyleSheetWinner : NSObject {
@public
    IJSVGStyleSheetRule* rule;
    NSUInteger specificity;
    BOOL important;
}
@end

@implementation IJSVGStyleSheetWinner
@end

static void IJSVGStyleSheetUpdateWinners(NSMutableDictionary<NSString*, IJSVGStyleSheetWinner*>* winners, IJSVGStyleSheetRule* rule, NSUInteger specificity)
{
    for (NSString* property in rule.style.properties) {
        BOOL important = [rule.style isPropertyImportant:property];
        IJSVGStyleSheetWinner* winner = winners[property];
        if (winner == nil) {
            winner = [[IJSVGStyleSheetWinner alloc] init];
            winners[property] = winner;
        } else if (important != winner->important) {
            if (!important) {
                continue;
            }
        } else if (specificity < winner->specificity || (specificity == winner->specificity && rule.sourceIndex < winner->rule.sourceIndex)) {
            continue;
        }
        winner->rule = rule;
        winner->specificity = specificity;
        winner->important = important;
    }
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

@implementation IJSVGStyleSheet {
    NSMutableDictionary<NSString*, NSMutableIndexSet*>* _identifierRules;
    NSMutableDictionary<NSString*, NSMutableIndexSet*>* _classRules;
    NSMutableDictionary<NSString*, NSMutableIndexSet*>* _tagRules;
    NSMutableIndexSet* _universalRules;
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

- (NSArray<IJSVGStyleSheetSelector*>*)selectorsWithSelectorString:(NSString*)string
{
    if (string == nil) {
        return nil;
    }
    NSArray<IJSVGStyleSheetSelector*>* selectors = _selectors[string];
    if (selectors == nil) {
        // Ordinary rule lists are strict; only :is() and :where() forgive invalid entries.
        selectors = [IJSVGStyleSheetSelector selectorsWithString:string forgiving:NO] ?: @[];
        _selectors[string] = selectors;
    }
    return selectors;
}

- (void)parseStyleBlock:(NSString*)string
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

    NSUInteger depth = 0;
    NSUInteger marker = 0;
    NSUInteger parenDepth = 0;
    char quote = 0;
    BOOL escaped = NO;
    NSCharacterSet* whitespaceCharSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString* selector = nil;

    for (NSUInteger i = 0; i < length; i++) {
        if (quote == 0 && !escaped) {
            i += strcspn(chars + i, "{}()'\"\\");
            if (i == length) {
                break;
            }
        }
        char c = chars[i];

        if (IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
            continue;
        }

        if (c == '(') {
            parenDepth += 1;
            continue;
        }

        if (c == ')' && parenDepth != 0) {
            parenDepth -= 1;
            continue;
        }

        if (c == '{' && parenDepth == 0) {
            if (depth == 0) {
                selector = IJSVGStyleSheetStringFromUTF8Bytes(chars, marker, i);
                selector = [selector stringByTrimmingCharactersInSet:whitespaceCharSet];
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
                NSArray<IJSVGStyleSheetSelector*>* selectors = [self selectorsWithSelectorString:selector];
                if (i != marker && selectors.count != 0) {
                    IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleBytes:chars + marker length:i - marker];
                    [self addParsedStyle:style withSelectors:selectors];
                }
                marker = i + 1;
            }
            depth--;
        }
    }
}

- (void)addStyleRule:(NSString*)rule withSelectors:(NSArray<IJSVGStyleSheetSelector*>*)selectors
{
    [self addParsedStyle:[IJSVGStyleSheetStyle parseStyleString:rule] withSelectors:selectors];
}

- (void)addParsedStyle:(IJSVGStyleSheetStyle*)style withSelectors:(NSArray<IJSVGStyleSheetSelector*>*)selectors
{
    IJSVGStyleSheetRule* aRule = [[IJSVGStyleSheetRule alloc] init];
    aRule.style = style;
    aRule.selectors = selectors;
    aRule.sourceIndex = _rules.count;

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
    if (_rules.count == 1) {
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
    IJSVGStyleSheetRule* firstRule = nil;
    NSUInteger firstSpecificity = 0;
    NSMutableDictionary<NSString*, IJSVGStyleSheetWinner*>* winners = nil;
    for (NSUInteger index = candidates.firstIndex; index != NSNotFound; index = [candidates indexGreaterThanIndex:index]) {
        IJSVGStyleSheetRule* rule = _rules[index];
        IJSVGStyleSheetSelector* selector = nil;
        if (![rule matchesNode:node selector:&selector]) {
            continue;
        }

        // Reuse the existing style when only one rule matches.
        if (firstRule == nil) {
            firstRule = rule;
            firstSpecificity = selector.specificity;
            continue;
        }
        if (winners == nil) {
            winners = [[NSMutableDictionary alloc] init];
            IJSVGStyleSheetUpdateWinners(winners, firstRule, firstSpecificity);
        }
        IJSVGStyleSheetUpdateWinners(winners, rule, selector.specificity);
    }
    if (winners == nil) {
        return firstRule.style;
    }
    IJSVGStyleSheetStyle* style = [[IJSVGStyleSheetStyle alloc] init];
    for (NSString* property in winners) {
        IJSVGStyleSheetWinner* winner = winners[property];
        [style copyProperty:property fromStyle:winner->rule.style];
    }
    return style;
}

@end
