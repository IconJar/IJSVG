//
//  IJSVGStyleSheet.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVG/IJSVGStyleSheet.h>

@interface IJSVGStyleSheetSelectorListItem : NSObject {
}

@property (nonatomic, strong) IJSVGStyleSheetRule* rule;
@property (nonatomic, strong) IJSVGStyleSheetSelector* selector;

@end

@implementation IJSVGStyleSheetSelectorListItem


@end

@implementation IJSVGStyleSheet

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

    // split the string by the comma, as it could be multiple
    NSArray* comp = [string componentsSeparatedByString:@","];
    NSCharacterSet* whiteSpaceCharSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

    // create a selector or reuse one already being used
    for (__strong NSString* selectorName in comp) {
        selectorName = [selectorName stringByTrimmingCharactersInSet:whiteSpaceCharSet];
        IJSVGStyleSheetSelector* selector = nil;

        // create a new selector if not found
        if((selector = [_selectors objectForKey:selectorName]) == nil) {
            selector = [[IJSVGStyleSheetSelector alloc] initWithSelectorString:selectorName];
            if(selector != nil) {
                [_selectors setObject:selector
                               forKey:selectorName];
            }
        }

        // add it to our list
        if(selector != nil) {
            [array addObject:selector];
        }
    }
    return array;
}

- (void)parseStyleBlock:(NSString*)string
{
    NSUInteger depth = 0, marker = 0;
    NSUInteger length = [string length];
    NSCharacterSet* whitespaceCharSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

    NSString* selector = nil;

    for (NSUInteger i = 0; i < length; i++) {
        unichar c = [string characterAtIndex:i];
        if(c == '/') {
            i++;
            if(i < length) {
                c = [string characterAtIndex:i];
                if(c == '*') {
                    // skip comment until closing /
                    for (; i < length; i++) {
                        if([string characterAtIndex:i] == '/') {
                            break;
                        }
                    }
                    if(i < length) {
                        marker = i + 1;
                        continue;
                    } else {
                        // end of string
                        return;
                    }
                } else {
                    i--;
                }
            }
        }

        // opening brace, could be nested or start of a new string
        if(c == '{') {
            // start a new rule
            if(depth == 0) {
                // grab selector and trim it
                selector = [string substringWithRange:NSMakeRange(marker, i - marker)];
                selector = [selector stringByTrimmingCharactersInSet:whitespaceCharSet];
                marker = i + 1;
            }
            depth += 1;
        }

        // ending brace
        else if(c == '}') {
            // if we finished rule
            if(depth == 1) {
                NSString* rule = [string substringWithRange:NSMakeRange(marker, i - marker)];
                rule = [rule stringByTrimmingCharactersInSet:whitespaceCharSet];

                // append the rule to the style sheet
                [self addStyleRule:rule
                     withSelectors:[self selectorsWithSelectorString:selector]];
                marker = i + 1;
            }
            depth = MAX(depth - 1, 0);
        }
    }
}

- (void)addStyleRule:(NSString*)rule
       withSelectors:(NSArray*)selectors
{
    // append the rule onto the list within
    // this style sheet
    IJSVGStyleSheetRule* aRule = [[IJSVGStyleSheetRule alloc] init];
    aRule.style = [IJSVGStyleSheetStyle parseStyleString:rule];
    aRule.selectors = selectors;
    [_rules addObject:aRule];
}

- (IJSVGStyleSheetStyle*)styleForNode:(IJSVGNode*)node
{
    IJSVGStyleSheetStyle* style = [[IJSVGStyleSheetStyle alloc] init];
    NSMutableArray* matchedRules = [[NSMutableArray alloc] init];
    for (IJSVGStyleSheetRule* rule in _rules) {
        IJSVGStyleSheetSelector* matchedSelector = nil;
        if([rule matchesNode:node selector:&matchedSelector]) {

            // make a wrapper for the selector with the rule
            IJSVGStyleSheetSelectorListItem* listItem = nil;
            listItem = [[IJSVGStyleSheetSelectorListItem alloc] init];
            listItem.rule = rule;
            listItem.selector = matchedSelector;

            // add it to the array of matches
            [matchedRules addObject:listItem];
        }
    }

    // now we have all the wrappers, we need to sort them
    // by specificity
    NSSortDescriptor* sort = [NSSortDescriptor sortDescriptorWithKey:@"selector.specificity"
                                                           ascending:YES];
    [matchedRules sortUsingDescriptors:@[ sort ]];

    // combine the rule
    for (IJSVGStyleSheetSelectorListItem* listItem in matchedRules) {
        style = [style mergedStyle:listItem.rule.style];
    }

    return style;
}

@end
