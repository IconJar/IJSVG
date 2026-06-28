//
//  IJSVGStringAdditions.m
//  IconJar
//
//  Created by Curtis Hard on 07/06/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStringAdditions.h>
#import <IJSVG/IJSVGUtils.h>

@implementation NSString (IJSVGAdditions)

- (NSArray<NSString*>*)ijsvg_componentsSeparatedByChars:(const char*)aChar
{
    char* chars = (char*)self.UTF8String;
    if(chars == NULL || strlen(chars) == 0) {
        return @[];
    }
    NSMutableArray<NSString*>* strings = nil;
    strings = [[NSMutableArray alloc] init];
    char* copy = strdup(chars);
    char* spt = NULL;
    char* ptr = strtok_r(copy, aChar, &spt);
    while(ptr != NULL) {
        NSString* possibleString = nil;
        if((possibleString = [NSString stringWithUTF8String:ptr]) != nil) {
            [strings addObject:possibleString];
        }
        ptr = strtok_r(NULL, aChar, &spt);
    }
    (void)free(copy), copy = NULL;
    return strings;
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
