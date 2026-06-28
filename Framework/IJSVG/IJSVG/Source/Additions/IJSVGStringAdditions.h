//
//  IJSVGStringAdditions.h
//  IconJar
//
//  Created by Curtis Hard on 07/06/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (IJSVGAdditions)

- (NSArray<NSString*>*)ijsvg_componentsSeparatedByChars:(const char*)aChar;
- (NSArray*)ijsvg_componentsSplitByWhiteSpace;
- (BOOL)ijsvg_isHexString;

@end
