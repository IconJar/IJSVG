//
//  IJSVGGradientLayer.h
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "IJSVGGradient.h"
#import "IJSVGPath.h"
#import "IJSVGLayer.h"

@interface IJSVGGradientLayer : IJSVGLayer {
    
}

@property (nonatomic, assign) CGRect viewBox;
@property (nonatomic, retain) IJSVGGradient * gradient;

@end
