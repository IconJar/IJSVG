//
//  IJSVGStyleSheet.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVG/IJSVGStyleSheetUtils.h>
#import <IJSVG/IJSVGStyleSheet.h>

@interface IJSVGStyleSheetSelectorListItem : NSObject {
}

@property (nonatomic, strong) IJSVGStyleSheetRule* rule;
@property (nonatomic, strong) IJSVGStyleSheetSelector* selector;
@property (nonatomic, assign) NSUInteger sourceIndex;

@end

@implementation IJSVGStyleSheetSelectorListItem
@end

@implementation IJSVGStyleSheet

- (NSUInteger)ruleCount
{
    return _rules.count;
}

- (id)init
{
    if((self = [super init]) != nil) {
        _selectors = [[NSMutableDictionary alloc] init];
        _rules = [[NSMutableArray alloc] init];
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
    NSCharacterSet* whitespaceCharSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString* selector = nil;

    for(NSUInteger i = 0; i < length; i++) {
        char c = chars[i];

        if(quote != 0) {
            if(c == quote && (i == 0 || chars[i - 1] != '\\')) {
                quote = 0;
            }
            continue;
        }

        if(c == '\'' || c == '"') {
            quote = c;
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
            depth = MAX(depth - 1, 0);
        }
    }
}

- (void)addStyleRule:(NSString*)rule
       withSelectors:(NSArray*)selectors
{
    IJSVGStyleSheetRule* aRule = [[IJSVGStyleSheetRule alloc] init];
    aRule.style = [IJSVGStyleSheetStyle parseStyleString:rule];
    aRule.selectors = selectors;
    [_rules addObject:aRule];
}

- (IJSVGStyleSheetStyle*)styleForNode:(IJSVGNode*)node
{
    NSMutableArray* matchedRules = [[NSMutableArray alloc] init];
    NSUInteger sourceIndex = 0;
    for (IJSVGStyleSheetRule* rule in _rules) {
        IJSVGStyleSheetSelector* matchedSelector = nil;
        if([rule matchesNode:node selector:&matchedSelector]) {
            IJSVGStyleSheetSelectorListItem* listItem = [[IJSVGStyleSheetSelectorListItem alloc] init];
            listItem.rule = rule;
            listItem.selector = matchedSelector;
            listItem.sourceIndex = sourceIndex;
            [matchedRules addObject:listItem];
        }
        sourceIndex += 1;
    }

    if(matchedRules.count == 0) {
        return nil;
    }
  
    if(matchedRules.count == 1) {
        IJSVGStyleSheetSelectorListItem* listItem = matchedRules.firstObject;
        return listItem.rule.style;
    }

    NSSortDescriptor* specificitySort = [NSSortDescriptor sortDescriptorWithKey:@"selector.specificity"
                                                                    ascending:YES];
    NSSortDescriptor* sourceSort = [NSSortDescriptor sortDescriptorWithKey:@"sourceIndex"
                                                               ascending:YES];
    [matchedRules sortUsingDescriptors:@[ specificitySort, sourceSort ]];

    IJSVGStyleSheetStyle* style = [[IJSVGStyleSheetStyle alloc] init];
    for (IJSVGStyleSheetSelectorListItem* listItem in matchedRules) {
        [style addPropertiesFromStyle:listItem.rule.style];
    }

    return style;
}

@end
