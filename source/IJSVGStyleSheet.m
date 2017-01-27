//
//  IJSVGStyleSheet.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGStyleSheet.h"
#import "IJSVGStyle.h"
#import "IJSVGNode.h"

@interface IJSVGStyleSheetSelectorListItem : NSObject {
    
    IJSVGStyleSheetSelector * selector;
    IJSVGStyleSheetRule * rule;
    
}

@property (nonatomic, retain) IJSVGStyleSheetRule * rule;
@property (nonatomic, retain) IJSVGStyleSheetSelector * selector;

@end

@implementation IJSVGStyleSheetSelectorListItem

@synthesize rule, selector;

- (void)dealloc
{
    [rule release], rule = nil;
    [selector release], selector = nil;
    [super dealloc];
}

@end

@implementation IJSVGStyleSheet

- (void)dealloc
{
    [_selectors release], _selectors = nil;
    [_rules release], _rules = nil;
    [super dealloc];
}

- (id)init
{
    if((self = [super init]) != nil)
    {
        _selectors = [[NSMutableDictionary alloc] init];
        _rules = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray *)selectorsWithSelectorString:(NSString *)string
{
    NSMutableArray * array = [[[NSMutableArray alloc] init] autorelease];
    
    // split the string by the comma, as it could be multiple
    NSArray * comp = [string componentsSeparatedByString:@","];
    NSCharacterSet * whiteSpaceCharSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    // create a selector or reuse one already being used
    for( NSString * selectorName in comp )
    {
        selectorName = [selectorName stringByTrimmingCharactersInSet:whiteSpaceCharSet];
        IJSVGStyleSheetSelector * selector = nil;
        
        // create a new selector if not found
        if((selector = [_selectors objectForKey:selectorName]) == nil) {
            selector = [[[IJSVGStyleSheetSelector alloc] initWithSelectorString:selectorName] autorelease];
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

- (void)parseStyleBlock:(NSString *)string
{
    NSUInteger depth = 0, marker = 0;
    NSUInteger length = [string length];
    NSCharacterSet * whitespaceCharSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    NSString * selector = nil;
    
    for( NSUInteger i = 0; i < length; i++ )
    {
        unichar c = [string characterAtIndex:i];
        if( c == '/' ) {
            i++;
            if( i<length ) {
                c = [string characterAtIndex:i];
                if( c == '*' ) {
                    // skip comment until closing /
                    for( ; i < length; i++ ) {
                        if([string characterAtIndex:i] == '/') {
                            break;
                        }
                    }
                    if( i < length ) {
                        marker = i+1;
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
        if( c == '{' ) {
            // start a new rule
            if(depth == 0) {
                // grab selector and trim it
                selector = [string substringWithRange:NSMakeRange(marker, i-marker)];
                selector = [selector stringByTrimmingCharactersInSet:whitespaceCharSet];
                marker = i+1;
            }
            depth += 1;
        }
        
        // ending brace
        else if( c == '}' ) {
            // if we finished rule
            if(depth == 1) {
                NSString * rule = [string substringWithRange:NSMakeRange(marker, i-marker)];
                rule = [rule stringByTrimmingCharactersInSet:whitespaceCharSet];
                
                // append the rule to the style sheet
                [self addStyleRule:rule
                     withSelectors:[self selectorsWithSelectorString:selector]];
                marker = i+1;
            }
            depth = MAX(depth-1, 0);
        }
        
    }
}

- (void)addStyleRule:(NSString *)rule
       withSelectors:(NSArray *)selectors
{
    // append the rule onto the list within
    // this style sheet
    IJSVGStyleSheetRule * aRule = [[[IJSVGStyleSheetRule alloc] init] autorelease];
    aRule.style = [IJSVGStyle parseStyleString:rule];
    aRule.selectors = selectors;
    [_rules addObject:aRule];
}

- (IJSVGStyle *)styleForNode:(IJSVGNode *)node
{
    IJSVGStyle * style = [[[IJSVGStyle alloc] init] autorelease];
    NSMutableArray * matchedRules = [[[NSMutableArray alloc] init] autorelease];
    for(IJSVGStyleSheetRule * rule in _rules)
    {
        IJSVGStyleSheetSelector * matchedSelector = nil;
        if([rule matchesNode:node selector:&matchedSelector]) {
            
            // make a wrapper for the selector with the rule
            IJSVGStyleSheetSelectorListItem * listItem = nil;
            listItem = [[[IJSVGStyleSheetSelectorListItem alloc] init] autorelease];
            listItem.rule = rule;
            listItem.selector = matchedSelector;
            
            // add it to the array of matches
            [matchedRules addObject:listItem];
        }
    }
    
    // now we have all the wrappers, we need to sort them
    // by specificity
    NSSortDescriptor * sort = [NSSortDescriptor sortDescriptorWithKey:@"selector.specificity"
                                                            ascending:YES];
    [matchedRules sortUsingDescriptors:@[sort]];
    
    // combine the rule
    for(IJSVGStyleSheetSelectorListItem * listItem in matchedRules) {
        style = [style mergedStyle:listItem.rule.style];
    }
    
    return style;
}

@end
