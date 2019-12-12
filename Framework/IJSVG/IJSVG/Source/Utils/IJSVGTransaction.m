//
//  IJSVGTransaction.m
//  IconJar
//
//  Created by Curtis Hard on 11/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGTransaction.h"

BOOL IJSVGIsMainThread(void) { return NSThread.isMainThread; };

void IJSVGBeginTransactionLock(void)
{
    if (IJSVGIsMainThread()) {
        return;
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
};

void IJSVGEndTransactionLock(void)
{
    if (IJSVGIsMainThread()) {
        return;
    }
    [CATransaction commit];
};
