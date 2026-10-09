//
//  IJSVGCSSFontParserChecks.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 07/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGCSSFontParserChecks.h"
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGText.h>

static NSDictionary* IJSVGFontProperties(NSString* property, NSString* value)
{
    IJSVGStyleSheetStyle* style = [[IJSVGStyleSheetStyle alloc] init];
    [style setPropertyValue:value
                forProperty:property];
    return style.properties;
}

static void IJSVGCheckFont(NSMutableArray<NSString*>* failures, NSString* value, BOOL valid)
{
    NSDictionary* result = IJSVGFontProperties(@"font", value);
    if((result.count == 11) != valid || (result.count != 0 && result.count != 11)) {
        if(failures.count < 100) {
            [failures addObject:[NSString stringWithFormat:@"Unexpected font acceptance: %@",
                                                          value]];
        }
    }
    IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:@"font:italic 30px Helvetica"];
    NSDictionary* previous = [style.properties copy];
    [style setPropertyValue:value
                forProperty:@"font"];
    if(!valid && ![previous isEqualToDictionary:style.properties] && failures.count < 100) {
        [failures addObject:@"Invalid shorthand changed an earlier declaration"];
    }
}

static void IJSVGCheckCSSDeclarations(NSMutableArray<NSString*>* failures)
{
    NSArray* fixtures = @[
        @[ @";fill:red", @"fill", @"red" ],
        @[ @"fill:red;;stroke:blue", @"stroke", @"blue" ],
        @[ @"garbage;fill:red", @"fill", @"red" ],
        @[ @"fill:red!important;fill:blue", @"fill", @"red" ],
        @[ @"fill:red;fill:blue ! IMPORTANT", @"fill", @"blue" ],
        @[ @"font-weight:bold!important;font:20px Helvetica", @"font-weight", @"bold" ],
        @[ @"font:20px Helvetica!important;font-weight:bold", @"font-weight", @"normal" ]
    ];
    for(NSArray* fixture in fixtures) {
        IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:fixture[0]];
        if(![style.properties[fixture[1]] isEqual:fixture[2]]) {
            [failures addObject:[NSString stringWithFormat:@"Declaration recovery or priority failed: %@", fixture[0]]];
        }
    }
    for(NSArray* fixture in @[
        @[ @"} rect {fill:red}", @1 ],
        @[ @"}} rect {fill:red} } circle {stroke:blue}", @2 ],
        @[ @"text {font:20px \"A\\\\\";} rect {fill:red}", @2 ]
    ]) {
        IJSVGStyleSheet* sheet = [[IJSVGStyleSheet alloc] init];
        [sheet parseStyleBlock:fixture[0]];
        if(sheet.ruleCount != [fixture[1] unsignedIntegerValue]) {
            [failures addObject:[NSString stringWithFormat:@"Stylesheet recovery failed: %@", fixture[0]]];
        }
    }
}

static void IJSVGCheckCSSIntegration(NSMutableArray<NSString*>* failures)
{
    NSArray* fixtures = @[
        @[ @"<text font-family='&quot;A,B&quot;, Helvetica'>A</text>", @"font-family", @[ @"A,B", @"Helvetica" ] ],
        @[ @"<text font-family='Helve\\74 ica'>A</text>", @"font-family", @[ @"Helvetica" ] ],
        @[ @"<text font-family='&quot;serif&quot;, serif'>A</text>", @"font-family", @[ @"serif", @"Times" ] ],
        @[ @"<style>text {font-size:20px!important} #t {font-size:30px}</style><text id='t' style='font-size:40px'>A</text>", @"font-size", @"20px" ],
        @[ @"<style>text {font-size:20px!important}</style><text style='font-size:40px!important'>A</text>", @"font-size", @"40px" ],
        @[ @"<style>#t {font-size:30px!important} text {font-size:20px!important}</style><text id='t'>A</text>", @"font-size", @"30px" ]
    ];
    for(NSArray* fixture in fixtures) {
        NSString* xml = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg'>%@</svg>", fixture[0]];
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml fileURL:nil error:nil];
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(400, 200)];
        __block BOOL matched = NO;
        [IJSVGNode walkNodeTree:root handler:^(IJSVGNode* node, BOOL* descend, BOOL* stop) {
            if([node isKindOfClass:IJSVGText.class]) {
                IJSVGTextAttributeValue* value = node.textStyle[fixture[1]];
                id actual = [fixture[1] isEqual:@"font-family"] ? value.families : value.string;
                matched = [actual isEqual:fixture[2]];
                *stop = YES;
            }
        }];
        if(!matched) {
            [failures addObject:[NSString stringWithFormat:@"CSS integration failed: %@", fixture[0]]];
        }
    }
}

