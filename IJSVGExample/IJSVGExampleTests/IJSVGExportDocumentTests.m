//
//  IJSVGExportDocumentTests.m
//  IJSVGExample
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGExportUtilities.h>
#import <IJSVGTestHelpers.h>

@interface IJSVGExportIdentifierDelegate : NSObject <IJSVGExporterDelegate>
@property (nonatomic, strong) IJSVGExportElement* retainedElement;
@end

@implementation IJSVGExportIdentifierDelegate

- (NSString*)svgExporter:(IJSVGExporter*)exporter identifierForElement:(IJSVGExportElement*)element type:(IJSVGNodeType)type defaultID:(NSString* (^)(void))defaultID
{
    self.retainedElement = element;
    [element setAttributesAsDictionary:@{ @"data-delegate" : @"café & <tag>" }];
    return [@"custom-" stringByAppendingString:defaultID()];
}

@end

@interface IJSVGExportDocumentTests : XCTestCase
@end

@implementation IJSVGExportDocumentTests

- (void)testEncodingAwareCompactSerializationAndStrings
{
    for (NSString* name in @[ @"UTF-8", @"UTF-16", @"UTF-16BE", @"UTF-16LE", @"ISO-8859-1" ]) {
        NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)name));
        IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
        root.stringValue = @"café\nsecond";
        IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
        document.characterEncoding = name;
        for (NSNumber* pretty in @[ @NO, @YES ]) {
            for (NSNumber* declaration in @[ @NO, @YES ]) {
                NSData* data = [document XMLDataWithPrettyPrinting:pretty.boolValue includeXMLDeclaration:declaration.boolValue];
                NSString* string = [[NSString alloc] initWithData:data encoding:encoding];
                XCTAssertNotNil(string, @"%@", name);
                XCTAssertEqual([string hasPrefix:@"<?xml"], declaration.boolValue);
                XCTAssertTrue([string containsString:@">café\nsecond</svg>"]);
                if (!pretty.boolValue) {
                    XCTAssertFalse([string hasSuffix:@"\n"]);
                    XCTAssertFalse([string containsString:@"?>\n"]);
                }
                if (declaration.boolValue) {
                    XCTAssertEqualObjects([document XMLStringWithPrettyPrinting:pretty.boolValue], string);
                    NSError* error = nil;
                    NSXMLDocument* parsed = [[NSXMLDocument alloc] initWithData:data options:0 error:&error];
                    XCTAssertNil(error);
                    XCTAssertEqualObjects(parsed.rootElement.stringValue, root.stringValue);
                }
            }
        }
    }
}

- (void)testSerializedBuffersRemainIndependentAfterMutationAndTeardown
{
    NSString* original = [@"café & < > 😀" stringByPaddingToLength:131072 withString:@"x & 😀" startingAtIndex:0];
    for (NSString* encoding in @[ @"UTF-8", @"UTF-16" ]) {
        NSData* first = nil;
        NSData* second = nil;
        @autoreleasepool {
            IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
            [root setAttributeWithName:@"value" stringValue:original];
            IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
            document.characterEncoding = encoding;
            first = [document XMLDataWithPrettyPrinting:NO];
            [root setAttributeWithName:@"value" stringValue:@"changed"];
            second = [document XMLDataWithPrettyPrinting:YES];
        }
        NSError* error = nil;
        NSXMLDocument* firstParsed = [[NSXMLDocument alloc] initWithData:first options:0 error:&error];
        XCTAssertNil(error);
        XCTAssertEqualObjects([firstParsed.rootElement attributeForName:@"value"].stringValue, original);
        NSXMLDocument* secondParsed = [[NSXMLDocument alloc] initWithData:second options:0 error:&error];
        XCTAssertNil(error);
        XCTAssertEqualObjects([secondParsed.rootElement attributeForName:@"value"].stringValue, @"changed");
    }
}

