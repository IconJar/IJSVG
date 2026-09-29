//
//  IJSVGInnerShadowTests.m
//  IJSVGExampleTests
//

#import <IJSVGTestHelpers.h>
#import <IJSVG/IJSVGFilter.h>
#import <IJSVG/IJSVGFilterPrimitive.h>

@interface IJSVGInnerShadowTests : XCTestCase
@end

@implementation IJSVGInnerShadowTests

- (NSString*)document
{
    NSString* directory = [@(__FILE__).stringByDeletingLastPathComponent stringByAppendingPathComponent:@"Fixtures"];
    NSError* error = nil;
    NSString* string = [NSString stringWithContentsOfFile:[directory stringByAppendingPathComponent:@"ab-button-blood-type-color.svg"]
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(string);
    return string;
}

- (NSArray<IJSVGFilter*>*)filters:(NSString*)string
{
    if(string == nil) {
        return nil;
    }
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:string fileURL:nil error:&error];
    XCTAssertNil(error);
    IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(32, 32)];
    XCTAssertNotNil(root);
    NSMutableArray<IJSVGFilter*>* filters = [[NSMutableArray alloc] init];
    for(IJSVGNode* node in root.children) {
        if(node.filter != nil) {
            [filters addObject:node.filter];
        }
    }
    return filters;
}

