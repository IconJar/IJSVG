//
//  IJSVGUtilityParsingTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"
#import <IJSVG/IJSVGBitFlags.h>
#import <IJSVG/IJSVGBitFlags64.h>
#import <IJSVG/IJSVGCommandParser.h>
#import <IJSVG/IJSVGFeatureFlag.h>
#import <IJSVG/IJSVGFeatureFlags.h>
#import <IJSVG/IJSVGGradientUnitLength.h>
#import <IJSVG/IJSVGMath.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGUnitLength.h>
#import <IJSVG/IJSVGUnitPoint.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGUnitSize.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGViewBox.h>

@interface IJSVGUtilityParsingTests : XCTestCase
@end

@implementation IJSVGUtilityParsingTests

- (void)testParseFloatHandlesSignsDecimalsAndExponents
{
    XCTAssertEqualWithAccuracy(IJSVGParseFloat("12.5"), 12.5f, 0.0001f);
    XCTAssertEqualWithAccuracy(IJSVGParseFloat("-0.125"), -0.125f, 0.0001f);
    XCTAssertEqualWithAccuracy(IJSVGParseFloat("+4.25e2"), 425.f, 0.0001f);
    XCTAssertEqualWithAccuracy(IJSVGParseFloat("3E-2"), 0.03f, 0.0001f);
}

- (void)testScanFloatsSplitsOnWhitespaceCommasSignsAndRepeatedDecimals
{
    NSInteger count = 0;
    CGFloat* values = [IJSVGUtils scanFloatsFromString:@"M10,-5.5.25e2 +3e-2"
                                                  size:&count];

    XCTAssertEqual(count, 4);
    XCTAssertEqualWithAccuracy(values[0], 10.f, 0.0001f);
    XCTAssertEqualWithAccuracy(values[1], -5.5f, 0.0001f);
    XCTAssertEqualWithAccuracy(values[2], 25.f, 0.0001f);
    XCTAssertEqualWithAccuracy(values[3], 0.03f, 0.0001f);

    free(values);
}

- (void)testPathDataStreamParsesArcFlagSequence
{
    IJSVGPathDataSequence sequence[] = {
        kIJSVGPathDataSequenceTypeFloat,
        kIJSVGPathDataSequenceTypeFloat,
        kIJSVGPathDataSequenceTypeFloat,
        kIJSVGPathDataSequenceTypeFlag,
        kIJSVGPathDataSequenceTypeFlag,
        kIJSVGPathDataSequenceTypeFloat,
        kIJSVGPathDataSequenceTypeFloat,
    };
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    NSInteger commandsFound = 0;
    const char* command = "30 50 0 0 1 162.55 162.45";
    CGFloat* values = IJSVGParsePathDataStreamSequence(command,
                                                       strlen(command),
                                                       stream,
                                                       sequence,
                                                       7,
                                                       &commandsFound);

    XCTAssertNotEqual(values, NULL);
    XCTAssertEqual(commandsFound, 1);
    XCTAssertEqualWithAccuracy(values[0], 30.f, 0.0001f);
    XCTAssertEqualWithAccuracy(values[1], 50.f, 0.0001f);
    XCTAssertEqualWithAccuracy(values[2], 0.f, 0.0001f);
    XCTAssertEqualWithAccuracy(values[3], 0.f, 0.0001f);
    XCTAssertEqualWithAccuracy(values[4], 1.f, 0.0001f);
    XCTAssertEqualWithAccuracy(values[5], 162.55f, 0.0001f);
    XCTAssertEqualWithAccuracy(values[6], 162.45f, 0.0001f);

    free(values);
    IJSVGPathDataStreamRelease(stream);
}

- (void)testPathDataStreamRejectsInvalidArcFlagValues
{
    IJSVGPathDataSequence sequence[] = {
        kIJSVGPathDataSequenceTypeFloat,
        kIJSVGPathDataSequenceTypeFloat,
        kIJSVGPathDataSequenceTypeFloat,
        kIJSVGPathDataSequenceTypeFlag,
        kIJSVGPathDataSequenceTypeFlag,
        kIJSVGPathDataSequenceTypeFloat,
        kIJSVGPathDataSequenceTypeFloat,
    };
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    NSInteger commandsFound = NSNotFound;
    const char* command = "30 50 0 2 1 162.55 162.45";
    CGFloat* values = IJSVGParsePathDataStreamSequence(command,
                                                       strlen(command),
                                                       stream,
                                                       sequence,
                                                       7,
                                                       &commandsFound);

    XCTAssertEqual(values, NULL);
    XCTAssertEqual(commandsFound, NSNotFound);

    IJSVGPathDataStreamRelease(stream);
}

