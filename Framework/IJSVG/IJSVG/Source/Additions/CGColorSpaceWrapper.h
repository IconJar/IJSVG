//
//  CGColorSpaceWrapper.h
//  IJSVG
//
//  Created by François Lamboley on 2024/02/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface CGColorSpaceWrapper : NSObject {
    CGColorSpaceRef colorSpace;
}

@property(nonatomic) CGColorSpaceRef colorSpace;

+ (instancetype)deviceRGBColorSpace;
+ (instancetype)sRGBColorSpace;
- (CGColorSpaceRef)CGColorSpace;
- (NSString *)colorSpaceName;

- (instancetype)initWithCGColorSpace:(CGColorSpaceRef)colorSpace;

@end

NS_ASSUME_NONNULL_END
