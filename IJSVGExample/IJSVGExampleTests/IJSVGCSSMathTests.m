//
//  IJSVGCSSMathTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 12/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTestHelpers.h>
#import <IJSVG/IJSVGUnitLength.h>
#import <IJSVGStyleSheetUtils.h>
#import <time.h>
#import <IJSVGCSSParser.h>
#import <IJSVGCSSVariables.h>
#import <IJSVGCSSMathExpression.h>
#import <IJSVGParserUtils.h>
#import <IJSVG/IJSVGCommandParser.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGUtils.h>

@interface IJSVGCSSMathTests: XCTestCase
@end

@implementation IJSVGCSSMathTests

- (IJSVGUnitLength*)length:(NSString*)source
{
    IJSVGUnitLength* length = [IJSVGUnitLength unitWithCalculationString:source
                                                       allowNegative:YES];
    XCTAssertNotNil(length, @"%@", source);
    return length;
}

- (NSData*)pixels:(NSString*)body
            width:(NSUInteger)width
           height:(NSUInteger)height
{
    NSString* source = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='%lu' height='%lu'>%@</svg>",
        (unsigned long)width, (unsigned long)height, body];
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
    XCTAssertNotNil(svg);
    NSImage* image = [svg imageWithSize:CGSizeMake(width, height)];
    XCTAssertNotNil(image);
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    XCTAssertNotEqual(cgImage, NULL);
    if(cgImage == NULL) {
        return nil;
    }
    NSMutableData* pixels = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8,
                                                width * 4, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    XCTAssertNotEqual(context, NULL);
    if(context == NULL) {
        return nil;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(context);
    return pixels;
}

- (NSData*)pixels:(NSString*)body
{
    return [self pixels:body width:200 height:100];
}

- (void)testNestedArithmeticAndUnits
{
    NSArray<NSString*>* sources = @[
        @"calc(2px + 3px * 4)",
        @"calc((2px + 3px) * 4)",
        @"calc(20px / 2 / 2)",
        @"calc(1in - 24px)",
        @"calc(-2px + +3px)",
        @"min(12px, max(2px, 7px + 1px))",
        @"clamp(20px, 10px, 5px)",
        @"calc(2px * 3px / 1px)",
        @"calc(1e2px / 4)",
        @"c\\61lc(1p\\78  + 2px)",
        @"CALC(1px /* comment */ + 2px)"
    ];
    CGFloat expected[] = { 14, 20, 5, 72, 1, 8, 20, 6, 25, 3, 3 };
    for(NSUInteger index = 0; index < sources.count; index++) {
        IJSVGUnitLength* value = [self length:sources[index]];
        XCTAssertEqualWithAccuracy([value computeValue:200], expected[index], .0001,
                                   @"%@", sources[index]);
    }
}

- (void)testPercentagesRemainDeferredAndFontResolutionPreservesThem
{
    IJSVGUnitLength* value = [self length:@"clamp(20px, calc(50% - min(2em, 30px)), 200px)"];
    XCTAssertTrue(value.usesPercentage);
    XCTAssertTrue(value.usesFontMetrics);
    XCTAssertEqual([value computeValue:200 fontSize:10 xHeight:5], 80);
    XCTAssertEqual([value computeValue:400 fontSize:10 xHeight:5], 180);
    IJSVGUnitLength* resolved = [value lengthByResolvingFontSize:10 xHeight:5];
    XCTAssertNotNil(resolved);
    XCTAssertFalse(resolved.usesFontMetrics);
    XCTAssertTrue(resolved.usesPercentage);
    XCTAssertEqual([resolved computeValue:400], 180);
    IJSVGUnitLength* inherited = [resolved lengthWithInheritance:YES];
    XCTAssertNotNil(inherited);
    XCTAssertEqual([inherited computeValue:200], 80);
    IJSVGUnitLength* roundTrip = [self length:resolved.stringValue];
    XCTAssertEqual([roundTrip computeValue:400], 180);
}

- (void)testRejectsInvalidCalculations
{
    NSArray<NSString*>* sources = @[
        @"calc()", @"min()", @"max(1px,)", @"clamp(1px, 2px)",
        @"calc(1px + 1)", @"calc(0 + 1px)", @"min(1px, 1)",
        @"calc(1px * 1px)", @"calc(1 / 2px)",
        @"calc(1px+2px)", @"calc(1px +2px)", @"calc(1px+ 2px)",
        @"calc(1px/**/+/**/2px)", @"calc(1/**/px)", @"calc(1. + 2)",
        @"calc(-(1px))", @"calc(1px))", @"calc((1px])", @"calc(1px",
        @"calc(1px) garbage", @"calc(1px, 2px)", @"calc(1px 2px)",
        @"calc(1px + unknown(2px))", @"var(--size)", @"calc(1vh + 2px)",
        @"calc(1px + 2deg)", @"calc(1px + /* unterminated)"
    ];
    for(NSString* source in sources) {
        XCTAssertNil([IJSVGUnitLength unitWithCalculationString:source allowNegative:YES], @"%@", source);
    }
}

- (void)testRangeCheckingHappensAfterEvaluation
{
    IJSVGUnitLength* nonnegative = [IJSVGUnitLength unitWithCalculationString:@"calc(2px - 5px)"
                                                             allowNegative:NO];
    XCTAssertNotNil(nonnegative);
    XCTAssertEqual([nonnegative computeValue:100], 0);
    XCTAssertEqual([[self length:@"calc(2px - 5px)"] computeValue:100], -3);
    XCTAssertTrue(isfinite([[self length:@"calc(10px / 0)"] computeValue:100]));
    XCTAssertEqual([[self length:@"calc(0px / 0)"] computeValue:100], 0);
    XCTAssertEqual([[self length:@"min(NaN * 1px, 10px)"] computeValue:100], 0);
    XCTAssertLessThan([[self length:@"calc(1px / min(-0, 0))"] computeValue:100], 0);
    XCTAssertGreaterThan([[self length:@"calc(1px / max(-0, 0))"] computeValue:100], 0);
}

- (void)testSerializationPreservesPrecedenceAndFlatExpressions
{
    NSMutableArray<NSString*>* terms = [NSMutableArray arrayWithCapacity:100];
    for(NSUInteger index = 0; index < 100; index++) {
        [terms addObject:@"1px"];
    }
    NSArray<NSString*>* sources = @[
        @"calc((2px + 3px) * (4 + 5))",
        @"calc(10px - (2px - 1px))",
        @"calc(20px / (4 / 2))",
        @"min(2px + 3px, 10px / 2)",
        [NSString stringWithFormat:@"calc(%@)", [terms componentsJoinedByString:@" + "]]
    ];
    for(NSString* source in sources) {
        IJSVGUnitLength* value = [self length:source];
        NSString* serialized = value.stringValue;
        XCTAssertNotNil(serialized);
        IJSVGUnitLength* reparsed = [self length:serialized];
        XCTAssertEqual([value computeValue:100], [reparsed computeValue:100], @"%@", source);
    }
}

