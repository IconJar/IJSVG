//
//  IJSVGImagePaint.h
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGPaint.h>
#import <IJSVG/IJSVGImage.h>

@interface IJSVGImagePaint : IJSVGPaint

@property (nonatomic, strong) IJSVGImage* image;

- (id)initWithImage:(IJSVGImage*)image;

@end