- (void)testPathDataStreamGrowsPastInitialFloatAndCharacterCapacity
{
    NSMutableString* command = [NSMutableString string];
    for(NSInteger i = 0; i < 75; i++) {
        [command appendFormat:@"%ld.125 ", (long)i];
    }

    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(1, 3);
    NSInteger count = 0;
    CGFloat* values = IJSVGParsePathDataStreamSequence(command.UTF8String,
                                                       strlen(command.UTF8String),
                                                       stream,
                                                       NULL,
                                                       1,
                                                       &count);

    XCTAssertEqual(count, 75);
    XCTAssertEqualWithAccuracy(values[0], 0.125f, 0.0001f);
    XCTAssertEqualWithAccuracy(values[74], 74.125f, 0.0001f);

    free(values);
    IJSVGPathDataStreamRelease(stream);
}

- (void)testPathDataStreamReturnsNoValuesForZeroCommandLength
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    NSInteger commandsFound = NSNotFound;
    CGFloat* values = IJSVGParsePathDataStreamSequence("10 20", 5, stream, NULL, 0, &commandsFound);

    XCTAssertEqual(values, NULL);
    XCTAssertEqual(commandsFound, 0);

    IJSVGPathDataStreamRelease(stream);
}

- (void)testMethodParserSplitsNamesAndTrimmedParameters
{
    NSUInteger count = 0;
    IJSVGParsingStringMethod** methods = IJSVGParsingMethodParseString(" translate ( 10, 20 ) rotate(45) scale( 2 ) ", &count);

    XCTAssertEqual(count, 3u);
    XCTAssertEqual(strcmp(methods[0]->name, "translate"), 0);
    XCTAssertEqual(strcmp(methods[0]->parameters, "10, 20"), 0);
    XCTAssertEqual(strcmp(methods[1]->name, "rotate"), 0);
    XCTAssertEqual(strcmp(methods[1]->parameters, "45"), 0);
    XCTAssertEqual(strcmp(methods[2]->name, "scale"), 0);
    XCTAssertEqual(strcmp(methods[2]->parameters, "2"), 0);

    IJSVGParsingStringMethodsRelease(methods, count);
}

- (void)testMethodParserDropsIncompleteMethod
{
    NSUInteger count = 0;
    IJSVGParsingStringMethod** methods = IJSVGParsingMethodParseString("translate(10, 20", &count);

    XCTAssertEqual(count, 0u);

    IJSVGParsingStringMethodsRelease(methods, count);
}

- (void)testTransformsForStringCreatesCommandsAndParsedParameters
{
    NSArray<IJSVGTransform*>* transforms = [IJSVGTransform transformsForString:@"translate(10 -5) rotate(45) scale(.5,2e1) unknown(1)"];

    XCTAssertEqual(transforms.count, 3u);
    XCTAssertEqual(transforms[0].command, IJSVGTransformCommandTranslate);
    XCTAssertEqual(transforms[0].parameterCount, 2);
    XCTAssertEqualWithAccuracy(transforms[0].parameters[0], 10.f, 0.0001f);
    XCTAssertEqualWithAccuracy(transforms[0].parameters[1], -5.f, 0.0001f);
    XCTAssertEqual(transforms[1].command, IJSVGTransformCommandRotate);
    XCTAssertEqualWithAccuracy(transforms[1].parameters[0], 45.f, 0.0001f);
    XCTAssertEqual(transforms[2].command, IJSVGTransformCommandScale);
    XCTAssertEqualWithAccuracy(transforms[2].parameters[0], 0.5f, 0.0001f);
    XCTAssertEqualWithAccuracy(transforms[2].parameters[1], 20.f, 0.0001f);
}