- (void)testCalculationEvaluationBenchmark
{
    IJSVGUnitLength* value = [self length:@"clamp(20px, 50% - min(2em, 30px), 200px)"];
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    CGFloat total = 0;
    for(NSUInteger index = 0; index < 100000; index++) {
        total += [value computeValue:index % 2 == 0 ? 200 : 400 fontSize:10 xHeight:5];
    }
    CFAbsoluteTime elapsed = CFAbsoluteTimeGetCurrent() - start;
    XCTAssertEqual(total, 13000000);
    NSLog(@"CSS math: 100,000 evaluations in %.6f seconds", elapsed);
}


- (void)benchmark:(NSString*)name
       iterations:(NSUInteger)iterations
             work:(NSUInteger (^)(void))work
{
    NSUInteger expected = work();
    XCTAssertGreaterThan(expected, 0);
    work();
    double samples[7];
    for(NSUInteger sample = 0; sample < 7; sample++) {
        NSUInteger checksum = 0;
        uint64_t start = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        for(NSUInteger iteration = 0; iteration < iterations; iteration++) {
            @autoreleasepool {
                checksum += work();
            }
        }
        samples[sample] = (clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - start) / 1e6;
        XCTAssertEqual(checksum, expected * iterations, @"%@", name);
    }
    for(NSUInteger index = 1; index < 7; index++) {
        double value = samples[index];
        NSUInteger position = index;
        while(position != 0 && samples[position - 1] > value) {
            samples[position] = samples[position - 1];
            position--;
        }
        samples[position] = value;
    }
    NSLog(@"CSS benchmark %@ iterations %lu median %.3f ms range %.3f to %.3f ms",
          name, (unsigned long)iterations, samples[3], samples[0], samples[6]);
}

- (void)testVariableDictionaryBenchmark
{
    NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] init];
    CFMutableDictionaryRef coreDictionary = CFDictionaryCreateMutable(NULL, 128,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    NSMutableArray* queries = [[NSMutableArray alloc] init];
    for(NSUInteger index = 0; index < 128; index++) {
        NSString* key = [NSString stringWithFormat:@"--variable%lu", (unsigned long)index];
        NSString* value = [NSString stringWithFormat:@"%lupx", (unsigned long)index];
        dictionary[key] = value;
        CFDictionarySetValue(coreDictionary, (__bridge const void*)key, (__bridge const void*)value);
        [queries addObject:[NSString stringWithFormat:@"--variable%lu", (unsigned long)index]];
    }
    for(NSString* key in queries) {
        XCTAssertEqualObjects(dictionary[key],
            (__bridge id)CFDictionaryGetValue(coreDictionary, (__bridge const void*)key));
    }
    [self benchmark:@"NS variable dictionary lookups" iterations:3000 work:^NSUInteger {
        NSUInteger count = 0;
        for(NSString* key in queries) {
            count += dictionary[key] != nil;
        }
        return count;
    }];
    [self benchmark:@"CF variable dictionary lookups" iterations:3000 work:^NSUInteger {
        NSUInteger count = 0;
        for(NSString* key in queries) {
            count += CFDictionaryGetValue(coreDictionary, (__bridge const void*)key) != NULL;
        }
        return count;
    }];
    CFRelease(coreDictionary);
}

- (void)testVariableResolutionBenchmark
{
    NSMutableDictionary* declarations = [[NSMutableDictionary alloc] init];
    for(NSUInteger index = 0; index < 64; index++) {
        declarations[[NSString stringWithFormat:@"--size%lu", (unsigned long)index]] =
            [NSString stringWithFormat:@"calc(var(--base, 10px) + %lupx)", (unsigned long)index];
    }
    declarations[@"--base"] = @"20px";
    [self benchmark:@"custom property scope resolution" iterations:100 work:^NSUInteger {
        return IJSVGCSSResolveCustomProperties(declarations, nil).count;
    }];
    NSDictionary* properties = IJSVGCSSResolveCustomProperties(declarations, nil);
    IJSVGStyleSheetStyle* style = [IJSVGStyleSheetStyle parseStyleString:
        @"width:var(--size20);height:var(--missing,var(--size30));fill:rgb(var(--red,128),0,0)"];
    [self benchmark:@"variable style resolution" iterations:1000 work:^NSUInteger {
        return [style styleByResolvingVariables:properties].properties.count;
    }];
}

- (void)testPathStyleBenchmark
{
    NSMutableString* path = [NSMutableString stringWithString:@"M0 0"];
    for(NSUInteger index = 0; index < 256; index++) {
        [path appendFormat:@"L%lu %lu", (unsigned long)index, (unsigned long)(index % 31)];
    }
    NSString* style = [NSString stringWithFormat:@"d:path('%@');fill:red", path];
    XCTAssertEqualObjects(IJSVGCSSPathDataFromString(
        [[IJSVGStyleSheetStyle parseStyleString:style] property:@"d"]), path);
    [self benchmark:@"path declaration validation"
         iterations:1000
               work:^NSUInteger {
        return [IJSVGStyleSheetStyle parseStyleString:style].properties.count;
    }];
}

