//
//  IJSVGTextTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <CoreText/CoreText.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGText.h>
#import <IJSVG/IJSVGTextLayout.h>
#import <IJSVGTextPathMetrics.h>
#import <IJSVGTextGlyphUtils.h>
#import <IJSVGParserTextUtils.h>

@interface IJSVGTextTests: XCTestCase

@property (nonatomic, strong) IJSVGRootNode* parsedRoot;

@end

@implementation IJSVGTextTests

- (void)testAutomaticKerningHonoursRenderingPreference
{
    IJSVGTextLayout* automatic = [self layout:@"<text font-family='Times' font-size='30'>AVATAR</text>"];
    IJSVGTextLayout* normal = [self layout:@"<text font-family='Times' font-size='30' font-kerning='normal'>AVATAR</text>"];
    IJSVGTextLayout* disabled = [self layout:@"<text font-family='Times' font-size='30' font-kerning='none'>AVATAR</text>"];
    IJSVGTextLayout* speed = [self layout:@"<text font-family='Times' font-size='30' text-rendering='optimizeSpeed'>AVATAR</text>"];
    IJSVGTextLayout* explicit = [self layout:@"<text font-family='Times' font-size='30' text-rendering='optimizeSpeed' "
                                              "font-kerning='normal'>AVATAR</text>"];
    XCTAssertLessThan(automatic.advance, disabled.advance);
    XCTAssertEqualWithAccuracy(automatic.advance, normal.advance, .00001);
    XCTAssertEqualWithAccuracy(speed.advance, disabled.advance, .00001);
    XCTAssertEqualWithAccuracy(explicit.advance, normal.advance, .00001);
}

- (void)testSyntheticSmallCapsPreserveCharacterMapping
{
    for(NSString* scope in @[@"", @"unicode-bidi='isolate'"]) {
        NSString* body = [NSString stringWithFormat:@"<text font-family='Times' font-size='20' %@ "
                                                     "font-variant='small-caps'>Aßb</text>", scope];
        IJSVGTextLayout* actual = [self layout:body];
        IJSVGTextLayout* expected = [self layout:@"<text font-family='Times' font-size='20'>"
                                                 "A<tspan font-size='14'>SSB</tspan></text>"];
        XCTAssertEqual(actual.characterPositions.count, 3);
        XCTAssertEqualWithAccuracy(actual.advance, expected.advance, .00001);
        XCTAssertEqualWithAccuracy(actual.characterPositions[2].pointValue.x,
                                   expected.characterPositions[3].pointValue.x, .00001);
    }
}

- (void)testSmallCapsInheritanceAndNormalOverride
{
    IJSVGTextLayout* actual = [self layout:@"<g font-family='Times' font-size='20' font-variant='small-caps'>"
                                             "<text>a<tspan>b</tspan><tspan font-variant='normal'>c</tspan></text></g>"];
    IJSVGTextLayout* expected = [self layout:@"<text font-family='Times' font-size='20'>"
                                               "<tspan font-size='14'>AB</tspan>c</text>"];
    XCTAssertEqualWithAccuracy(actual.advance, expected.advance, .00001);
    XCTAssertEqualObjects(actual.characterPositions, expected.characterPositions);
}

- (void)testFontSizeAdjustInheritanceAndReset
{
    IJSVGTextLayout* adjusted = [self layout:@"<text font-family='Times' font-size='20' font-size-adjust='.7'>xxx</text>"];
    IJSVGTextLayout* plain = [self layout:@"<text font-family='Times' font-size='20'>xxx</text>"];
    XCTAssertGreaterThan(adjusted.advance, plain.advance);
    IJSVGTextLayout* shorthand = [self layout:@"<g font-size-adjust='.7'>"
                                                "<text style='font:20px Times'>xxx</text></g>"];
    XCTAssertEqualWithAccuracy(shorthand.advance, plain.advance, .00001);
    IJSVGTextLayout* inherited = [self layout:@"<g style='font:20px Times;font-size-adjust:.7'>"
                                                "<text style='font:inherit'>xxx</text></g>"];
    XCTAssertEqualWithAccuracy(inherited.advance, adjusted.advance, .00001);
    for(NSString* value in @[@"inherit", @"unset", @"invalid", @"normal", @"-1", @"NaN", @"1px"]) {
        NSString* body = [NSString stringWithFormat:@"<g font-family='Times' font-size='20' font-size-adjust='.7'>"
                                                     "<text font-size-adjust='%@'>xxx</text></g>", value];
        XCTAssertEqualWithAccuracy([self layout:body].advance, adjusted.advance, .00001);
    }
    for(NSString* value in @[@"none", @"initial"]) {
        NSString* body = [NSString stringWithFormat:@"<g font-family='Times' font-size='20' font-size-adjust='.7'>"
                                                     "<text font-size-adjust='%@'>xxx</text></g>", value];
        XCTAssertEqualWithAccuracy([self layout:body].advance, plain.advance, .00001);
    }
}

- (void)testExPositionsUseFontMetricsAtEveryRenderScale
{
    CGSize viewport = CGSizeMake(400, 200);
    IJSVGText* text = [self textWithBody:@"<text font-family='Helvetica' font-size='40' x='2ex' y='3em'>"
                                          "A</text>"];
    for(NSUInteger scale = 1; scale <= 3; scale++) {
        CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), 40 * scale,
                                              NULL);
        CGFloat xHeight = CTFontGetXHeight(font) / scale;
        IJSVGTextLayout* layout = [[IJSVGTextLayout alloc] initWithText:text
                                                               viewport:viewport
                                                            renderScale:scale
                                                           pathResolver:nil];
        CGPoint point = layout.characterPositions.firstObject.pointValue;
        XCTAssertEqualWithAccuracy(point.x, xHeight * 2, .00001);
        XCTAssertEqualWithAccuracy(point.y, 120, .00001);
        CFRelease(font);
    }
}

- (void)testExFontSizeWithZeroParentStaysZero
{
    IJSVGTextLayout* layout = [self layout:@"<text font-size='0'><tspan font-size='2ex'>A</tspan></text>"];
    XCTAssertTrue(CGRectIsEmpty(layout.group.bounds));
}

- (void)testExFontSizeUsesTheParentFont
{
    CTFontRef parentFont = CTFontCreateWithName(CFSTR("Helvetica"), 40, NULL);
    CGFloat size = CTFontGetXHeight(parentFont) * 2;
    IJSVGTextLayout* layout = [self layout:@"<g font-family='Helvetica' font-size='40'><text "
                                            "font-family='Times' font-size='2ex' x='1em' y='60'>A</text>"
                                            "</g>"];
    XCTAssertEqualWithAccuracy(layout.characterPositions.firstObject.pointValue.x,
                               size, .00001);
    CFRelease(parentFont);
}

