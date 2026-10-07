//
//  UIImage+macOS.m
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#import <TargetConditionals.h>
#if !TARGET_OS_OSX

#import <UIKit/UIKit.h>
#import "UIImage+macOS.h"
#import "IJSVGXEntities.h"

@implementation UIImage (macOS)

- (instancetype)initWithCGImage:(CGImageRef)image size:(CGSize)size
{
    return [self initWithCGImage:image];
#warning TODO: size
}

- (CGImageRef)CGImageForProposedRect:(XRect *)proposedDestRect
                             context:(void *)referenceContext
                               hints:(NSDictionary<id, id> *)hints
{
    return self.CGImage;
#warning TODO: size and co
}

@end

#endif
