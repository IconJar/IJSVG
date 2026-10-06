//
//  IJSVGParserTextKeywords.m
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGParserTextUtils.h>
#import <IJSVG/IJSVGUtils.h>
#import <string.h>

static IJSVGTextKeyword IJSVGTextKeywordStartingWithA(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "auto") == YES) {
        return IJSVGTextKeywordAuto;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "after-edge") == YES) {
        return IJSVGTextKeywordAfterEdge;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "align") == YES) {
        return IJSVGTextKeywordAlign;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithB(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "bold") == YES) {
        return IJSVGTextKeywordBold;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "bolder") == YES) {
        return IJSVGTextKeywordBolder;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "baseline") == YES) {
        return IJSVGTextKeywordBaseline;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "before-edge") == YES) {
        return IJSVGTextKeywordBeforeEdge;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "break-spaces") == YES) {
        return IJSVGTextKeywordBreakSpaces;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "bidi-override") == YES) {
        return IJSVGTextKeywordBidiOverride;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithC(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "condensed") == YES) {
        return IJSVGTextKeywordCondensed;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "central") == YES) {
        return IJSVGTextKeywordCentral;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "capitalize") == YES) {
        return IJSVGTextKeywordCapitalize;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithE(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "extra-condensed") == YES) {
        return IJSVGTextKeywordExtraCondensed;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "extra-expanded") == YES) {
        return IJSVGTextKeywordExtraExpanded;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "expanded") == YES) {
        return IJSVGTextKeywordExpanded;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "embed") == YES) {
        return IJSVGTextKeywordEmbed;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "end") == YES) {
        return IJSVGTextKeywordEnd;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "exact") == YES) {
        return IJSVGTextKeywordExact;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithG(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "geometricprecision") == YES) {
        return IJSVGTextKeywordGeometricPrecision;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithH(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "horizontal-tb") == YES) {
        return IJSVGTextKeywordHorizontalTB;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "hanging") == YES) {
        return IJSVGTextKeywordHanging;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithI(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "inherit") == YES) {
        return IJSVGTextKeywordInherit;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "initial") == YES) {
        return IJSVGTextKeywordInitial;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "italic") == YES) {
        return IJSVGTextKeywordItalic;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "ideographic") == YES) {
        return IJSVGTextKeywordIdeographic;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "isolate") == YES) {
        return IJSVGTextKeywordIsolate;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "isolate-override") == YES) {
        return IJSVGTextKeywordIsolateOverride;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithL(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "lighter") == YES) {
        return IJSVGTextKeywordLighter;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "larger") == YES) {
        return IJSVGTextKeywordLarger;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "large") == YES) {
        return IJSVGTextKeywordLarge;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "ltr") == YES) {
        return IJSVGTextKeywordLTR;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "lowercase") == YES) {
        return IJSVGTextKeywordLowercase;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "left") == YES) {
        return IJSVGTextKeywordLeft;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "line-through") == YES) {
        return IJSVGTextKeywordLineThrough;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithM(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "medium") == YES) {
        return IJSVGTextKeywordMedium;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "middle") == YES) {
        return IJSVGTextKeywordMiddle;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "mathematical") == YES) {
        return IJSVGTextKeywordMathematical;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "mixed") == YES) {
        return IJSVGTextKeywordMixed;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithN(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "normal") == YES) {
        return IJSVGTextKeywordNormal;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "none") == YES) {
        return IJSVGTextKeywordNone;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "no-common-ligatures") == YES) {
        return IJSVGTextKeywordNoCommonLigatures;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithO(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "on") == YES) {
        return IJSVGTextKeywordOn;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "off") == YES) {
        return IJSVGTextKeywordOff;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "optimizelegibility") == YES) {
        return IJSVGTextKeywordOptimizeLegibility;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "optimizespeed") == YES) {
        return IJSVGTextKeywordOptimizeSpeed;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "oblique") == YES) {
        return IJSVGTextKeywordOblique;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "overline") == YES) {
        return IJSVGTextKeywordOverline;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithP(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "pre") == YES) {
        return IJSVGTextKeywordPre;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "pre-wrap") == YES) {
        return IJSVGTextKeywordPreWrap;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "preserve") == YES) {
        return IJSVGTextKeywordPreserve;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "pre-line") == YES) {
        return IJSVGTextKeywordPreLine;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "plaintext") == YES) {
        return IJSVGTextKeywordPlaintext;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithR(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "rtl") == YES) {
        return IJSVGTextKeywordRTL;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "right") == YES) {
        return IJSVGTextKeywordRight;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithS(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "semi-condensed") == YES) {
        return IJSVGTextKeywordSemiCondensed;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "semi-expanded") == YES) {
        return IJSVGTextKeywordSemiExpanded;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "small-caps") == YES) {
        return IJSVGTextKeywordSmallCaps;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "smaller") == YES) {
        return IJSVGTextKeywordSmaller;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "small") == YES) {
        return IJSVGTextKeywordSmall;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "super") == YES) {
        return IJSVGTextKeywordSuper;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "sub") == YES) {
        return IJSVGTextKeywordSub;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "spacing") == YES) {
        return IJSVGTextKeywordSpacing;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "spacingandglyphs") == YES) {
        return IJSVGTextKeywordSpacingAndGlyphs;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "start") == YES) {
        return IJSVGTextKeywordStart;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "sideways") == YES) {
        return IJSVGTextKeywordSideways;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "stretch") == YES) {
        return IJSVGTextKeywordStretch;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithT(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "text-before-edge") == YES) {
        return IJSVGTextKeywordTextBeforeEdge;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "text-top") == YES) {
        return IJSVGTextKeywordTextTop;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "text-after-edge") == YES) {
        return IJSVGTextKeywordTextAfterEdge;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "text-bottom") == YES) {
        return IJSVGTextKeywordTextBottom;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "tb") == YES) {
        return IJSVGTextKeywordVerticalRL;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "tb-rl") == YES) {
        return IJSVGTextKeywordVerticalRL;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "tb-lr") == YES) {
        return IJSVGTextKeywordVerticalLR;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithU(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "unset") == YES) {
        return IJSVGTextKeywordUnset;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "ultra-condensed") == YES) {
        return IJSVGTextKeywordUltraCondensed;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "ultra-expanded") == YES) {
        return IJSVGTextKeywordUltraExpanded;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "uppercase") == YES) {
        return IJSVGTextKeywordUppercase;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "upright") == YES) {
        return IJSVGTextKeywordUpright;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "underline") == YES) {
        return IJSVGTextKeywordUnderline;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithV(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "vertical-rl") == YES) {
        return IJSVGTextKeywordVerticalRL;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "vertical-lr") == YES) {
        return IJSVGTextKeywordVerticalLR;
    }
    return IJSVGTextKeywordUnspecified;
}