- (void)testExSpacingAndTextLengthMatchResolvedLengths
{
    CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), 40, NULL);
    CGFloat xHeight = CTFontGetXHeight(font);
    NSString* resolved = [NSString stringWithFormat:@"<text font-family='Helvetica' font-size='40' "
                                                     "x='%.9f' y='120' dx='%.9f' dy='%.9f' "
                                                     "letter-spacing='%.9f' word-spacing='%.9f' "
                                                     "baseline-shift='%.9f' textLength='%.9f'>A B</text>",
                                                    2 * xHeight,
                                                    xHeight,
                                                    -xHeight,
                                                    .5 * xHeight,
                                                    .25 * xHeight,
                                                    .5 * xHeight,
                                                    10 * xHeight];
    IJSVGTextLayout* expected = [self layout:resolved];
    IJSVGTextLayout* actual = [self layout:@"<text font-family='Helvetica' font-size='40' x='2ex' "
                                            "y='3em' dx='1ex' dy='-1ex' letter-spacing='.5ex' "
                                            "word-spacing='.25ex' baseline-shift='.5ex' "
                                            "textLength='10ex'>A B</text>"];
    XCTAssertEqual(actual.characterPositions.count,
                   expected.characterPositions.count);
    for(NSUInteger index = 0; index < expected.characterPositions.count; index++) {
        CGPoint a = actual.characterPositions[index].pointValue;
        CGPoint b = expected.characterPositions[index].pointValue;
        XCTAssertEqualWithAccuracy(a.x, b.x, .00001);
        XCTAssertEqualWithAccuracy(a.y, b.y, .00001);
    }
    CFRelease(font);
}

- (void)testTextKeywordMatching
{
    NSDictionary<NSString*, NSNumber*>* keywords = @{
        @"inherit": @(IJSVGTextKeywordInherit),
        @"unset": @(IJSVGTextKeywordUnset),
        @"initial": @(IJSVGTextKeywordInitial),
        @"normal": @(IJSVGTextKeywordNormal),
        @"on": @(IJSVGTextKeywordOn),
        @"off": @(IJSVGTextKeywordOff),
        @"ultra-condensed": @(IJSVGTextKeywordUltraCondensed),
        @"extra-condensed": @(IJSVGTextKeywordExtraCondensed),
        @"semi-condensed": @(IJSVGTextKeywordSemiCondensed),
        @"semi-expanded": @(IJSVGTextKeywordSemiExpanded),
        @"extra-expanded": @(IJSVGTextKeywordExtraExpanded),
        @"ultra-expanded": @(IJSVGTextKeywordUltraExpanded),
        @"none": @(IJSVGTextKeywordNone),
        @"auto": @(IJSVGTextKeywordAuto),
        @"geometricprecision": @(IJSVGTextKeywordGeometricPrecision),
        @"optimizelegibility": @(IJSVGTextKeywordOptimizeLegibility),
        @"optimizespeed": @(IJSVGTextKeywordOptimizeSpeed),
        @"italic": @(IJSVGTextKeywordItalic),
        @"oblique": @(IJSVGTextKeywordOblique),
        @"bold": @(IJSVGTextKeywordBold),
        @"bolder": @(IJSVGTextKeywordBolder),
        @"lighter": @(IJSVGTextKeywordLighter),
        @"small-caps": @(IJSVGTextKeywordSmallCaps),
        @"condensed": @(IJSVGTextKeywordCondensed),
        @"expanded": @(IJSVGTextKeywordExpanded),
        @"smaller": @(IJSVGTextKeywordSmaller),
        @"larger": @(IJSVGTextKeywordLarger),
        @"xx-small": @(IJSVGTextKeywordXXSmall),
        @"x-small": @(IJSVGTextKeywordXSmall),
        @"small": @(IJSVGTextKeywordSmall),
        @"medium": @(IJSVGTextKeywordMedium),
        @"large": @(IJSVGTextKeywordLarge),
        @"x-large": @(IJSVGTextKeywordXLarge),
        @"xx-large": @(IJSVGTextKeywordXXLarge),
        @"ltr": @(IJSVGTextKeywordLTR),
        @"rtl": @(IJSVGTextKeywordRTL),
        @"horizontal-tb": @(IJSVGTextKeywordHorizontalTB),
        @"vertical-rl": @(IJSVGTextKeywordVerticalRL),
        @"vertical-lr": @(IJSVGTextKeywordVerticalLR),
        @"super": @(IJSVGTextKeywordSuper),
        @"sub": @(IJSVGTextKeywordSub),
        @"baseline": @(IJSVGTextKeywordBaseline),
        @"middle": @(IJSVGTextKeywordMiddle),
        @"central": @(IJSVGTextKeywordCentral),
        @"hanging": @(IJSVGTextKeywordHanging),
        @"text-before-edge": @(IJSVGTextKeywordTextBeforeEdge),
        @"before-edge": @(IJSVGTextKeywordBeforeEdge),
        @"text-top": @(IJSVGTextKeywordTextTop),
        @"text-after-edge": @(IJSVGTextKeywordTextAfterEdge),
        @"after-edge": @(IJSVGTextKeywordAfterEdge),
        @"ideographic": @(IJSVGTextKeywordIdeographic),
        @"text-bottom": @(IJSVGTextKeywordTextBottom),
        @"mathematical": @(IJSVGTextKeywordMathematical),
        @"pre": @(IJSVGTextKeywordPre),
        @"pre-wrap": @(IJSVGTextKeywordPreWrap),
        @"break-spaces": @(IJSVGTextKeywordBreakSpaces),
        @"preserve": @(IJSVGTextKeywordPreserve),
        @"pre-line": @(IJSVGTextKeywordPreLine),
        @"uppercase": @(IJSVGTextKeywordUppercase),
        @"lowercase": @(IJSVGTextKeywordLowercase),
        @"capitalize": @(IJSVGTextKeywordCapitalize),
        @"no-common-ligatures": @(IJSVGTextKeywordNoCommonLigatures),
        @"embed": @(IJSVGTextKeywordEmbed),
        @"bidi-override": @(IJSVGTextKeywordBidiOverride),
        @"isolate": @(IJSVGTextKeywordIsolate),
        @"isolate-override": @(IJSVGTextKeywordIsolateOverride),
        @"plaintext": @(IJSVGTextKeywordPlaintext),
        @"spacing": @(IJSVGTextKeywordSpacing),
        @"spacingandglyphs": @(IJSVGTextKeywordSpacingAndGlyphs),
        @"start": @(IJSVGTextKeywordStart),
        @"end": @(IJSVGTextKeywordEnd),
        @"left": @(IJSVGTextKeywordLeft),
        @"right": @(IJSVGTextKeywordRight),
        @"mixed": @(IJSVGTextKeywordMixed),
        @"upright": @(IJSVGTextKeywordUpright),
        @"sideways": @(IJSVGTextKeywordSideways),
        @"align": @(IJSVGTextKeywordAlign),
        @"stretch": @(IJSVGTextKeywordStretch),
        @"exact": @(IJSVGTextKeywordExact),
        @"underline": @(IJSVGTextKeywordUnderline),
        @"overline": @(IJSVGTextKeywordOverline),
        @"line-through": @(IJSVGTextKeywordLineThrough),
        @"tb": @(IJSVGTextKeywordVerticalRL),
        @"tb-rl": @(IJSVGTextKeywordVerticalRL),
        @"tb-lr": @(IJSVGTextKeywordVerticalLR)
    };
    for(NSString* keyword in keywords) {
        IJSVGTextKeyword expected = keywords[keyword].unsignedIntegerValue;
        XCTAssertEqual(IJSVGTextKeywordForString(keyword), expected);
        XCTAssertEqual(IJSVGTextKeywordForString(keyword.uppercaseString),
                       expected);
        XCTAssertEqual(IJSVGTextKeywordForString(keyword.capitalizedString),
                       expected);
        XCTAssertEqual(IJSVGTextKeywordForString([keyword stringByAppendingString:@"?"]),
                       IJSVGTextKeywordUnspecified);
    }
    XCTAssertEqual(IJSVGTextKeywordForString(@""), IJSVGTextKeywordUnspecified);
    XCTAssertEqual(IJSVGTextKeywordForString(@" normal"),
                   IJSVGTextKeywordUnspecified);
    XCTAssertEqual(IJSVGTextKeywordForString(@"normal "),
                   IJSVGTextKeywordUnspecified);
    XCTAssertEqual(IJSVGTextKeywordForString(@"未知"),
                   IJSVGTextKeywordUnspecified);
    unichar characters[] = { 'b', 'o', 'l', 'd', 0, 'x' };
    NSString* embeddedNull = [[NSString alloc] initWithCharacters:characters
                                                           length:6];
    XCTAssertEqual(IJSVGTextKeywordForString(embeddedNull),
                   IJSVGTextKeywordUnspecified);
}

