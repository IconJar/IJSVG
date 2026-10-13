//
//  IJSVGGlyph.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGGlyph : IJSVGGroup
@property (nonatomic, copy, nullable) NSString* unicode;

@end

NS_ASSUME_NONNULL_END
