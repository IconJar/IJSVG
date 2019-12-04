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
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
};

void IJSVGEndTransactionLock()
{
    [CATransaction commit];
};
