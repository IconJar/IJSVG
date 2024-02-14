//
//  UIScreen+macOS.m
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#if __has_include(<UIKit/UIKit.h>)
@import UIKit;
#import "UIScreen+macOS.h"

@implementation UIScreen (macOS)

- (CGFloat)backingScaleFactor
{
    return self.scale;
}

@end

#endif
