//
//  UIImage+macOS.h
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#if __has_include(<UIKit/UIKit.h>)
@import UIKit;

@interface UIImage (macOS)

- (instancetype)initWithCGImage:(CGImageRef)image size:(CGSize)size;
- (CGImageRef)CGImageForProposedRect:(CGRect *)proposedDestRect
                             context:(void *)referenceContext
                               hints:(NSDictionary<id, id> *)hints;

@end

#endif
