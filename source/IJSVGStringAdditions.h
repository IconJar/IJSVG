//
//  IJSVGStringAdditions.h
//  IconJar
//
//  Created by Curtis Hard on 07/06/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (IJSVGAdditions)

- (NSArray<NSString *> *)ijsvg_componentsSeparatedByChars:(char *)aChar;
- (BOOL)ijsvg_isNumeric;
- (BOOL)ijsvg_containsAlpha;
- (NSArray *)ijsvg_componentsSplitByWhiteSpace;

@end
