//
//  IJSVGStyleSheetUtils.h
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGStyleSheetSelectorRaw.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IJSVGSelectorPseudoKind) {
    IJSVGSelectorPseudoRoot,
    IJSVGSelectorPseudoScope,
    IJSVGSelectorPseudoEmpty,
    IJSVGSelectorPseudoNth,
    IJSVGSelectorPseudoIs,
    IJSVGSelectorPseudoWhere,
    IJSVGSelectorPseudoNot,
    IJSVGSelectorPseudoHas,
    IJSVGSelectorPseudoLang
};

typedef NS_OPTIONS(uint8_t, IJSVGSelectorPseudoFlags) {
    IJSVGSelectorPseudoFunctional = 1 << 0,
    IJSVGSelectorPseudoOfType = 1 << 1,
    IJSVGSelectorPseudoFromEnd = 1 << 2,
    IJSVGSelectorPseudoOnly = 1 << 3,
    IJSVGSelectorPseudoForgiving = 1 << 4
};
typedef struct {
    IJSVGSelectorPseudoKind kind;
    IJSVGSelectorPseudoFlags flags;
    BOOL valid;
} IJSVGSelectorPseudoDescriptor;

// ASCII lookup ignores case. The span does not need a terminating NUL.
IJSVGSelectorPseudoDescriptor IJSVGSelectorPseudoForBytes(const char* _Nullable bytes, NSUInteger length);

typedef NS_ENUM(uint8_t, IJSVGMediaType) {
    IJSVGMediaTypeAll,
    IJSVGMediaTypeScreen,
    IJSVGMediaTypePrint
};

typedef struct {
    CGSize viewport;
    IJSVGMediaType type;
} IJSVGMediaEnvironment;

typedef struct IJSVGMediaQuery IJSVGMediaQuery;

// The caller owns the immutable query until release.
IJSVGMediaQuery* _Nullable IJSVGMediaQueryCreate(NSString* _Nullable media);
// Bounded UTF8 span with CSS comments already removed. No NUL terminator needed.
IJSVGMediaQuery* _Nullable IJSVGMediaQueryCreateFromCleanBytes(const char* bytes, NSUInteger length);
void IJSVGMediaQueryRelease(IJSVGMediaQuery* _Nullable query);
BOOL IJSVGMediaQueryMatches(const IJSVGMediaQuery* _Nullable query, IJSVGMediaEnvironment environment);

BOOL IJSVGStyleSheetSkipEscape(const char* chars, NSUInteger length, NSUInteger* index, BOOL quoted);
BOOL IJSVGStyleSheetSkipQuotedString(const char* chars, NSUInteger length, NSUInteger* index);

// Consumes one CSS identifier, decoding escapes. Does not skip leading
// whitespace.
NSString* _Nullable IJSVGStyleSheetConsumeIdentifier(const char* chars, NSUInteger length, NSUInteger* index);

// A valid name that cannot fit or is not ASCII produces an empty output.
BOOL IJSVGStyleSheetConsumeASCIIIdentifier(const char* chars, NSUInteger length, NSUInteger* index, char* name, NSUInteger capacity);

BOOL IJSVGStyleSheetCharIsWhitespace(char aChar);
BOOL IJSVGStyleSheetCharIsCombinator(char aChar);
BOOL IJSVGStyleSheetCharEndsIdentifier(char aChar);
BOOL IJSVGStyleSheetCharIsInvalidSelectorChar(char aChar);

BOOL IJSVGStyleSheetSelectorIsColumnCombinatorAtIndex(const char* _Nullable chars, NSUInteger index, NSUInteger length);

NSUInteger IJSVGStyleSheetIndexBySkippingWhitespace(const char* chars, NSUInteger index, NSUInteger length);

IJSVGStyleSheetSelectorCombinator IJSVGStyleSheetCombinatorForChar(char aChar);
NSString* IJSVGStyleSheetCombinatorStringForCombinator(IJSVGStyleSheetSelectorCombinator combinator);

NSString* _Nullable IJSVGStyleSheetStringFromUTF8Bytes(const char* _Nullable chars, NSUInteger start, NSUInteger end);

NSString* _Nullable IJSVGStyleSheetDecodeString(const char* chars, NSUInteger start, NSUInteger end);

BOOL IJSVGStyleSheetConsumeQuotedCharacter(char c, char* quote, BOOL* escaped);
NSRange IJSVGStyleSheetDeclarationRange(const char* chars, NSUInteger length, BOOL* important);
NSString* _Nullable IJSVGStyleSheetDeclarationValue(NSString* value, BOOL* important);
BOOL IJSVGStyleSheetEnumerateFontFamilies(NSString* value, void (^handler)(NSString* family, BOOL quoted));
NSString* IJSVGStyleSheetStringByRemovingCSSComments(NSString* string);
NSString* _Nullable IJSVGStyleSheetResolveDeclaration(NSString* property, NSString* value, NSDictionary<NSString*, NSString*>* _Nullable* _Nonnull expanded);
NSString* _Nullable IJSVGStyleSheetResolveVariableDeclaration(NSString* property, NSString* value, NSDictionary<NSString*, NSString*>* _Nullable* _Nonnull expanded, BOOL* variables);
NSDictionary<NSString*, NSString*>* IJSVGStyleSheetExpandDeclaration(NSString* property, NSString* value);

BOOL IJSVGStyleSheetSelectorRawHasSimpleSelector(IJSVGStyleSheetSelectorRaw* rawSelector);
BOOL IJSVGStyleSheetSelectorRawHasAnySelector(IJSVGStyleSheetSelectorRaw* rawSelector, BOOL hasUniversalSelector);

BOOL IJSVGStyleSheetSelectorCommitRawSelector(NSMutableArray<IJSVGStyleSheetSelectorRaw*>* parsedSelectors, IJSVGStyleSheetSelectorRaw* rawSelector, BOOL hasUniversalSelector);

IJSVGStyleSheetSelectorRaw* IJSVGStyleSheetCreateRawSelector(IJSVGStyleSheetSelectorCombinator combinator);

NS_ASSUME_NONNULL_END
