//
//  IJSVGFilter.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGFilterPrimitive.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGFilter : IJSVGGroup

@property (nonatomic, readonly) NSArray<IJSVGFilterPrimitive*>* primitives;
@property (nonatomic, readonly) NSSet<NSString*>* inputNames;
@property (nonatomic, readonly) BOOL requiresSupersampling;
// Recognised exporter style inner shadows retain the original antialiased coverage.
@property (nonatomic, readonly) BOOL preservesInnerShadowCoverage;

@end

NS_ASSUME_NONNULL_END
