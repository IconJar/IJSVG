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

@interface IJSVGUnitRect : NSObject <NSCopying>

@property (nonatomic, strong) IJSVGUnitSize* size;
@property (nonatomic, strong) IJSVGUnitPoint* origin;
@property (nonatomic, readonly) BOOL isZeroRect;
@property (nonatomic, readonly) CGRect value;

+ (IJSVGUnitRect*)rectWithCGRect:(CGRect)rect;
+ (IJSVGUnitRect*)rectWithOrigin:(IJSVGUnitPoint*)origin
                            size:(IJSVGUnitSize*)size;
+ (IJSVGUnitRect*)rectWithX:(CGFloat)x
                          y:(CGFloat)y
                      width:(CGFloat)width
                     height:(CGFloat)height;

- (CGRect)computeValue:(CGSize)size;

- (IJSVGUnitRect*)copyByConvertingToUnitsLengthType:(IJSVGUnitLengthType)type;
- (void)convertUnitsLengthType:(IJSVGUnitLengthType)type;

@end
