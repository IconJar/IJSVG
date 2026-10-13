//
//  IJSVGUse.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

#import <IJSVG/IJSVGReference.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGUse : IJSVGGroup <IJSVGReferenceNode>

@property (nonatomic, strong, nullable) IJSVGReference* reference;
@end

NS_ASSUME_NONNULL_END
