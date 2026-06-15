//
//  IJSVGPlatform.m
//  IJSVG
//

#import "IJSVGPlatform.h"

#if TARGET_OS_IOS

@implementation UIView (IJSVGNeedsDisplay)

- (void)setNeedsDisplay:(BOOL)flag
{
    if(flag) {
        [self setNeedsDisplay];
    }
}

@end

@implementation NSValue (IJSVGGeometry)

+ (NSValue*)valueWithPoint:(CGPoint)point { return [NSValue valueWithCGPoint:point]; }
+ (NSValue*)valueWithSize:(CGSize)size { return [NSValue valueWithCGSize:size]; }
+ (NSValue*)valueWithRect:(CGRect)rect { return [NSValue valueWithCGRect:rect]; }
- (CGPoint)pointValue { return [self CGPointValue]; }
- (CGSize)sizeValue { return [self CGSizeValue]; }
- (CGRect)rectValue { return [self CGRectValue]; }

@end

#endif
