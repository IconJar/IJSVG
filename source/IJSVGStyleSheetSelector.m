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
    NSLog(@"%@",_rawSelectors);
}

- (IJSVGNode *)previousNode:(IJSVGNode *)node
{
    IJSVGGroup * group = (IJSVGGroup *)node.parentNode;
    if([group isKindOfClass:[IJSVGGroup class]] == NO)
        return nil;
    NSInteger currentIndex = [group.children indexOfObject:node];
    if(currentIndex == 0)
        return nil;
    return group.children[currentIndex-1];
}

- (IJSVGNode *)nextNode:(IJSVGNode *)node
{
    IJSVGGroup * group = (IJSVGGroup *)node.parentNode;
    if([group isKindOfClass:[IJSVGGroup class]] == NO)
        return nil;
    NSInteger currentIndex = [group.children indexOfObject:node];
    if(currentIndex == group.children.count-1)
        return nil;
    return group.children[currentIndex+1];
}

- (BOOL)_matchesNode:(IJSVGNode *)node
         rawSelector:(IJSVGStyleSheetSelectorRaw *)rawSelector
          combinator:(IJSVGStyleSheetSelectorCombinator)combinator
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
    
    // if we get here, the rest match, so we need to check any combinator...
    if(combinator != IJSVGStyleSheetSelectorCombinatorDescendant) {
        
        // the parent node must be of type group in order to actually have children
        IJSVGGroup * group = (IJSVGGroup *)node.parentNode;
        
        // are we actually a group?
        if([group isKindOfClass:[IJSVGGroup class]]) {
            
            // work out next and previous
            IJSVGNode * previousNode = [self previousNode:node];
            IJSVGNode * nextNode = [self nextNode:node];
            
            // work out what to do for each combinator
            switch (rawSelector.combinator) {
                    
                // > direct decendant
                case IJSVGStyleSheetSelectorCombinatorDirectDescendant: {
                    if([self _matchesNode:group
                              rawSelector:[self previousSelector:rawSelector]
                               combinator:IJSVGStyleSheetSelectorCombinatorDescendant])
                        return YES;
                    break;
                }
                    
                // + next sibling
                case IJSVGStyleSheetSelectorCombinatorNextSibling: {
                    if( previousNode.type == node.type )
                        return YES;
                    break;
                }
                    
                // ~ previous sibling
                case IJSVGStyleSheetSelectorCombinatorPrecededSibling: {
                    if( nextNode.type == node.type )
                        return YES;
                    break;
                }
                    
                default:
                    return NO;
            }
        }
        return NO;
    }
    return YES;
}

- (IJSVGStyleSheetSelectorRaw *)previousSelector:(IJSVGStyleSheetSelectorRaw *)aSelector
{
    NSInteger index = [_rawSelectors indexOfObject:aSelector];
    if(index == 0)
        return nil;
    return _rawSelectors[--index];
}

- (IJSVGStyleSheetSelectorRaw *)nextSelector:(IJSVGStyleSheetSelectorRaw *)aSelector
{
    NSInteger index = [_rawSelectors indexOfObject:aSelector];
    if(index == _rawSelectors.count-1)
        return nil;
    return _rawSelectors[++index];
}

- (BOOL)matchesNode:(IJSVGNode *)node
{
    // grab the list of remaing selectors
    IJSVGNode * checkNode = node;
    for(IJSVGStyleSheetSelectorRaw * rawSelector in _rawSelectors) {
        
        BOOL basicMatch = [self _matchesNode:checkNode
                                 rawSelector:rawSelector
                                  combinator:IJSVGStyleSheetSelectorCombinatorDescendant];
        
        // simple, just return NO
        if(!basicMatch)
            return NO;
        
        // requires more then just a standard descendant
        if(rawSelector.combinator != IJSVGStyleSheetSelectorCombinatorDescendant) {
            
            basicMatch = [self _matchesNode:checkNode
                                rawSelector:rawSelector
                                 combinator:rawSelector.combinator];
            if(!basicMatch)
                return NO;
            
        } else {
            
            IJSVGNode * pNode = checkNode;
            BOOL found = NO;
            for(;;) {
                pNode = pNode.parentNode;
                if(pNode == nil)
                    return NO;
                basicMatch = [self _matchesNode:checkNode
                                    rawSelector:rawSelector
                                     combinator:rawSelector.combinator];
                if(basicMatch) {
                    found = YES;
                    break;
                } else {
                    return NO;
                }
            }
        }
        
    }
    return YES;
}

@end