- (void)testGenericTextFamiliesUseParserMatching
{
    NSString* value = @"'SERIF', \"Sans-Serif\", MONOSPACE, CuRsIvE, Fantasy, SYSTEM-UI, '日本語フォント', "
                       "'Custom Family'";
    IJSVGTextAttributeValue* parsed = IJSVGParseTextAttribute(value,
                                                              IJSVGNodeAttributeFontFamily);
    NSArray<NSString*>* expected = @[@"SERIF", @"Sans-Serif", @"Courier", @"Apple Chancery",
                                     @"Papyrus", @".AppleSystemUIFont", @"日本語フォント", @"Custom Family"];
    XCTAssertEqualObjects(parsed.families, expected);
}

- (IJSVGText*)textWithBody:(NSString*)body
{
    CGSize viewport = CGSizeMake(400, 200);
    NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 "
                                                "400 200'>%@</svg>",
                                               body];
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml
                                                         fileURL:nil
                                                           error:nil];
    self.parsedRoot = [parser rootNodeWithSize:viewport];
    __block IJSVGText* text = nil;
    [IJSVGNode walkNodeTree:self.parsedRoot
                    handler:^(IJSVGNode* node, BOOL* descend, BOOL* stop) {
                        if([node isKindOfClass:IJSVGText.class]) {
                            text = (IJSVGText*)node;
                            *stop = YES;
                        }
                    }];
    XCTAssertNotNil(text);
    return text;
}

- (IJSVGTextLayout*)layout:(NSString*)body
{
    CGSize viewport = CGSizeMake(400, 200);
    return [[IJSVGTextLayout alloc] initWithText:[self textWithBody:body]
                                        viewport:viewport
                                    pathResolver:^CGPathRef(IJSVGPath* path) {
            CGAffineTransform transform = IJSVGConcatTransforms(path.transforms);
            return CGPathCreateCopyByTransformingPath(path.path, &transform);
        }];
}

- (NSData*)pixels:(NSString*)body
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:[NSString stringWithFormat:@"<svg "
                                                                              "xmlns='http://www.w3.org/"
                                                                              "2000/svg' viewBox='0 0 "
                                                                              "240 80'>%@</svg>",
                                                                             body]];
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    CGContextRef context = CGBitmapContextCreate(NULL, 480, 160, 8, 480 * 4,
                                                 space, bitmapInfo);
    CGColorSpaceRelease(space);
    CGContextTranslateCTM(context, 0, 160);
    CGContextScaleCTM(context, 1, -1);
    [svg drawInRect:CGRectMake(0, 0, 480, 160)
            context:context];
    NSData* result = [NSData dataWithBytes:CGBitmapContextGetData(context)
                                    length:480 * 160 * 4];
    CGContextRelease(context);
    return result;
}

- (void)testMixedContentPreservesStringsCDATAAndSpans
{
    CGSize viewport = CGSizeMake(400, 200);
    IJSVGText* text = [self textWithBody:@"<text>A<![CDATA[B]]><tspan>C</tspan>D<title>ignored</title>"
                                          "</text>"];
    XCTAssertEqual(text.children.count, 1);
    IJSVGTextLayout* layout = [[IJSVGTextLayout alloc] initWithText:text
                                                           viewport:viewport
                                                       pathResolver:nil];
    XCTAssertEqualObjects(layout.string, @"ABCD");
    XCTAssertEqual(layout.glyphCount, 4);
    IJSVGText* copy = text.copy;
    XCTAssertNotEqual(copy.children.firstObject, text.children.firstObject);
    IJSVGTextLayout* copied = [[IJSVGTextLayout alloc] initWithText:copy
                                                           viewport:viewport
                                                       pathResolver:nil];
    XCTAssertEqualObjects(copied.string, layout.string);
}

- (void)testWhitespaceAndSupplementaryCharactersAcrossSpans
{
    IJSVGTextLayout* layout = [self layout:@"<text>  A\t  <tspan> \n😀é </tspan>  B  </text>"];
    XCTAssertEqualObjects(layout.string, @"A 😀é B");
    XCTAssertEqual(layout.characterPositions.count, 7);
    IJSVGTextLayout* explicit = [self layout:@"<text>A 😀é B</text>"];
    XCTAssertEqualObjects(layout.characterPositions,
                          explicit.characterPositions);
}

- (void)testTextBoundingBoxIncludesGlyphCells
{
    IJSVGTextLayout* layout = [self layout:@"<text x='20' y='60' font-family='Verdana' font-size='24' "
                                            "font-kerning='none'> A </text>"];
    IJSVGTextLayout* preserved = [self layout:@"<text x='20' y='60' font-family='Verdana' font-size='24' "
                                               "font-kerning='none' xml:space='preserve'> A </text>"];
    CTFontRef font = CTFontCreateWithName(CFSTR("Verdana"), 24, NULL);
    XCTAssertEqualWithAccuracy(CGRectGetMinY(layout.boundingBox),
                               60 - CTFontGetAscent(font), .00001);
    XCTAssertEqualWithAccuracy(CGRectGetMaxY(layout.boundingBox),
                               60 + CTFontGetDescent(font), .00001);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(preserved.boundingBox), 20, .00001);
    XCTAssertEqualWithAccuracy(preserved.boundingBox.size.width, preserved.advance, .00001);
    XCTAssertGreaterThan(preserved.boundingBox.size.width, layout.boundingBox.size.width);
    XCTAssertGreaterThan(layout.boundingBox.size.height, layout.group.bounds.size.height);
    CFRelease(font);
}

- (void)testAutomaticAlignmentUsesDominantBaseline
{
    for(NSString* baseline in @[@"hanging", @"middle", @"central", @"mathematical"]) {
        NSString* format = @"<text x='10' y='60' font-size='24' dominant-baseline='%@' %@>ABC</text>";
        IJSVGTextLayout* expected = [self layout:[NSString stringWithFormat:format, baseline, @""]];
        for(NSString* alignment in @[@"auto", @"baseline"]) {
            NSString* attribute = [NSString stringWithFormat:@"alignment-baseline='%@'", alignment];
            IJSVGTextLayout* actual = [self layout:[NSString stringWithFormat:format, baseline, attribute]];
            XCTAssertEqualObjects(actual.characterPositions, expected.characterPositions);
            XCTAssertTrue(CGRectEqualToRect(actual.group.bounds, expected.group.bounds));
        }
    }
}

