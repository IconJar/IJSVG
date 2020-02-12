//
//  IJSVGUnitSize.h
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import "IJSVGUnitLength.h"
#import <Foundation/Foundation.h>

@interface IJSVGUnitSize : NSObject

@property (nonatomic, retain) IJSVGUnitLength* width;
@property (nonatomic, retain) IJSVGUnitLength* height;

+ (IJSVGUnitSize*)sizeWithWidth:(IJSVGUnitLength*)width
                         height:(IJSVGUnitLength*)height;

@end
