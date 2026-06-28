//
//  IJSVGCommandAndAdditionsTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGTestHelpers.h"
#import <IJSVG/IJSVGCommand.h>
#import <IJSVG/IJSVGCommandClose.h>
#import <IJSVG/IJSVGCommandCurve.h>
#import <IJSVG/IJSVGCommandEllipticalArc.h>
#import <IJSVG/IJSVGCommandHorizontalLine.h>
#import <IJSVG/IJSVGCommandLineTo.h>
#import <IJSVG/IJSVGCommandMove.h>
#import <IJSVG/IJSVGCommandQuadraticCurve.h>
#import <IJSVG/IJSVGCommandSmoothCurve.h>
#import <IJSVG/IJSVGCommandSmoothQuadraticCurve.h>
#import <IJSVG/IJSVGCommandVerticalLine.h>
#import <IJSVG/IJSVGStringAdditions.h>

@interface IJSVGCommandAndAdditionsTests : XCTestCase
@end

@implementation IJSVGCommandAndAdditionsTests

- (void)testStringAdditionsSplitByCharacterSetAndWhitespace
{
    XCTAssertEqualObjects([@" a,b,,c " ijsvg_componentsSeparatedByChars:", "], (@[ @"a", @"b", @"c" ]));
    XCTAssertEqualObjects([@"one\ttwo\nthree  four" ijsvg_componentsSplitByWhiteSpace], (@[ @"one", @"two", @"three", @"four" ]));
    XCTAssertEqualObjects([@"" ijsvg_componentsSeparatedByChars:","], @[]);
}

- (void)testStringAdditionsHexChecks
{
    XCTAssertTrue([@"#A0f" ijsvg_isHexString]);
    XCTAssertFalse([@"#xyz" ijsvg_isHexString]);
}

- (void)testCommandClassLookupForPathCommands
{
    XCTAssertEqual([IJSVGCommand commandClassForCommandChar:'M'], IJSVGCommandMove.class);
    XCTAssertEqual([IJSVGCommand commandClassForCommandChar:'l'], IJSVGCommandLineTo.class);
    XCTAssertEqual([IJSVGCommand commandClassForCommandChar:'H'], IJSVGCommandHorizontalLine.class);
    XCTAssertEqual([IJSVGCommand commandClassForCommandChar:'v'], IJSVGCommandVerticalLine.class);
    XCTAssertEqual([IJSVGCommand commandClassForCommandChar:'C'], IJSVGCommandCurve.class);
    XCTAssertEqual([IJSVGCommand commandClassForCommandChar:'s'], IJSVGCommandSmoothCurve.class);
    XCTAssertEqual([IJSVGCommand commandClassForCommandChar:'Q'], IJSVGCommandQuadraticCurve.class);
    XCTAssertEqual([IJSVGCommand commandClassForCommandChar:'t'], IJSVGCommandSmoothQuadraticCurve.class);
    XCTAssertEqual([IJSVGCommand commandClassForCommandChar:'A'], IJSVGCommandEllipticalArc.class);
    XCTAssertEqual([IJSVGCommand commandClassForCommandChar:'z'], IJSVGCommandClose.class);
    XCTAssertNil([IJSVGCommand commandClassForCommandChar:'R']);
}

- (void)testCommandParsingCreatesCommandsAndSubcommands
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    NSArray<IJSVGCommand*>* commands = [IJSVGCommand commandsForDataCharacters:"M0 0 L10 10 20 20 h5 v-5 z"
                                                                  dataStream:stream];

    XCTAssertEqual(commands.count, 5u);
    XCTAssertTrue([commands[0] isKindOfClass:IJSVGCommandMove.class]);
    XCTAssertTrue([commands[1] isKindOfClass:IJSVGCommandLineTo.class]);
    XCTAssertTrue([commands[2] isKindOfClass:IJSVGCommandHorizontalLine.class]);
    XCTAssertTrue([commands[3] isKindOfClass:IJSVGCommandVerticalLine.class]);
    XCTAssertTrue([commands[4] isKindOfClass:IJSVGCommandClose.class]);
    XCTAssertEqual(commands[1].subCommands.count, 2u);
    XCTAssertFalse(commands[1].subCommands[0].isSubCommand);
    XCTAssertTrue(commands[1].subCommands[1].isSubCommand);
    XCTAssertEqual(commands[1].subCommands[1].previousCommand, commands[1].subCommands[0]);
    XCTAssertEqualWithAccuracy(commands[2].subCommands[0].parameters[0], 5.f, 0.0001f);
    XCTAssertEqualWithAccuracy(commands[3].subCommands[0].parameters[0], -5.f, 0.0001f);

    IJSVGPathDataStreamRelease(stream);
}

