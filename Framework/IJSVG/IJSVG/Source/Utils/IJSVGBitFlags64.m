//
//  IJSVGBitFlags64.m
//  IJSVG
//
//  Created by Curtis Hard on 08/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGBitFlags64.h>

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

- (int)length
{
    return 64;
}

- (uint64_t)bitMask
{
    return _storage64;
}

- (BOOL)bitIsSet:(int)bit
{
    return bit >= 0 && bit < 64 && ((_storage64 >> bit) & 1ULL) == 1;
}

- (void)setBit:(int)bit
{
    _storage64 |= (1ULL << bit);
}

- (void)unsetBit:(int)bit
{
  _storage64 &= ~(1ULL << bit);
}

- (void)setAllBits
{
  _storage64 = 1ULL;
}

@end
