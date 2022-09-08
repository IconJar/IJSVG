//
//  IJSVGBitFlags64.m
//  IJSVG
//
//  Created by Curtis Hard on 08/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGBitFlags64.h"

@implementation IJSVGBitFlags64

- (instancetype)init
{
    if((self = [super init]) != nil) {
        _storage64 = 0ULL;
    }
    return self;
}

- (void)addBits:(IJSVGBitFlags*)storage
{
    for(int i = 0; i < 64; i++) {
        if([storage bitIsSet:i] == YES) {
            [self setBit:i];
        }
    }
}

- (BOOL)bitIsSet:(int)bit
{
    return ((_storage64 >> bit) & 1ULL) == 1;
}

- (void)setBit:(int)bit
{
    _storage64 |= (1ULL << bit);
}

@end