- (NSBitmapImageRep*)render:(NSString*)string pixels:(NSInteger)pixels backingScale:(NSInteger)backingScale
{
    if(string == nil) {
        return nil;
    }
    IJSVG* svg = IJSVGTestSVGObject(string);
    XCTAssertNotNil(svg);
    svg.renderingBackingScaleHelper = ^CGFloat { return backingScale; };
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    XCTAssertTrue(space != NULL);
    if(space == NULL) {
        return nil;
    }
    CGContextRef context = CGBitmapContextCreate(NULL, pixels, pixels, 8, pixels * 4,
                                                 space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    XCTAssertTrue(context != NULL);
    if(context == NULL) {
        return nil;
    }
    CGContextTranslateCTM(context, 0, pixels);
    CGContextScaleCTM(context, backingScale, -backingScale);
    CGFloat points = (CGFloat)pixels / backingScale;
    [svg drawInRect:CGRectMake(0, 0, points, points) context:context];
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    XCTAssertTrue(image != NULL);
    if(image == NULL) {
        return nil;
    }
    NSBitmapImageRep* result = [[NSBitmapImageRep alloc] initWithCGImage:image];
    CGImageRelease(image);
    return result;
}

- (NSString*)lettersFiltered:(BOOL)filtered
{
    NSString* string = [self document];
    if(string == nil) {
        return nil;
    }
    NSError* error = nil;
    NSXMLDocument* xml = [[NSXMLDocument alloc] initWithXMLString:string options:0 error:&error];
    XCTAssertNil(error);
    NSXMLElement* root = xml.rootElement;
    XCTAssertNotNil(root);
    NSMutableArray<NSXMLElement*>* groups = [[NSMutableArray alloc] init];
    for(NSXMLNode* child in root.children) {
        if(child.kind == NSXMLElementKind && [child.name isEqualToString:@"g"]) {
            [groups addObject:(NSXMLElement*)child];
        }
    }
    NSXMLElement* lettering = groups.lastObject;
    XCTAssertNotNil(lettering);
    if(lettering == nil) {
        return nil;
    }
    for(NSXMLElement* group in groups) {
        if(group != lettering) {
            [group detach];
        }
    }
    if(filtered == NO) {
        // Keep the same offscreen raster bounds, but remove the shadows.
        // This isolates damage to edge coverage from small
        // rasterisation differences between offscreen and direct drawing.
        NSArray<NSXMLNode*>* nodes = [root nodesForXPath:@".//*[local-name()='filter' and @id='filter4_ii_18590_2298']"
                                                  error:&error];
        XCTAssertNil(error);
        NSXMLElement* filter = (NSXMLElement*)nodes.firstObject;
        XCTAssertNotNil(filter);
        if(filter == nil) {
            return nil;
        }
        filter.children = @[[NSXMLElement elementWithName:@"feColorMatrix"]];
    }
    return xml.XMLString;
}

// Compare the filtered letters with their unshaded silhouette, on transparent
// pixels. A mean RGB score over an opaque button can hide damaged edge alpha.
- (void)assertInnerShadowsPreserveLetterCoverageAtPixels:(NSInteger)pixels backingScale:(NSInteger)backingScale
{
    NSBitmapImageRep* actual = [self render:[self lettersFiltered:YES] pixels:pixels backingScale:backingScale];
    NSBitmapImageRep* source = [self render:[self lettersFiltered:NO] pixels:pixels backingScale:backingScale];
    XCTAssertNotNil(actual);
    XCTAssertNotNil(source);
    if(actual == nil || source == nil) {
        return;
    }
    double maximumAlphaError = 0;
    NSUInteger partialPixels = 0, shadedPixels = 0;
    for(NSInteger y = 0; y < pixels; y++) {
        for(NSInteger x = 0; x < pixels; x++) {
            NSColor* a = [[actual colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            NSColor* b = [[source colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            XCTAssertNotNil(a);
            XCTAssertNotNil(b);
            if(a == nil || b == nil) {
                return;
            }
            maximumAlphaError = MAX(maximumAlphaError, fabs(a.alphaComponent - b.alphaComponent));
            if(b.alphaComponent > 0 && b.alphaComponent < 1) {
                partialPixels++;
            }
            double colorDifference = MAX(fabs(a.redComponent - b.redComponent),
                MAX(fabs(a.greenComponent - b.greenComponent), fabs(a.blueComponent - b.blueComponent)));
            if(b.alphaComponent > .25 && colorDifference > 1. / 255) {
                shadedPixels++;
            }
        }
    }
    XCTAssertGreaterThan(partialPixels, 0u);
    XCTAssertGreaterThan(shadedPixels, 0u);
    // Allow a few 8 bit levels through the CI colour conversions and blends.
    // The old source over path changes edge alpha by over 120 levels at 32px.
    XCTAssertLessThanOrEqual(maximumAlphaError * 255, 4.01);
}

- (void)testInnerShadowsPreserveLetterCoverageAt32Pixels1x
{
    [self assertInnerShadowsPreserveLetterCoverageAtPixels:32 backingScale:1];
}

- (void)testInnerShadowsPreserveLetterCoverageAt32Pixels2x
{
    [self assertInnerShadowsPreserveLetterCoverageAtPixels:32 backingScale:2];
}

- (void)testInnerShadowsPreserveLetterCoverageAt64Pixels1x
{
    [self assertInnerShadowsPreserveLetterCoverageAtPixels:64 backingScale:1];
}

- (void)testInnerShadowsPreserveLetterCoverageAt64Pixels2x
{
    [self assertInnerShadowsPreserveLetterCoverageAtPixels:64 backingScale:2];
}

- (void)testInnerShadowsPreserveLetterCoverageAt128Pixels1x
{
    [self assertInnerShadowsPreserveLetterCoverageAtPixels:128 backingScale:1];
}

- (void)testInnerShadowsPreserveLetterCoverageAt128Pixels2x
{
    [self assertInnerShadowsPreserveLetterCoverageAtPixels:128 backingScale:2];
}

- (void)testInnerShadowsPreserveLetterCoverageAt256Pixels1x
{
    [self assertInnerShadowsPreserveLetterCoverageAtPixels:256 backingScale:1];
}

- (void)testInnerShadowsPreserveLetterCoverageAt256Pixels2x
{
    [self assertInnerShadowsPreserveLetterCoverageAtPixels:256 backingScale:2];
}

- (void)testRecognisedInnerShadowsUseNativeResolution
{
    NSArray<IJSVGFilter*>* values = [self filters:[self document]];
    XCTAssertEqual(values.count, 5u);
    XCTAssertNotNil(values.firstObject);
    XCTAssertNotNil(values.lastObject);
    XCTAssertEqual(values.firstObject.primitives.count, 14u);
    XCTAssertEqual(values.lastObject.primitives.count, 14u);
    for(IJSVGFilter* filter in values) {
        XCTAssertFalse(filter.requiresSupersampling);
    }
    XCTAssertTrue(values.firstObject.preservesInnerShadowCoverage);
    XCTAssertTrue(values.lastObject.preservesInnerShadowCoverage);
}

- (void)setParameter:(NSString*)key value:(NSString*)value onPrimitive:(IJSVGFilterPrimitive*)primitive
{
    NSMutableDictionary* parameters = [primitive.parameters mutableCopy] ?: [[NSMutableDictionary alloc] init];
    parameters[key] = value;
    primitive.parameters = parameters;
}

- (void)assertUnfamiliarGraphKeepsSupersampling:(NSString*)change
{
    IJSVGFilter* filter = [self filters:[self document]].lastObject;
    XCTAssertNotNil(filter);
    NSArray<IJSVGFilterPrimitive*>* primitives = filter.primitives;
    XCTAssertEqual(primitives.count, 14u);
    if(primitives.count != 14) {
        return;
    }
    IJSVGFilterPrimitive* hardAlpha = primitives[2];
    if([change isEqualToString:@"matrix"]) {
        [self setParameter:@"values" value:@"0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 -0.5" onPrimitive:hardAlpha];
    } else if([change isEqualToString:@"input"]) {
        hardAlpha.input = @"SourceGraphic";
    } else if([change isEqualToString:@"operator"]) {
        [self setParameter:@"operator" value:@"in" onPrimitive:primitives[5]];
    } else if([change isEqualToString:@"coefficient"]) {
        [self setParameter:@"k2" value:@"-0.5" onPrimitive:primitives[5]];
    } else if([change isEqualToString:@"tint"]) {
        [self setParameter:@"values" value:@"0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 0 0 0 2 0" onPrimitive:primitives[6]];
    } else if([change isEqualToString:@"blend"]) {
        [self setParameter:@"mode" value:@"multiply" onPrimitive:primitives[7]];
    } else if([change isEqualToString:@"region"]) {
        primitives[4].width = [IJSVGUnitLength unitWithFloat:2];
    } else if([change isEqualToString:@"branch"]) {
        primitives[4].input = @"SourceAlpha";
    } else if([change isEqualToString:@"sourceCollision"]) {
        hardAlpha.result = @"SourceAlpha";
    } else if([change isEqualToString:@"shapeCollision"]) {
        hardAlpha.result = primitives[1].result;
    } else {
        XCTAssertEqualObjects(change, @"incompleteGraph");
        // Retaining just the first hard alpha primitive is a valid general
        // filter, not the complete inner shadow pattern.
        [filter removeChildren:primitives];
        [filter addChild:hardAlpha];
    }
    XCTAssertTrue(filter.requiresSupersampling);
    XCTAssertFalse(filter.preservesInnerShadowCoverage);
}

- (void)testUnfamiliarGraphKeepsSupersamplingForMatrix
{
    [self assertUnfamiliarGraphKeepsSupersampling:@"matrix"];
}

- (void)testUnfamiliarGraphKeepsSupersamplingForInput
{
    [self assertUnfamiliarGraphKeepsSupersampling:@"input"];
}

- (void)testUnfamiliarGraphKeepsSupersamplingForOperator
{
    [self assertUnfamiliarGraphKeepsSupersampling:@"operator"];
}

- (void)testUnfamiliarGraphKeepsSupersamplingForCoefficient
{
    [self assertUnfamiliarGraphKeepsSupersampling:@"coefficient"];
}

- (void)testUnfamiliarGraphKeepsSupersamplingForTint
{
    [self assertUnfamiliarGraphKeepsSupersampling:@"tint"];
}

- (void)testUnfamiliarGraphKeepsSupersamplingForBlend
{
    [self assertUnfamiliarGraphKeepsSupersampling:@"blend"];
}

- (void)testUnfamiliarGraphKeepsSupersamplingForRegion
{
    [self assertUnfamiliarGraphKeepsSupersampling:@"region"];
}

- (void)testUnfamiliarGraphKeepsSupersamplingForBranch
{
    [self assertUnfamiliarGraphKeepsSupersampling:@"branch"];
}

- (void)testUnfamiliarGraphKeepsSupersamplingForSourceCollision
{
    [self assertUnfamiliarGraphKeepsSupersampling:@"sourceCollision"];
}

- (void)testUnfamiliarGraphKeepsSupersamplingForShapeCollision
{
    [self assertUnfamiliarGraphKeepsSupersampling:@"shapeCollision"];
}

- (void)testUnfamiliarGraphKeepsSupersamplingForIncompleteGraph
{
    [self assertUnfamiliarGraphKeepsSupersampling:@"incompleteGraph"];
}

@end