- (void)testUnwrapSplicesChildrenAndPreservesOwnership
{
    for (NSUInteger edges = 0; edges < 4; edges++) {
        for (NSNumber* size in @[ @0, @1, @4096 ]) {
            IJSVGExportNode* retained = nil;
            @autoreleasepool {
                IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
                IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
                IJSVGExportElement* group = [[IJSVGExportElement alloc] initWithName:@"g"];
                NSMutableArray* expected = [[NSMutableArray alloc] init];
                if (edges & 1) {
                    IJSVGExportElement* before = [[IJSVGExportElement alloc] initWithName:@"before"];
                    [root addChild:before];
                    [expected addObject:before];
                }
                [root addChild:group];
                for (NSUInteger index = 0; index < size.unsignedIntegerValue; index++) {
                    IJSVGExportNode* child = [[IJSVGExportNode alloc] initWithKind:IJSVGXMLNodeKindText];
                    child.stringValue = @"x";
                    [group addChild:child];
                    [expected addObject:child];
                    retained = child;
                }
                if (edges & 2) {
                    IJSVGExportElement* after = [[IJSVGExportElement alloc] initWithName:@"after"];
                    [root addChild:after];
                    [expected addObject:after];
                }
                IJSVGExportUnwrapElement(group);
                XCTAssertEqualObjects(root.children, expected);
                XCTAssertEqual(root.childCount, expected.count);
                XCTAssertEqual(group.childCount, 0U);
                XCTAssertNil(group.parent);
                XCTAssertNil(group.nextSibling);
                for (NSUInteger index = 0; index < expected.count; index++) {
                    IJSVGExportNode* child = expected[index];
                    XCTAssertEqual(child.parent, root);
                    XCTAssertEqual(child.nextSibling, index + 1 < expected.count ? expected[index + 1] : nil);
                }
                XCTAssertNotNil([document XMLDataWithPrettyPrinting:NO]);
                IJSVGExportUnwrapElement(group);
                XCTAssertEqual(root.childCount, expected.count);
            }
            if (retained != nil) {
                XCTAssertNil(retained.parent);
                XCTAssertNil(retained.nextSibling);
                XCTAssertEqualObjects(retained.stringValue, @"x");
            }
        }
    }
}

- (void)testDuplicatePathGroupingMatchesStringComparison
{
    IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
    IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
    NSMutableDictionary* first = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* repeated = [[NSMutableDictionary alloc] init];
    NSMutableArray* expected = [[NSMutableArray alloc] init];
    for (NSUInteger index = 0; index < 512; index++) {
        IJSVGExportElement* path = [[IJSVGExportElement alloc] initWithName:@"path"];
        NSString* value = index % 13 == 0 ? @"" : [NSString stringWithFormat:@"M%lu 0L1 1 café & <", (unsigned long)(index * 37 % 83)];
        if (index % 17 != 0) {
            [path setAttributeWithName:@"d" stringValue:value];
        }
        if (index % 19 == 0) {
            [path setAttributeWithName:@"vector-effect" stringValue:@"non-scaling-stroke"];
        }
        [root addChild:path];
        if (index % 17 == 0 || index % 19 == 0) {
            continue;
        }
        if (repeated[value] != nil) {
            [repeated[value] addObject:path];
        } else if (first[value] != nil) {
            NSMutableArray* group = [NSMutableArray arrayWithObjects:first[value], path, nil];
            repeated[value] = group;
            [expected addObject:group];
        } else {
            first[value] = path;
        }
    }
    XCTAssertEqualObjects(IJSVGExportDuplicatePaths(document), expected);
    for (IJSVGExportElement* path in root.children) {
        [path removeAttributeForName:@"d"];
    }
    XCTAssertEqual(IJSVGExportDuplicatePaths(document).count, 0U);
}

- (void)testGradientStopOffsetsPreserveFormattingPrecision
{
    NSArray<NSNumber*>* locations = @[ @0, @0.000000123456789, @0.123456789, @0.333333333333, @0.99999999, @1 ];
    NSMutableString* stops = [[NSMutableString alloc] init];
    for (NSNumber* location in locations) {
        [stops appendFormat:@"<stop offset='%.17g' stop-color='red' stop-opacity='.5'/>", location.doubleValue];
    }
    NSString* source = [NSString stringWithFormat:@"<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><defs><linearGradient id='g'>%@</linearGradient></defs><rect width='16' height='16' fill='url(#g)'/></svg>", stops];
    IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:IJSVGTestSVGObject(source) size:CGSizeMake(16, 16) options:IJSVGExporterOptionNone];
    NSError* error = nil;
    NSXMLDocument* parsed = [[NSXMLDocument alloc] initWithData:exporter.SVGData options:0 error:&error];
    XCTAssertNil(error);
    NSArray<NSXMLElement*>* exportedStops = (id)[parsed nodesForXPath:@"//*[local-name()='stop']" error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(exportedStops.count, locations.count);
    for (NSUInteger index = 0; index < MIN(exportedStops.count, locations.count); index++) {
        NSString* expected = [NSString stringWithFormat:@"%g%%", locations[index].doubleValue * 100];
        XCTAssertEqualObjects([exportedStops[index] attributeForName:@"offset"].stringValue, expected);
        XCTAssertEqualObjects([exportedStops[index] attributeForName:@"stop-color"].stringValue, @"#F00");
        XCTAssertEqualObjects([exportedStops[index] attributeForName:@"stop-opacity"].stringValue, @".5");
    }
}