- (void)testUnitLengthParsesNumbersPercentagesAndAbsoluteUnits
{
    IJSVGUnitLength* number = [IJSVGUnitLength unitWithString:@" 12.5px "];
    IJSVGUnitLength* percent = [IJSVGUnitLength unitWithString:@"25%"];
    IJSVGUnitLength* inch = [IJSVGUnitLength unitWithString:@"2in"];
    IJSVGUnitLength* empty = [IJSVGUnitLength unitWithString:@"   "];

    XCTAssertEqual(number.type, IJSVGUnitLengthTypeNumber);
    XCTAssertEqual(number.originalType, IJSVGUnitLengthTypePX);
    XCTAssertEqualWithAccuracy(number.value, 12.5f, 0.0001f);
    XCTAssertEqual(percent.type, IJSVGUnitLengthTypePercentage);
    XCTAssertEqual(percent.originalType, IJSVGUnitLengthTypePercentage);
    XCTAssertEqualWithAccuracy(percent.value, 0.25f, 0.0001f);
    XCTAssertEqualWithAccuracy([percent computeValue:200.f], 50.f, 0.0001f);
    XCTAssertEqual(inch.originalType, IJSVGUnitLengthTypeIN);
    XCTAssertEqualWithAccuracy(inch.value, 192.f, 0.0001f);
    XCTAssertNil(empty);
}

- (void)testFloatingPointStringFormattingOptions
{
    IJSVGFloatingPointOptions rounded = IJSVGFloatingPointOptionsMake(YES, 2);
    IJSVGUnitLength* percent = [IJSVGUnitLength unitWithString:@"12.345%"];
    IJSVGUnitLength* number = [IJSVGUnitLength unitWithString:@"3.14159"];

    XCTAssertEqualObjects([percent stringValueWithFloatingPointOptions:rounded], @"12.34%");
    XCTAssertEqualObjects([number stringValueWithFloatingPointOptions:rounded], @"3.14");
}

- (void)testViewBoxAspectRatioParsingAndFormatting
{
    IJSVGViewBoxMeetOrSlice meetOrSlice = IJSVGViewBoxMeetOrSliceUnknown;
    IJSVGViewBoxAlignment alignment = [IJSVGViewBox alignmentForString:@"xMaxYMid slice"
                                                           meetOrSlice:&meetOrSlice];

    XCTAssertEqual(alignment, IJSVGViewBoxAlignmentXMaxYMid);
    XCTAssertEqual(meetOrSlice, IJSVGViewBoxMeetOrSliceSlice);
    XCTAssertEqualObjects([IJSVGViewBox aspectRatioWithAlignment:alignment
                                                    meetOrSlice:meetOrSlice], @"xMaxYMid slice");
    XCTAssertEqual([IJSVGViewBox alignmentForString:@"none"], IJSVGViewBoxAlignmentNone);
    XCTAssertEqual([IJSVGViewBox meetOrSliceForString:@"meet"], IJSVGViewBoxMeetOrSliceMeet);
    XCTAssertEqual([IJSVGViewBox meetOrSliceForString:@"unknown"], IJSVGViewBoxMeetOrSliceUnknown);
}

- (void)testViewBoxComputeTransformForMeetSliceAndNone
{
    CGRect viewBox = CGRectMake(10.f, 20.f, 50.f, 100.f);
    CGRect drawingRect = CGRectMake(0.f, 0.f, 200.f, 200.f);

    CGAffineTransform meet = IJSVGViewBoxComputeTransform(viewBox,
                                                          drawingRect,
                                                          IJSVGViewBoxAlignmentXMidYMid,
                                                          IJSVGViewBoxMeetOrSliceMeet);
    XCTAssertEqualWithAccuracy(meet.a, 2.f, 0.0001f);
    XCTAssertEqualWithAccuracy(meet.d, 2.f, 0.0001f);
    XCTAssertEqualWithAccuracy(meet.tx, 30.f, 0.0001f);
    XCTAssertEqualWithAccuracy(meet.ty, -40.f, 0.0001f);

    CGAffineTransform slice = IJSVGViewBoxComputeTransform(viewBox,
                                                           drawingRect,
                                                           IJSVGViewBoxAlignmentXMinYMin,
                                                           IJSVGViewBoxMeetOrSliceSlice);
    XCTAssertEqualWithAccuracy(slice.a, 4.f, 0.0001f);
    XCTAssertEqualWithAccuracy(slice.d, 4.f, 0.0001f);
    XCTAssertEqualWithAccuracy(slice.tx, -40.f, 0.0001f);
    XCTAssertEqualWithAccuracy(slice.ty, -80.f, 0.0001f);

    CGAffineTransform none = IJSVGViewBoxComputeTransform(viewBox,
                                                          drawingRect,
                                                          IJSVGViewBoxAlignmentNone,
                                                          IJSVGViewBoxMeetOrSliceMeet);
    XCTAssertEqualWithAccuracy(none.a, 4.f, 0.0001f);
    XCTAssertEqualWithAccuracy(none.d, 2.f, 0.0001f);
    XCTAssertEqualWithAccuracy(none.tx, -40.f, 0.0001f);
    XCTAssertEqualWithAccuracy(none.ty, -40.f, 0.0001f);
}

