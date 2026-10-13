//
//  IJSVGSymbol.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRootNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGSymbol : IJSVGRootNode
// Optional reference point for an instantiated symbol, in its content
// coordinates.
@property (nonatomic, strong, nullable) IJSVGUnitLength* refX;
@property (nonatomic, strong, nullable) IJSVGUnitLength* refY;

@end

NS_ASSUME_NONNULL_END
