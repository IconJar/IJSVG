//
//  IJSVGUnitPoint.h
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUnitLength.h>
#import <Foundation/Foundation.h>

@interface IJSVGUnitPoint : NSObject <NSCopying>

@property (nonatomic, strong) IJSVGUnitLength* x;
@property (nonatomic, strong) IJSVGUnitLength* y;
@property (nonatomic, readonly) CGPoint value;

+ (IJSVGUnitPoint*)zeroPoint;
+ (IJSVGUnitPoint*)pointWithCGPoint:(CGPoint)point;
+ (IJSVGUnitPoint*)pointWithX:(IJSVGUnitLength*)x
                            y:(IJSVGUnitLength*)y;

- (void)convertUnitsToLengthType:(IJSVGUnitLengthType)lengthType;
- (CGPoint)computeValue:(CGSize)size;

@end