- (void)testMathHelpersConvertAnglesAndClampPrecision
{
    XCTAssertEqualWithAccuracy(IJSVGMathRad(180.f), (CGFloat)M_PI, 0.0001f);
    XCTAssertEqualWithAccuracy(IJSVGMathDeg((CGFloat)M_PI), 180.f, 0.0001f);
    XCTAssertEqualWithAccuracy(IJSVGMathSin(90.f), 1.f, 0.0001f);
    XCTAssertEqualWithAccuracy(IJSVGMathToFixed(3.149f, 2), 3.14f, 0.0001f);
}

- (void)testUnitLengthParsesAllAbsoluteUnitsAndStringValues
{
    IJSVGUnitLength* cm = [IJSVGUnitLength unitWithString:@"2.54cm"];
    IJSVGUnitLength* mm = [IJSVGUnitLength unitWithString:@"25.4mm"];
    IJSVGUnitLength* pt = [IJSVGUnitLength unitWithString:@"12pt"];
    IJSVGUnitLength* pc = [IJSVGUnitLength unitWithString:@"2pc"];
    IJSVGUnitLength* matched = [[IJSVGUnitLength unitWithString:@"0.5"] lengthByMatchingPercentage];
    IJSVGUnitLength* copied = cm.copy;

    XCTAssertEqual(cm.originalType, IJSVGUnitLengthTypeCM);
    XCTAssertEqualWithAccuracy(cm.value, 96.f, 0.001f);
    XCTAssertEqual(mm.originalType, IJSVGUnitLengthTypeMM);
    XCTAssertEqualWithAccuracy(mm.value, 96.f, 0.001f);
    XCTAssertEqual(pt.originalType, IJSVGUnitLengthTypePT);
    XCTAssertEqualWithAccuracy(pt.value, 16.f, 0.001f);
    XCTAssertEqual(pc.originalType, IJSVGUnitLengthTypePC);
    XCTAssertEqualWithAccuracy(pc.value, 32.f, 0.001f);
    XCTAssertEqual(matched.type, IJSVGUnitLengthTypePercentage);
    XCTAssertEqualWithAccuracy(matched.value, 0.5f, 0.0001f);
    XCTAssertEqualObjects([[IJSVGUnitLength unitWithString:@"25%"] stringValue], @"25%");
    XCTAssertNotEqual(copied, cm);
    XCTAssertEqual(copied.originalType, cm.originalType);
    XCTAssertEqualWithAccuracy(copied.value, cm.value, 0.0001f);
}

- (void)testGradientUnitLengthStringValueKeepsNormalizedPercentages
{
    IJSVGGradientUnitLength* gradient = [[IJSVGGradientUnitLength alloc] init];
    gradient.value = 0.25f;
    gradient.type = IJSVGUnitLengthTypePercentage;

    XCTAssertEqualObjects(gradient.stringValue, @"0.25");

    gradient.type = IJSVGUnitLengthTypeNumber;
    XCTAssertEqualObjects(gradient.stringValue, @".25");
}

- (void)testUnitPointComputesRelativeCoordinatesAndCopiesDeeply
{
    IJSVGUnitPoint* point = [IJSVGUnitPoint pointWithX:[IJSVGUnitLength unitWithString:@"25%"]
                                                    y:[IJSVGUnitLength unitWithString:@"10"]];
    CGPoint computed = [point computeValue:CGSizeMake(200.f, 300.f)];
    IJSVGUnitPoint* copy = point.copy;

    XCTAssertTrue(point.containsRelativeUnits);
    XCTAssertEqualWithAccuracy(computed.x, 50.f, 0.0001f);
    XCTAssertEqualWithAccuracy(computed.y, 10.f, 0.0001f);
    XCTAssertNotEqual(copy, point);
    XCTAssertNotEqual(copy.x, point.x);
    XCTAssertEqualWithAccuracy(copy.x.value, point.x.value, 0.0001f);

    [copy convertUnitsToLengthType:IJSVGUnitLengthTypePX];
    XCTAssertEqual(copy.x.type, IJSVGUnitLengthTypePX);
    XCTAssertEqual(copy.y.type, IJSVGUnitLengthTypePX);
    XCTAssertEqual(point.x.type, IJSVGUnitLengthTypePercentage);
}

