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
- (instancetype)initWithSize:(CGSize)size;
- (void)lockFocus;
- (void)unlockFocus;
- (CGImageRef)CGImageForProposedRect:(CGRect *)proposedDestRect
                             context:(void *)referenceContext
                               hints:(NSDictionary<id, id> *)hints;
- (void)drawInRect:(CGRect)rect
          fromRect:(CGRect)fromRect
         operation:(CGBlendMode)op
          fraction:(CGFloat)delta;

@end

#endif