static IJSVGTextKeyword IJSVGTextKeywordStartingWithX(const char* value)
{
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "xx-small") == YES) {
        return IJSVGTextKeywordXXSmall;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "x-small") == YES) {
        return IJSVGTextKeywordXSmall;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "x-large") == YES) {
        return IJSVGTextKeywordXLarge;
    }
    if(IJSVGCharBufferCaseInsensitiveCompare(value, "xx-large") == YES) {
        return IJSVGTextKeywordXXLarge;
    }
    return IJSVGTextKeywordUnspecified;
}

IJSVGTextKeyword IJSVGTextKeywordForString(NSString* value)
{
    const char* characters = value.UTF8String;
    if(characters == NULL || *characters == 0) {
        return IJSVGTextKeywordUnspecified;
    }
    // A null inside the string must not turn an invalid value into a keyword.
    if(strlen(characters) != [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return IJSVGTextKeywordUnspecified;
    }
    // Use the same first character check as the node parser.
    switch(IJSVGCharToLower(characters[0])) {
        case 'a':
            return IJSVGTextKeywordStartingWithA(characters);
        case 'b':
            return IJSVGTextKeywordStartingWithB(characters);
        case 'c':
            return IJSVGTextKeywordStartingWithC(characters);
        case 'e':
            return IJSVGTextKeywordStartingWithE(characters);
        case 'g':
            return IJSVGTextKeywordStartingWithG(characters);
        case 'h':
            return IJSVGTextKeywordStartingWithH(characters);
        case 'i':
            return IJSVGTextKeywordStartingWithI(characters);
        case 'l':
            return IJSVGTextKeywordStartingWithL(characters);
        case 'm':
            return IJSVGTextKeywordStartingWithM(characters);
        case 'n':
            return IJSVGTextKeywordStartingWithN(characters);
        case 'o':
            return IJSVGTextKeywordStartingWithO(characters);
        case 'p':
            return IJSVGTextKeywordStartingWithP(characters);
        case 'r':
            return IJSVGTextKeywordStartingWithR(characters);
        case 's':
            return IJSVGTextKeywordStartingWithS(characters);
        case 't':
            return IJSVGTextKeywordStartingWithT(characters);
        case 'u':
            return IJSVGTextKeywordStartingWithU(characters);
        case 'v':
            return IJSVGTextKeywordStartingWithV(characters);
        case 'x':
            return IJSVGTextKeywordStartingWithX(characters);
        default:
            return IJSVGTextKeywordUnspecified;
    }
}