- (void)testComplexStyleBenchmarks
{
    NSArray<NSString*>* expressions = @[
        @"clamp(2px, calc(25% - min(2em, max(3px, 1ex))) / 2, 80px)",
        @"calc((min(12px, 2em) + max(1px, 2ex)) * 3 / 2)",
        @"max(0px, calc(50% - clamp(4px, 2em + 1ex, 40px)))",
        @"calc(1in / 4 + min(3px, 1em) - max(1px, .5ex))",
        @"clamp(1px, min(10%, 2em) + max(.5px, 1ex), 20px)",
        @"calc((20px + min(2em, 8px)) / max(1, 2) + 5%)",
        @"c\\61lc(10px /* retained boundary */ + min(2em, 5px))",
        @"calc(2px * 3px / max(1px, 2px))"
    ];
    NSMutableString* stylesheet = [NSMutableString string];
    NSMutableString* plainStylesheet = [NSMutableString string];
    NSMutableString* elements = [NSMutableString string];
    for(NSUInteger index = 0; index < 128; index++) {
        NSString* declarations = [NSString stringWithFormat:
            @"x:calc(%lu%% + min(2px, 1em)); y:calc(%lu%% + 1px); "
             "width:%@; height:%@; stroke-width:%@; "
             "stroke-dasharray:%@ %@; stroke-dashoffset:calc(1px - min(2px, 1ex)); "
             "fill:#369; stroke:#123; font-size:12px;",
            (unsigned long)(index % 16 * 5), (unsigned long)(index / 16 * 10),
            expressions[index % 4], expressions[(index + 1) % 4],
            expressions[4], expressions[5], expressions[7]];
        [plainStylesheet appendFormat:@"g.layer > rect.tile%lu, #tile%lu { %@ }\n",
                         (unsigned long)index, (unsigned long)index, declarations];
        [stylesheet appendFormat:
            @"/* rule %lu */ g.layer > rect.tile%lu, #tile%lu { %@ "
             "width:calc(10px /* preserve tokens */ + min(2em, 5px)); }\n",
            (unsigned long)index, (unsigned long)index, (unsigned long)index, declarations];
        [elements appendFormat:
            @"<rect id='tile%lu' class='tile%lu'/>"
             "<rect class='tile%lu' style='height:clamp(4px, 2%% + 1em, 20px)'/>",
            (unsigned long)index, (unsigned long)index, (unsigned long)index];
    }
    NSString* source = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='400' height='300'>"
         "<style>%@</style><g class='layer'>%@</g></svg>", stylesheet, elements];
    for(NSString* expression in expressions) {
        XCTAssertNotNil([IJSVGUnitLength unitWithCalculationString:expression
                                                   allowNegative:YES]);
    }
    IJSVGStyleSheet* expectedSheet = [[IJSVGStyleSheet alloc] init];
    [expectedSheet parseStyleBlock:stylesheet];
    XCTAssertEqual(expectedSheet.ruleCount, 128);
    NSString* uncommented = [source stringByReplacingOccurrencesOfString:@"/\\*.*?\\*/"
                                                             withString:@""
                                                                options:NSRegularExpressionSearch
                                                                  range:NSMakeRange(0, source.length)];
    NSData* expectedPixels = IJSVGTestRGBADataForSVG(uncommented, CGSizeMake(400, 300));
    NSData* actualPixels = IJSVGTestRGBADataForSVG(source, CGSizeMake(400, 300));
    XCTAssertNotNil(expectedPixels);
    XCTAssertNotNil(actualPixels);
    XCTAssertEqualObjects(actualPixels, expectedPixels);

    NSLog(@"CSS benchmark fixture 128 rules 256 rectangles %lu stylesheet bytes",
          (unsigned long)strlen(stylesheet.UTF8String));

    [self benchmark:@"nested expression parsing"
         iterations:3000
               work:^NSUInteger {
        NSUInteger checksum = 0;
        for(NSString* expression in expressions) {
            IJSVGUnitLength* length = [IJSVGUnitLength unitWithCalculationString:expression
                                                                 allowNegative:YES];
            if(length != nil) {
                checksum += 1 + (NSUInteger)[length computeValue:400 fontSize:12 xHeight:6];
            }
        }
        return checksum;
    }];
    [self benchmark:@"comment processing"
         iterations:100
               work:^NSUInteger {
        return IJSVGStyleSheetStringByRemovingCSSComments(stylesheet).length;
    }];
    [self benchmark:@"stylesheet without comments"
         iterations:8
               work:^NSUInteger {
        IJSVGStyleSheet* sheet = [[IJSVGStyleSheet alloc] init];
        [sheet parseStyleBlock:plainStylesheet];
        return sheet.ruleCount;
    }];
    [self benchmark:@"stylesheet with comments"
         iterations:8
               work:^NSUInteger {
        IJSVGStyleSheet* sheet = [[IJSVGStyleSheet alloc] init];
        [sheet parseStyleBlock:stylesheet];
        return sheet.ruleCount;
    }];
    [self benchmark:@"document parsing"
         iterations:4
               work:^NSUInteger {
        IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
        return svg != nil;
    }];
    [self benchmark:@"document parsing and first image"
         iterations:2
               work:^NSUInteger {
        IJSVG* svg = [[IJSVG alloc] initWithSVGString:source];
        NSImage* image = [svg imageWithSize:CGSizeMake(400, 300)];
        return [image CGImageForProposedRect:NULL context:nil hints:nil] != NULL;
    }];
}

- (void)testSupportsRequiredNestingAndBoundsResourceUse
{
    NSString* valid = [NSString stringWithFormat:@"%@1px%@",
        [@"" stringByPaddingToLength:32 * 5 withString:@"calc(" startingAtIndex:0],
        [@"" stringByPaddingToLength:32 withString:@")" startingAtIndex:0]];
    XCTAssertEqual([[self length:valid] computeValue:100], 1);
    NSString* excessive = [NSString stringWithFormat:@"%@1px%@",
        [@"" stringByPaddingToLength:65 * 5 withString:@"calc(" startingAtIndex:0],
        [@"" stringByPaddingToLength:65 withString:@")" startingAtIndex:0]];
    XCTAssertNil([IJSVGUnitLength unitWithCalculationString:excessive allowNegative:YES]);
    NSMutableArray<NSString*>* terms = [NSMutableArray arrayWithCapacity:32];
    for(NSUInteger index = 0; index < 32; index++) {
        [terms addObject:@"1px"];
    }
    NSString* many = [NSString stringWithFormat:@"min(%@)", [terms componentsJoinedByString:@", "]];
    XCTAssertEqual([[self length:many] computeValue:100], 1);
}

- (void)testGeometryRenderingAndCascade
{
    NSString* calculated =
        @"<style>rect { x: calc(10% + 5px); width: clamp(20px, 50% - 10px, 200px);"
         "height: calc(20px * 2); width: calc(1px + 1); }</style>"
         "<rect y='10' fill='red'/>";
    XCTAssertEqualObjects([self pixels:calculated],
                          [self pixels:@"<rect x='25' y='10' width='90' height='40' fill='red'/>"]);
    XCTAssertEqualObjects([self pixels:calculated width:400 height:100],
                          [self pixels:@"<rect x='45' y='10' width='190' height='40' fill='red'/>"
                                 width:400 height:100]);
    XCTAssertEqualObjects([self pixels:@"<rect x='calc(10px + 5px)' width='calc(20px + 10px)' height='40'/>"],
                          [self pixels:@"<rect x='15' width='30' height='40'/>"]);
}

- (void)testGeometryContextsAndInheritedStrokeFonts
{
    XCTAssertEqualObjects([self pixels:@"<circle cx='50' cy='50' r='calc(10% + 2px)'/>" width:100 height:100],
                          [self pixels:@"<circle cx='50' cy='50' r='12'/>" width:100 height:100]);
    XCTAssertEqualObjects([self pixels:
        @"<svg x='calc(10px)' width='calc(50% - 10px)' height='50'>"
         "<rect width='100%' height='100%'/></svg>"],
                          [self pixels:
        @"<svg x='10' width='90' height='50'><rect width='100%' height='100%'/></svg>"]);
    XCTAssertEqualObjects([self pixels:
        @"<defs><clipPath id='c' clipPathUnits='objectBoundingBox'>"
         "<rect width='calc(.5)' height='calc(1)'/></clipPath></defs>"
         "<rect width='100' height='50' clip-path='url(#c)'/>"],
                          [self pixels:@"<rect width='50' height='50'/>"]);
    XCTAssertEqualObjects([self pixels:
        @"<g font-size='10px' stroke='black' stroke-width='calc(1em + 2px)' fill='none'>"
         "<rect font-size='30px' x='20' y='20' width='100' height='50'/></g>"],
                          [self pixels:
        @"<rect stroke='black' stroke-width='12' fill='none' x='20' y='20' width='100' height='50'/>"]);
}

- (void)testCalculatedDashesRespectPathLength
{
    NSString* calculated =
        @"<path d='M0 50H100' fill='none' stroke='black' stroke-width='2' pathLength='50' "
         "stroke-dasharray='calc(10% + 2px) calc(3px)' stroke-dashoffset='calc(5% + 1px)'/>";
    NSString* literal =
        @"<path d='M0 50H100' fill='none' stroke='black' stroke-width='2' "
         "stroke-dasharray='14 6' stroke-dashoffset='7'/>";
    XCTAssertEqualObjects([self pixels:calculated width:100 height:100],
                          [self pixels:literal width:100 height:100]);
}

