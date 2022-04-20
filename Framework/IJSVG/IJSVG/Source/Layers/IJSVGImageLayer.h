//
//  IJSVGImageLayer.h
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLayer.h>
#import <IJSVG/IJSVGImage.h>
#import <IJSVG/IJSVGTransformLayer.h>
#import <IJSVG/IJSVGBasicLayer.h>
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

@interface IJSVGImageLayer : IJSVGLayer {
    
@private
    CALayer* _imageLayer;
}

@property (nonatomic, strong) IJSVGImage* image;

- (id)initWithImage:(IJSVGImage*)image;

@end
