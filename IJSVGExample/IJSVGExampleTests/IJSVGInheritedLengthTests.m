//
//  IJSVGInheritedLengthTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTestHelpers.h>
#import <IJSVG/IJSVGGradientUnitLength.h>
#import <math.h>

@interface IJSVGInheritedLengthTests: XCTestCase
@end

@implementation IJSVGInheritedLengthTests

- (void)testInheritedLengthsFollowParentReplacements
{
    for(NSString* property in @[@"fillOpacity", @"strokeOpacity", @"strokeWidth", @"strokeDashOffset"]) {
        IJSVGNode* first = [[IJSVGNode alloc] init];
        IJSVGNode* second = [[IJSVGNode alloc] init];
        IJSVGNode* child = [[IJSVGNode alloc] init];
        IJSVGUnitLength* firstValue = [IJSVGUnitLength unitWithFloat:0.25f];
        IJSVGUnitLength* secondValue = [IJSVGUnitLength unitWithFloat:0.75f];
        [first setValue:firstValue forKey:property];
        [second setValue:secondValue forKey:property];
        child.parentNode = first;
        XCTAssertEqual([child valueForKey:property], firstValue);

        IJSVGUnitLength* replacement = [firstValue lengthWithValue:0.5f];
        [first setValue:replacement forKey:property];
        IJSVGUnitLength* resolved = [child valueForKey:property];
        XCTAssertNotNil(resolved);
        XCTAssertEqual(resolved.value, 0.5f);
        XCTAssertEqual(firstValue.value, 0.25f);

        child.parentNode = second;
        XCTAssertEqual([child valueForKey:property], secondValue);
        child.styleParent = first;
        XCTAssertEqual([child valueForKey:property], replacement);
        child.styleParent = nil;
        child.parentNode = nil;

        IJSVGUnitLength* ownDefault = [child valueForKey:property];
        XCTAssertNotNil(ownDefault);
        XCTAssertEqual(ownDefault.value, [property isEqualToString:@"strokeDashOffset"] ? 0.f : 1.f);
        XCTAssertTrue(ownDefault.inherit);
        IJSVGUnitLength* explicit = [ownDefault lengthWithValue:0.375f];
        [child setValue:explicit forKey:property];
        child.parentNode = first;
        XCTAssertEqual([child valueForKey:property], explicit);
        [child setValue:nil forKey:property];
        if([property isEqualToString:@"strokeDashOffset"]) {
            XCTAssertEqual([child valueForKey:property], replacement);
        } else {
            XCTAssertNil([child valueForKey:property]);
        }
    }
}

- (void)testOpacityPreservesReplacementNilAndExplicitInheritance
{
    IJSVGNode* parent = [[IJSVGNode alloc] init];
    IJSVGNode* child = [[IJSVGNode alloc] init];
    child.parentNode = parent;
    parent.opacity = [IJSVGUnitLength unitWithFloat:0.25f];
    XCTAssertEqual(child.opacity.value, 1.f);

    IJSVGUnitLength* inherited = [[IJSVGUnitLength unitWithFloat:1.f] lengthWithInheritance:YES];
    XCTAssertNotNil(inherited);
    child.opacity = inherited;
    XCTAssertEqual(child.opacity.value, 0.25f);
    parent.opacity = [IJSVGUnitLength unitWithFloat:0.5f];
    XCTAssertEqual(child.opacity.value, 0.5f);

    IJSVGNode* styleParent = [[IJSVGNode alloc] init];
    styleParent.opacity = [IJSVGUnitLength unitWithFloat:0.75f];
    child.styleParent = styleParent;
    XCTAssertEqual(child.opacity.value, 0.75f);
    child.styleParent = nil;
    child.parentNode = nil;
    XCTAssertEqual(child.opacity, inherited);
    child.opacity = nil;
    XCTAssertNil(child.opacity);
}

- (void)testCommonLengthsShareOnlyMatchingMetadata
{
    IJSVGUnitLength* one = [IJSVGUnitLength unitWithFloat:1.f];
    IJSVGUnitLength* parsed = [IJSVGUnitLength unitWithString:@"1"];
    XCTAssertNotNil(one);
    XCTAssertNotNil(parsed);
    XCTAssertNotEqual(one, parsed);
    XCTAssertEqual(one.value, parsed.value);

    IJSVGNode* firstNode = [[IJSVGNode alloc] init];
    IJSVGNode* secondNode = [[IJSVGNode alloc] init];
    XCTAssertNotNil(firstNode.opacity);
    XCTAssertNotNil(firstNode.fillOpacity);
    XCTAssertNotNil(firstNode.strokeDashOffset);
    XCTAssertEqual(firstNode.opacity, secondNode.opacity);
    XCTAssertEqual(firstNode.fillOpacity, secondNode.fillOpacity);
    XCTAssertEqual(firstNode.strokeDashOffset, secondNode.strokeDashOffset);
    XCTAssertEqual(one.copy, one);

    IJSVGUnitLength* percent = [IJSVGUnitLength unitWithFloat:1.f type:IJSVGUnitLengthTypePercentage];
    XCTAssertNotNil(percent);
    XCTAssertEqual(percent.value, [IJSVGUnitLength unitWithString:@"100%"].value);
    XCTAssertNotEqual(percent, one);
    IJSVGUnitLength* inherited = [one lengthWithInheritance:YES];
    XCTAssertNotNil(inherited);
    XCTAssertNotEqual(inherited, one);
    XCTAssertNotEqual(inherited, [one lengthWithInheritance:YES]);
    XCTAssertFalse(one.inherit);
    XCTAssertTrue(inherited.inherit);

    IJSVGUnitLength* changed = [inherited lengthWithValue:0.5f];
    XCTAssertNotNil(changed);
    XCTAssertEqual(changed.value, 0.5f);
    XCTAssertFalse(changed.inherit);
    XCTAssertEqual(inherited.value, 1.f);
    XCTAssertTrue(inherited.inherit);

    IJSVGUnitLength* pixels = [IJSVGUnitLength unitWithString:@"1px"];
    XCTAssertNotNil(pixels);
    XCTAssertNotEqual(pixels, one);
    XCTAssertEqual(pixels.originalType, IJSVGUnitLengthTypePX);
    IJSVGUnitLength* negativeZero = [IJSVGUnitLength unitWithString:@"-0"];
    XCTAssertNotNil(negativeZero);
    XCTAssertTrue(signbit(negativeZero.value));
    XCTAssertNotEqual(negativeZero, [IJSVGUnitLength unitWithFloat:0.f]);

    IJSVGUnitLength* subclass = [IJSVGGradientUnitLength unitWithFloat:1.f type:IJSVGUnitLengthTypePercentage];
    XCTAssertNotNil(subclass);
    XCTAssertEqualObjects(subclass.stringValue, @"1");
    XCTAssertEqual(subclass.copy, subclass);
}

@end
