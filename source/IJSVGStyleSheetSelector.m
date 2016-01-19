//
//  IJSVGStyleSheetSelector.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGStyleSheetSelector.h"
#import "IJSVGNode.h"
#import "IJSVGGroup.h"

@implementation IJSVGStyleSheetSelector

- (void)dealloc
{
    [selector release], selector = nil;
    [super dealloc];
}

- (BOOL)combinatorIsGreedy:(IJSVGStyleSheetSelectorCombinator)combinator
{
    return combinator == IJSVGStyleSheetSelectorCombinatorDescendant ||
    combinator == IJSVGStyleSheetSelectorCombinatorPrecededSibling;
}

- (BOOL)isAncestorOperator:(IJSVGStyleSheetSelectorCombinator)combinator
{
    return combinator == IJSVGStyleSheetSelectorCombinatorDescendant ||
    combinator == IJSVGStyleSheetSelectorCombinatorDirectDescendant;
}

- (IJSVGStyleSheetSelectorCombinator)combinatorForUnichar:(unichar)aChar
{
    if(aChar == '+')
        return IJSVGStyleSheetSelectorCombinatorNextSibling;
    if(aChar == '~')
        return IJSVGStyleSheetSelectorCombinatorPrecededSibling;
    if(aChar == '>')
        return IJSVGStyleSheetSelectorCombinatorDirectDescendant;
    return IJSVGStyleSheetSelectorCombinatorDescendant;
}

- (id)initWithSelectorString:(NSString *)string
{
    if((self = [super init]) != nil)
    {
        selector = [string copy];
        _rawSelectors = [[NSMutableArray alloc] init];
        [self _compile];
    }
    return self;
}

- (void)_compile
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
        
        // white space or end of string
        else if ( c == ' ' || i == length-1 ) {
            
            // add the current parsed selector into the list
            if(rawSelector != nil) {
                [sels addObject:rawSelector];
                rawSelector = nil;
            }
            
            // need to skip until we find something that isnt white space....
            for( NSUInteger s = i; s < length; s++ ) {
                unichar sc = [selector characterAtIndex:s];
                if( sc != ' ' ) {
                    i = --s;
                    break;
                }
            }
            
            // reset the raw selector
            if(!(i == length-1))
                rawSelector = [[[IJSVGStyleSheetSelectorRaw alloc] init] autorelease];
        }
        
        // combinator
        else if ( c == '+' || c == '~' || c == '>' ) {
            
            // set the combinator onto the selector
            rawSelector.combinator = [self combinatorForUnichar:c];
            rawSelector.combinatorString = [NSString stringWithFormat:@"%c",c];
            
            // skip until non white space
            // need to skip until we find something that isnt white space....
            for( NSUInteger s = i+1; s < length; s++ ) {
                unichar sc = [selector characterAtIndex:s];
                if( sc != ' ' ) {
                    i = --s;
                    break;
                }
            }
            
        }
        
        // tag name / any other character
        else {
            for( NSUInteger a = i; a < length; a++ ) {
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

- (IJSVGNode *)_previousNode:(IJSVGNode *)node
{
    IJSVGGroup * group = (IJSVGGroup *)node.parentNode;
    if([group isKindOfClass:[IJSVGGroup class]] == NO)
        return nil;
    NSInteger currentIndex = [group.children indexOfObject:node];
    if(currentIndex == 0)
        return nil;
    return group.children[currentIndex-1];
}

- (IJSVGNode *)_nextNode:(IJSVGNode *)node
{
    IJSVGGroup * group = (IJSVGGroup *)node.parentNode;
    if([group isKindOfClass:[IJSVGGroup class]] == NO)
        return nil;
    NSInteger currentIndex = [group.children indexOfObject:node];
    if(currentIndex == group.children.count-1)
        return nil;
    return group.children[currentIndex+1];
}

- (IJSVGStyleSheetSelectorRaw *)_previousSelector:(IJSVGStyleSheetSelectorRaw *)aSelector
{
    NSInteger index = [_rawSelectors indexOfObject:aSelector];
    if(index == 0)
        return nil;
    return _rawSelectors[index-1];
}

- (IJSVGStyleSheetSelectorRaw *)_nextSelector:(IJSVGStyleSheetSelectorRaw *)aSelector
{
    NSInteger index = [_rawSelectors indexOfObject:aSelector];
    if(index == _rawSelectors.count-1)
        return nil;
    return _rawSelectors[index+1];
}

- (BOOL)_match:(IJSVGNode *)node
      selector:(IJSVGStyleSheetSelectorRaw *)rawSelector
{
    // return no if the tag is set but doesnt match the node
    if(rawSelector.tag != nil && [rawSelector.tag isEqualToString:node.name] == NO)
        return NO;
    
    // check if the classes match the class
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
    
    return YES;
}

- (BOOL)_matches:(IJSVGNode *)aNode
        selector:(IJSVGStyleSheetSelectorRaw *)rawSelector
{
    IJSVGNode * prevNode = aNode;
    IJSVGStyleSheetSelectorRaw * aSelector = rawSelector;
    
    while(aSelector != nil) {
        
        IJSVGNode * workingNode = nil;
        
        // for adjacent node, the content to test against
        // is the previous sibling
        if(rawSelector.combinator == IJSVGStyleSheetSelectorCombinatorNextSibling ||
           rawSelector.combinator == IJSVGStyleSheetSelectorCombinatorPrecededSibling) {
            workingNode = [self _previousNode:prevNode];
        }
        
        // for descedant combinators and child, the element
        // to test against is the parent node
        else {
            
            // find the parent
            IJSVGGroup * possibleParent = (IJSVGGroup *)prevNode.parentNode;
            if(possibleParent != nil) {
                workingNode = possibleParent;
            }
        }
        
        // no node - just kill
        if(workingNode == nil)
            return NO;
        
        // test the working node against the current selector
        if([self _match:workingNode
               selector:aSelector]) {

            // check for greedy
            IJSVGStyleSheetSelectorRaw * nSelector = [self _nextSelector:rawSelector];
            
            if([self combinatorIsGreedy:aSelector.combinator] &&
               nSelector.combinator != rawSelector.combinator &&
               (rawSelector.combinator == IJSVGStyleSheetSelectorCombinatorPrecededSibling
                    && [self isAncestorOperator:nSelector.combinator]) == NO) {                   
                // just do a quick dirty check
                if([self _matches:workingNode selector:rawSelector]) {
                    return YES;
                }
            }
            
            // get the next selector
            aSelector = [self _nextSelector:aSelector];
        } else {
            
            // is its greedy, if we didnt match, just return NO
            if([self combinatorIsGreedy:aSelector.combinator] == NO) {
                return NO;
            }
        }
        prevNode = workingNode;
    }
    return YES;
}


- (BOOL)matchesNode:(IJSVGNode *)node
{
    IJSVGStyleSheetSelectorRaw * raw = _rawSelectors[0];
    if([self _match:node selector:raw] &&
       ([self _matches:node selector:raw] || _rawSelectors.count == 1 ))
        return YES;
    return NO;
}

@end