- (void)testUnitSizeComputesRelativeDimensionsAndZeroState
{
    IJSVGUnitSize* zero = IJSVGUnitSize.zeroSize;
    IJSVGUnitSize* size = [IJSVGUnitSize sizeWithWidth:[IJSVGUnitLength unitWithString:@"50%"]
                                                height:[IJSVGUnitLength unitWithString:@"25%"]];
    CGSize computed = [size computeValue:CGSizeMake(120.f, 80.f)];
    IJSVGUnitSize* copy = size.copy;

    XCTAssertTrue(zero.isZeroSize);
    XCTAssertFalse(size.isZeroSize);
    XCTAssertTrue(size.containsRelativeUnits);
    XCTAssertEqualWithAccuracy(computed.width, 60.f, 0.0001f);
    XCTAssertEqualWithAccuracy(computed.height, 20.f, 0.0001f);
    XCTAssertNotEqual(copy.width, size.width);

    [copy convertUnitsToLengthType:IJSVGUnitLengthTypeNumber];
    XCTAssertEqual(copy.width.type, IJSVGUnitLengthTypeNumber);
    XCTAssertEqual(copy.height.type, IJSVGUnitLengthTypeNumber);
    XCTAssertEqual(size.width.type, IJSVGUnitLengthTypePercentage);
}

- (void)testUnitRectComputesRelativeValuesAndConvertsCopies
{
    IJSVGUnitPoint* origin = [IJSVGUnitPoint pointWithX:[IJSVGUnitLength unitWithString:@"10%"]
                                                    y:[IJSVGUnitLength unitWithString:@"20%"]];
    IJSVGUnitSize* size = [IJSVGUnitSize sizeWithWidth:[IJSVGUnitLength unitWithString:@"50%"]
                                                height:[IJSVGUnitLength unitWithString:@"25%"]];
    IJSVGUnitRect* rect = [IJSVGUnitRect rectWithOrigin:origin
                                                   size:size];
    CGRect computed = [rect computeValue:CGSizeMake(200.f, 100.f)];
    IJSVGUnitRect* converted = [rect copyByConvertingToUnitsLengthType:IJSVGUnitLengthTypePX];

    XCTAssertTrue(rect.containsRelativeUnits);
    XCTAssertFalse(rect.isZeroRect);
    XCTAssertEqualWithAccuracy(computed.origin.x, 20.f, 0.0001f);
    XCTAssertEqualWithAccuracy(computed.origin.y, 20.f, 0.0001f);
    XCTAssertEqualWithAccuracy(computed.size.width, 100.f, 0.0001f);
    XCTAssertEqualWithAccuracy(computed.size.height, 25.f, 0.0001f);
    XCTAssertEqual(converted.origin.x.type, IJSVGUnitLengthTypePX);
    XCTAssertEqual(converted.origin.y.type, IJSVGUnitLengthTypePX);
    XCTAssertEqual(converted.size.width.type, IJSVGUnitLengthTypePX);
    XCTAssertEqual(converted.size.height.type, IJSVGUnitLengthTypePX);
    XCTAssertEqual(rect.origin.x.type, IJSVGUnitLengthTypePercentage);
    XCTAssertTrue(IJSVGUnitRect.zeroRect.isZeroRect);
}

- (void)testUtilsStringBufferHelpersTrimCompareAndLowercase
{
    char* trimmed = IJSVGTimmedCharBufferCreate(" \t MixedCase \n");
    char mutableBuffer[] = "  Another Value  ";
    char lowerBuffer[] = "AbC123";

    XCTAssertEqual(strcmp(trimmed, "MixedCase"), 0);
    IJSVGTrimCharBuffer(mutableBuffer);
    XCTAssertEqual(strcmp(mutableBuffer, "Another Value"), 0);
    IJSVGCharBufferToLower(lowerBuffer);
    XCTAssertEqual(strcmp(lowerBuffer, "abc123"), 0);
    XCTAssertTrue(IJSVGCharBufferCaseInsensitiveCompare("Path", "path"));
    XCTAssertTrue(IJSVGCharBufferCompare("rect", "rect"));
    XCTAssertFalse(IJSVGCharBufferCompare("rect", "path"));
    XCTAssertTrue(IJSVGCharBufferHasPrefix("rgb(0,0,0)", "rgb"));
    XCTAssertTrue(IJSVGCharBufferHasSuffix("12px", "px"));
    XCTAssertTrue(IJSVGCharBufferIsHEX("#0AaF"));
    XCTAssertFalse(IJSVGCharBufferIsHEX("#xyz"));
    XCTAssertEqual(IJSVGCharToLower('Z'), 'z');

    free(trimmed);
}

