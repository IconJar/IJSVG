//
//  CGColorSpaceWrapper.h
//  IJSVG
//
//  Created by François Lamboley on 2024/02/13.
//
//

#import <Foundation/Foundation.h>
@import CoreGraphics;

NS_ASSUME_NONNULL_BEGIN

@interface CGColorSpaceWrapper : NSObject

+ (instancetype)deviceRGBColorSpace;
+ (instancetype)sRGBColorSpace;
- (CGColorSpaceRef)CGColorSpace;

- (instancetype)initWithCGColorSpace:(CGColorSpaceRef)colorSpace;

@end

NS_ASSUME_NONNULL_END
