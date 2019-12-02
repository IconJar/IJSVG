//
//  IJSVGTransaction.m
//  IconJar
//
//  Created by Curtis Hard on 11/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGTransaction.h"

void IJSVGBeginTransactionLock()
{
    if (NSThread.isMainThread == YES) {
        return;
    }
    [CATransaction begin];
    if (@available(macOS 10.14, *)) {
    } else {
        [CATransaction lock];
    }
    [CATransaction setDisableActions:YES];
};

void IJSVGEndTransactionLock()
{
    if (NSThread.isMainThread == YES) {
        return;
    }

    if (@available(macOS 10.14, *)) {
    } else {
        [CATransaction unlock];
    }
    [CATransaction commit];
};
