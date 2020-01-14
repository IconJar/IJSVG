//
//  IJSVGTransaction.h
//  IconJar
//
//  Created by Curtis Hard on 11/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

BOOL IJSVGIsMainThread(void);
BOOL IJSVGBeginTransaction(void);
void IJSVGEndTransaction(void);