- (void)testUnstyledSpansResetNonInheritedTextProperties
{
    IJSVGTextLayout* layout = [self layout:@"<text font-size='24' baseline-shift='super'>A<tspan>"
                                            "B</tspan></text>"];
    IJSVGTextLayout* explicit = [self layout:@"<text font-size='24' baseline-shift='super'>A<tspan "
                                              "baseline-shift='baseline'>B</tspan></text>"];
    XCTAssertEqualObjects(layout.characterPositions,
                          explicit.characterPositions);
    XCTAssertTrue(CGRectEqualToRect(layout.group.bounds, explicit.group.bounds));
}

- (void)testCharacterPositionsAreCachedForConcurrentReaders
{
    NSString* body = @"<text x='10' y='30'>A😀<tspan dx='5'>BC</tspan></text>";
    IJSVGTextLayout* layout = [self layout:body];
    NSArray<NSValue*>* expected = [self layout:body].characterPositions;
    dispatch_apply(32, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
                   ^(size_t index) {
        XCTAssertEqualObjects(layout.characterPositions, expected);
    });
    NSArray<NSValue*>* positions = layout.characterPositions;
    XCTAssertTrue(positions == layout.characterPositions);
    XCTAssertFalse([positions isKindOfClass:NSMutableArray.class]);
}

- (void)testEmptyLayoutHasEmptyCharacterPositions
{
    IJSVGTextLayout* layout = [self layout:@"<text/>"];
    XCTAssertEqual(layout.characterPositions.count, 0);
    XCTAssertEqual(layout.glyphCount, 0);
}

- (void)testCharacterBufferGrowthPreservesSupplementaryCharacters
{
    NSMutableString* content = [NSMutableString string];
    for(NSUInteger index = 0; index < 257; index++) {
        [content appendString:@"A😀 "];
    }
    NSString* body = [NSString stringWithFormat:@"<text xml:space='preserve'>%@</text>",
                                                content];
    IJSVGTextLayout* layout = [self layout:body];
    XCTAssertEqualObjects(layout.string, content);
    NSArray<NSValue*>* positions = layout.characterPositions;
    XCTAssertEqual(positions.count, 771);
    XCTAssertGreaterThan(layout.glyphCount, 0);
    for(NSUInteger index = 3; index < positions.count; index += 3) {
        XCTAssertGreaterThan(positions[index].pointValue.x,
                             positions[index - 3].pointValue.x);
    }
}

- (void)testFontStretchKeywordsRequireExactMatches
{
    NSDictionary<NSString*, NSNumber*>* keywords = @{
        @"ultra-condensed": @(IJSVGTextKeywordUltraCondensed),
        @"extra-condensed": @(IJSVGTextKeywordExtraCondensed),
        @"semi-condensed": @(IJSVGTextKeywordSemiCondensed),
        @"semi-expanded": @(IJSVGTextKeywordSemiExpanded),
        @"extra-expanded": @(IJSVGTextKeywordExtraExpanded),
        @"ultra-expanded": @(IJSVGTextKeywordUltraExpanded),
        @"not-condensed": @(IJSVGTextKeywordUnspecified),
        @"expanded-invalid": @(IJSVGTextKeywordUnspecified)
    };
    for(NSString* value in keywords) {
        IJSVGText* text = [self textWithBody:[NSString stringWithFormat:@"<text font-stretch='%@'>"
                                                                         "AB</text>",
                                                                        value]];
        XCTAssertEqual(text.textStyle[IJSVGAttributeFontStretch].keyword,
                       keywords[value].unsignedIntegerValue);
    }
}

- (void)testOpenTypeSettingsAndKeywordLists
{
    IJSVGText* text = [self textWithBody:@"<text font-feature-settings=\"'liga' off, 'kern' on, 'salt' "
                                          "2\" font-variant-ligatures='no-common-ligatures contextual' "
                                          "text-decoration='underline overline line-through'>AB</text>"];
    XCTAssertEqualObjects(text.textStyle[IJSVGAttributeFontFeatureSettings].features,
                          (@{@"liga": @0, @"kern": @1, @"salt": @2}));
    XCTAssertEqual(text.textStyle[IJSVGAttributeFontVariantLigatures].keyword,
                   IJSVGTextKeywordNoCommonLigatures);
    XCTAssertEqual(text.textStyle[IJSVGAttributeTextDecoration].decorations,
                   IJSVGTextDecorationUnderline | IJSVGTextDecorationOverline |
                       IJSVGTextDecorationLineThrough);
}

- (void)testUnavailableFontFallsBackToNextFamily
{
    NSData* expected = [self pixels:@"<text x='10' y='50' font-family='Helvetica' font-size='30' "
                                     "font-weight='bold'>Fallback</text>"];
    NSData* actual = [self pixels:@"<text x='10' y='50' font-family='IJSVG Missing Font Alpha, "
                                   "Helvetica' font-size='30' font-weight='bold'>Fallback</text>"];
    XCTAssertEqualObjects(actual, expected);
}

- (void)testUnavailableFontListFallsBackToDefault
{
    NSData* expected = [self pixels:@"<text x='10' y='50' font-size='30'>Fallback</text>"];
    NSData* actual = [self pixels:@"<text x='10' y='50' font-size='30' font-family='IJSVG Missing Font "
                                   "Alpha, IJSVG Missing Font Beta'>Fallback</text>"];
    XCTAssertEqualObjects(actual, expected);
}

- (void)testFirstAvailableFontWins
{
    NSData* expected = [self pixels:@"<text x='10' y='50' font-size='30' font-family='Helvetica'>Family "
                                     "order</text>"];
    NSData* actual = [self pixels:@"<text x='10' y='50' font-size='30' font-family='Helvetica, Courier'>"
                                   "Family order</text>"];
    XCTAssertEqualObjects(actual, expected);
}

- (NSData*)pixelsForSVG:(IJSVG*)svg
                  scale:(CGFloat)scale
{
    size_t width = 240 * scale;
    size_t height = 80 * scale;
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8,
                                                 width * 4, space, bitmapInfo);
    CGColorSpaceRelease(space);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, scale, -scale);
    [svg drawInRect:CGRectMake(0, 0, 240, 80)
            context:context];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(context)
                                    length:width * height * 4];
    CGContextRelease(context);
    return pixels;
}

- (void)testCachedTextRebuildsWhenDeviceScaleChanges
{
    NSString* source = @"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 240 80'><text x='10' "
                        "y='50' font-family='system-ui' font-size='28'>System font</text></svg>";
    IJSVG* reused = [[IJSVG alloc] initWithSVGString:source];
    for(NSNumber* scale in @[@1, @2, @3, @1]) {
        IJSVG* fresh = [[IJSVG alloc] initWithSVGString:source];
        XCTAssertEqualObjects([self pixelsForSVG:reused
                                           scale:scale.doubleValue],
                              [self pixelsForSVG:fresh
                                           scale:scale.doubleValue]);
    }
}

