//
//  IJSVGTextFontResolver.h
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGText.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGTextFontResolver: NSObject

@property (nonatomic, assign) CGFloat renderScale;

- (BOOL)usesNativeSpacingForFont:(id)font;

- (id)fontForValues:(NSDictionary<NSString*, IJSVGTextAttributeValue*>*)values
               size:(CGFloat)size;

@end

NS_ASSUME_NONNULL_END