- (void)testImmediateNumbersMatchOwnedExpressions
{
    NSMutableArray<NSString*>* sources = [@[
        @"calc(2 + 3 * 4)", @"min(20%, 50%)", @"max(-0, 0)", @"min(-0, 0)",
        @"clamp(20%, 10%, 5%)", @"calc(1 / 0)", @"calc(0 / 0)", @"calc(1px)",
        @"calc(2em)", @"min(1, 2%)", @"unknown(1)", @"calc(1 +)"
    ] mutableCopy];
    [sources addObject:[NSString stringWithFormat:@"calc(%@1)",
        [@"" stringByPaddingToLength:600 withString:@"1 + " startingAtIndex:0]]];
    for(NSString* source in sources) {
        IJSVGStringBytes bytes = IJSVGStringGetBytes(source);
        IJSVGCSSComponents components;
        XCTAssertTrue(IJSVGCSSComponentsCreate(bytes.bytes, bytes.length, &components));
        IJSVGCSSMathExpression* expression = [IJSVGCSSMathExpression expressionWithComponents:&components atIndex:0];
        IJSVGCSSNumericValue result = { 123, NO };
        BOOL valid = IJSVGCSSMathExpressionEvaluateNumber(&components, 0, 100, &result);
        BOOL expectedValid = expression != nil && !expression.usesLength && !expression.usesFontMetrics;
        XCTAssertEqual(valid, expectedValid, @"%@", source);
        if(valid) {
            CGFloat expected = [expression evaluate:(IJSVGCSSCalculationContext) { 100, 0, 0 }];
            if(isnan(expected)) {
                XCTAssertTrue(isnan(result.value));
            } else {
                XCTAssertEqual(result.value, expected, @"%@", source);
                XCTAssertEqual(!!signbit(result.value), !!signbit(expected));
            }
            XCTAssertEqual(result.percentage, expression.lengthExponent == 1);
        } else {
            XCTAssertEqual(result.value, 123);
        }
        IJSVGCSSComponentsRelease(&components);
    }
}

- (void)testCalculatedColourBenchmark
{
    NSArray<NSString*>* colors = @[
        @"rgb(calc(20 + 31) min(120, 102) clamp(100, 153, 200) / calc(25% + 25%))",
        @"hsl(calc(60 + 60) calc(50% + 50%) max(25%, 50%) / calc(1 / 2))",
        @"oklch(calc(50% + 12.8%) calc(.1 + .15) calc(30 - .77) / calc(.25 * 2))"
    ];
    NSArray<NSString*>* literals = @[
        @"rgb(51 102 153 / 50%)", @"hsl(120 100% 50% / .5)", @"oklch(62.8% .25 29.23 / .5)"
    ];
    for(NSUInteger index = 0; index < colors.count; index++) {
        NSColor* actual = [IJSVGColor colorFromString:colors[index]];
        NSColor* expected = [IJSVGColor colorFromString:literals[index]];
        XCTAssertNotNil(actual);
        XCTAssertEqualWithAccuracy(actual.redComponent, expected.redComponent, .00001);
        XCTAssertEqualWithAccuracy(actual.greenComponent, expected.greenComponent, .00001);
        XCTAssertEqualWithAccuracy(actual.blueComponent, expected.blueComponent, .00001);
        XCTAssertEqualWithAccuracy(actual.alphaComponent, expected.alphaComponent, .00001);
    }
    [self benchmark:@"calculated colour functions"
         iterations:3000
               work:^NSUInteger {
        NSUInteger count = 0;
        for(NSString* source in colors) {
            count += [IJSVGColor colorFromString:source] != nil;
        }
        return count;
    }];
}

- (void)testSharedFunctionBenchmarks
{
    NSArray<NSString*>* colors = @[
        @"rgb(51,102,153)", @"rgba(20%,40%,60%,.5)", @"rgb(51 102 153 / 50%)",
        @"hsl(120,100%,50%)", @"hsla(240,100%,50%,.25)", @"oklch(62.8% .25 29.23 / .5)"
    ];
    [self benchmark:@"shared colour functions"
         iterations:1000
               work:^NSUInteger {
        NSUInteger count = 0;
        for(NSString* source in colors) {
            count += [IJSVGColor colorFromString:source] != nil;
        }
        return count;
    }];
    [self benchmark:@"shared URL functions"
         iterations:3000
               work:^NSUInteger {
        return [IJSVGUtils defURLs:@"url('#first') URL(#second) url('#third(with spaces)')"].count;
    }];
    [self benchmark:@"shared transform functions"
         iterations:3000
               work:^NSUInteger {
        return [IJSVGTransform transformsForString:@"translate(10 20) rotate(45) scale(.5,2) matrix(1 0 0 1 2 3)"].count;
    }];
    [self benchmark:@"shared clip functions"
         iterations:3000
               work:^NSUInteger {
        return [IJSVGClipPath clipPathWithBasicShape:@"ellipse(25% 40% at 30% 60%) fill-box"] != nil;
    }];
}




- (void)testDecimalParsingMatchesGeneralConversion
{
    NSMutableArray<NSString*>* numbers = [NSMutableArray array];
    for(NSUInteger index = 0; index < 256; index++) {
        [numbers addObject:[NSString stringWithFormat:@"%lu.%06lu", index * 7919,
                              (index * 104729) % 1000000]];
        [numbers addObject:[NSString stringWithFormat:@"-.%06lu", index * 997]];
        [numbers addObject:[NSString stringWithFormat:@"%lu.%lue%ld", index, index * 13,
                              (long)index - 128]];
    }
    NSString* zeros = [@"" stringByPaddingToLength:400 withString:@"0" startingAtIndex:0];
    [numbers addObject:[NSString stringWithFormat:@"-0.%@1", zeros]];
    [numbers addObject:[NSString stringWithFormat:@"0.%@1e400", zeros]];
    [numbers addObjectsFromArray:@[@"1e309", @"1e-999", @"-0e999", @"1.", @".5", @"+.25"]];
    for(NSString* number in numbers) {
        CGFloat expected = IJSVGParseFloatWithLength(number.UTF8String, strlen(number.UTF8String));
        for(NSString* suffix in @[@"px", @"em", @"ex", @"%"]) {
            NSString* source = [number stringByAppendingString:suffix];
            const char* bytes = source.UTF8String;
            const char* end = bytes;
            CGFloat value = 123;
            BOOL valid = IJSVGParseLengthNumber(&end, YES, &value);
            XCTAssertEqual(valid, isfinite(expected), @"%@", source);
            if(valid) {
                XCTAssertEqual(value, expected, @"%@", source);
                XCTAssertEqual(!!signbit(value), !!signbit(expected), @"%@", source);
                XCTAssertEqual(end - bytes, strlen(number.UTF8String));
            } else {
                XCTAssertEqual(end, bytes);
                XCTAssertEqual(value, 123);
            }
        }
    }
}

