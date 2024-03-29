//
//  IJSVGGradientLayer.h
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGLayer.h>
#import <IJSVG/IJSVGPath.h>
#import <QuartzCore/QuartzCore.h>

@interface IJSVGGradientLayer : IJSVGLayer {
}

@property (nonatomic, strong) IJSVGGradient* gradient;
@property (nonatomic, assign) CGRect viewBox;

@end

