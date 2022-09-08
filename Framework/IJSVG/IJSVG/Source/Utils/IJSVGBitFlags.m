//
//  IJSVGBitStorage.m
//  IJSVG
//
//  Created by Curtis Hard on 06/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGBitFlags.h"

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
    int* ps = storage.storage;
    int* ss = _storage;
    for(int i = 0; i < storage.length; i++) {
        int* current = ss++;
        if(*ps++ == 1) {
            *current = 1;
        }
    }
}

- (BOOL)bitIsSet:(int)bit
{
    return *(_storage + bit) == 1;
}

- (void)setBit:(int)bit
{
    *(_storage + bit) = 1;
}



@end
