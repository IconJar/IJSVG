//
//  IJSVGLayerTree.h
//  IJSVGExample
//
//  Created by Curtis Hard on 29/12/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGStyle.h>
#import <QuartzCore/QuartzCore.h>

@class IJSVGLayer;
@class IJSVGRootLayer;
@class IJSVGRootNode;

@interface IJSVGLayerTree : NSObject {
@private
    NSMutableArray<NSValue*>* _viewPortStack;
}

@property (nonatomic, assign) CGRect viewBox;
@property (nonatomic, assign) CGFloat backingScale;
@property (nonatomic, strong) IJSVGStyle* style;

- (IJSVGRootLayer*)rootLayerForRootNode:(IJSVGRootNode*)rootNode;

@end
