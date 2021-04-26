//
//  IJSVGUnitRect.h
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUnitPoint.h>
#import <IJSVG/IJSVGUnitSize.h>
#import <Foundation/Foundation.h>

@interface IJSVGUnitRect : NSObject

@property (nonatomic, retain) IJSVGUnitSize* size;
@property (nonatomic, retain) IJSVGUnitPoint* origin;

+ (IJSVGUnitRect*)rectWithOrigin:(IJSVGUnitPoint*)origin
                            size:(IJSVGUnitSize*)size;

@end
