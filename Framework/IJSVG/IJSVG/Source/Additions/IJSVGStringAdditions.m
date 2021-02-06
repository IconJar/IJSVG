//
//  IJSVGStringAdditions.m
//  IconJar
//
//  Created by Curtis Hard on 07/06/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import "IJSVGStringAdditions.h"
#import "IJSVGUtils.h"

@implementation NSString (IJSVGAdditions)

- (NSArray<NSString*>*)ijsvg_componentsSeparatedByChars:(const char*)aChar
{
    NSMutableArray<NSString*>* strings = nil;
    strings = [[[NSMutableArray alloc] init] autorelease];
    char* chars = (char*)self.UTF8String;
    if(chars == NULL || strlen(chars) == 0) {
        return strings;
    }
    char* copy = (char*)calloc(strlen(chars)+1, sizeof(char));
    char* orig = copy;
    strcpy(copy, chars);
    char* ptr = strtok(copy, aChar);
    while(ptr != NULL) {
        [strings addObject:[NSString stringWithUTF8String:ptr]];
        ptr = strtok(NULL, aChar);
    }
    (void)free(orig), orig = NULL;
    return strings;
}

- (BOOL)ijsvg_containsAlpha
{
    const char* buffer = self.UTF8String;
    char currentChar;
    while((currentChar = *buffer++) ) {
        if (isalpha(currentChar)) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)ijsvg_isNumeric
{
    const char* buffer = self.UTF8String;
    char currentChar;
    while((currentChar = *buffer++) ) {
        if (!isnumber(currentChar)) {
            return NO;
        }
    }
    return YES;
}

- (NSArray*)ijsvg_componentsSplitByWhiteSpace
{
    return [self ijsvg_componentsSeparatedByChars:"\t\n\r "];
}

- (BOOL)ijsvg_isHexString
{
    const char* chars = self.UTF8String;
    return IJSVGCharBufferIsHEX((char*)chars);
}

@end
