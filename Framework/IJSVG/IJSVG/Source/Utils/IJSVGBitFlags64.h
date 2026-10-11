//
//  IJSVGBitFlags64.h
//  IJSVG
//
//  Created by Curtis Hard on 08/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGBitFlags.h>

// Fixed capacity of 64 bits with no integer array storage.
// initWithLength preserves this capacity and storage returns NULL.
@interface IJSVGBitFlags64 : IJSVGBitFlags {
@private
    uint64_t _storage64;
}

@end
