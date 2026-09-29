//
//  IJSVGBitStorage.m
//  IJSVG
//
//  Created by Curtis Hard on 06/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGBitFlags.h>

@implementation IJSVGBitFlags

- (void)dealloc
{
    if(_storage != NULL) {
        (void)free(_storage), _storage = NULL;
    }
}

- (id)initWithLength:(int)length
{
    if((self = [super init]) != nil) {
        _length = length;
        _storage = (int*)calloc(sizeof(int), length);
    }
    return self;
}

- (void)addBits:(IJSVGBitFlags*)storage
{
    for(int i = 0; i < MIN(_length, storage.length); i++) {
        if([storage bitIsSet:i] == YES) {
            _storage[i] = 1;
        }
    }
}

- (uint64_t)bitMask
{
    uint64_t mask = 0ULL;
    for(int i = 0; i < MIN(_length, 64); i++) {
        if(*(_storage + i) == 1) {
            mask |= (1ULL << i);
        }
    }
    return mask;
}

- (BOOL)bitIsSet:(int)bit
{
    return bit >= 0 && bit < _length && _storage[bit] == 1;
}

- (void)setBit:(int)bit
{
    *(_storage + bit) = 1;
}

- (void)unsetBit:(int)bit
{
    *(_storage + bit) = 0;
}

- (void)setAllBits
{
    for(int i = 0; i < _length; i++) {
        _storage[i] = 1;
    }
}

@end