- (void)testValidationMatchesConstructedLengths
{
    NSArray<NSString*>* sources = @[
        @"calc(1px + 2px)", @"calc(2px - 5px)", @"calc(1 / 0)",
        @"min(NaN * 1px, 10px)", @"clamp(1px, 20%, 30px)",
        @"calc(2px * 3px / 1px)", @"calc(2px * 3px)", @"calc(1px + 1)",
        @"calc(1px + 2px) 3px", @"1px, calc(2px + 1em)", @"1px,",
        @"1px/**/2px", @"-1px", @"-1e-999px", @"calc(-1px)",
        @"1px/**/ 2px", @"calc()", @"calc(1px", @"url(#paint)",
        @"calc(1px) unknown", @"calc(1px),,2px", @""
    ];
    NSMutableArray<NSString*>* expanded = [sources mutableCopy];
    NSString* terms = [@"" stringByPaddingToLength:100 * 6 withString:@" + 1px" startingAtIndex:0];
    [expanded addObject:[NSString stringWithFormat:@"calc(1px%@)", terms]];
    [expanded addObject:[NSString stringWithFormat:@"calc(1px%@ + 1)", terms]];
    for(NSString* source in expanded) {
        XCTAssertEqual(IJSVGUnitLengthsAreValid(source, NO, NO),
                       IJSVGUnitLengthsFromString(source) != nil, @"%@", source);
        for(NSUInteger negative = 0; negative < 2; negative++) {
            XCTAssertEqual(IJSVGUnitLengthsAreValid(source, negative != 0, YES),
                           IJSVGLengthFromString(source, negative != 0) != nil, @"%@", source);
        }
    }
}

- (void)testCommentBufferPreservesUnicodeAndEscapes
{
    NSArray<NSArray<NSString*>*>* pairs = @[
        @[@"/*全部*/", @""],
        @[@"a/*一*/b/*二*/c", @"abc"],
        @[@"é/*一*/😀", @"é😀"],
        @[@"calc(1px/*一*/ + 2px)/*二*/", @"calc(1px/**/ + 2px)"],
        @[@"calc(min(1px, 2px)/*一*/)/*二*/", @"calc(min(1px, 2px)/**/)"],
        @[@"calc(1px/*未完成", @"calc(1px/*"],
        @[@"é/*未完成", @"é"],
        @[@"calc('é/*literal*/😀' + 1px)/*remove*/", @"calc('é/*literal*/😀' + 1px)"],
        @[@"calc(foo\\)/*keep*/ + 1px)/*remove*/", @"calc(foo\\)/**/ + 1px)"],
        @[@"calc(foo\\/*literal*/ + 1px)/*remove*/", @"calc(foo\\/*literal*/ + 1px)"]
    ];
    for(NSArray<NSString*>* pair in pairs) {
        XCTAssertEqualObjects(IJSVGStyleSheetStringByRemovingCSSComments(pair[0]), pair[1]);
    }
}

- (void)testTrimmedDeclarationsOwnMutableInput
{
    NSMutableString* source = [NSMutableString stringWithString:@"calc(1px + 2px)"];
    BOOL important = YES;
    NSString* value = IJSVGStyleSheetDeclarationValue(source, &important);
    [source setString:@"changed"];
    XCTAssertEqualObjects(value, @"calc(1px + 2px)");
    XCTAssertFalse(important);
    XCTAssertNil(IJSVGStyleSheetDeclarationValue(@"", &important));
    XCTAssertNil(IJSVGStyleSheetDeclarationValue(@"   ", &important));
    XCTAssertEqualObjects(IJSVGStyleSheetDeclarationValue(@"  calc(1px + 2px) !IMPORTANT  ", &important),
                          @"calc(1px + 2px)");
    XCTAssertTrue(important);
    XCTAssertEqualObjects(IJSVGStyleSheetDeclarationValue(@"url('!important')", &important),
                          @"url('!important')");
    XCTAssertFalse(important);
}

- (void)testFunctionNamesUseExactASCIIMatches
{
    const struct {
        const char* name;
        IJSVGCSSFunction function;
    } cases[] = {
        { "calc", IJSVGCSSFunctionCalc },
        { "min", IJSVGCSSFunctionMin },
        { "max", IJSVGCSSFunctionMax },
        { "clamp", IJSVGCSSFunctionClamp },
        { "url", IJSVGCSSFunctionURL },
        { "path", IJSVGCSSFunctionPath },
        { "inset", IJSVGCSSFunctionInset },
        { "rect", IJSVGCSSFunctionRect },
        { "xywh", IJSVGCSSFunctionXYWH },
        { "polygon", IJSVGCSSFunctionPolygon },
        { "shape", IJSVGCSSFunctionShape },
        { "rgb", IJSVGCSSFunctionRGB },
        { "rgba", IJSVGCSSFunctionRGBA },
        { "hsl", IJSVGCSSFunctionHSL },
        { "hsla", IJSVGCSSFunctionHSLA },
        { "oklch", IJSVGCSSFunctionOKLCH },
        { "matrix", IJSVGCSSFunctionMatrix },
        { "translate", IJSVGCSSFunctionTranslate },
        { "translatex", IJSVGCSSFunctionTranslateX },
        { "translatey", IJSVGCSSFunctionTranslateY },
        { "scale", IJSVGCSSFunctionScale },
        { "rotate", IJSVGCSSFunctionRotate },
        { "skewx", IJSVGCSSFunctionSkewX },
        { "skewy", IJSVGCSSFunctionSkewY },
        { "circle", IJSVGCSSFunctionCircle },
        { "ellipse", IJSVGCSSFunctionEllipse },
        { "var", IJSVGCSSFunctionVar }
    };
    for(NSUInteger index = 0; index < sizeof(cases) / sizeof(*cases); index++) {
        NSString* name = [NSString stringWithUTF8String:cases[index].name];
        IJSVGCSSFunction expected = cases[index].function;
        XCTAssertEqual(IJSVGCSSFunctionForName(name.UTF8String), expected);
        XCTAssertEqual(IJSVGCSSFunctionForName(name.uppercaseString.UTF8String), expected);
        XCTAssertEqual(IJSVGCSSFunctionForName([name stringByAppendingString:@"extra"].UTF8String),
                       IJSVGCSSFunctionUnknown);
        XCTAssertEqual(IJSVGCSSFunctionForName([name substringToIndex:name.length - 1].UTF8String),
                       [name isEqualToString:@"rgba"] ? IJSVGCSSFunctionRGB :
                           ([name isEqualToString:@"hsla"] ? IJSVGCSSFunctionHSL :
                               ([name hasPrefix:@"translate"] && name.length == 10 ?
                                   IJSVGCSSFunctionTranslate : IJSVGCSSFunctionUnknown)));
    }
    XCTAssertEqual(IJSVGCSSFunctionForName(NULL), IJSVGCSSFunctionUnknown);
    XCTAssertEqual(IJSVGCSSFunctionForName(""), IJSVGCSSFunctionUnknown);
    XCTAssertEqual(IJSVGCSSFunctionForName("cälc"), IJSVGCSSFunctionUnknown);
}

