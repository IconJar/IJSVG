//
//  IJSVGUnitPoint.h
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import "IJSVGUnitLength.h"
#import <Foundation/Foundation.h>

@interface IJSVGUnitPoint : NSObject

@property (nonatomic, retain) IJSVGUnitLength* x;
@property (nonatomic, retain) IJSVGUnitLength* y;

@end