- (void)testGeometricPrecisionKeepsSVGFontMetricsAcrossScales
{
    CGSize viewport = CGSizeMake(400, 200);
    IJSVGText* text = [self textWithBody:@"<g text-rendering='geometricPrecision'><text "
                                          "font-family='system-ui' font-size='32'>System font</text></g>"];
    IJSVGTextLayout* normal = [[IJSVGTextLayout alloc] initWithText:text
                                                           viewport:viewport
                                                        renderScale:1
                                                       pathResolver:nil];
    IJSVGTextLayout* retina = [[IJSVGTextLayout alloc] initWithText:text
                                                           viewport:viewport
                                                        renderScale:2
                                                       pathResolver:nil];
    XCTAssertEqualObjects(normal.characterPositions, retina.characterPositions);
    XCTAssertTrue(CGRectEqualToRect(normal.group.bounds, retina.group.bounds));
}

- (void)testSystemFontAutomaticSpacingUsesNativeMetrics
{
    IJSVGTextLayout* automatic = [self layout:@"<text font-family='system-ui' font-size='32'>System AV "
                                               "To</text>"];
    IJSVGTextLayout* normal = [self layout:@"<text font-family='system-ui' font-size='32' "
                                            "font-kerning='normal'>System AV To</text>"];
    IJSVGTextLayout* disabled = [self layout:@"<text font-family='system-ui' font-size='32' "
                                              "font-kerning='none'>System AV To</text>"];
    XCTAssertEqualObjects(automatic.characterPositions,
                          normal.characterPositions);
    XCTAssertNotEqualObjects(normal.characterPositions,
                             disabled.characterPositions);
}

- (void)testTextLengthsUseSharedUnitConversions
{
    IJSVGText* text = [self textWithBody:@"<text x='25%, 1in, 2em, 3ex' font-size='12pt' "
                                          "letter-spacing='2px' word-spacing='10%' line-height='1.5'>"
                                          "AB</text>"];
    NSArray<IJSVGTextAttributeValue*>* positions = text.positioning[IJSVGAttributeX].lengths;
    XCTAssertEqual(positions.count, 4);
    XCTAssertEqual(positions[0].lengthBasis, IJSVGTextLengthBasisPercentage);
    XCTAssertEqualWithAccuracy(positions[0].number, .25, .000001);
    XCTAssertEqualWithAccuracy(positions[1].number, 96, .000001);
    XCTAssertEqual(positions[2].lengthBasis, IJSVGTextLengthBasisFontSize);
    XCTAssertEqualWithAccuracy(positions[2].number, 2, .000001);
    XCTAssertEqual(positions[3].lengthBasis, IJSVGTextLengthBasisXHeight);
    XCTAssertEqualWithAccuracy(positions[3].number, 3, .000001);
    XCTAssertEqualWithAccuracy(text.textStyle[IJSVGAttributeFontSize].number,
                               16, .00001);
    XCTAssertFalse(text.textStyle[IJSVGAttributeLetterSpacing].unitless);
    XCTAssertEqual(text.textStyle[IJSVGAttributeWordSpacing].lengthBasis,
                   IJSVGTextLengthBasisPercentage);
    XCTAssertEqualWithAccuracy(text.textStyle[IJSVGAttributeWordSpacing].number,
                               .1, .000001);
    XCTAssertTrue(text.textStyle[IJSVGAttributeLineHeight].unitless);
    XCTAssertEqualWithAccuracy(text.textStyle[IJSVGAttributeLineHeight].number,
                               1.5, .000001);
}

- (void)testParsedTextRenderingUsesKeywords
{
    IJSVGText* text = [self textWithBody:@"<text text-rendering='geometricPrecision'>AB</text>"];
    XCTAssertEqual(text.textStyle[IJSVGAttributeTextRendering].keyword,
                   IJSVGTextKeywordGeometricPrecision);
}

- (void)testParsedFontInheritanceKeepsTraitsAndSize
{
    IJSVGTextLayout* inherited = [self layout:@"<g font-family='Helvetica' font-size='30' "
                                               "font-weight='bold' font-style='italic'><text "
                                               "style='font:inherit'>AB</text></g>"];
    IJSVGTextLayout* explicit = [self layout:@"<text font-family='Helvetica' font-size='30' "
                                              "font-weight='bold' font-style='italic'>AB</text>"];
    XCTAssertEqualObjects(inherited.characterPositions,
                          explicit.characterPositions);
    XCTAssertTrue(CGRectEqualToRect(inherited.group.bounds,
                                    explicit.group.bounds));
}

- (void)testParsedInitialFontSizeDoesNotInherit
{
    IJSVGTextLayout* initial = [self layout:@"<g font-family='Helvetica' font-size='60'><text "
                                             "font-size='initial'>AB</text></g>"];
    IJSVGTextLayout* explicit = [self layout:@"<text font-family='Helvetica' font-size='16'>AB</text>"];
    XCTAssertEqualObjects(initial.characterPositions,
                          explicit.characterPositions);
    XCTAssertTrue(CGRectEqualToRect(initial.group.bounds,
                                    explicit.group.bounds));
}

- (void)testTextAttributesUseTheSharedStyleCascade
{
    IJSVGTextLayout* layout = [self layout:@"<style>.label {font-size:30px;text-anchor:end}</style><g "
                                            "font-family='Helvetica' font-size='12'><text class='label' "
                                            "x='200' y='70' font-size='10' style='font-size:40px;"
                                            "text-anchor:middle'>AB</text></g>"];
    IJSVGTextLayout* explicit = [self layout:@"<text x='200' y='70' font-family='Helvetica' "
                                              "font-size='40' text-anchor='middle'>AB</text>"];
    XCTAssertEqualObjects(layout.characterPositions,
                          explicit.characterPositions);
    XCTAssertTrue(CGRectEqualToRect(layout.group.bounds, explicit.group.bounds));
}

- (void)testTextPathStylesInheritThroughTheSharedAttributePipeline
{
    IJSVGTextLayout* layout = [self layout:@"<style>.label {font-size:28px}</style><defs><path id='p' "
                                            "d='M0 100 H400'/></defs><g class='label' "
                                            "font-family='Helvetica'><text><textPath href='#p' "
                                            "startOffset='25%'>AB</textPath></text></g>"];
    XCTAssertEqualWithAccuracy(layout.characterPositions[0].pointValue.x, 100,
                               .01);
    XCTAssertEqualWithAccuracy(layout.characterPositions[0].pointValue.y, 100,
                               .01);
    XCTAssertGreaterThan(layout.characterPositions[1].pointValue.x, 118);
}

- (void)testFontKerningPreservesPairAdjustmentOnTextPaths
{
    NSString* prefix = @"<defs><path id='p' d='M0 100 H400'/></defs>";
    IJSVGTextLayout* kerned = [self layout:[prefix stringByAppendingString:@"<text "
                                                                            "font-family='Helvetica' "
                                                                            "font-size='25' "
                                                                            "font-kerning='normal'>"
                                                                            "<textPath href='#p'>"
                                                                            "Te</textPath></text>"]];
    IJSVGTextLayout* unkerned = [self layout:[prefix stringByAppendingString:@"<text "
                                                                              "font-family='Helvetica' "
                                                                              "font-size='25' "
                                                                              "font-kerning='none'>"
                                                                              "<textPath href='#p'>"
                                                                              "Te</textPath></text>"]];
    XCTAssertLessThan(kerned.characterPositions[1].pointValue.x,
                      unkerned.characterPositions[1].pointValue.x - 1);
}