- (void)testComponentStorageGrowthAndFailure
{
    for(NSUInteger count = 31; count <= 129; count++) {
        NSMutableString* source = [NSMutableString stringWithString:@"calc("];
        for(NSUInteger index = 1; index < count; index++) {
            [source appendString:@"1 "];
        }
        [source appendString:@")"];
        IJSVGCSSComponents components;
        XCTAssertTrue(IJSVGCSSComponentsCreate(source.UTF8String, [source lengthOfBytesUsingEncoding:NSUTF8StringEncoding], &components));
        XCTAssertEqual(components.count, count);
        XCTAssertEqual(components.values[0].next, count);
        for(NSUInteger index = 1; index < components.count; index++) {
            XCTAssertEqual(components.values[index].number, 1);
            XCTAssertEqual(components.values[index].next, index + 1);
        }
        IJSVGCSSComponentsRelease(&components);
        [source deleteCharactersInRange:NSMakeRange(source.length - 1, 1)];
        XCTAssertFalse(IJSVGCSSComponentsCreate(source.UTF8String, [source lengthOfBytesUsingEncoding:NSUTF8StringEncoding], &components));
        IJSVGCSSComponentsRelease(&components);
        XCTAssertFalse(IJSVGCSSComponentsCreate(NULL, 0, &components));
        IJSVGCSSComponentsRelease(&components);
        XCTAssertTrue(IJSVGCSSComponentsCreate("", 0, &components));
        XCTAssertEqual(components.count, 0);
        IJSVGCSSComponentsRelease(&components);
    }
}

- (void)testIntegerParsingMatchesGeneralConversion
{
    NSArray<NSString*>* numbers = @[
        @"0", @"-0", @"+0", @"00012", @"-00012", @"123456789",
        @"9007199254740991", @"9007199254740993", @"999999999999999999999999",
        @"12.25", @"-0.0", @"1e2", @"-1e-320"
    ];
    for(NSString* number in numbers) {
        for(NSString* suffix in @[@"", @"px", @"em", @"ex", @"%", @","]) {
            NSString* source = [number stringByAppendingString:suffix];
            const char* bytes = source.UTF8String;
            const char* end = bytes;
            CGFloat value = 0;
            CGFloat expected = IJSVGParseFloatWithLength(number.UTF8String, strlen(number.UTF8String));
            XCTAssertTrue(IJSVGParseLengthNumber(&end, YES, &value), @"%@", source);
            XCTAssertEqual(value, expected, @"%@", source);
            XCTAssertEqual(!!signbit(value), !!signbit(expected), @"%@", source);
            XCTAssertEqual(end - bytes, strlen(number.UTF8String));
        }
    }
    for(NSString* number in @[@"-1px", @"-1e-999px", @"1e999px",
                              [@"" stringByPaddingToLength:400 withString:@"9" startingAtIndex:0]]) {
        const char* bytes = number.UTF8String;
        const char* end = bytes;
        CGFloat value = 123;
        XCTAssertFalse(IJSVGParseLengthNumber(&end, NO, &value));
        XCTAssertEqual(end, bytes);
        XCTAssertEqual(value, 123);
    }
}

- (void)testSharedFunctionComponentsAndCompatibilityAdapter
{
    const char* source = "rgba(calc(1 + max(2, 3)), 0, 0, .5) url('#paint(with spaces)')";
    IJSVGCSSComponents components;
    XCTAssertTrue(IJSVGCSSComponentsCreate(source, strlen(source), &components));
    XCTAssertGreaterThan(components.count, 0);
    if(components.count == 0) {
        IJSVGCSSComponentsRelease(&components);
        return;
    }
    XCTAssertEqual(components.values[0].function, IJSVGCSSFunctionRGBA);
    XCTAssertEqual(components.values[1].function, IJSVGCSSFunctionCalc);
    const IJSVGCSSComponent* url = components.values + components.values[0].next;
    XCTAssertEqual(url->function, IJSVGCSSFunctionURL);
    XCTAssertEqual(url->next, components.count);
    char* arguments = IJSVGCSSComponentCopyArguments(&components, url);
    XCTAssertEqual(strcmp(arguments, "'#paint(with spaces)'"), 0);
    free(arguments);
    IJSVGCSSComponentsRelease(&components);

    NSUInteger count = 0;
    BOOL valid = NO;
    IJSVGParsingStringMethod** methods = IJSVGParsingMethodParseStringWithValidation(source, &count, &valid);
    XCTAssertTrue(valid);
    XCTAssertEqual(count, 2);
    if(count == 2) {
        XCTAssertEqual(strcmp(methods[0]->parameters, "calc(1 + max(2, 3)), 0, 0, .5"), 0);
        XCTAssertEqual(strcmp(methods[1]->name, "url"), 0);
    }
    IJSVGParsingStringMethodsRelease(methods, count);
}

- (void)testStringBytesPreserveEncodedLength
{
    IJSVGStringBytes missing = IJSVGStringGetBytes(nil);
    XCTAssertEqual(missing.bytes, NULL);
    XCTAssertEqual(missing.length, 0);
    for(NSString* string in @[@"", @"calc(1px)", @"é😀", @"url(#first)\0url(#second)"]) {
        IJSVGStringBytes source = IJSVGStringGetBytes(string);
        NSData* expected = [string dataUsingEncoding:NSUTF8StringEncoding];
        XCTAssertNotEqual(source.bytes, NULL);
        XCTAssertEqual(source.length, expected.length);
        XCTAssertEqual(memcmp(source.bytes, expected.bytes, source.length), 0);
        XCTAssertEqual(source.bytes[source.length], '\0');
    }
}

- (void)testExplicitByteLengthsRejectEmbeddedNUL
{
    for(NSString* source in @[@"calc(1px + 2px)\0calc(3px)", @"url('#é')\0url(#second)",
                              @"\0calc(1px)", @"calc(1px)\0"]) {
        IJSVGCSSComponents components;
        XCTAssertFalse(IJSVGCSSComponentsCreate(source.UTF8String,
            [source lengthOfBytesUsingEncoding:NSUTF8StringEncoding], &components));
        XCTAssertEqual(components.count, 0);
        IJSVGCSSComponentsRelease(&components);
    }
    const char* source = "calc(1px)";
    for(NSUInteger length = strlen(source) - 1; length <= strlen(source) + 1; length++) {
        IJSVGCSSComponents components;
        XCTAssertEqual(IJSVGCSSComponentsCreate(source, length, &components), length == strlen(source));
        IJSVGCSSComponentsRelease(&components);
    }
    XCTAssertEqualObjects([IJSVGUtils defURL:@"url('#é')"], @"é");
    XCTAssertNil([IJSVGUnitLength unitWithCalculationString:@"calc(1px)\0junk" allowNegative:YES]);
    XCTAssertNil([IJSVGUnitLength unitWithString:@"12px\0junk"]);
    XCTAssertFalse(IJSVGUnitLengthsAreValid(@"12px\0junk", YES, YES));
    XCTAssertNil([IJSVGColor colorFromString:@"rgba(1,2,3,1)\0junk"]);
    XCTAssertNil([IJSVGColor colorFromString:@"red\0junk"]);
    XCTAssertFalse([IJSVGColor isNoneOrTransparent:@"none\0junk"]);
    XCTAssertEqual([IJSVGTransform transformsForString:@"translate(1 2)\0scale(2)"].count, 0);
    XCTAssertNil([IJSVGClipPath clipPathWithBasicShape:@"circle(20%)\0junk"]);
    NSString* declaration = @"width:calc(1px + 2px)\0;height:4px";
    XCTAssertNil(IJSVGStyleSheetStringByRemovingCSSComments(declaration));
    XCTAssertEqual([IJSVGStyleSheetStyle parseStyleString:declaration].properties.count, 0);
    XCTAssertEqual([IJSVGStyleSheetStyle parseStyleString:declaration removeComments:NO].properties.count, 0);
    IJSVGStyleSheet* sheet = [[IJSVGStyleSheet alloc] init];
    [sheet parseStyleBlock:@"rect { width:1px }\0circle { width:2px }"];
    XCTAssertEqual(sheet.ruleCount, 0);
}

