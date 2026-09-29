//
//  IJSVGFilter.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGFilterPrimitive.h>

@interface IJSVGFilter : IJSVGGroup

@property (nonatomic, readonly) NSArray<IJSVGFilterPrimitive*>* primitives;
@property (nonatomic, readonly) NSSet<NSString*>* inputNames;
@property (nonatomic, readonly) BOOL requiresSupersampling;

@end
