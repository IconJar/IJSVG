//
//  IJSVGTransaction.m
//  IconJar
//
//  Created by Curtis Hard on 11/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGTransaction.h"
#import <AppKit/AppKit.h>

BOOL IJSVGIsMainThread(void) { return NSThread.isMainThread; };

BOOL IJSVGBeginTransaction(void)
{
    if(IJSVGIsMainThread() == YES) {
        return NO;
    }
    // use nsanimationcontext as this sets a private flag of 0x4
    // of the catransaction for background composites
    [NSAnimationContext beginGrouping];
    return YES;
};

void IJSVGEndTransaction(void)
{
    [NSAnimationContext endGrouping];
};
