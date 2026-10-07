//
//  IJSVGTextLayout.h
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGText.h>

NS_ASSUME_NONNULL_BEGIN

typedef CGPathRef _Nullable (^IJSVGTextPathResolver)(IJSVGPath* node);

// Immutable layout result. Constructed with the paint tree, never during drawing.
@interface IJSVGTextLayout: NSObject

@property (nonatomic, readonly) IJSVGGroup* group;
@property (nonatomic, readonly) NSString* string;
@property (nonatomic, readonly) NSUInteger glyphCount;
@property (nonatomic, readonly) NSArray<NSValue*>* characterPositions;

// Final rotation of each character in degrees, including rotation along a text path.
@property (nonatomic, readonly) NSArray<NSNumber*>* characterRotations;
@property (nonatomic, readonly) CGFloat advance;

- (instancetype)initWithText:(IJSVGText*)text
                    viewport:(CGSize)viewport
                pathResolver:(nullable IJSVGTextPathResolver)pathResolver;

- (instancetype)initWithText:(IJSVGText*)text
                    viewport:(CGSize)viewport
                 renderScale:(CGFloat)renderScale
                pathResolver:(nullable IJSVGTextPathResolver)pathResolver;

@end

NS_ASSUME_NONNULL_END
