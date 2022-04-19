//
//  IJSVGFilterLayer.h
//  IJSVG
//
//  Created by Curtis Hard on 19/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLayer.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGBasicLayer.h>

@interface IJSVGFilterLayer : IJSVGLayer {
    
@private
    IJSVGBasicLayer* _hostingLayer;
    CGImageRef _image;
    
}

@property (nonatomic, retain) CALayer<IJSVGDrawableLayer>* sublayer;

@end