- (void)testDeclarationKeywordsUseExactMatches
{
    for(NSString* value in @[@"VIEW-BOX", @"fill-box", @"STROKE-BOX", @"content-box",
                             @"border-box", @"INITIAL", @"unset", @"revert", @"revert-layer"]) {
        IJSVGStyleSheetStyle* style = [[IJSVGStyleSheetStyle alloc] init];
        [style setPropertyValue:value forProperty:@"transform-box"];
        XCTAssertEqualObjects([style property:@"transform-box"], value);
    }
    for(NSString* value in @[@"fill-box-extra", @"fill-box\0junk", @"none\0junk"]) {
        IJSVGStyleSheetStyle* style = [[IJSVGStyleSheetStyle alloc] init];
        [style setPropertyValue:value forProperty:@"transform-box"];
        XCTAssertNil([style property:@"transform-box"]);
        [style setPropertyValue:value forProperty:@"stroke-dasharray"];
        XCTAssertNil([style property:@"stroke-dasharray"]);
    }
}

- (void)testDeclarationAllocationBenchmark
{
    [self benchmark:@"pending font declarations"
         iterations:3000
               work:^NSUInteger {
        return [IJSVGStyleSheetStyle parseStyleString:@"font:var(--font)"].properties.count;
    }];
    [self benchmark:@"keyword declarations"
         iterations:3000
               work:^NSUInteger {
        return [IJSVGStyleSheetStyle parseStyleString:
            @"transform-box:FILL-BOX;stroke-dasharray:NONE"].properties.count;
    }];
}

- (void)testEscapedFunctionNameBoundaries
{
    NSArray<NSString*>* valid = @[@"\\75rl(#paint)", @"\\000075rl(#paint)",
        @"\\75\r\nrl(#paint)", @"u\\r\\l(#paint)"];
    for(NSString* value in valid) {
        XCTAssertEqualObjects([IJSVGUtils defURL:value], @"paint");
    }
    for(NSString* value in @[@"\\0rl(#paint)", @"\\d800rl(#paint)",
                             @"\\110000rl(#paint)", @"\\e9rl(#paint)",
                             @"\\75rlxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx(#paint)"]) {
        XCTAssertNil([IJSVGUtils defURL:value]);
    }
}

- (void)testEscapedFunctionBenchmark
{
    [self benchmark:@"escaped URL functions"
         iterations:3000
               work:^NSUInteger {
        return [IJSVGUtils defURLs:@"u\\72l('#first') \\55RL(#second) \\75\\72\\6c('#third')"].count;
    }];
}

- (void)testDefinitionLookupBenchmark
{
    NSArray<NSString*>* values = @[
        @"none", @"red", @"#ff0000", @"currentColor",
        @"rgb(calc(255 / 2) min(10, 20) 0 / calc(1 / 2))",
        @"url(#paint)", @" URL('#paint') red", @"u\\\\72l(#paint)"
    ];
    [self benchmark:@"mixed definition lookups"
         iterations:3000
               work:^NSUInteger {
        NSUInteger count = 0;
        for(NSString* value in values) {
            count += [IJSVGUtils defURL:value] != nil;
        }
        return count;
    }];
}

- (void)testSharedURLParsing
{
    XCTAssertNil([IJSVGUtils defURL:@"url(#paint) rgb("]);
    XCTAssertEqualObjects([IJSVGUtils defURL:@" /* leading */ URL(#paint) red"], @"paint");
    for(NSString* source in @[@"red", @"none", @"#fff", @"rgba(1,2,3,.5)", @"urlwrong(#paint)"]) {
        XCTAssertNil([IJSVGUtils defURL:source]);
        XCTAssertEqual([IJSVGUtils defURLs:source].count, 0);
    }
    for(NSString* source in @[@"url(#first)\0url(#second)", @"url('#é')\0url(#second)"]) {
        XCTAssertNil([IJSVGUtils defURL:source]);
        XCTAssertEqual([IJSVGUtils defURLs:source].count, 0);
    }
    XCTAssertEqualObjects([IJSVGUtils defURL:@"u\\72l('#paint(with spaces)')"], @"paint(with spaces)");
    XCTAssertEqualObjects([IJSVGUtils defURL:@"URL(#paint/**/literal)"], @"paint/**/literal");
    const char* escaped = "url(#paint\\20 name)";
    IJSVGCSSComponents components;
    XCTAssertTrue(IJSVGCSSComponentsCreate(escaped, strlen(escaped), &components));
    IJSVGCSSComponentsRelease(&components);
    XCTAssertEqualObjects([IJSVGUtils defURLs:@"url('#first') /* gap */ URL(#second)"],
                          (@[@"first", @"second"]));
    for(NSString* source in @[@"url(#a b)", @"url(#a(b))", @"url('#a)", @"url(#a))",
                              @"url(#a) junk", @"url(#a) rgba(0,0,0,1)"]) {
        XCTAssertEqual([IJSVGUtils defURLs:source].count, 0, @"%@", source);
    }
}

