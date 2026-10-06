//
//  NSValue+macOS.h
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#import <TargetConditionals.h>
#if !TARGET_OS_OSX

#import <UIKit/UIKit.h>

@interface NSValue (macOS)

+ (instancetype)valueWithRect:(CGRect)rect;
- (CGRect)rectValue;

+ (instancetype)valueWithSize:(CGSize)size;
- (CGSize)sizeValue;

+ (instancetype)valueWithPoint:(CGPoint)point;
- (CGPoint)pointValue;

@end

#endif
