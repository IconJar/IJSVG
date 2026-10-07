//
//  UIScreen+macOS.m
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#import <TargetConditionals.h>
#if !TARGET_OS_OSX

#import <UIKit/UIKit.h>
#import "UIScreen+macOS.h"

@implementation UIScreen (macOS)

- (CGFloat)backingScaleFactor
{
    return self.scale;
}

@end

#endif