- (void)testBaselineAndViewportPercentages
{
    IJSVGTextLayout* layout = [self layout:@"<text x='25%' y='50%' font-size='20'>Hello</text>"];
    CGPoint p = layout.characterPositions.firstObject.pointValue;
    XCTAssertEqualWithAccuracy(p.x, 100, .01);
    XCTAssertEqualWithAccuracy(p.y, 100, .01);
    XCTAssertGreaterThan(CGRectGetWidth(layout.group.bounds), 20);
    XCTAssertLessThan(CGRectGetMinY(layout.group.bounds), 100);
}

- (void)testCSSFontShorthandMatchesLonghands
{
    NSString* css = @"<style>.small {font:italic 13px sans-serif;} .heavy {font:bold 30px sans-serif;} "
                     ".Rrrrr {font:italic 40px serif;fill:red;}</style><text x='20' y='35' class='small'>"
                     "My</text><text x='40' y='35' class='heavy'>cat</text><text x='55' y='55' "
                     "class='small'>is</text><text x='65' y='55' class='Rrrrr'>Grumpy!</text>";
    NSString* explicit = @"<text x='20' y='35' font-style='italic' font-size='13' "
                          "font-family='sans-serif'>My</text><text x='40' y='35' font-weight='bold' "
                          "font-size='30' font-family='sans-serif'>cat</text><text x='55' y='55' "
                          "font-style='italic' font-size='13' font-family='sans-serif'>is</text><text "
                          "x='65' y='55' font-style='italic' font-size='40' font-family='serif' "
                          "fill='red'>Grumpy!</text>";
    NSData* actual = [self pixels:css];
    XCTAssertEqualObjects(actual, [self pixels:explicit]);
    const uint8_t* bytes = actual.bytes;
    NSUInteger black = 0, red = 0;
    for(NSUInteger i = 0; i < actual.length; i += 4) {
        if(bytes[i + 3] > 128) {
            if(bytes[i] > 150 && bytes[i + 1] < 30) {
                red++;
            }
            if(bytes[i] < 30 && bytes[i + 1] < 30) {
                black++;
            }
        }
    }
    XCTAssertGreaterThan(red, 100);
    XCTAssertGreaterThan(black, 100);
}

- (void)testFontsInheritThroughGroupsAndRelativeSizesResolveOnce
{
    IJSVGTextLayout* inherited = [self layout:@"<g font-family='sans-serif' font-size='20'><text y='40'>"
                                               "<tspan font-size='150%'>ABC</tspan></text></g>"];
    CGRect bounds = inherited.group.bounds;
    IJSVGTextLayout* explicit = [self layout:@"<text y='40' font-family='sans-serif' font-size='30'>"
                                              "ABC</text>"];
    XCTAssertEqualWithAccuracy(bounds.size.width,
                               explicit.group.bounds.size.width, .01);
    XCTAssertEqualWithAccuracy(bounds.size.height,
                               explicit.group.bounds.size.height, .01);
}

- (void)testPositionListsOverrideAncestorsAndContinueAfterSpan
{
    IJSVGTextLayout* layout = [self layout:@"<text x='10 30 50 70' y='40'>A<tspan x='100'>BC</tspan>"
                                            "D</text>"];
    XCTAssertEqual(layout.characterPositions.count, 4);
    XCTAssertEqualWithAccuracy(layout.characterPositions[0].pointValue.x, 10,
                               .01);
    XCTAssertEqualWithAccuracy(layout.characterPositions[1].pointValue.x, 100,
                               .01);
    XCTAssertEqualWithAccuracy(layout.characterPositions[2].pointValue.x, 50,
                               .01);
    XCTAssertEqualWithAccuracy(layout.characterPositions[3].pointValue.x, 70,
                               .01);
}

- (void)testRelativeOffsetsAreCumulative
{
    IJSVGTextLayout* plain = [self layout:@"<text x='10' y='40'>ABC</text>"];
    NSArray<NSValue*>* positions = plain.characterPositions;
    IJSVGTextLayout* shifted = [self layout:@"<text x='10' y='40' dx='2 3 4' dy='1 2 3'>ABC</text>"];
    CGFloat dx[] = { 2, 5, 9 }, dy[] = { 1, 3, 6 };
    for(NSUInteger i = 0; i < 3; i++) {
        XCTAssertEqualWithAccuracy(shifted.characterPositions[i].pointValue.x - positions[i].pointValue.x,
                                   dx[i], .01);
        XCTAssertEqualWithAccuracy(shifted.characterPositions[i].pointValue.y - positions[i].pointValue.y,
                                   dy[i], .01);
    }
}

- (void)testWhitespaceCollapsesAcrossSpanBoundaries
{
    IJSVGTextLayout* layout = [self layout:@"<text style='white-space:normal'>  A <tspan>  B </tspan> C  "
                                            "</text>"];
    XCTAssertEqualObjects(layout.string, @"A B C");
    IJSVGTextLayout* preserved = [self layout:@"<text xml:space='preserve'> A  B </text>"];
    XCTAssertEqualObjects(preserved.string, @" A  B ");
}

- (void)testCollapsedWhitespaceDoesNotConsumeCoordinates
{
    IJSVGTextLayout* layout = [self layout:@"<text x='100 200 300' style='white-space:normal'>  A  B  "
                                            "</text>"];
    XCTAssertEqualObjects(layout.string, @"A B");
    XCTAssertEqualWithAccuracy(layout.characterPositions[2].pointValue.x, 300,
                               .01);
}

- (void)testTextAnchorMovesWholeChunk
{
    IJSVGTextLayout* start = [self layout:@"<text x='100'>AB<tspan>CD</tspan></text>"];
    CGRect bounds = start.group.bounds;
    CGFloat advance = start.advance;
    IJSVGTextLayout* middle = [self layout:@"<text x='100' text-anchor='middle'>AB<tspan>CD</tspan>"
                                            "</text>"];
    XCTAssertEqualWithAccuracy(CGRectGetMinX(bounds) - CGRectGetMinX(middle.group.bounds),
                               advance * .5, .1);
    IJSVGTextLayout* end = [self layout:@"<text x='100' text-anchor='end'>AB<tspan>CD</tspan></text>"];
    XCTAssertEqualWithAccuracy(CGRectGetMinX(bounds) - CGRectGetMinX(end.group.bounds),
                               advance, .1);
}

- (void)testRotationLastValueRepeats
{
    NSData* one = [self pixels:@"<text x='20' y='40' rotate='30'>ABC</text>"];
    NSData* list = [self pixels:@"<text x='20' y='40' rotate='30 30 30'>ABC</text>"];
    XCTAssertEqualObjects(one, list);
    XCTAssertNotEqualObjects(one,
                             [self pixels:@"<text x='20' y='40'>ABC</text>"]);
}

- (void)testTextLengthSpacingKeepsGlyphSize
{
    IJSVGTextLayout* plain = [self layout:@"<text>ABC</text>"];
    CGFloat width = plain.group.bounds.size.width;
    CGFloat advance = plain.advance;
    IJSVGTextLayout* adjusted = [self layout:@"<text textLength='120'>ABC</text>"];
    XCTAssertEqualWithAccuracy(adjusted.group.bounds.size.width - width,
                               120 - advance, .1);
}