NSArray<NSString*>* IJSVGRunCSSFontParserChecks(void)
{
    NSMutableArray<NSString*>* failures = [[NSMutableArray alloc] init];
    IJSVGCheckCSSDeclarations(failures);
    IJSVGCheckCSSIntegration(failures);
    NSArray* invalid = @[
        @"", @"/", @"20px", @"20px /", @"20px //2 Helvetica",
        @"20px 'Helvetica", @"20px Helvetica'", @"20px \"Helvetica\"junk",
        @"20px Helvetica,,Arial", @"20px ,Helvetica", @"20px Helvetica,",
        @"20px 123", @"20px Helvetica / Arial", @"20px inherit",
        @"20px initial", @"20px unset", @"20px default", @"20px ()",
        @"20px \"line\nbreak\"", @"20px foo\\", @"20px foo\\\nbar",
        @"20px / NaN Helvetica", @"20px / 1e999 Helvetica",
        @"italic italic 20px Helvetica", @"normal normal normal normal normal 20px Helvetica",
        @"20px a%;font-size:99px"
    ];
    for(NSString* value in invalid) {
        IJSVGCheckFont(failures, value, NO);
    }
    NSArray* valid = @[
        @"16px Helvetica", @"italic small-caps 600 condensed 20px / 1.5 Helvetica",
        @"  MEDIUM Helvetica  ", @"20px \"Helvetica Neue\", sans-serif",
        @"20px 不存在, Helvetica", @"20px \"A,B\"", @"20px \"A\\\"B\"",
        @"20px \"A\\\\\"", @"20px Font\\ Name", @"20px \\31 23",
        @"20px / .5 Helvetica", @"1em / 2ex Helvetica", @"0 Helvetica",
        @"inherit", @"unset", @"initial"
    ];
    for(NSString* value in valid) {
        IJSVGCheckFont(failures, value, YES);
    }
    NSString* embeddedNull = [[NSString alloc] initWithBytes:"20px Helvetica\0junk"
                                                     length:19
                                                   encoding:NSUTF8StringEncoding];
    IJSVGCheckFont(failures, embeddedNull, NO);
    IJSVGCheckFont(failures, [@"20px " stringByAppendingString:
        [@"\"" stringByAppendingString:[@"" stringByPaddingToLength:1048576
                                                       withString:@"A"
                                                  startingAtIndex:0]]], NO);
    IJSVGCheckFont(failures, [[@"" stringByPaddingToLength:1048576
                                             withString:@"9"
                                        startingAtIndex:0] stringByAppendingString:@"px Helvetica"], NO);

    // Use a fixed seed so a failing random input can be reproduced.
    const char alphabet[] = "abcXYZ019+-.eE%/,'\"\\ \t\r\n()";
    uint64_t seed = 0x49A537ULL;
    NSUInteger checked = 0;
    for(NSUInteger iteration = 0; iteration < 10000; iteration++) {
        char bytes[129] = { 0 };
        NSUInteger length = iteration % 129;
        for(NSUInteger index = 0; index < length; index++) {
            seed = seed * 6364136223846793005ULL + 1442695040888963407ULL;
            bytes[index] = alphabet[(seed >> 32) % (sizeof(alphabet) - 1)];
        }
        @autoreleasepool {
            NSString* value = [[NSString alloc] initWithBytes:bytes
                                                     length:length
                                                   encoding:NSUTF8StringEncoding];
            NSDictionary* first = IJSVGFontProperties(@"font", value);
            NSDictionary* second = IJSVGFontProperties(@"font", value);
            if((first.count != 0 && first.count != 11) ||
               ![first isEqualToDictionary:second]) {
                if(failures.count < 100) {
                    [failures addObject:[NSString stringWithFormat:@"Nonatomic or unstable fuzz result at %lu",
                                                                  (unsigned long)iteration]];
                }
            }
            checked++;
        }
    }
    // Check valid declarations as well as invalid random inputs.
    const char* units[] = { "px", "pt", "pc", "in", "cm", "mm", "em", "ex", "%" };
    for(NSUInteger index = 0; index < 1000; index++) {
        NSString* value = [NSString stringWithFormat:@"italic %lu %.1f%s / 1.5 \"Family %lu\", Helvetica",
                          (unsigned long)(index % 1000 + 1), (index % 100 + 1) * .5,
                          units[index % 9], (unsigned long)index];
        IJSVGCheckFont(failures, value, YES);
        IJSVGCheckFont(failures, [value stringByAppendingString:@","], NO);
        checked += 2;
    }
    for(NSString* value in valid) {
        for(NSUInteger length = 0; length <= value.length; length++) {
            NSDictionary* result = IJSVGFontProperties(@"font",
                [value substringToIndex:length]);
            if(result.count != 0 && result.count != 11 && failures.count < 100) {
                [failures addObject:@"Truncated shorthand produced partial properties"];
            }
            checked++;
        }
    }
    // A pair of backslashes before a closing quote must leave the next declaration readable.
    IJSVGStyleSheetStyle* escaped = [IJSVGStyleSheetStyle parseStyleString:
        @"font:20px \"A\\\\\";font-weight:bold"];
    if(![escaped.properties[@"font-weight"] isEqual:@"bold"]) {
        [failures addObject:@"Escaped quote prevented the following declaration from parsing"];
    }
    NSLog(@"CSS FONT CHECKS %lu generated/truncated inputs, %lu failures",
          (unsigned long)checked, (unsigned long)failures.count);
    return failures;
}
