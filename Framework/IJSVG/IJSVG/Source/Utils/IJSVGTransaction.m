//
//  IJSVGTransaction.m
//  IconJar
//
//  Created by Curtis Hard on 11/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGTransaction.h"

BOOL IJSVGIsMainThread(void) { return NSThread.isMainThread; };

BOOL IJSVGBeginTransactionLock(void)
{
    if (IJSVGIsMainThread()) {
        return NO;
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    return YES;
};

void IJSVGEndTransactionLock(void)
{
    [CATransaction commit];
};
