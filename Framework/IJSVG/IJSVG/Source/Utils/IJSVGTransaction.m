//
//  IJSVGTransaction.m
//  IconJar
//
//  Created by Curtis Hard on 11/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGTransaction.h>
#import <AppKit/AppKit.h>

BOOL IJSVGIsMainThread(void) { return NSThread.isMainThread; };

BOOL IJSVGBeginTransaction(void)
{
    if(IJSVGIsMainThread() == YES) {
        return NO;
    }
    // use nsanimationcontext as this sets a private flag of 0x4
    // of the catransaction for background composites
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [CATransaction lock];
    return YES;
};

void IJSVGEndTransaction(void)
{
    [CATransaction unlock];
    [CATransaction commit];
};

void IJSVGPerformTransactionBlock(dispatch_block_t _Nonnull block)
{
    BOOL begin = IJSVGBeginTransaction();
    block();
    if(begin == YES) {
        IJSVGEndTransaction();
    }
}
