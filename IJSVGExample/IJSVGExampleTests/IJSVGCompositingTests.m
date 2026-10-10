#import "IJSVGTestHelpers.h"

@interface IJSVGCompositingTests: XCTestCase
@end

@implementation IJSVGCompositingTests

- (void)testGroupBlendAndIsolationPixels
{
    for(NSString* isolation in @[@"auto", @"isolate"]) {
        NSString* source = IJSVGTestSVG([NSString stringWithFormat:
            @"<rect width='8' height='8' fill='red'/>"
             "<g style='isolation:%@'><rect x='2' y='2' width='4' height='4'"
             " fill='lime' style='mix-blend-mode:multiply'/></g>", isolation]);
        NSColor* color = IJSVGTestColorFromSVGAtPoint(source, CGPointMake(4, 4));
        IJSVGAssertColorComponents(color, 0, [isolation isEqualToString:@"isolate"] ? 1 : 0, 0, 1);
    }
    NSString* source = IJSVGTestSVG(
        @"<rect width='8' height='8' fill='red'/>"
         "<g style='mix-blend-mode:multiply'><rect width='8' height='8' fill='blue'/>"
         "<rect x='2' y='2' width='4' height='4' fill='yellow'/></g>");
    IJSVGAssertColorComponents(IJSVGTestColorFromSVGAtPoint(source, CGPointMake(4, 4)), 1, 0, 0, 1);
    IJSVGAssertColorComponents(IJSVGTestColorFromSVGAtPoint(source, CGPointMake(1, 1)), 0, 0, 0, 1);
}

- (void)testExportPreservesGroupCompositing
{
    for(NSString* style in @[@"isolation:isolate", @"mix-blend-mode:multiply",
                              @"isolation:isolate;mix-blend-mode:screen"]) {
        NSString* source = IJSVGTestSVG([NSString stringWithFormat:
            @"<rect width='8' height='8' fill='red'/>"
             "<g style='%@'><rect width='6' height='6' fill='blue'/>"
             "<rect x='2' y='2' width='4' height='4' fill='lime' style='mix-blend-mode:multiply'/></g>",
            style]);
        IJSVG* svg = IJSVGTestSVGObject(source);
        for(NSNumber* options in @[@(IJSVGExporterOptionNone), @(IJSVGExporterOptionAll)]) {
            NSString* exported = [svg SVGStringWithSize:CGSizeMake(8, 8) options:options.unsignedIntegerValue];
            XCTAssertEqualObjects(IJSVGTestRGBADataForSVG(source, CGSizeMake(8, 8)),
                                  IJSVGTestRGBADataForSVG(exported, CGSizeMake(8, 8)), @"%@", exported);
        }
    }
}

@end