- (void)testCommandReadHelpersAdvanceAndReset
{
    CGFloat* params = (CGFloat*)malloc(sizeof(CGFloat) * 4);
    params[0] = 1.f;
    params[1] = 2.f;
    params[2] = 1.f;
    params[3] = 0.f;
    IJSVGCommand* command = [[IJSVGCommand alloc] init];
    command.parameters = params;
    command.parameterCount = 4;

    XCTAssertEqualWithAccuracy([command readFloat], 1.f, 0.0001f);
    NSPoint point = [command readPoint];
    XCTAssertEqualWithAccuracy(point.x, 2.f, 0.0001f);
    XCTAssertEqualWithAccuracy(point.y, 1.f, 0.0001f);
    XCTAssertFalse([command readBOOL]);

    [command resetRead];
    XCTAssertEqualWithAccuracy([command readFloat], 1.f, 0.0001f);
}

- (void)testCommandCopyDeepCopiesParametersAndSubcommands
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    IJSVGCommand* command = [IJSVGCommand commandsForDataCharacters:"L10 10 20 20"
                                             dataStream:stream].firstObject;
    IJSVGCommand* copy = command.copy;

    XCTAssertNotEqual(copy, command);
    XCTAssertEqual(copy.command, command.command);
    XCTAssertEqual(copy.subCommands.count, command.subCommands.count);
    XCTAssertNotEqual(copy.subCommands[0], command.subCommands[0]);
    XCTAssertNotEqual(copy.subCommands[0].parameters, command.subCommands[0].parameters);
    XCTAssertEqualWithAccuracy(copy.subCommands[1].parameters[0], 20.f, 0.0001f);
    XCTAssertEqual(command.subCommands[1].previousCommand, command.subCommands[0]);

    IJSVGPathDataStreamRelease(stream);
}

- (void)testCommandPathCreationImplicitlyMovesWhenFirstCommandIsNotMove
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    NSArray<IJSVGCommand*>* commands = [IJSVGCommand commandsForDataCharacters:"L10 10 L20 0"
                                                                  dataStream:stream];
    CGMutablePathRef path = [IJSVGCommand newPathForCommandsArray:commands];
    CGRect bounds = CGPathGetPathBoundingBox(path);

    XCTAssertEqualWithAccuracy(bounds.origin.x, 0.f, 0.0001f);
    XCTAssertEqualWithAccuracy(bounds.origin.y, 0.f, 0.0001f);
    XCTAssertEqualWithAccuracy(bounds.size.width, 20.f, 0.0001f);
    XCTAssertEqualWithAccuracy(bounds.size.height, 10.f, 0.0001f);

    CGPathRelease(path);
    IJSVGPathDataStreamRelease(stream);
}

- (void)testCommandCoordinatePairAndConversionCopies
{
    CGFloat values[] = { 1.f, 2.f, 3.f, 4.f };
    NSPoint second = [IJSVGCommand readCoordinatePair:values
                                               index:1];
    XCTAssertEqualWithAccuracy(second.x, 3.f, 0.0001f);
    XCTAssertEqualWithAccuracy(second.y, 4.f, 0.0001f);

    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    NSArray<IJSVGCommand*>* commands = [IJSVGCommand commandsForDataCharacters:"L.5 .25"
                                                                  dataStream:stream];
    NSArray<IJSVGCommand*>* converted = [IJSVGCommand convertCommands:commands
                                                               toUnits:IJSVGUnitObjectBoundingBox
                                                                bounds:CGRectMake(0.f, 0.f, 200.f, 100.f)];

    XCTAssertEqual(converted.count, commands.count);
    XCTAssertNotEqual(converted.firstObject, commands.firstObject);
    XCTAssertEqualWithAccuracy(converted.firstObject.subCommands[0].parameters[0], 100.f, 0.0001f);
    XCTAssertEqualWithAccuracy(converted.firstObject.subCommands[0].parameters[1], 25.f, 0.0001f);
    XCTAssertEqualWithAccuracy(commands.firstObject.subCommands[0].parameters[0], 0.5f, 0.0001f);

    IJSVGPathDataStreamRelease(stream);
}

@end
