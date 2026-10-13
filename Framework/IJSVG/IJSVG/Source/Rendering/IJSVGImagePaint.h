//
//  IJSVGImagePaint.h
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGImage.h>
#import <IJSVGPaint.h>

@interface IJSVGImagePaint : IJSVGPaint

@property (nonatomic, strong) IJSVGImage* image;

- (id)initWithImage:(IJSVGImage*)image;

@end
