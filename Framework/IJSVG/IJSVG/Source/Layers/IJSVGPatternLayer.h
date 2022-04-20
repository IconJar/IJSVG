//
//  IJSVGPatternLayer.h
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGLayer.h>
#import <IJSVG/IJSVGPattern.h>
#import <QuartzCore/QuartzCore.h>

@interface IJSVGPatternLayer : IJSVGLayer

@property (nonatomic, strong) CALayer<IJSVGDrawableLayer>* pattern;
@property (nonatomic, strong) IJSVGPattern* patternNode;

@end
