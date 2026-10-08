//
//  IJSVGRegressionRegistration.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 07/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "IJSVGCSSFontParserChecks.h"

@interface IJSVGRegressionRegistration: XCTestCase
@end

@implementation IJSVGRegressionRegistration

- (void)testObjectiveCRegressions
{
    NSArray<NSString*>* names = IJSVGTextRegressionCaseNames();
    XCTAssertGreaterThan(names.count, 0u);
    for(NSString* name in names) {
        NSArray<NSString*>* failures = IJSVGRunTextRegressionCase(name);
        XCTAssertEqual(failures.count, 0u, @"%@: %@", name,
                       [failures componentsJoinedByString:@"; "]);
    }
}

- (void)testObjectiveCWebKitComparisons
{
    NSArray<NSString*>* names = IJSVGReferenceWebKitCaseNames();
    XCTAssertGreaterThan(names.count, 0u);
    for(NSString* name in names) {
        XCTestExpectation* completed = [self expectationWithDescription:name];
        // WebKit and AppKit work must run on the main thread.
        dispatch_async(dispatch_get_main_queue(), ^{
            IJSVGRunReferenceWebKitCase(name, ^(NSArray<NSString*>* failures) {
                XCTAssertEqual(failures.count, 0u, @"%@: %@", name,
                               [failures componentsJoinedByString:@"; "]);
                [completed fulfill];
            });
        });
        [self waitForExpectations:@[completed] timeout:60.0];
    }
}

- (void)testObjectiveCParserChecks
{
    NSArray<NSString*>* failures = IJSVGRunCSSFontParserChecks();
    XCTAssertEqual(failures.count, 0u, @"%@",
                   [failures componentsJoinedByString:@"; "]);
}

@end
