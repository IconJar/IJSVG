//
//  IJSVGMemorySafetyTests.m
//  IJSVGExampleTests
//

#import <IJSVG/IJSVGCommandParser.h>
#import <IJSVG/IJSVGGradient.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <XCTest/XCTest.h>
#include <dlfcn.h>

@interface IJSVGMemorySafetyTests : XCTestCase
@end

@implementation IJSVGMemorySafetyTests

- (void)testManagerLookupEnumeratesManagers
{
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:@"<svg width='10' height='10'/>"];
    IJSVGThreadManager* manager = IJSVGThreadManager.currentManager;
    XCTAssertEqual([IJSVGThreadManager managerForSVG:svg], manager);
    [manager remove:svg];
    XCTAssertNil([IJSVGThreadManager managerForSVG:svg]);
    [manager adopt:svg];
    XCTAssertEqual([IJSVGThreadManager managerForSVG:svg], manager);
}

- (void)testOversizedPathStreamsAreRejected
{
    NSUInteger count = SIZE_MAX / sizeof(CGFloat) + 2;
    XCTAssertTrue(IJSVGPathDataStreamCreate(count, 64) == NULL);
    XCTAssertTrue(IJSVGPathDataStreamCreate(1, NSUIntegerMax) == NULL);
    IJSVGPathDataStreamRelease(NULL);
}

- (void)testMissingPathStreamProducesNoParameters
{
    NSInteger sets = 123;
    CGFloat* values = IJSVGParsePathDataStreamSequence("1 2 3", 5, NULL, NULL, 1, &sets);
    XCTAssertTrue(values == NULL);
    XCTAssertEqual(sets, 0);
    free(values);
}

- (void)testSmallPathStreamGrowsWithoutLosingValues
{
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(1, 1);
    XCTAssertTrue(stream != NULL);
    NSInteger sets = 0;
    CGFloat* values = IJSVGParsePathDataStreamSequence("1 2 3", 5, stream, NULL, 1, &sets);
    XCTAssertEqual(sets, 3);
    XCTAssertTrue(values != NULL);
    if (values != NULL) {
        XCTAssertEqual(values[0], 1);
        XCTAssertEqual(values[1], 2);
        XCTAssertEqual(values[2], 3);
    }
    free(values);
    IJSVGPathDataStreamRelease(stream);
}

- (void)testGradientLocationsCanBeReassignedToThemselves
{
    @autoreleasepool {
        IJSVGGradient* gradient = [[IJSVGGradient alloc] init];
        CGFloat* locations = calloc(2, sizeof(CGFloat));
        XCTAssertTrue(locations != NULL);
        if (locations == NULL) {
            return;
        }
        locations[0] = 0.25;
        locations[1] = 0.75;
        gradient.locations = locations;
        gradient.numberOfStops = 2;
        gradient.locations = gradient.locations;
        XCTAssertEqual(gradient.locations[0], 0.25);
        XCTAssertEqual(gradient.locations[1], 0.75);
        gradient.locations = NULL;
        XCTAssertTrue(gradient.locations == NULL);
    }
}

- (void)testReplacingDashArraysReleasesOwnedStorage
{
    @autoreleasepool {
        IJSVGPath* node = [[IJSVGPath alloc] init];
        CGFloat* first = calloc(2, sizeof(CGFloat));
        CGFloat* second = calloc(2, sizeof(CGFloat));
        XCTAssertTrue(first != NULL && second != NULL);
        if (first == NULL || second == NULL) {
            free(first);
            free(second);
            return;
        }
        first[0] = 2;
        first[1] = 4;
        second[0] = 3;
        second[1] = 6;
        node.strokeDashArrayCount = 2;
        node.strokeDashArray = first;
        node.strokeDashArray = node.strokeDashArray;
        XCTAssertEqual(node.strokeDashArray[0], 2);
        node.strokeDashArray = second;
        XCTAssertEqual(node.strokeDashArray[0], 3);

        // Allocate both buffers before replacement so the old address cannot be reused.
        // AddressSanitizer lets this test verify that replacement frees the old buffer.
        int (*isPoisoned)(const void*) = dlsym(RTLD_DEFAULT, "__asan_address_is_poisoned");
        if (isPoisoned != NULL) {
            XCTAssertNotEqual(isPoisoned(first), 0);
        }
        node.strokeDashArray = NULL;
        node.strokeDashArrayCount = 0;
        if (isPoisoned != NULL) {
            XCTAssertNotEqual(isPoisoned(second), 0);
        }
    }
}

@end
