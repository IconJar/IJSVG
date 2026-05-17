//
//  IJSVGBitStorage.h
//  IJSVG
//
//  Created by Curtis Hard on 06/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IJSVGBitFlags : NSObject {

@private
    int* _storage;
}

@property (nonatomic, readonly) int length;
@property (nonatomic, readonly) int* storage;

- (id)initWithLength:(int)length;
- (void)addBits:(IJSVGBitFlags*)storage;
- (BOOL)bitIsSet:(int)bit;
- (void)setBit:(int)bit;

@end
