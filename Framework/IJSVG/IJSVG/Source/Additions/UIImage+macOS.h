//
//  UIImage+macOS.h
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#import <TargetConditionals.h>
#if !TARGET_OS_OSX

#import <UIKit/UIKit.h>

@interface UIImage (macOS)

- (instancetype)initWithCGImage:(CGImageRef)image size:(CGSize)size;
- (CGImageRef)CGImageForProposedRect:(CGRect *)proposedDestRect
                             context:(void *)referenceContext
                               hints:(NSDictionary<id, id> *)hints;

@end

#endif
