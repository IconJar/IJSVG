//
//  IJSVGStop.h
//  IJSVG
//
//  Created by Curtis Hard on 05/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGPaintNode.h>

@interface IJSVGStop : IJSVGPaintNode

@property (nonatomic, strong, nullable) IJSVGUnitLength* offset;

@end
