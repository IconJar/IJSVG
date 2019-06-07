//
//  IJSVGStringAdditions.m
//  IconJar
//
//  Created by Curtis Hard on 07/06/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import "IJSVGStringAdditions.h"

@implementation NSString (IJSVGAdditions)

- (NSArray<NSString *> *)componentsSeparatedByChars:(char *)aChar
{
    NSMutableArray * comp = [[[NSMutableArray alloc] init] autorelease];
    NSInteger length = self.length;
    unichar * chars = (unichar *)calloc(sizeof(unichar),self.length);
    
    NSInteger ind = 0;
    BOOL startedString = NO;
    
    // block for easy comparison
    NSUInteger aLength = strlen(aChar);
    BOOL (^charsContainsChar)(char anotherChar) = ^(char anotherChar) {
        for(NSInteger i = 0; i < aLength; i++) {
            if(aChar[i] == anotherChar) {
                return YES;
            }
        }
        return NO;
    };
    
    for(NSInteger i = 0; i < length; i++) {
        
        // the char
        unichar theChar = [self characterAtIndex:i];
        
        // start the buffer
        BOOL isEqualToChar = charsContainsChar(theChar);
        if(isEqualToChar == NO) {
            startedString = YES;
            chars[ind++] = theChar;
        }
        
        // has started and char is the search char, or its at end
        if((startedString == YES && isEqualToChar) ||
           (i == (length-1) && startedString == YES)) {
            startedString = NO;
            
            // append the comp
            [comp addObject:[NSString stringWithCharacters:chars length:ind]];
            free(chars);
            
            // restart and realloc the memory
            ind = 0;
            chars = (unichar *)calloc(sizeof(unichar), self.length);
        }
    }
    free(chars);
    return comp;
}

- (BOOL)containsAlpha
{
    const char * buffer = self.UTF8String;
    unsigned long length = strlen(buffer);
    for( int i = 0; i < length; i++ ) {
        if( isalpha(buffer[i]) ) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isNumeric
{
    const char * buffer = self.UTF8String;
    unsigned long length = strlen(buffer);
    for(int i = 0; i < length; i++) {
        if(!isnumber(buffer[i])) {
            return NO;
        }
    }
    return YES;
}

- (NSArray *)componentsSplitByWhiteSpace
{
    return [self componentsSeparatedByChars:"\t\n\r "];
}

@end
