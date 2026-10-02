//
//  IJSVGPatternPaint.h
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGPaint.h>
#import <IJSVG/IJSVGPattern.h>

@interface IJSVGPatternPaint : IJSVGPaint

@property (nonatomic, strong) IJSVGPattern* patternNode;
@property (nonatomic, strong) IJSVGPaint* pattern;

- (void)computeCellSize:(CGSize*)cellSize
                viewBox:(CGRect*)viewBox
                 origin:(CGPoint*)origin;

@end
