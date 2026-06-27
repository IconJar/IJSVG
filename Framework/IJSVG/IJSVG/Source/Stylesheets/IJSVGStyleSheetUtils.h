//
//  IJSVGStyleSheetUtils.h
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetSelectorRaw.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

BOOL IJSVGStyleSheetCharIsWhitespace(char aChar);
BOOL IJSVGStyleSheetCharIsCombinator(char aChar);
BOOL IJSVGStyleSheetCharEndsIdentifier(char aChar);
BOOL IJSVGStyleSheetCharIsInvalidSelectorChar(char aChar);

BOOL IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(const char* chars,
                                                    NSUInteger index,
                                                    NSUInteger length);

NSUInteger IJSVGStyleSheetIndexBySkippingWhitespace(const char* chars,
                                                    NSUInteger index,
                                                    NSUInteger length);

IJSVGStyleSheetSelectorCombinator IJSVGStyleSheetCombinatorForChar(char aChar);
NSString* IJSVGStyleSheetCombinatorStringForCombinator(IJSVGStyleSheetSelectorCombinator combinator);

NSString* _Nullable IJSVGStyleSheetStringFromUTF8Bytes(const char* chars,
                                                       NSUInteger start,
                                                       NSUInteger end);

NSString* IJSVGStyleSheetStringByRemovingCSSComments(NSString* string);

BOOL IJSVGStyleSheetSelectorRawHasSimpleSelector(IJSVGStyleSheetSelectorRaw* rawSelector);
BOOL IJSVGStyleSheetSelectorRawHasAnySelector(IJSVGStyleSheetSelectorRaw* rawSelector,
                                              BOOL hasUniversalSelector);

BOOL IJSVGStyleSheetSelectorCommitRawSelector(NSMutableArray<IJSVGStyleSheetSelectorRaw*>* parsedSelectors,
                                              IJSVGStyleSheetSelectorRaw* rawSelector,
                                              BOOL hasUniversalSelector);

IJSVGStyleSheetSelectorRaw* IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinator combinator);

NS_ASSUME_NONNULL_END
