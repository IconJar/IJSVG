//
//  IJSVGMask.h
//  IJSVG
//
//  Created by Curtis Hard on 28/05/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

typedef NS_ENUM(NSUInteger, IJSVGMaskType) {
    IJSVGMaskTypeLuminance,
    IJSVGMaskTypeAlpha
};

@interface IJSVGMask : IJSVGGroup

@property (nonatomic, assign) IJSVGMaskType maskType;

@end
