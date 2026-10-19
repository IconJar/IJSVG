//
//  IJSVGAnchor.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGReference.h>
#import <IJSVG/IJSVGText.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGAnchor : IJSVGGroup <IJSVGReferenceNode>

@property (nonatomic, strong, nullable) IJSVGReference* reference;
@end

@interface IJSVGTextAnchor : IJSVGText <IJSVGReferenceNode>

@property (nonatomic, strong, nullable) IJSVGReference* reference;
@end

NS_ASSUME_NONNULL_END
