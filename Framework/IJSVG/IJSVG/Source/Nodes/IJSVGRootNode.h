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

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGRootNode : IJSVGGroup {
  BOOL _hasCalculatedContainsRelativeUnits;
  BOOL _containsRelativeUnits;
}

@property (nonatomic, assign) CGSize clientSize;
@property (nonatomic, strong, nullable) NSColor* backgroundColor;
@property (nonatomic, assign) BOOL viewBoxWasInferred;
@property (nonatomic, assign) IJSVGIntrinsicDimensions intrinsicDimensions;
@property (nonatomic, strong, nullable) IJSVGUnitSize* intrinsicSize;
@property (nonatomic, readonly) CGRect bounds;

// The document owns style ancestors so paint references cannot form retain cycles.
@property (nonatomic, copy) NSArray<IJSVGNode*>* styleAncestors;

// Optional reference point for an instantiated symbol, in its content coordinates.
@property (nonatomic, strong, nullable) IJSVGUnitLength* refX;
@property (nonatomic, strong, nullable) IJSVGUnitLength* refY;

- (void)inferViewBoxIfRequired;

@end

NS_ASSUME_NONNULL_END
