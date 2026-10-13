//
//  IJSVGPattern.h
//  IJSVG
//
//  Created by Curtis Hard on 27/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGImage.h>

#import <IJSVG/IJSVGReference.h>

@interface IJSVGPattern : IJSVGGroup <IJSVGReferenceNode>

@property (nonatomic, strong, nullable) IJSVGReference* reference;

@end
