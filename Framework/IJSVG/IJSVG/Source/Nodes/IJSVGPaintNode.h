//
//  IJSVGPaintNode.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGPaintNode : IJSVGNode

@property (nonatomic, strong, nullable) IJSVGUnitLength* fillOpacity;
@property (nonatomic, strong, nullable) IJSVGNode* fill;

@end

NS_ASSUME_NONNULL_END