- (void)testTextLengthScalesGlyphsOnlyAlongInlineAxis
{
    IJSVGTextLayout* plain = [self layout:@"<text>ABC</text>"];
    CGRect bounds = plain.group.bounds;
    CGFloat advance = plain.advance;
    IJSVGTextLayout* adjusted = [self layout:@"<text textLength='120' lengthAdjust='spacingAndGlyphs'>"
                                              "ABC</text>"];
    XCTAssertEqualWithAccuracy(adjusted.group.bounds.size.height,
                               bounds.size.height, .01);
    XCTAssertEqualWithAccuracy(adjusted.group.bounds.size.width,
                               bounds.size.width * 120 / advance, .1);
}

- (void)testCoreTextShapesLigaturesAndComplexScripts
{
    IJSVGTextLayout* ligature = [self layout:@"<text font-family='Times New Roman'>ffi</text>"];
    XCTAssertGreaterThan(ligature.glyphCount, 0);
    XCTAssertLessThanOrEqual(ligature.glyphCount, 3);
    IJSVGTextLayout* arabic = [self layout:@"<text direction='rtl' x='200'>مرحبا بالعالم</text>"];
    XCTAssertGreaterThan(arabic.glyphCount, 0);
    XCTAssertGreaterThan(arabic.group.bounds.size.width, 0);
    XCTAssertLessThanOrEqual(CGRectGetMaxX(arabic.group.bounds), 205);
    IJSVGTextLayout* combined = [self layout:@"<text>A&#x301;B</text>"];
    XCTAssertGreaterThan(combined.glyphCount, 0);
    XCTAssertEqual(combined.characterPositions.count, 3);
}

- (void)testSupplementaryCodePointConsumesOnePosition
{
    IJSVGTextLayout* layout = [self layout:@"<text x='10 40 70'>A&#x1D400;B</text>"];
    XCTAssertEqual(layout.characterPositions.count, 3);
    XCTAssertEqualWithAccuracy(layout.characterPositions[2].pointValue.x, 70,
                               .01);
}

- (void)testTextPathFollowsStraightBaselineAndStartOffset
{
    IJSVGTextLayout* layout = [self layout:@"<defs><path id='line' d='M0 80 H300'/></defs><text>"
                                            "<textPath href='#line' startOffset='20'>ABC</textPath>"
                                            "</text>"];
    XCTAssertEqualWithAccuracy(layout.characterPositions[0].pointValue.x, 20,
                               .05);
    XCTAssertEqualWithAccuracy(layout.characterPositions[0].pointValue.y, 80,
                               .05);
    XCTAssertGreaterThan(layout.group.bounds.size.width, 0);
}

- (void)testTextPathReferenceAliasesAndHrefPrecedence
{
    NSString* definitions = @"<defs><path id='a' d='M0 40 H300'/><path id='b' d='M0 90 H300'/></defs>";
    IJSVGTextLayout* expected = [self layout:[definitions stringByAppendingString:@"<text><textPath "
                                                                                   "href='#a'>"
                                                                                   "ABC</textPath></text>"
                                                                                   ""]];
    for(NSString* attributes in @[
            @"xmlns:link='http://www.w3.org/1999/xlink' link:href='#a'",
            @"xmlns:xlink='http://www.w3.org/1999/xlink' href='#a' xlink:href='#b'"
        ]) {
        IJSVGTextLayout* actual = [self layout:[definitions stringByAppendingFormat:@"<text><textPath %@>"
                                                                                     "ABC</textPath></text>"
                                                                                     "",
                                                                                    attributes]];
        XCTAssertEqualObjects(actual.characterPositions,
                              expected.characterPositions);
        XCTAssertTrue(CGRectEqualToRect(actual.group.bounds,
                                        expected.group.bounds));
    }
}

- (void)testMissingTextPathRendersNothing
{
    IJSVGTextLayout* layout = [self layout:@"<text><textPath href='#absent'>ABC</textPath></text>"];
    XCTAssertTrue(CGRectIsNull(layout.group.bounds) || CGRectIsEmpty(layout.group.bounds));
}

- (void)testCurvedTextPathProducesDifferentGlyphHeights
{
    IJSVGTextLayout* layout = [self layout:@"<defs><path id='curve' d='M0 100 Q100 0 200 100'/></defs>"
                                            "<text font-size='24'><textPath href='#curve'>Curved "
                                            "text</textPath></text>"];
    XCTAssertGreaterThan(layout.glyphCount, 5);
    XCTAssertNotEqualWithAccuracy(layout.characterPositions[0].pointValue.y,
                                  layout.characterPositions[5].pointValue.y, 1);
}

- (void)testInlineSizeWrapsText
{
    IJSVGTextLayout* layout = [self layout:@"<text x='50' y='30' style='font:20px sans-serif;"
                                            "inline-size:100px'>This text wraps over several "
                                            "lines.</text>"];
    CGFloat first = layout.characterPositions.firstObject.pointValue.y;
    CGFloat last = layout.characterPositions.lastObject.pointValue.y;
    XCTAssertGreaterThan(last, first + 20);
}

- (void)testPreformattedNewlinesAdvanceBaseline
{
    IJSVGTextLayout* layout = [self layout:@"<text x='20' y='30' style='white-space:pre;line-height:2;"
                                            "font-size:10'>A\nB</text>"];
    XCTAssertEqualWithAccuracy(layout.characterPositions[2].pointValue.y - layout.characterPositions[0].pointValue.y,
                               20, .01);
}

- (void)testHiddenSpanDoesNotAdvanceText
{
    IJSVGTextLayout* layout = [self layout:@"<text>A<tspan display='none'>hidden</tspan>B</text>"];
    XCTAssertEqualObjects(layout.string, @"AB");
}

- (void)testBaselineShiftAndDecorationAffectGeometry
{
    IJSVGTextLayout* plain = [self layout:@"<text x='20' y='60' font-size='30'>ABC</text>"];
    CGRect original = plain.group.bounds;
    IJSVGTextLayout* superText = [self layout:@"<text x='20' y='60' font-size='30' "
                                               "baseline-shift='super'>ABC</text>"];
    XCTAssertLessThan(CGRectGetMinY(superText.group.bounds),
                      CGRectGetMinY(original));
    XCTAssertNotEqualObjects([self pixels:@"<text x='20' y='40' text-decoration='underline'>ABC</text>"],
                             [self pixels:@"<text x='20' y='40'>ABC</text>"]);
}

- (void)testVerticalWritingAdvancesDownward
{
    IJSVGTextLayout* layout = [self layout:@"<text x='100' y='20' writing-mode='vertical-rl'>日本語</text>"];
    XCTAssertGreaterThan(layout.characterPositions[2].pointValue.y,
                         layout.characterPositions[0].pointValue.y);
    XCTAssertGreaterThan(layout.group.bounds.size.height, 0);
}

