//
//  IJSVGTransaction.h
//  IconJar
//
//  Created by Curtis Hard on 11/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

void IJSVGBeginTransactionLock();
void IJSVGEndTransactionLock();
void IJSVGObtainTransactionLock(dispatch_block_t block, BOOL renderOnMainThread);
