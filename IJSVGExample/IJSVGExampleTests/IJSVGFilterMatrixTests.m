#import <IJSVGFilterTestHelpers.h>

@interface IJSVGFilterMatrixTests: XCTestCase
@end

@implementation IJSVGFilterMatrixTests

- (NSArray<NSDictionary*>*)fixtures
{
    // The standalone benchmark reads this same generated corpus.
    NSString* path = [@(__FILE__).stringByDeletingLastPathComponent
        stringByAppendingPathComponent:@"Fixtures/FilterMatrix/manifest.json"];
    NSError* error = nil;
    NSData* data = [NSData dataWithContentsOfFile:path
                                          options:0
                                            error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(data);
    if(data == nil) {
        return nil;
    }
    NSArray* fixtures = [NSJSONSerialization JSONObjectWithData:data
                                                        options:0
                                                          error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([fixtures isKindOfClass:NSArray.class]);
    return [fixtures isKindOfClass:NSArray.class] ? fixtures : nil;
}

- (void)testCorpusCoversEveryRegisteredFilter
{
    NSArray<NSDictionary*>* fixtures = [self fixtures];
    XCTAssertEqual(fixtures.count, 80u);
    if(fixtures == nil) return;
    XCTAssertEqual([NSSet setWithArray:[fixtures valueForKey:@"name"]].count,
                   fixtures.count);
    NSSet* tiers = [NSSet setWithArray:@[@"simple", @"mixed", @"complex"]];
    XCTAssertEqualObjects([NSSet setWithArray:[fixtures valueForKey:@"tier"]],
                          tiers);
    NSString* documents = [[fixtures valueForKey:@"document"] componentsJoinedByString:@""];
    for(NSString* name in @[@"Blend", @"ColorMatrix", @"ComponentTransfer", @"Composite",
        @"ConvolveMatrix", @"DisplacementMap", @"Morphology", @"Tile", @"Flood", @"Offset",
        @"Image", @"Merge", @"GaussianBlur", @"DropShadow", @"Turbulence",
        @"DiffuseLighting", @"SpecularLighting"]) {
        XCTAssertTrue([documents containsString:[@"<fe" stringByAppendingString:name]],
                      @"Missing filter: %@", name);
    }
}

- (void)testRenderingOptionsToggleEveryFilterRecipe
{
    NSArray<NSDictionary*>* fixtures = [self fixtures];
    XCTAssertEqual(fixtures.count, 80u);
    for(NSDictionary* fixture in fixtures) {
        for(NSNumber* flipped in @[@NO, @YES]) {
            for(NSNumber* exportImage in @[@NO, @YES]) {
                NSString* name = [NSString stringWithFormat:@"%@ flipped=%@ exportImage=%@",
                                                            fixture[@"name"],
                                                            flipped,
                                                            exportImage];
                [XCTContext runActivityNamed:name
                                       block:^(id<XCTActivity> activity) {
                    @autoreleasepool {
                        [self assertFilterOptionsForDocument:fixture[@"document"]
                                                     flipped:flipped.boolValue
                                                 exportImage:exportImage.boolValue];
                    }
                }];
            }
        }
    }
}

- (void)testCombinedMatchesIndependentRendering
{
    NSArray<NSDictionary*>* fixtures = [self fixtures];
    XCTAssertEqual(fixtures.count, 80u);
    // Individual renders check batching, layering and transforms. Existing
    // numeric filter tests remain the oracle for primitive mathematics.
    for(NSDictionary* fixture in fixtures) {
        for(NSNumber* flipped in @[@NO, @YES]) {
            NSString* name = [NSString stringWithFormat:@"%@ flipped=%@",
                                                        fixture[@"name"],
                                                        flipped];
            [XCTContext runActivityNamed:name
                                   block:^(id<XCTActivity> activity) {
                @autoreleasepool {
                    NSData* actual = [self renderDocument:fixture[@"document"]
                                                  flipped:flipped.boolValue];
                    NSArray* references = fixture[@"references"];
                    XCTAssertEqual(references.count, 3u);
                    NSData* reference = [self compositeDocuments:references
                                                         flipped:flipped.boolValue
                                                         clipped:NO];
                    XCTAssertTrue([self containsPaintedPixels:actual],
                                  @"Empty output: %@", name);
                    XCTAssertLessThanOrEqual([self maximumDifference:actual
                                                               other:reference],
                                             3, @"%@", name);
                }
            }];
        }
    }
}

@end