- (void)testUtilsFloatStringAndCommandHelpers
{
    XCTAssertEqualObjects(IJSVGShortenFloatString(@"0.25"), @".25");
    XCTAssertEqualObjects(IJSVGShortenFloatString(@"-0.25"), @"-.25");
    XCTAssertEqualObjects(IJSVGShortFloatString(0.5f), @".5");
    XCTAssertEqualObjects(IJSVGShortFloatStringWithPrecision(1.25f, 2), @"1.25");
    XCTAssertEqualObjects(IJSVGShortFloatStringWithPrecision(2.f, 2), @"2");
    XCTAssertEqualObjects(IJSVGPointToCommandString(CGPointMake(0.5f, -0.25f)), @".5 -.25");
    XCTAssertEqualObjects(IJSVGCompressFloatParameterArray(@[ @".5", @".25", @"-1", @"2" ]), @".5.25-1 2");
    XCTAssertTrue(IJSVGIsLegalCommandCharacter('M'));
    XCTAssertTrue(IJSVGIsLegalCommandCharacter('a'));
    XCTAssertFalse(IJSVGIsLegalCommandCharacter('R'));
    XCTAssertTrue(IJSVGIsValidContextSize(CGSizeMake(1.f, 1.f)));
    XCTAssertFalse(IJSVGIsValidContextSize(CGSizeMake(0.5f, 1.f)));
}

- (void)testUtilsDefURLAndParenthesesRange
{
    XCTAssertEqualObjects([IJSVGUtils defURL:@"url(#gradient)"], @"gradient");
    XCTAssertEqualObjects([IJSVGUtils defURL:@"url(mask)"], @"mask");
    XCTAssertNil([IJSVGUtils defURL:@"none"]);

    NSRange range = [IJSVGUtils rangeOfParentheses:@"translate(10, 20)"];
    XCTAssertEqual(range.location, 10u);
    XCTAssertEqual(range.length, 6u);
}

- (void)testBitFlagsSetUnsetMergeAndExposeMasks
{
    IJSVGBitFlags* flags = [[IJSVGBitFlags alloc] initWithLength:8];
    IJSVGBitFlags* other = [[IJSVGBitFlags alloc] initWithLength:8];

    [flags setBit:1];
    [flags setBit:3];
    XCTAssertTrue([flags bitIsSet:1]);
    XCTAssertTrue([flags bitIsSet:3]);
    XCTAssertFalse([flags bitIsSet:2]);
    XCTAssertEqual(flags.bitMask, 0b1010ULL);

    [flags unsetBit:1];
    XCTAssertFalse([flags bitIsSet:1]);
    XCTAssertEqual(flags.bitMask, 0b1000ULL);

    [other setBit:2];
    [flags addBits:other];
    XCTAssertEqual(flags.bitMask, 0b1100ULL);
}

- (void)testBitFlags64SetUnsetMergeAndExposeMasks
{
    IJSVGBitFlags64* flags = [[IJSVGBitFlags64 alloc] init];
    IJSVGBitFlags64* other = [[IJSVGBitFlags64 alloc] init];

    [flags setBit:0];
    [flags setBit:63];
    XCTAssertTrue([flags bitIsSet:0]);
    XCTAssertTrue([flags bitIsSet:63]);
    XCTAssertEqual(flags.bitMask, ((1ULL << 63) | 1ULL));

    [flags unsetBit:0];
    XCTAssertFalse([flags bitIsSet:0]);
    XCTAssertEqual(flags.bitMask, (1ULL << 63));

    [other setBit:4];
    [flags addBits:other];
    XCTAssertTrue([flags bitIsSet:4]);
}

- (void)testFeatureFlagsExposeDefaultStates
{
    IJSVGFeatureFlag* disabled = [IJSVGFeatureFlag featureFlagWithEnabled:NO];
    IJSVGFeatureFlags* flags = [[IJSVGFeatureFlags alloc] init];

    XCTAssertFalse(disabled.enabled);
    XCTAssertTrue(flags.viewBoxNormalization.enabled);
    XCTAssertTrue(flags.inferViewBoxes.enabled);
}

@end
