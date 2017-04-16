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

#define SPECIFICITY_TAG 1
#define SPECIFICITY_CLASS 10
#define SPECIFICITY_IDENTIFIER 100

@synthesize specificity;

BOOL IJSVGStyleSheetIsSiblingCombinator(IJSVGStyleSheetSelectorCombinator combinator)
{
    return combinator == IJSVGStyleSheetSelectorCombinatorNextSibling ||
    combinator == IJSVGStyleSheetSelectorCombinatorPrecededSibling;
};

IJSVGStyleSheetSelectorCombinator IJSVGStyleSheetCombinatorForUnichar(unichar aChar)
{
    if(aChar == '+') {
        return IJSVGStyleSheetSelectorCombinatorNextSibling;
    }
    if(aChar == '~') {
        return IJSVGStyleSheetSelectorCombinatorPrecededSibling;
    }
    if(aChar == '>') {
        return IJSVGStyleSheetSelectorCombinatorDirectDescendant;
    }
    return IJSVGStyleSheetSelectorCombinatorDescendant;
};

IJSVGNode * IJSVGStyleSheetPreviousNode(IJSVGNode * node)
{
    IJSVGGroup * group = (IJSVGGroup *)node.parentNode;
    if([group isKindOfClass:[IJSVGGroup class]] == NO)
        return nil;
    NSInteger currentIndex = [group.children indexOfObject:node];
    if(currentIndex == 0) {
        return nil;
    }
    return group.children[currentIndex-1];
};

IJSVGNode * IJSVGStyleSheetNextNode(IJSVGNode * node)
{
    IJSVGGroup * group = (IJSVGGroup *)node.parentNode;
    if([group isKindOfClass:[IJSVGGroup class]] == NO) {
        return nil;
    }
    NSInteger currentIndex = [group.children indexOfObject:node];
    if(currentIndex == group.children.count-1) {
        return nil;
    }
    return group.children[currentIndex+1];
};

IJSVGStyleSheetSelectorRaw * IJSVGStyleSheetPreviousSelector(IJSVGStyleSheetSelectorRaw * aSelector, NSArray * _rawSelectors)
{
    NSInteger index = [_rawSelectors indexOfObject:aSelector];
    if(index == 0) {
        return nil;
    }
    return _rawSelectors[index-1];
};

IJSVGStyleSheetSelectorRaw * IJSVGStyleSheetNextSelector(IJSVGStyleSheetSelectorRaw * aSelector, NSArray * _rawSelectors)
{
    NSInteger index = [_rawSelectors indexOfObject:aSelector];
    if(index == _rawSelectors.count-1) {
        return nil;
    }
    return _rawSelectors[index+1];
};

BOOL IJSVGStyleSheetMatchSelector(IJSVGNode * node, IJSVGStyleSheetSelectorRaw * rawSelector)
{
    // return no if the tag is set but doesnt match the node
    if(rawSelector.tag != nil && [rawSelector.tag isEqualToString:node.name] == NO)
        return NO;
    
    // check if the classes match the class
    if(rawSelector.classes.count != 0) {
        for(NSString * className in rawSelector.classes) {
            if([node.classNameList containsObject:className] == NO) {
                return NO;
            }
        }
    }
    
    // check the idenfitier
    if(rawSelector.identifier != nil &&
       [rawSelector.identifier isEqualToString:node.identifier] == NO) {
        return NO;
    }
    
    return YES;
};


- (BOOL)_matches:(IJSVGNode *)aNode
        selector:(IJSVGStyleSheetSelectorRaw *)rawSelector
{
    IJSVGStyleSheetSelectorRaw * aSelector = rawSelector;
    
    // loop until aSelector is nil
    while(aSelector != nil) {
        
        // sibling, so + or ~
        if(IJSVGStyleSheetIsSiblingCombinator(aSelector.combinator)) {
            
            // the +
            if(aSelector.combinator == IJSVGStyleSheetSelectorCombinatorNextSibling) {
                
                // straight forward again, find the previous sibling
                // and match it against the next selector in the list
                IJSVGNode * previousNode = IJSVGStyleSheetPreviousNode(aNode);
                IJSVGStyleSheetSelectorRaw * s = IJSVGStyleSheetNextSelector(aSelector, _rawSelectors);
                
                if(previousNode != nil &&  IJSVGStyleSheetMatchSelector(previousNode, s)) {
                    // set the new starting selector and node
                    aSelector = s;
                    aNode = previousNode;
                }
                
                // didnt match previous element
                else {
                    return NO;
                }
                
            }
            
            // the ~
            if(aSelector.combinator == IJSVGStyleSheetSelectorCombinatorPrecededSibling) {
                
                IJSVGGroup * parentNode = (IJSVGGroup *)aNode.parentNode;
                
                // no parent, just return no
                if(parentNode == nil) {
                    return NO;
                }
                
                // grab the children
                NSArray * nodes = parentNode.children;
                NSInteger index = [nodes indexOfObject:aNode];
                
                // doesnt contain the child
                if(index == NSNotFound) {
                    return NO;
                }
                
                // find the next selector
                IJSVGStyleSheetSelectorRaw * s = IJSVGStyleSheetNextSelector(aSelector,_rawSelectors);
                BOOL found = NO;
                for( NSUInteger i = index; index > 0; i-- ) {
                    
                    // grab the child node
                    IJSVGNode * childNode = nodes[i];
                    
                    // matches, huzzah!
                    if(IJSVGStyleSheetMatchSelector(childNode, s)) {
                        // set the new starting selector and node
                        found = YES;
                        aSelector = s;
                        aNode = childNode;
                        break;
                    }
                }
                
                // nothing found
                if(found == NO) {
                    return NO;
                }
                
            }
            
        }
        
        // not a + or a ~
        else {
            
            // can up to the matching parent, if not found, nothing!
            if(aSelector.combinator == IJSVGStyleSheetSelectorCombinatorDescendant) {
                // go up the chain until we match a parent that
                // matches the next selector
                IJSVGStyleSheetSelectorRaw * s = IJSVGStyleSheetNextSelector(aSelector,_rawSelectors);
                IJSVGNode * p = aNode;
                while(p != nil) {
                    
                    // set p to current parentNode
                    p = p.parentNode;
                    
                    // p must exist and match the selector
                    if(p != nil && IJSVGStyleSheetMatchSelector(p, s)) {
                        // set the new starting selector and node
                        aSelector = s;
                        aNode = p;
                        break;
                    }
                    
                    // no parent match found
                    else if(p == nil) {
                        return NO;
                    }
                }
            }
            
            // > direct descedant
            else if(aSelector.combinator == IJSVGStyleSheetSelectorCombinatorDirectDescendant) {
                
                // grab parent
                IJSVGGroup * parentNode = (IJSVGGroup *)aNode.parentNode;
                
                // no parent, just return
                if(parentNode == nil) {
                    return NO;
                }
                
                // really straight forward, just check if the parent
                // matches the next selector and... contains the node in question
                IJSVGStyleSheetSelectorRaw * s = IJSVGStyleSheetNextSelector(aSelector,_rawSelectors);
                if(IJSVGStyleSheetMatchSelector(parentNode, s) &&
                   [parentNode.children containsObject:aNode]) {
                    // set the new starting selector and node
                    aSelector = s;
                    aNode = parentNode;
                }
                
                // no match found
                else {
                    return NO;
                }
            }
        }
    }
    return YES;
}

