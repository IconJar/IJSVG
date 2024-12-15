//
//  IJSVGRootNode.h
//  IJSVG
//
//  Created by Curtis Hard on 28/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGUnitSize.h>

@interface IJSVGRootNode : IJSVGGroup

@property (nonatomic, assign) CGSize clientSize;
@property (nonatomic, assign) BOOL viewBoxContainsRelativeUnits;
@property (nonatomic, assign) IJSVGIntrinsicDimensions intrinsicDimensions;
@property (nonatomic, strong) IJSVGUnitSize* intrinsicSize;
@property (nonatomic, readonly) CGRect bounds;

@end
