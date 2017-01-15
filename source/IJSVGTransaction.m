//
//  IJSVGTransaction.m
//  IconJar
//
//  Created by Curtis Hard on 11/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGTransaction.h"

void IJSVGBeginTransactionLock() {
    [CATransaction begin];
    [CATransaction lock];
    [CATransaction setDisableActions:YES];
};

void IJSVGEndTransactionLock() {
    [CATransaction unlock];
    [CATransaction commit];
};

void IJSVGObtainTransactionLock(dispatch_block_t block, BOOL renderOnMainThread)
{
    IJSVGBeginTransactionLock();
    if(renderOnMainThread) {
        dispatch_sync(dispatch_get_main_queue(), block);
    } else {
        block();
    }
    IJSVGEndTransactionLock();
};
