//
//  IJSVGImageLayer.h
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLayer.h>
#import <IJSVG/IJSVGImage.h>
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

@interface IJSVGImageLayer : IJSVGLayer {
    
@private
    IJSVGLayer* _transformLayer;
    IJSVGLayer* _imageLayer;
}

@property (nonatomic, retain) IJSVGImage* image;

- (id)initWithImage:(IJSVGImage*)image;

@end
