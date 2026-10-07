//
//  IJSVGStyleSheet.m
//  IJSVG
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVG/IJSVGStyleSheetUtils.h>
#import <IJSVG/IJSVGStyleSheet.h>

typedef struct {
    __unsafe_unretained IJSVGStyleSheetRule* rule;
    NSUInteger specificity;
} IJSVGStyleSheetMatch;

static int IJSVGStyleSheetCompareMatches(const void* first, const void* second)
{
    const IJSVGStyleSheetMatch* a = first;
    const IJSVGStyleSheetMatch* b = second;
    if(a->specificity != b->specificity) {
        return a->specificity < b->specificity ? -1 : 1;
    }
    NSUInteger aIndex = a->rule.sourceIndex;
    NSUInteger bIndex = b->rule.sourceIndex;
    return aIndex < bIndex ? -1 : (aIndex > bIndex ? 1 : 0);
}

static void IJSVGStyleSheetIndexRule(NSMutableDictionary<NSString*, NSMutableIndexSet*>* index,
    NSSet<NSString*>* names, NSUInteger ruleIndex)
{
    for(NSString* name in names) {
        NSMutableIndexSet* entries = index[name];
        if(entries == nil) {
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

- (NSUInteger)ruleCount
{
    return _rules.count;
}

- (id)init
{
    if((self = [super init]) != nil) {
        _selectors = [[NSMutableDictionary alloc] init];
        _rules = [[NSMutableArray alloc] init];
        _identifierRules = [[NSMutableDictionary alloc] init];
        _classRules = [[NSMutableDictionary alloc] init];
        _tagRules = [[NSMutableDictionary alloc] init];
        _universalRules = [[NSMutableIndexSet alloc] init];
    }
    return self;
}

- (NSArray*)selectorsWithSelectorString:(NSString*)string
{
    NSMutableArray* array = [[NSMutableArray alloc] init];

    NSArray* comp = [string componentsSeparatedByString:@","];
    NSCharacterSet* whiteSpaceCharSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

    for (__strong NSString* selectorName in comp) {
        selectorName = [selectorName stringByTrimmingCharactersInSet:whiteSpaceCharSet];
        if(selectorName.length == 0) {
            continue;
        }

        IJSVGStyleSheetSelector* selector = nil;
        if((selector = [_selectors objectForKey:selectorName]) == nil) {
            selector = [[IJSVGStyleSheetSelector alloc] initWithSelectorString:selectorName];
            if(selector != nil) {
                [_selectors setObject:selector
                               forKey:selectorName];
            }
        }

        if(selector != nil) {
            [array addObject:selector];
        }
    }
    return array;
}

- (void)parseStyleBlock:(NSString*)string
{
    NSString* cleanString = IJSVGStyleSheetStringByRemovingCSSComments(string);
    const char* chars = cleanString.UTF8String;
    if(chars == NULL) {
        return;
    }

    NSUInteger length = strlen(chars);
    if(length == 0) {
        return;
    }

    NSUInteger depth = 0;
    NSUInteger marker = 0;
    NSUInteger parenDepth = 0;
    char quote = 0;
    BOOL escaped = NO;
    NSCharacterSet* whitespaceCharSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString* selector = nil;

    for(NSUInteger i = 0; i < length; i++) {
        char c = chars[i];

        if(IJSVGStyleSheetConsumeQuotedCharacter(c, &quote, &escaped)) {
            continue;
        }

        if(c == '(') {
            parenDepth += 1;
            continue;
        }

        if(c == ')' && parenDepth != 0) {
            parenDepth -= 1;
            continue;
        }

        if(c == '{' && parenDepth == 0) {
            if(depth == 0) {
                selector = IJSVGStyleSheetStringFromUTF8Bytes(chars, marker, i);
                selector = [selector stringByTrimmingCharactersInSet:whitespaceCharSet];
                marker = i + 1;
            }
            depth += 1;
            continue;
        }

        if(c == '}' && parenDepth == 0) {
            if(depth == 0) {
                marker = i + 1;
                continue;
            }
            if(depth == 1) {
                NSString* rule = IJSVGStyleSheetStringFromUTF8Bytes(chars, marker, i);
                rule = [rule stringByTrimmingCharactersInSet:whitespaceCharSet];

                NSArray* selectors = [self selectorsWithSelectorString:selector];
                if(rule.length != 0 && selectors.count != 0) {
                    [self addStyleRule:rule
                         withSelectors:selectors];
                }
                marker = i + 1;
            }
            depth--;
        }
    }
}

- (void)addStyleRule:(NSString*)rule
       withSelectors:(NSArray*)selectors
{
    IJSVGStyleSheetRule* aRule = [[IJSVGStyleSheetRule alloc] init];
    aRule.style = [IJSVGStyleSheetStyle parseStyleString:rule];
    aRule.selectors = selectors;
    aRule.sourceIndex = _rules.count;
  
    for(IJSVGStyleSheetSelector* selector in selectors) {
        [aRule addMatchingSelector:selector];
        _requiresSelectorTree |= selector.requiresSelectorTree;
    }
    [_rules addObject:aRule];
    if(aRule.matchesUniversalSelector) {
        [_universalRules addIndex:aRule.sourceIndex];
    } else {
        IJSVGStyleSheetIndexRule(_identifierRules, aRule.matchingIdentifiers, aRule.sourceIndex);
        IJSVGStyleSheetIndexRule(_classRules, aRule.matchingClassNames, aRule.sourceIndex);
        IJSVGStyleSheetIndexRule(_tagRules, aRule.matchingTagNames, aRule.sourceIndex);
    }
}

- (IJSVGStyleSheetStyle*)styleForNode:(IJSVGNode*)node
{
    NSMutableIndexSet* candidates = [_universalRules mutableCopy];
    if(node.identifier != nil) {
        NSIndexSet* entries = _identifierRules[node.identifier];
        if(entries != nil) {
            [candidates addIndexes:entries];
        }
    }
    if(node.name != nil) {
        NSIndexSet* entries = _tagRules[node.name];
        if(entries != nil) {
            [candidates addIndexes:entries];
        }
    }
    for(NSString* className in node.classNameList) {
        NSIndexSet* entries = _classRules[className];
        if(entries != nil) {
            [candidates addIndexes:entries];
        }
    }
    NSUInteger capacity = candidates.count;
    if(capacity == 0) {
        return nil;
    }
    IJSVGStyleSheetMatch localMatches[32];
    IJSVGStyleSheetMatch* matches = capacity <= 32 ? localMatches :
        malloc(capacity * sizeof(*matches));
    if(matches == NULL) {
        return nil;
    }
    NSUInteger count = 0;
    for(NSUInteger index = candidates.firstIndex; index != NSNotFound;
        index = [candidates indexGreaterThanIndex:index]) {
        IJSVGStyleSheetRule* rule = _rules[index];
        IJSVGStyleSheetSelector* selector = nil;
        if([rule matchesNode:node selector:&selector]) {
            matches[count++] = (IJSVGStyleSheetMatch){rule, selector.specificity};
        }
    }
    IJSVGStyleSheetStyle* style = nil;
    if(count == 1) {
        style = matches[0].rule.style;
    } else if(count > 1) {
        qsort(matches, count, sizeof(*matches), IJSVGStyleSheetCompareMatches);
        style = [[IJSVGStyleSheetStyle alloc] init];
        for(NSUInteger index = 0; index < count; index++) {
            [style addPropertiesFromStyle:matches[index].rule.style];
        }
    }
    if(matches != localMatches) {
        free(matches);
    }
    return style;
}

@end