- (void)testLiteralAttributesAndNamespacesRoundTrip
{
    IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
    NSString* value = @"café 😀 & < > \" ' &amp;\t\n\r";
    [root setAttributesAsDictionary:@{ @"xmlns" : @"http://www.w3.org/2000/svg", @"xmlns:xlink" : @"http://www.w3.org/1999/xlink", @"data-value" : value }];
    IJSVGExportElement* use = [[IJSVGExportElement alloc] initWithName:@"use"];
    [use setAttributesAsDictionary:@{ @"xlink:href" : @"#café" }];
    [root addChild:use];
    IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
    NSError* error = nil;
    NSXMLDocument* parsed = [[NSXMLDocument alloc] initWithData:[document XMLDataWithPrettyPrinting:NO] options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([parsed.rootElement attributeForName:@"data-value"].stringValue, value);
    XCTAssertEqualObjects(parsed.rootElement.URI, @"http://www.w3.org/2000/svg");
    NSXMLElement* child = (NSXMLElement*)parsed.rootElement.children.firstObject;
    XCTAssertEqualObjects([child attributeForName:@"xlink:href"].URI, @"http://www.w3.org/1999/xlink");
    XCTAssertEqualObjects([use attributeForName:@"xlink:href"].URI, @"http://www.w3.org/1999/xlink");
    const char* names[] = { "xlink:href" };
    XCTAssertEqualObjects(IJSVGExportAttributesNamed(document, names, 1), (@[ [use attributeForName:@"xlink:href"] ]));
    XCTAssertNil(error);
}

- (void)testDetachedSnapshotsSurviveDocumentDestructionAndReparenting
{
    IJSVGExportElement* retained = nil;
    @autoreleasepool {
        IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
        IJSVGExportElement* group = [[IJSVGExportElement alloc] initWithName:@"g"];
        retained = [[IJSVGExportElement alloc] initWithName:@"path"];
        [retained setAttributesAsDictionary:@{ @"d" : @"M0 0h8v8z" }];
        [group addChild:retained];
        [root addChild:group];
        IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
        XCTAssertEqual(document.rootElement.childCount, 1);
    }
    XCTAssertNil(retained.parent);
    XCTAssertEqualObjects([retained attributeForName:@"d"].stringValue, @"M0 0h8v8z");
    IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
    [root addChild:retained];
    IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
    XCTAssertEqualObjects(IJSVGExportElementsNamed(document, "path", NULL), (@[ retained ]));
    NSArray<IJSVGExportNode*>* attributes = retained.attributes;
    [retained removeAttributeForName:@"d"];
    IJSVGExportElement* replacement = [[IJSVGExportElement alloc] initWithName:@"path"];
    [replacement addAttribute:attributes.firstObject];
    [root replaceChildAtIndex:0 withNode:replacement];
    XCTAssertNil(retained.parent);
    XCTAssertEqualObjects([replacement attributeForName:@"d"].stringValue, @"M0 0h8v8z");
    const char* names[] = { "d" };
    XCTAssertEqualObjects(IJSVGExportAttributesNamed(document, names, 1), (@[ [replacement attributeForName:@"d"] ]));
}

- (void)testTextNodesAreNotMergedAndTextIsEscaped
{
    IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"text"];
    IJSVGExportNode* first = [[IJSVGExportNode alloc] initWithKind:IJSVGXMLNodeKindText];
    first.stringValue = @"A & ";
    IJSVGExportNode* second = [[IJSVGExportNode alloc] initWithKind:IJSVGXMLNodeKindText];
    second.stringValue = @"<B>";
    [root addChild:first];
    [root addChild:second];
    XCTAssertEqual(root.childCount, 2);
    [second detach];
    XCTAssertEqualObjects(first.stringValue, @"A & ");
    XCTAssertEqualObjects(second.stringValue, @"<B>");
    [root addChild:second];
    IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
    NSError* error = nil;
    NSXMLDocument* parsed = [[NSXMLDocument alloc] initWithData:[document XMLDataWithPrettyPrinting:YES] options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(parsed.rootElement.stringValue, @"A & <B>");
}

/// Checks compact formatting without removing meaningful content whitespace.
- (void)testRepeatedSerializationKeepsAttributeOrderAndCompactOutput
{
    IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
    [root addAttribute:[IJSVGExportNode attributeWithName:@"z" stringValue:@"1"]];
    [root addAttribute:[IJSVGExportNode attributeWithName:@"a" stringValue:@"2"]];
    [root addChild:[[IJSVGExportElement alloc] initWithName:@"path"]];
    IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
    NSData* first = [document XMLDataWithPrettyPrinting:NO];
    [document XMLDataWithPrettyPrinting:YES];
    XCTAssertEqualObjects([document XMLDataWithPrettyPrinting:NO], first);
    NSString* string = [document XMLStringWithPrettyPrinting:NO];
    XCTAssertTrue([string containsString:@"z=\"1\" a=\"2\""]);
    XCTAssertTrue([string hasSuffix:@"</svg>"]);
    XCTAssertTrue([string containsString:@"<path/>"]);
    XCTAssertFalse([string containsString:@"\n"]);
    XCTAssertTrue([string containsString:@"?><svg"]);

    root.stringValue = @"first\nsecond";
    NSString* content = [document XMLStringWithPrettyPrinting:NO];
    XCTAssertTrue([content containsString:@">first\nsecond</svg>"]);
    XCTAssertTrue([content containsString:@"?><svg"]);

    for (NSNumber* prettyPrint in @[ @NO, @YES ]) {
        NSData* data = [document XMLDataWithPrettyPrinting:prettyPrint.boolValue includeXMLDeclaration:NO];
        NSString* withoutDeclaration = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        XCTAssertTrue([withoutDeclaration hasPrefix:@"<svg"]);
        XCTAssertFalse([withoutDeclaration containsString:@"<?xml"]);
        NSError* error = nil;
        NSXMLDocument* parsed = [[NSXMLDocument alloc] initWithData:data options:0 error:&error];
        XCTAssertNil(error);
        XCTAssertEqualObjects(parsed.rootElement.stringValue, @"first\nsecond");
    }
    XCTAssertEqualObjects([document XMLStringWithPrettyPrinting:NO], content);
}

- (void)testExporterDelegateUsesMutableExportElements
{
    IJSVG* svg = IJSVGTestSVGObject(@"<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect width='16' height='16' fill='url(#g)'/></svg>");
    IJSVGExportIdentifierDelegate* delegate = [[IJSVGExportIdentifierDelegate alloc] init];
    NSData* data = nil;
    @autoreleasepool {
        IJSVGExporter* exporter = [[IJSVGExporter alloc] initWithSVG:svg size:CGSizeMake(16, 16) options:IJSVGExporterOptionNone];
        exporter.delegate = delegate;
        data = exporter.SVGData;
    }
    NSError* error = nil;
    NSXMLDocument* parsed = [[NSXMLDocument alloc] initWithData:data options:0 error:&error];
    XCTAssertNil(error);
    NSXMLElement* gradient = (NSXMLElement*)[parsed nodesForXPath:@"//*[local-name()='linearGradient']" error:&error].firstObject;
    XCTAssertNil(error);
    XCTAssertTrue([[gradient attributeForName:@"id"].stringValue hasPrefix:@"custom-"]);
    XCTAssertEqualObjects([gradient attributeForName:@"data-delegate"].stringValue, @"café & <tag>");
    XCTAssertEqualObjects(delegate.retainedElement.name, @"linearGradient");
    XCTAssertNil(delegate.retainedElement.parent);
}

- (void)testWideSiblingOwnershipAndAttributeReplacement
{
    IJSVGExportElement* retained = nil;
    IJSVGExportNode* oldAttribute = nil;
    @autoreleasepool {
        IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
        for (NSUInteger index = 0; index < 20000; index++) {
            IJSVGExportElement* child = [[IJSVGExportElement alloc] initWithName:@"path"];
            [root addChild:child];
            if (index == 10000) {
                retained = child;
            }
        }
        XCTAssertEqual(root.childCount, 20000);
        oldAttribute = [IJSVGExportNode attributeWithName:@"id" stringValue:@"old"];
        [retained addAttribute:oldAttribute];
        [retained addAttribute:[IJSVGExportNode attributeWithName:@"id" stringValue:@"new"]];
        XCTAssertNil(oldAttribute.parent);
        XCTAssertEqual(retained.attributes.count, 1);
        [root insertChild:retained atIndex:0];
        XCTAssertEqual(root.children.firstObject, retained);
        XCTAssertEqual(root.childCount, 20000);
    }
    XCTAssertNil(retained.parent);
    XCTAssertNil(retained.nextSibling);
    XCTAssertEqualObjects(oldAttribute.stringValue, @"old");
    XCTAssertEqualObjects([retained attributeForName:@"id"].stringValue, @"new");
}

- (void)testCQueriesPreserveDocumentOrderAndHiddenStyleMatching
{
    IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
    IJSVGExportElement* group = [[IJSVGExportElement alloc] initWithName:@"g"];
    [root addChild:group];
    NSArray<NSString*>* styles = @[ @"DISPLAY: NONE", @"fill:red; dis\tplay : n\none", @"display:block", @"display:non", @"display:none" ];
    for (NSString* style in styles) {
        IJSVGExportElement* path = [[IJSVGExportElement alloc] initWithName:@"path"];
        [path setAttributesAsDictionary:@{ @"style" : style, @"fill" : @"red" }];
        [group addChild:path];
    }
    IJSVGExportElement* excluded = (IJSVGExportElement*)group.children.lastObject;
    [excluded setAttributesAsDictionary:@{ @"vector-effect" : @"non-scaling-stroke", @"display" : @"none" }];
    IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
    XCTAssertEqualObjects(IJSVGExportElementsNamed(document, "path", "vector-effect"), [group.children subarrayWithRange:NSMakeRange(0, 4)]);
    const char* names[] = { "fill", "style" };
    NSMutableArray<IJSVGExportNode*>* expectedAttributes = [[NSMutableArray alloc] init];
    for (IJSVGExportElement* path in group.children) {
        for (IJSVGExportNode* attribute in path.attributes) {
            if ([attribute.name isEqualToString:@"fill"] || [attribute.name isEqualToString:@"style"]) {
                [expectedAttributes addObject:attribute];
            }
        }
    }
    XCTAssertEqualObjects(IJSVGExportAttributesNamed(document, names, 2), expectedAttributes);
    XCTAssertEqualObjects(IJSVGExportHiddenElements(document), (@[ group.children[0], group.children[1], group.children[4] ]));
}

- (void)testDirectReplacementPreservesSiblingOwnership
{
    IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
    IJSVGExportElement* first = [[IJSVGExportElement alloc] initWithName:@"a"];
    IJSVGExportElement* middle = [[IJSVGExportElement alloc] initWithName:@"b"];
    IJSVGExportElement* last = [[IJSVGExportElement alloc] initWithName:@"c"];
    root.children = @[ first, middle, last ];
    [middle replaceWithNode:first];
    XCTAssertEqualObjects(root.children, (@[ first, last ]));
    XCTAssertEqual(root.childCount, 2);
    XCTAssertNil(middle.parent);
    XCTAssertNil(middle.nextSibling);
    [first replaceWithNode:last];
    XCTAssertEqualObjects(root.children, (@[ last ]));
    XCTAssertEqual(root.childCount, 1);
    [last replaceWithNode:last];
    XCTAssertThrows([last replaceWithNode:root]);
    [last replaceWithNode:middle];
    XCTAssertEqualObjects(root.children, (@[ middle ]));
    XCTAssertNil(last.parent);
    IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
    XCTAssertTrue([[document XMLStringWithPrettyPrinting:NO] containsString:@"<svg><b/></svg>"]);
}

- (void)testCGradientComparisonRespectsNamespacesAndValues
{
    IJSVGExportElement* left = [[IJSVGExportElement alloc] initWithName:@"linearGradient"];
    IJSVGExportElement* right = [[IJSVGExportElement alloc] initWithName:@"linearGradient"];
    for (IJSVGExportElement* gradient in @[ left, right ]) {
        [gradient setAttributesAsDictionary:@{ @"xmlns:p" : @"urn:first" }];
        IJSVGExportElement* stop = [[IJSVGExportElement alloc] initWithName:@"stop"];
        [stop addAttribute:[IJSVGExportNode attributeWithName:@"p:value" stringValue:@"café & <red>"]];
        [gradient addChild:stop];
    }
    XCTAssertTrue(IJSVGExportChildrenEqual(left, right));
    XCTAssertEqual(IJSVGExportChildrenHash(left), IJSVGExportChildrenHash(right));
    [right setAttributesAsDictionary:@{ @"xmlns:p" : @"urn:second" }];
    XCTAssertFalse(IJSVGExportChildrenEqual(left, right));
    [right setAttributesAsDictionary:@{ @"xmlns:p" : @"urn:first" }];
    IJSVGExportElement* stop = (IJSVGExportElement*)right.children.firstObject;
    [stop attributeForName:@"p:value"].stringValue = @"blue";
    XCTAssertFalse(IJSVGExportChildrenEqual(left, right));
    [stop attributeForName:@"p:value"].stringValue = @"café & <red>";
    XCTAssertTrue(IJSVGExportChildrenEqual(left, right));
    [stop addChild:[[IJSVGExportElement alloc] initWithName:@"extra"]];
    XCTAssertFalse(IJSVGExportChildrenEqual(left, right));
}

- (void)testDefaultCleanupPreservesInheritanceAndRestoresSiblingState
{
    IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
    [root setAttributesAsDictionary:@{ @"fill" : @"blue" }];
    IJSVGExportElement* group = [[IJSVGExportElement alloc] initWithName:@"g"];
    [group setAttributesAsDictionary:@{ @"fill" : @"red", @"opacity" : @".5" }];
    IJSVGExportElement* nested = [[IJSVGExportElement alloc] initWithName:@"g"];
    [group addChild:nested];
    IJSVGExportElement* path = [[IJSVGExportElement alloc] initWithName:@"path"];
    [path setAttributesAsDictionary:@{ @"fill" : @"#000", @"opacity" : @"1" }];
    [nested addChild:path];
    IJSVGExportElement* sibling = [[IJSVGExportElement alloc] initWithName:@"path"];
    [sibling setAttributesAsDictionary:@{ @"fill" : @"#000" }];
    IJSVGExportElement* identified = [[IJSVGExportElement alloc] initWithName:@"path"];
    [identified setAttributesAsDictionary:@{ @"id" : @"keep", @"fill" : @"#000", @"opacity" : @"1" }];
    root.children = @[ group, sibling, identified ];
    IJSVGExportRemoveDefaultAttributes(root, @{ @"fill" : @"#000", @"opacity" : @"1" }, [NSSet setWithObject:@"fill"]);
    XCTAssertEqualObjects([path attributeForName:@"fill"].stringValue, @"#000");
    XCTAssertNil([path attributeForName:@"opacity"]);
    XCTAssertNil([sibling attributeForName:@"fill"]);
    XCTAssertNotNil([identified attributeForName:@"fill"]);
    XCTAssertNotNil([identified attributeForName:@"opacity"]);
    XCTAssertEqualObjects([root attributeForName:@"fill"].stringValue, @"blue");
}

- (void)testReferenceCollectionMatchesExistingURLSemantics
{
    XCTAssertNil(IJSVGDefURLFromBytes(NULL, 0));
    XCTAssertNil(IJSVGDefURLFromBytes("", 0));
    IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
    NSArray* values = @[ @"url(#paint)", @"url( '#café & space' )", @"none", @"#fff", @"url(\"#clip\")", @"url(mask)", @"url(#first) url(#second)" ];
    NSMutableSet* expected = [[NSMutableSet alloc] initWithObjects:@"href", @"linked", nil];
    for (NSString* value in values) {
        IJSVGExportElement* path = [[IJSVGExportElement alloc] initWithName:@"path"];
        [path setAttributesAsDictionary:@{ @"fill" : value, @"data-ignore" : @"url(#ignored)" }];
        [root addChild:path];
        NSString* identifier = [IJSVGUtils defURL:value];
        if (identifier.length != 0) {
            [expected addObject:identifier];
        }
    }
    [root setAttributesAsDictionary:@{ @"href" : @"#href", @"xlink:href" : @"#linked" }];
    IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
    XCTAssertEqualObjects(IJSVGExportReferencedIdentifiers(document, IJSVGDefURLFromBytes), expected);
}

- (void)testCGroupingMatchesExhaustiveRunSelection
{
    uint64_t state = 42;
    NSArray* names = @[ @"fill", @"stroke", @"fill-opacity" ];
    for (NSUInteger trial = 0; trial < 150; trial++) {
        @autoreleasepool {
            IJSVGExportElement* parent = [[IJSVGExportElement alloc] initWithName:@"g"];
            for (NSUInteger index = 0; index < 30; index++) {
                if (index % 11 == 10) {
                    [parent addChild:[[IJSVGExportNode alloc] initWithKind:IJSVGXMLNodeKindComment]];
                    continue;
                }
                IJSVGExportElement* child = [[IJSVGExportElement alloc] initWithName:@"path"];
                for (NSString* name in names) {
                    state = state * UINT64_C(6364136223846793005) + 1;
                    NSUInteger value = (state >> 32) % 4;
                    if (value != 0) {
                        [child addAttribute:[IJSVGExportNode attributeWithName:name stringValue:@[ @"", @"red", @"blue", @"" ][value]]];
                    }
                }
                [parent addChild:child];
            }
            NSArray* children = parent.children;
            NSRange expectedRange = NSMakeRange(NSNotFound, 0);
            NSDictionary* expectedAttributes = @{};
            for (NSUInteger start = 0; start < children.count; start++) {
                NSMutableDictionary* common = [[NSMutableDictionary alloc] init];
                for (NSUInteger end = start; end < children.count; end++) {
                    IJSVGExportElement* child = children[end];
                    if (child.kind != IJSVGXMLNodeKindElement) {
                        break;
                    }
                    for (NSString* name in names) {
                        NSString* value = [child attributeForName:name].stringValue;
                        if (end == start && value != nil) {
                            common[name] = value;
                        } else if (![common[name] isEqualToString:value]) {
                            [common removeObjectForKey:name];
                        }
                    }
                    if (common.count == 0) {
                        break;
                    }
                    NSUInteger length = end - start + 1;
                    if (length >= 2 && (length > expectedRange.length || (length == expectedRange.length && common.count > expectedAttributes.count))) {
                        expectedRange = NSMakeRange(start, length);
                        expectedAttributes = common.copy;
                    }
                }
            }
            NSRange actualRange;
            NSDictionary* actualAttributes = IJSVGExportSharedAttributes(parent, names, &actualRange);
            XCTAssertTrue(NSEqualRanges(actualRange, expectedRange));
            XCTAssertEqualObjects(actualAttributes, expectedAttributes);
        }
    }
}

- (void)testDirectAttributeWritesPreserveIdentityOrderAndEscaping
{
    IJSVGExportElement* root = [[IJSVGExportElement alloc] initWithName:@"svg"];
    IJSVGExportDocument* document = [[IJSVGExportDocument alloc] initWithRootElement:root];
    [root setAttributeWithName:@"first" stringValue:@"one"];
    [root setAttributeWithName:@"second" stringValue:@"two"];
    IJSVGExportNode* retained = [root attributeForName:@"first"];
    NSString* value = @"café & <tag> \" \n\t";
    [root setAttributeWithName:@"first" stringValue:value];
    XCTAssertEqual([root attributeForName:@"first"], retained);
    XCTAssertEqual(root.attributes.count, 2);
    XCTAssertEqualObjects([root.attributes valueForKey:@"name"], (@[ @"first", @"second" ]));
    NSError* error = nil;
    NSXMLDocument* parsed = [[NSXMLDocument alloc] initWithData:[document XMLDataWithPrettyPrinting:NO] options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([parsed.rootElement attributeForName:@"first"].stringValue, value);
    [retained detach];
    XCTAssertEqual(root.attributes.count, 1);
    XCTAssertEqualObjects(retained.stringValue, value);
}

@end
