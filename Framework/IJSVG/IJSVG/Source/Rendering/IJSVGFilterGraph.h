//
//  IJSVGFilterGraph.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilter.h>
#import <CoreImage/CoreImage.h>

@interface IJSVGFilterGraph : NSObject

@property (nonatomic, strong) IJSVGFilter* filter;
@property (nonatomic, assign) CGRect boundingBox;
@property (nonatomic, assign) CGRect viewPort;
@property (nonatomic, assign) CGRect extent;
@property (nonatomic, assign) CGAffineTransform imageTransform;
@property (nonatomic, strong) CIContext* context;
@property (nonatomic, copy) CIImage* (^imageProvider)(IJSVGFilterPrimitive* primitive, CGRect region);
@property (nonatomic, copy) CIImage* (^paintProvider)(BOOL stroke);
@property (nonatomic, copy) CIImage* (^backgroundProvider)(void);

- (CGRect)regionForNode:(IJSVGNode*)node
                  units:(IJSVGUnitType)units
          defaultRegion:(CGRect)region;
- (CIImage*)imageByFilteringSource:(CIImage*)source;

@end
