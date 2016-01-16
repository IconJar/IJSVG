//
//  IJSVGStyleSheetSelector.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGStyleSheetSelector.h"
#import "IJSVGNode.h"

@implementation IJSVGStyleSheetSelector

- (void)dealloc
{
    [selector release], selector = nil;
    [super dealloc];
}

- (id)initWithSelectorString:(NSString *)string
{
    if((self = [super init]) != nil)
    {
        selector = [string copy];
        _rawSelectors = [[NSMutableArray alloc] init];
        [self compile];
    }
    return self;
}

- (void)compile
{
    NSUInteger length = selector.length;
    NSMutableArray * sels = [[[NSMutableArray alloc] init] autorelease];
    NSCharacterSet * alphaNumeric = [NSCharacterSet characterSetWithCharactersInString:@"_-abcdefghijklmnopqrstuvwxyz0123456789"];
    IJSVGStyleSheetSelectorRaw * rawSelector = [[[IJSVGStyleSheetSelectorRaw alloc] init] autorelease];
    
    for(NSUInteger i = 0; i < length; i++)
    {
        unichar c = [selector characterAtIndex:i];
        // beginning of class
        if( c == '.' ) {
            i++;
            for(NSUInteger a = i; a < length; a++ ) {
                unichar ca = [selector characterAtIndex:a];
                if([alphaNumeric characterIsMember:ca] == NO || a == length-1) {
                    // if at end, add 1 to a so it gets the last character
                    if( a == length-1 )
                        a++;
                    [rawSelector addClassName:[selector substringWithRange:NSMakeRange(i, a-i)]];
                    i = a-1;
                    break;
                }
            }
        }
        
        // beginning of identifier
        else if( c == '#' ) {
            i++;
            for(NSUInteger a = i; a < length; a++ ) {
                unichar ca = [selector characterAtIndex:a];
                if([alphaNumeric characterIsMember:ca] == NO || a == length-1) {
                    // if at end, add 1 to a so it gets the last character
                    if( a == length-1 )
                        a++;
                    rawSelector.identifier = [selector substringWithRange:NSMakeRange(i, a-i)];
                    i = a-1;
                    break;
                }
            }
        }
        
        // space
        else if ( c == ' ' || i == length-1 ) {
            if(rawSelector != nil) {
                [sels addObject:rawSelector];
                rawSelector = nil;
            }
            
            // reset the raw selector
            if(!(i == length-1))
                rawSelector = [[[IJSVGStyleSheetSelectorRaw alloc] init] autorelease];
        }
        
        // tag name / any other character
        else {
            for(NSUInteger a = i; a < length; a++ ) {
                unichar ca = [selector characterAtIndex:a];
                if([alphaNumeric characterIsMember:ca] == NO || a == length-1) {
                    if( a == length-1 )
                        a++;
                    rawSelector.tag = [selector substringWithRange:NSMakeRange(i, a-i)];
                    i = a-1;
                    break;
                }
            }
        }
        
        // add raw selector
        if( i == length - 1 ) {
            [sels addObject:rawSelector];
            rawSelector = nil;
        }
        
    }
    
    // now its compiled, we need to reverse the selectors
    [_rawSelectors addObjectsFromArray:[sels reverseObjectEnumerator].allObjects];
}

- (BOOL)_matchesNode:(IJSVGNode *)node
         rawSelector:(IJSVGStyleSheetSelectorRaw *)rawSelector
{
    // no need to attempt to match
    if(node.identifier == nil && node.classNameList.count == 0)
        return NO;
        
    // check if the classes match the lcass
    if(rawSelector.classes.count != 0) {
        for(NSString * className in rawSelector.classes) {
            if([node.classNameList containsObject:className] == NO)
                return NO;
        }
    }
    
    // check the idenfitier
    if(rawSelector.identifier != nil &&
       [rawSelector.identifier isEqualToString:node.identifier] == NO)
        return NO;
    
    // check the tag
    if(rawSelector.tag != nil &&
       [rawSelector.tag isEqualToString:node.name] == NO)
        return NO;
    
    return YES;
}

- (BOOL)matchesNode:(IJSVGNode *)node
{
    
    // check item matches first part
    if([self _matchesNode:node
              rawSelector:_rawSelectors[0]] == NO)
        return NO;

    // only check the parents if the count has more then 1
    if(_rawSelectors.count > 1) {
        
        // grab the list of remaing selectors
        NSArray * selectors = [_rawSelectors subarrayWithRange:NSMakeRange( 1, _rawSelectors.count-1)];
        for(IJSVGStyleSheetSelectorRaw * rawSelector in selectors) {
            
            // set the parent node
            IJSVGNode * parent = node;
            BOOL matches = NO;
            
            // interate over parents until find a match
            while(parent != nil) {
                parent = parent.parentNode;
                
                // if we find a match, reset the node to being the parent
                // and go up the chain again
                if([self _matchesNode:parent
                          rawSelector:rawSelector])
                {
                    matches = YES;
                    node = parent;
                    break;
                }
            }
            
            // if not match for this selector then it doesnt match
            // so return no
            if(!matches)
                return NO;
        }
    }
    return YES;
}

@end
