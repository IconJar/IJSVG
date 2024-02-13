//
//  NSValue+macOS.h
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#if __has_include(<UIKit/UIKit.h>)
@import UIKit;

@interface NSValue (macOS)

+ (instancetype)valueWithRect:(CGRect)rect;
- (CGRect)rectValue;

+ (instancetype)valueWithSize:(CGSize)size;
- (CGSize)sizeValue;

+ (instancetype)valueWithPoint:(CGPoint)point;
- (CGPoint)pointValue;

@end

#endif