- (void)testSharedColorFunctionsAndNestedCalculations
{
    for(NSString* source in @[@"RGBA(calc(255 / 2), min(10, 20), 0, calc(1 / 2))",
                              @"r\\67 ba(calc(50%) 10 0 / 50%)",
                              @"rgb(calc(50% / 100% * 255) 10 0 / .5)"]) {
        NSColor* color = [[IJSVGColor colorFromString:source] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
        XCTAssertNotNil(color, @"%@", source);
        XCTAssertEqualWithAccuracy(color.redComponent, .5, .0001);
        XCTAssertEqualWithAccuracy(color.greenComponent, 10.f / 255.f, .0001);
        XCTAssertEqualWithAccuracy(color.alphaComponent, .5, .0001);
    }
    for(NSString* source in @[@"HSL(120, 100%, 50%)", @"hsl(120deg 100% 50%)",
                              @"hsl(.333333333333turn 100% 50%)"]) {
        NSColor* color = [[IJSVGColor colorFromString:source] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
        XCTAssertNotNil(color);
        XCTAssertEqualWithAccuracy(color.greenComponent, 1, .0001);
        XCTAssertEqualWithAccuracy(color.redComponent, 0, .0001);
    }
    XCTAssertNotNil([IJSVGColor colorFromString:@"OKLCH(62.8% .25 29.23 / .5)"]);
    for(NSString* source in @[@"rgbwrong(1,2,3)", @"rgb(1 2 3) trailing",
                              @"hsl(1)", @"hsl(1 2)", @"rgba(calc(2px) 0 0 / 1)",
                              @"rgb(1,2,3))", @"oklch(1 .2 30) rgb(1 2 3)"]) {
        XCTAssertNil([IJSVGColor colorFromString:source], @"%@", source);
    }
}

- (void)testSharedTransformNumbersAndSeparators
{
    for(NSString* source in @[@"translate(1-2)", @"translate(1,-2)", @"translate(1 -2)",
                              @"translate(1. -2.)", @"translate(1e0 -2e0)"]) {
        NSArray<IJSVGTransform*>* transforms = [IJSVGTransform transformsForString:source];
        XCTAssertEqual(transforms.count, 1, @"%@", source);
        if(transforms.count == 1) {
            XCTAssertEqual(transforms[0].parameters[0], 1);
            XCTAssertEqual(transforms[0].parameters[1], -2);
        }
    }
    for(NSString* arguments in @[@"", @",1", @"1,", @"1,,2", @"1 2 3", @"1/**/2",
                                 @"1 /* comment */ 2", @"0x10", @"1e999", @"NaN",
                                 @"calc(1)", @"1pxjunk", @"1PX", @"1\\\\px", @"1deg"]) {
        NSString* source = [NSString stringWithFormat:@"translate(%@)", arguments];
        for(NSNumber* css in @[@NO, @YES]) {
            XCTAssertEqual([IJSVGTransform transformsForString:source allowCSSUnits:css.boolValue].count,
                0, @"%@", source);
            source = [@"scale(2) " stringByAppendingString:source];
            XCTAssertEqual([IJSVGTransform transformsForString:source allowCSSUnits:css.boolValue].count,
                1, @"%@", source);
            source = [NSString stringWithFormat:@"translate(%@)", arguments];
        }
    }
    IJSVGTransform* negativeZero = [IJSVGTransform transformsForString:@"scale(-0)"].firstObject;
    XCTAssertNotNil(negativeZero);
    XCTAssertTrue(signbit(negativeZero.parameters[0]));
}

- (void)testShapePositionsReuseBuffers
{
    for(NSString* shape in @[@"circle(25%)", @"ellipse(25% 30%)"]) {
        NSString* centered = [shape stringByReplacingOccurrencesOfString:@")" withString:@" at center)"];
        NSString* prefix = @"<rect width='200' height='100' clip-path='";
        NSString* suffix = @"'/>";
        NSData* implicit = [self pixels:[NSString stringWithFormat:@"%@%@%@", prefix, shape, suffix]];
        NSData* explicit = [self pixels:[NSString stringWithFormat:@"%@%@%@", prefix, centered, suffix]];
        XCTAssertEqualObjects(implicit, explicit);
    }
    for(NSString* source in @[@"circle(20% at)", @"circle(20% at 10% 20% 0)",
                              @"circle(20% at left right)", @"ellipse(20% at center)"]) {
        XCTAssertNil([IJSVGClipPath clipPathWithBasicShape:source], @"%@", source);
    }
    for(NSString* source in @[@"circle(CLOSEST-SIDE AT center)", @"ellipse(farthest-side closest-side at top left)",
                              @"circle(20% at 10% 20%)", @"circle(at bottom)"]) {
        XCTAssertNotNil([IJSVGClipPath clipPathWithBasicShape:source], @"%@", source);
    }
    NSMutableString* source = [@"width:calc(1px + 2px)" mutableCopy];
    NSString* clean = IJSVGStyleSheetStringByRemovingCSSComments(source);
    [source setString:@"height:4px"];
    XCTAssertEqualObjects(clean, @"width:calc(1px + 2px)");
}

- (void)testSharedTransformAndShapeFunctionNames
{
    NSArray<IJSVGTransform*>* transforms = [IJSVGTransform transformsForString:@"tr\\61nslate(10 20) ROTATE(45)"];
    XCTAssertEqual(transforms.count, 2);
    XCTAssertEqual(transforms.firstObject.command, IJSVGTransformCommandTranslate);
    XCTAssertEqualWithAccuracy(transforms.firstObject.parameters[0], 10, .0001);
    XCTAssertNotNil([IJSVGClipPath clipPathWithBasicShape:@"c\\69rcle(20%) fill-box"]);
    XCTAssertNil([IJSVGClipPath clipPathWithBasicShape:@"circle(20%))"]);
}

- (void)testCommentScanningPreservesEscapesAndQuotedFunctions
{
    NSArray<NSArray<NSString*>*>* cases = @[
        @[@"width:c\\61lc(1/* boundary */px)", @"width:c\\61lc(1/**/px)"],
        @[@"width:CLAMP(1px, MIN(2px /* note */ + 1px, 4px), 5px)",
          @"width:CLAMP(1px, MIN(2px /**/ + 1px, 4px), 5px)"],
        @[@"font-family:'calc(/* literal */)'; /* discard */ width:1px",
          @"font-family:'calc(/* literal */)';  width:1px"],
        @[@"fill:url('#calc(/* literal */)'); /* discard */ width:1px",
          @"fill:url('#calc(/* literal */)');  width:1px"],
        @[@"width:notcalc(1/* discard */px); width:calc(2/* keep */px)",
          @"width:notcalc(1px); width:calc(2/**/px)"],
        @[@"width:calc(1px /* unterminated", @"width:calc(1px /*"]
    ];
    for(NSArray<NSString*>* pair in cases) {
        XCTAssertEqualObjects(IJSVGStyleSheetStringByRemovingCSSComments(pair[0]), pair[1]);
    }
    NSData* expected = [self pixels:@"<rect width='30' height='20'/>"];
    XCTAssertEqualObjects([self pixels:
        @"<style>rect { width:30px; width:c\\61lc(1/**/px); height:20px; }</style><rect/>"],
                          expected);
}

- (void)testCommentsPreserveTokenBoundariesInStyles
{
    NSData* expected = [self pixels:@"<rect width='30' height='20'/>"];
    for(NSString* invalid in @[@"calc(1/**/px)", @"calc(10px/**/+/**/20px)"]) {
        NSString* inlineStyle = [NSString stringWithFormat:
            @"<rect style='width:30px; width:%@; height:20px'/>", invalid];
        NSString* styleSheet = [NSString stringWithFormat:
            @"<style>rect { width:30px; width:%@; height:20px; }</style><rect/>", invalid];
        XCTAssertEqualObjects([self pixels:inlineStyle], expected);
        XCTAssertEqualObjects([self pixels:styleSheet], expected);
    }
    XCTAssertEqualObjects([self pixels:@"<rect style='width:calc(10px /* ) */ + 20px); height:20px'/>"],
                          expected);
}

- (void)testStrokeRenderingAndFontRelativeCalculations
{
    NSString* calculated =
        @"<g font-size='10px' fill='none' stroke='black' stroke-width='calc(1em + 2px)' "
         "stroke-dasharray='min(2px, 3px) calc(1px + 2px)' stroke-dashoffset='calc(1px - 2px)'>"
         "<rect x='20' y='20' width='100' height='50'/></g>";
    NSString* literal =
        @"<g fill='none' stroke='black' stroke-width='12' stroke-dasharray='2 3' stroke-dashoffset='-1'>"
         "<rect x='20' y='20' width='100' height='50'/></g>";
    XCTAssertEqualObjects([self pixels:calculated], [self pixels:literal]);
    XCTAssertEqualObjects([self pixels:
        @"<rect style='font-size:10px; x:calc(1em + 10%); width:calc(3em + 10%); height:20px'/>"],
                          [self pixels:@"<rect x='30' width='50' height='20'/>"]);
}

@end
