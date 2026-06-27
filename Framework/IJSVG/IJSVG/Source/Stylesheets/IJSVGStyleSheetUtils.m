//
//  IJSVGStyleSheetUtils.m
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetUtils.h>

BOOL IJSVGStyleSheetCharIsWhitespace(char aChar)
{
    return aChar == ' ' || aChar == '\t' || aChar == '\n' ||
        aChar == '\r' || aChar == '\f';
}

BOOL IJSVGStyleSheetCharIsCombinator(char aChar)
{
    return aChar == '>' || aChar == '+' || aChar == '~';
}

BOOL IJSVGStyleSheetCharEndsIdentifier(char aChar)
{
    return aChar == '#' || aChar == '.' || aChar == '*' || aChar == '|' ||
        IJSVGStyleSheetCharIsCombinator(aChar) ||
        IJSVGStyleSheetCharIsWhitespace(aChar);
}

BOOL IJSVGStyleSheetCharIsInvalidSelectorChar(char aChar)
{
    return aChar == '@' || aChar == ':' || aChar == ';' ||
        aChar == '(' || aChar == ')' || aChar == '[' || aChar == ']';
}

BOOL IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(const char* chars,
                                                    NSUInteger index,
                                                    NSUInteger length)
{
    return chars != NULL && index + 1 < length &&
        chars[index] == '|' && chars[index + 1] == '|';
}

NSUInteger IJSVGStyleSheetIndexBySkippingWhitespace(const char* chars,
                                                    NSUInteger index,
                                                    NSUInteger length)
{
    while(index < length && IJSVGStyleSheetCharIsWhitespace(chars[index])) {
        index++;
    }
    return index;
}

IJSVGStyleSheetSelectorCombinator IJSVGStyleSheetCombinatorForChar(char aChar)
{
    switch(aChar) {
        case '+': {
            return IJSVGStyleSheetSelectorCombinatorNextSibling;
        }
        case '~': {
            return IJSVGStyleSheetSelectorCombinatorPrecededSibling;
        }
        case '|': {
            return IJSVGStyleSheetSelectorCombinatorColumn;
        }
        case '>':
        default: {
            return IJSVGStyleSheetSelectorCombinatorDirectDescendant;
        }
    }
}

NSString* IJSVGStyleSheetCombinatorStringForCombinator(IJSVGStyleSheetSelectorCombinator combinator)
{
    switch(combinator) {
        case IJSVGStyleSheetSelectorCombinatorDirectDescendant: {
            return @">";
        }
        case IJSVGStyleSheetSelectorCombinatorNextSibling: {
            return @"+";
        }
        case IJSVGStyleSheetSelectorCombinatorPrecededSibling: {
            return @"~";
        }
        case IJSVGStyleSheetSelectorCombinatorColumn: {
            return @"||";
        }
        case IJSVGStyleSheetSelectorCombinatorWildcard:
        case IJSVGStyleSheetSelectorCombinatorDescendant:
        default: {
            return @" ";
        }
    }
}

NSString* IJSVGStyleSheetStringFromUTF8Bytes(const char* chars, NSUInteger start, NSUInteger end)
{
    if(chars == NULL || end <= start) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:chars + start
                                    length:end - start
                                  encoding:NSUTF8StringEncoding];
}

NSString* IJSVGStyleSheetStringByRemovingCSSComments(NSString* string)
{
    const char* chars = string.UTF8String;
    if(chars == NULL) {
        return string;
    }

    NSUInteger length = strlen(chars);
    if(length == 0) {
        return string;
    }

    NSMutableString* cleanString = [[NSMutableString alloc] initWithCapacity:length];
    NSUInteger marker = 0;
    char quote = 0;
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

        if(c == '/' && i + 1 < length && chars[i + 1] == '*') {
            NSString* chunk = IJSVGStyleSheetStringFromUTF8Bytes(chars, marker, i);
            if(chunk != nil) {
                [cleanString appendString:chunk];
            }

            i += 2;
            while(i + 1 < length && !(chars[i] == '*' && chars[i + 1] == '/')) {
                i++;
            }

            if(i + 1 >= length) {
                marker = length;
                break;
            }

            i += 1;
            marker = i + 1;
        }
    }

    NSString* chunk = IJSVGStyleSheetStringFromUTF8Bytes(chars, marker, length);
    if(chunk != nil) {
        [cleanString appendString:chunk];
    }
    return cleanString;
}

BOOL IJSVGStyleSheetSelectorRawHasSimpleSelector(IJSVGStyleSheetSelectorRaw* rawSelector)
{
    return rawSelector.tag != nil || rawSelector.identifier != nil || rawSelector.classes.count != 0;
}

BOOL IJSVGStyleSheetSelectorRawHasAnySelector(IJSVGStyleSheetSelectorRaw* rawSelector,
                                              BOOL hasUniversalSelector)
{
    return hasUniversalSelector == YES || IJSVGStyleSheetSelectorRawHasSimpleSelector(rawSelector) == YES;
}

BOOL IJSVGStyleSheetSelectorCommitRawSelector(NSMutableArray<IJSVGStyleSheetSelectorRaw*>* parsedSelectors,
                                              IJSVGStyleSheetSelectorRaw* rawSelector,
                                              BOOL hasUniversalSelector)
{
    if(IJSVGStyleSheetSelectorRawHasAnySelector(rawSelector, hasUniversalSelector) == NO) {
        return NO;
    }
    [parsedSelectors addObject:rawSelector];
    return YES;
}

IJSVGStyleSheetSelectorRaw* IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinator combinator)
{
    IJSVGStyleSheetSelectorRaw* rawSelector = [[IJSVGStyleSheetSelectorRaw alloc] init];
    rawSelector.combinator = combinator;
    rawSelector.combinatorString = IJSVGStyleSheetCombinatorStringForCombinator(combinator);
    return rawSelector;
}
