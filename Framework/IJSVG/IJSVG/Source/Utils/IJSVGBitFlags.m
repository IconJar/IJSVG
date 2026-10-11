//
//  IJSVGBitFlags.m
//  IJSVG
//
//  Created by Curtis Hard on 06/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGBitFlags.h>
#import <IJSVG/IJSVGBitFlags64.h>

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
    int count = MIN(_length, storage.length);
    Class sourceClass = storage.class;
    if(sourceClass == IJSVGBitFlags64.class) {
        uint64_t mask = storage.bitMask;
        while(mask != 0) {
            int bit = __builtin_ctzll(mask);
            if(bit >= count) {
                break;
            }
            _storage[bit] = 1;
            mask &= mask - 1;
        }
        return;
    }
    if(sourceClass != IJSVGBitFlags.class) {
        for(int i = 0; i < count; i++) {
            if([storage bitIsSet:i]) {
                _storage[i] = 1;
            }
        }
        return;
    }
    const int* source = storage.storage;
    for(int i = 0; i < count; i++) {
        if(source[i] == 1) {
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
    if(bit >= 0 && bit < _length) {
        _storage[bit] = 1;
    }
}

- (void)unsetBit:(int)bit
{
    if(bit >= 0 && bit < _length) {
        _storage[bit] = 0;
    }
}

- (void)setAllBits
{
    for(int i = 0; i < _length; i++) {
        _storage[i] = 1;
    }
}

@end
