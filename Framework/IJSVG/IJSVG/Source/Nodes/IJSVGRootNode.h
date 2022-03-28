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

@property (nonatomic, assign) NSRect viewBox;
@property (nonatomic, retain) IJSVGUnitSize* intrinsicSize;
@property (nonatomic, readonly) CGRect bounds;

@end
