//
//  IJSVGUnitSize.h
//  IJSVG
//
//  Created by Curtis Hard on 12/02/2020.
//  Copyright © 2020 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUnitLength.h>
#import <Foundation/Foundation.h>

@interface IJSVGUnitSize : NSObject <NSCopying>

@property (nonatomic, strong) IJSVGUnitLength* width;
@property (nonatomic, strong) IJSVGUnitLength* height;
@property (nonatomic, readonly) CGSize value;
@property (nonatomic, readonly) BOOL isZeroSize;


+ (IJSVGUnitSize*)zeroSize;
+ (IJSVGUnitSize*)sizeWithCGSize:(CGSize)size;
+ (IJSVGUnitSize*)sizeWithWidth:(IJSVGUnitLength*)width
                         height:(IJSVGUnitLength*)height;

- (void)convertUnitsToLengthType:(IJSVGUnitLengthType)lengthType;
- (CGSize)computeValue:(CGSize)size;

@end