- (void)testNestedTextLengthKeepsDescendantSpansAsOneSpacingUnit
{
    for(NSString* writingMode in @[@"horizontal-tb", @"vertical-rl"]) {
        for(NSString* adjustment in @[@"spacing", @"spacingAndGlyphs"]) {
            NSString* format = @"<text font-family='Helvetica' font-size='20' writing-mode='%@' "
                                "textLength='200'>A<tspan textLength='80' lengthAdjust='%@'>%@</tspan>"
                                "E</text>";
            NSString* nestedBody = [NSString stringWithFormat:format,
                                                              writingMode,
                                                              adjustment,
                                                              @"B<tspan>C</tspan>D"];
            NSString* flatBody = [NSString stringWithFormat:format,
                                                            writingMode,
                                                            adjustment,
                                                            @"BCD"];
            IJSVGTextLayout* nested = [self layout:nestedBody];
            IJSVGTextLayout* flat = [self layout:flatBody];
            XCTAssertEqualObjects(nested.characterPositions,
                                  flat.characterPositions);
            XCTAssertEqual(nested.glyphCount, flat.glyphCount);
        }
    }
}

- (void)testDecorationMetricsFollowActualFontChanges
{
    CTFontRef fonts[] = {
        CTFontCreateWithName(CFSTR("Helvetica"), 18, NULL),
        CTFontCreateWithName(CFSTR("Times-Roman"), 42, NULL)
    };
    IJSVGTextComputedStyle* style = [[IJSVGTextComputedStyle alloc] init];
    style.decorations = IJSVGTextDecorationUnderline | IJSVGTextDecorationOverline | IJSVGTextDecorationLineThrough;
    IJSVGTextCharacter character = { .style = style, .advance = 20, .scale = 1 };
    IJSVGTextDecorationMetrics metrics = { 0 };
    for(NSUInteger index = 0; index < 4; index++) {
        CTFontRef font = fonts[index % 2];
        style.fontScale = index + 1;
        IJSVGTextGlyph glyph = { .font = font };
        CGMutablePathRef actual = CGPathCreateMutable();
        CGMutablePathRef expected = CGPathCreateMutable();
        IJSVGTextAppendDecorations(actual, &character, &glyph,
                                   CGAffineTransformIdentity, &metrics);
        CGFloat ascent, descent;
        IJSVGTextFontExtents(font, &ascent, &descent);
        CGFloat thickness = CTFontGetSize(font) / 20;
        CGFloat width = character.advance * style.fontScale;
        CGFloat offsets[] = {
            -2.5 * thickness,
            ascent - 2 * thickness,
            ascent * .375 - thickness
        };
        for(NSUInteger offset = 0; offset < 3; offset++) {
            CGRect bounds = CGRectMake(0, offsets[offset], width, thickness);
            CGPathAddRect(expected, NULL, bounds);
        }
        XCTAssertTrue(CGPathEqualToPath(actual, expected));
        CGPathRelease(actual);
        CGPathRelease(expected);
    }
    CFRelease(fonts[0]);
    CFRelease(fonts[1]);
}

- (void)testPathMetricsHandleClosedAndDisconnectedSubpaths
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 0, 0);
    CGPathAddLineToPoint(path, NULL, 30, 0);
    CGPathAddLineToPoint(path, NULL, 30, 40);
    CGPathCloseSubpath(path);
    IJSVGTextPathMetrics* closed = [[IJSVGTextPathMetrics alloc] initWithPath:path];
    XCTAssertTrue(closed.closed);
    XCTAssertEqualWithAccuracy(closed.length, 120, .000001);
    CGPoint point, tangent;
    XCTAssertTrue([closed pointAt:50
                            point:&point
                          tangent:&tangent]);
    XCTAssertEqualWithAccuracy(point.x, 30, .000001);
    XCTAssertEqualWithAccuracy(point.y, 20, .000001);
    CGPathMoveToPoint(path, NULL, 100, 100);
    CGPathAddQuadCurveToPoint(path, NULL, 150, 100, 200, 100);
    CGPathAddCurveToPoint(path, NULL, 230, 100, 270, 100, 300, 100);
    IJSVGTextPathMetrics* disconnected = [[IJSVGTextPathMetrics alloc] initWithPath:path];
    XCTAssertFalse(disconnected.closed);
    XCTAssertEqualWithAccuracy(disconnected.length, 320, .000001);
    XCTAssertTrue([disconnected pointAt:170
                                  point:&point
                                tangent:&tangent]);
    XCTAssertEqualWithAccuracy(point.x, 150, .000001);
    XCTAssertEqualWithAccuracy(point.y, 100, .000001);
    XCTAssertFalse([disconnected pointAt:NAN
                                   point:&point
                                 tangent:&tangent]);
    IJSVGTextPathMetrics* empty = [[IJSVGTextPathMetrics alloc] initWithPath:NULL];
    XCTAssertFalse([empty pointAt:0
                            point:&point
                          tangent:&tangent]);
    CGPathRelease(path);
}

- (void)testSharedPathMetricsPreserveOffsetsFontsAndTransforms
{
    IJSVGTextLayout* layout = [self layout:@"<defs><path id='p' d='M0 20 H400'/><path id='q' d='M0 20 "
                                            "H400' transform='translate(0 50)'/></defs><text "
                                            "font-size='20'><textPath href='#p' startOffset='1em'><tspan "
                                            "x='0'>A</tspan><tspan x='0' font-size='40'>B</tspan>"
                                            "</textPath><textPath href='#p' startOffset='10'><tspan "
                                            "x='0'>C</tspan></textPath><textPath href='#q'><tspan x='0'>"
                                            "D</tspan></textPath></text>"];
    XCTAssertEqual(layout.characterPositions.count, 4);
    CGFloat x[] = { 20, 20, 10, 0 };
    CGFloat y[] = { 20, 20, 20, 70 };
    for(NSUInteger index = 0; index < 4; index++) {
        CGPoint point = layout.characterPositions[index].pointValue;
        XCTAssertEqualWithAccuracy(point.x, x[index], .001);
        XCTAssertEqualWithAccuracy(point.y, y[index], .001);
    }
}

- (void)testNestedRangesPreserveParentContentAndEmptySpans
{
    IJSVGTextLayout* layout = [self layout:@"<text x='10 20 30 40 50'>A<tspan/><tspan dx='2 3 4'>B<tspan "
                                            "display='none'>hidden</tspan><tspan dx='5'>C</tspan>"
                                            "D</tspan><tspan/>E</text>"];
    XCTAssertEqualObjects(layout.string, @"ABCDE");
    CGFloat x[] = { 10, 22, 35, 44, 50 };
    XCTAssertEqual(layout.characterPositions.count, 5);
    for(NSUInteger index = 0; index < 5; index++) {
        XCTAssertEqualWithAccuracy(layout.characterPositions[index].pointValue.x,
                                   x[index], .001);
    }
}

- (void)testRepeatedRenderingIsStable
{
    CGSize viewport = CGSizeMake(400, 200);
    IJSVGText* text = [self textWithBody:@"<text x='20' y='50' font-size='30'>Repeat <tspan fill='red'>"
                                          "me</tspan></text>"];
    NSArray* content = text.textContent;
    IJSVGTextLayout* first = [[IJSVGTextLayout alloc] initWithText:text
                                                          viewport:viewport
                                                      pathResolver:nil];
    IJSVGTextLayout* second = [[IJSVGTextLayout alloc] initWithText:text
                                                           viewport:viewport
                                                       pathResolver:nil];
    XCTAssertEqualObjects(first.characterPositions, second.characterPositions);
    XCTAssertEqualObjects(content, text.textContent);
}

@end
