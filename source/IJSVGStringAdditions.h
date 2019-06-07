//
//  IJSVGStringAdditions.h
//  IconJar
//
//  Created by Curtis Hard on 07/06/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (IJSVGAdditions)

- (NSArray<NSString *> *)componentsSeparatedByChars:(char *)aChar;
- (BOOL)isNumeric;
- (BOOL)containsAlpha;
- (NSArray *)componentsSplitByWhiteSpace;

@end