- (void)dealloc
{
    [_rawSelectors release], _rawSelectors = nil;
    [selector release], selector = nil;
    [super dealloc];
}

- (id)initWithSelectorString:(NSString *)string
{
    if((self = [super init]) != nil)
    {
        selector = [string copy];
        _rawSelectors = [[NSMutableArray alloc] init];
        
        // failed to compile
        if([self _compile] == NO) {
            [self release], self = nil;
            return nil;
        }
        [self _calculate];
    }
    return self;
}

- (void)_calculate
{
    // calculate the specificity
    // of the selector
    for(IJSVGStyleSheetSelectorRaw * rawSelector in _rawSelectors) {
        
        // 1 for a tag
        if(rawSelector.tag != nil) {
            self.specificity += SPECIFICITY_TAG;
        }
        
        // 100 for a id
        if(rawSelector.identifier != nil)
            self.specificity += SPECIFICITY_IDENTIFIER;
        
        // 10 for a class
        self.specificity += (rawSelector.classes.count*SPECIFICITY_CLASS);
    }
}

- (BOOL)_compile
{
    
    // completely unsupported
    if([selector characterAtIndex:0] == '@') {
        return NO;
    }
    
    // keychar lookup
    char * keychars = "#+.>~ ";
    NSUInteger aLength = strlen(keychars);
    BOOL (^isKeyChar)(char anotherChar) = ^(char anotherChar) {
        for(NSInteger i = 0; i < aLength; i++) {
            if(keychars[i] == anotherChar) {
                return YES;
            }
        }
        return NO;
    };
    
    
    NSUInteger length = selector.length;
    NSMutableArray * sels = [[[NSMutableArray alloc] init] autorelease];
    IJSVGStyleSheetSelectorRaw * rawSelector = [[[IJSVGStyleSheetSelectorRaw alloc] init] autorelease];
    
    for(NSUInteger i = 0; i < length; i++) {
        unichar c = [selector characterAtIndex:i];
        // beginning of class
        if( c == '.' ) {
            i++;
            for(NSUInteger a = i; a < length; a++ ) {
                unichar ca = [selector characterAtIndex:a];
                if(isKeyChar(ca) == YES || a == length-1) {
                    // if at end, add 1 to a so it gets the last character
                    if( a == length-1 ) {
                        a++;
                    }
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
                if(isKeyChar(ca) == YES || a == length-1) {
                    // if at end, add 1 to a so it gets the last character
                    if( a == length-1 ) {
                        a++;
                    }
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
            if(!(i == length-1)) {
                rawSelector = [[[IJSVGStyleSheetSelectorRaw alloc] init] autorelease];
            }
        }
        
        // combinator
        else if ( c == '+' || c == '~' || c == '>' ) {
            
            // set the combinator onto the selector
            rawSelector.combinator = IJSVGStyleSheetCombinatorForUnichar(c);
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
                if(isKeyChar(ca) == YES || a == length-1) {
                    if( a == length-1 ) {
                        a++;
                    }
                    rawSelector.tag = [selector substringWithRange:NSMakeRange(i, a-i)];
                    i = a-1;
                    break;
                }
            }
        }
        
        // add raw selector
        if( i == length - 1 ) {
            if(rawSelector != nil) {
                [sels addObject:rawSelector];
            }
            rawSelector = nil;
        }
        
    }
    // now its compiled, we need to reverse the selectors
    [_rawSelectors addObjectsFromArray:[sels reverseObjectEnumerator].allObjects];
    return YES;
}


- (BOOL)matchesNode:(IJSVGNode *)node
{
    IJSVGStyleSheetSelectorRaw * sel = _rawSelectors[0];
    // return YES only if the first selector matches the node
    // and the next selector is nil, or the next selector isnt nil
    // and the node then goes up the tree and works itself out with the
    // selectors in question
    if(IJSVGStyleSheetMatchSelector(node, sel) &&
       (IJSVGStyleSheetNextSelector(sel,_rawSelectors) == nil ||
        [self _matches:node selector:sel])) {
        return YES;
    }
    return NO;
}

@end
