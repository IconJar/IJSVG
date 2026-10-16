//
//  IJSVGUtilityParsingTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

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
#import <IJSVGByteCache.h>
#import <IJSVGByteHash.h>
#import <IJSVGParsedPathCache.h>
#import <IJSVGParserUtils.h>
#import <IJSVGTestHelpers.h>
#import <IJSVGXML.h>
#import <sys/mman.h>
#import <unistd.h>

@interface IJSVGUtilityParsingTests : XCTestCase
@end

@implementation IJSVGUtilityParsingTests

- (void)testByteHashMatchesXXH64ReferenceVectors
{
    // Expected values were generated with upstream xxHash 0.8.3, seed zero.
    // Cover empty input, every tail width, and both sides of stripe boundaries.
    const size_t lengths[] = { 0, 1, 7, 8, 15, 16, 31, 32, 33, 63, 64, 65, 255, 256, 4096 };
    const uint64_t expected[] = {
        UINT64_C(0xef46db3751d8e999), UINT64_C(0xe934a84adb052768),
        UINT64_C(0x14cc643f630c72d2), UINT64_C(0x884a173614b81b8d),
        UINT64_C(0xa948f5f0f6abac2d), UINT64_C(0x44b6ef2fb84169f7),
        UINT64_C(0xc346d2b59b4d8ee1), UINT64_C(0xcbf59c5116ff32b4),
        UINT64_C(0x0c535d1acafb8ead), UINT64_C(0xe26aa9e2a95f8e4f),
        UINT64_C(0xf7c67301db6713f0), UINT64_C(0xc31eb63b2ae4465b),
        UINT64_C(0x0f7d97507caad693), UINT64_C(0x1facbe8406cd904b),
        UINT64_C(0x0f6e64be186af6a4)
    };
    unsigned char bytes[4096 + 16];
    for (NSUInteger offset = 0; offset < 16; offset++) {
        for (NSUInteger index = 0; index < 4096; index++) {
            bytes[offset + index] = (unsigned char)index;
        }
        for (NSUInteger index = 0; index < sizeof(lengths) / sizeof(lengths[0]); index++) {
            XCTAssertEqual(IJSVGHashBytes(bytes + offset, lengths[index]), expected[index], @"offset %lu, length %zu", (unsigned long)offset, lengths[index]);
        }
    }
    XCTAssertEqual(IJSVGHashBytes(NULL, 0), expected[0]);
}

- (void)testByteCacheAccountsForValueCostOnReplacement
{
    IJSVGByteCache* cache = IJSVGByteCacheCreate(100, 1024);
    IJSVGByteCacheSetValueWithCost(cache, "a", 1, CFSTR("a"), 200);
    IJSVGByteCacheSetValueWithCost(cache, "b", 1, CFSTR("b"), 200);
    IJSVGByteCacheSetValueWithCost(cache, "c", 1, CFSTR("c"), 200);

    // Growing the oldest entry evicts other entries without losing the replacement.
    IJSVGByteCacheSetValueWithCost(cache, "a", 1, CFSTR("large"), 800);
    XCTAssertEqual(IJSVGByteCacheGetCount(cache), 1u);
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, "a", 1), CFSTR("large"));
    IJSVGByteCacheSetValueWithCost(cache, "a", 1, CFSTR("overflow"), SIZE_MAX);
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, "a", 1), CFSTR("large"));
    IJSVGByteCacheSetValueWithCost(cache, "a", 1, CFSTR("small"), 0);
    IJSVGByteCacheSetValueWithCost(cache, "b", 1, CFSTR("b"), 800);
    XCTAssertEqual(IJSVGByteCacheGetCount(cache), 2u);
    IJSVGByteCacheSetValueWithCost(cache, "c", 1, CFSTR("c"), 800);
    XCTAssertEqual(IJSVGByteCacheGetCount(cache), 1u);
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, "c", 1), CFSTR("c"));
    IJSVGByteCacheDestroy(cache);
}

- (void)testSharedPathCachePreservesAllKindsForOneSource
{
    IJSVGParsedPathCache* cache = IJSVGParsedPathCacheCreate();
    CGMutablePathRef path = CGPathCreateMutable();
    for (NSUInteger kind = 0; kind < IJSVGParsedPathKindCount; kind++) {
        CGPathMoveToPoint(path, NULL, kind, kind + 1);
        IJSVGParsedPathCacheStoreBytes(cache, "same", 4, kind, path);
    }
    for (NSUInteger kind = 0; kind < IJSVGParsedPathKindCount; kind++) {
        CGPathRef saved = IJSVGParsedPathCacheCopyBytes(cache, "same", 4, kind);
        XCTAssertNotEqual(saved, NULL);
        XCTAssertTrue(CGPointEqualToPoint(CGPathGetCurrentPoint(saved), CGPointMake(kind, kind + 1)));
        CGPathRelease(saved);
    }
    XCTAssertEqual(IJSVGParsedPathCacheCopyBytes(cache, "same", 4, (IJSVGParsedPathKind)-1), NULL);
    CGPathRelease(path);
    IJSVGParsedPathCacheDestroy(cache);
}

- (void)testByteCacheCopiesBinaryKeysAndDistinguishesLengths
{
    IJSVGByteCache* cache = IJSVGByteCacheCreate(8, 4096);
    XCTAssertNotEqual(cache, NULL);
    unsigned char buffer[] = { 99, 1, 0, 2, 3 };
    const unsigned char original[] = { 1, 0, 2, 3 };
    IJSVGByteCacheSetValue(cache, buffer + 1, 4, CFSTR("full"));
    IJSVGByteCacheSetValue(cache, buffer + 1, 2, CFSTR("prefix"));
    IJSVGByteCacheSetValue(cache, NULL, 0, CFSTR("empty"));
    buffer[1] = 7;
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, original, 4), CFSTR("full"));
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, original, 2), CFSTR("prefix"));
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, NULL, 0), CFSTR("empty"));
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, buffer + 1, 4), NULL);
    XCTAssertEqual(IJSVGByteCacheGetCount(cache), 3u);
    IJSVGByteCacheDestroy(cache);
}

- (void)testByteCacheRetainsReplacesEvictsAndReleasesValues
{
    IJSVGByteCache* cache = IJSVGByteCacheCreate(1, 4096);
    __weak NSObject* first;
    __weak NSObject* second;
    @autoreleasepool {
        NSObject* value = [[NSObject alloc] init];
        first = value;
        IJSVGByteCacheSetValue(cache, "a", 1, (__bridge CFTypeRef)value);
    }
    XCTAssertNotNil(first);
    @autoreleasepool {
        NSObject* value = [[NSObject alloc] init];
        second = value;
        IJSVGByteCacheSetValue(cache, "a", 1, (__bridge CFTypeRef)value);
    }
    XCTAssertNil(first);
    XCTAssertNotNil(second);
    XCTAssertEqual(IJSVGByteCacheGetCount(cache), 1u);

    // A borrowed value must survive insertion that evicts its original key.
    IJSVGByteCacheSetValue(cache, "b", 1, IJSVGByteCacheGetValue(cache, "a", 1));
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, "a", 1), NULL);
    XCTAssertNotNil(second);
    IJSVGByteCacheDestroy(cache);
    XCTAssertNil(second);
}

- (void)testByteCacheEnforcesLimitsAndRejectsInvalidLengths
{
    IJSVGByteCache* cache = IJSVGByteCacheCreate(100, 256);
    unsigned char key[128] = { 0 };
    IJSVGByteCacheSetValue(cache, key, sizeof(key), CFSTR("old"));
    key[0] = 1;
    IJSVGByteCacheSetValue(cache, key, sizeof(key), CFSTR("new"));
    XCTAssertEqual(IJSVGByteCacheGetCount(cache), 1u);
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, key, sizeof(key)), CFSTR("new"));
    key[0] = 0;
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, key, sizeof(key)), NULL);
    IJSVGByteCacheSetValue(cache, key, SIZE_MAX, CFSTR("oversized"));
    IJSVGByteCacheSetValue(cache, NULL, 1, CFSTR("invalid"));
    IJSVGByteCacheSetValue(cache, "null", 4, NULL);
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, key, SIZE_MAX), NULL);
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, NULL, 1), NULL);
    XCTAssertEqual(IJSVGByteCacheGetCount(cache), 1u);
    IJSVGByteCacheDestroy(cache);
    for (NSUInteger index = 0; index < 2; index++) {
        cache = IJSVGByteCacheCreate(index == 0 ? 0 : 10, index == 0 ? 4096 : 0);
        IJSVGByteCacheSetValue(cache, "key", 3, CFSTR("ignored"));
        XCTAssertEqual(IJSVGByteCacheGetCount(cache), 0u);
        IJSVGByteCacheDestroy(cache);
    }
    XCTAssertEqual(IJSVGByteCacheGetCount(NULL), 0u);
    XCTAssertEqual(IJSVGByteCacheGetValue(NULL, NULL, 0), NULL);
    IJSVGByteCacheSetValue(NULL, NULL, 0, CFSTR("ignored"));
    IJSVGByteCacheDestroy(NULL);
}

- (void)testByteCacheBucketCollisionsAndFIFOEviction
{
    IJSVGByteCache* cache = IJSVGByteCacheCreate(8, 4096);
    uint64_t keys[12];
    NSUInteger count = 0;
    for (uint64_t candidate = 0; count < 12; candidate++) {
        // Deliberately exercise the same bucket in the 1024 bucket table.
        if ((IJSVGHashBytes(&candidate, sizeof(candidate)) & 1023) == 0) {
            keys[count++] = candidate;
        }
    }
    for (NSUInteger index = 0; index < 8; index++) {
        IJSVGByteCacheSetValue(cache, keys + index, sizeof(uint64_t), (__bridge CFTypeRef) @(index));
    }
    IJSVGByteCacheSetValue(cache, keys, sizeof(uint64_t), CFSTR("replacement"));
    XCTAssertEqual(IJSVGByteCacheGetCount(cache), 8u);
    XCTAssertEqual(IJSVGByteCacheGetValue(cache, keys, sizeof(uint64_t)), CFSTR("replacement"));
    for (NSUInteger index = 8; index < 12; index++) {
        IJSVGByteCacheSetValue(cache, keys + index, sizeof(uint64_t), (__bridge CFTypeRef) @(index));
    }
    for (NSUInteger index = 0; index < 12; index++) {
        id value = (__bridge id)IJSVGByteCacheGetValue(cache, keys + index, sizeof(uint64_t));
        if (index < 4) {
            XCTAssertNil(value);
        } else {
            XCTAssertEqualObjects(value, @(index));
        }
    }
    IJSVGByteCacheDestroy(cache);
}

- (void)testByteHashAndCacheRespectGuardPageBoundaries
{
    size_t page = (size_t)getpagesize();
    unsigned char* memory = mmap(NULL, page * 2, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    XCTAssertNotEqual(memory, MAP_FAILED);
    if (memory == MAP_FAILED) {
        return;
    }
    int result = mprotect(memory + page, page, PROT_NONE);
    XCTAssertEqual(result, 0);
    if (result != 0) {
        munmap(memory, page * 2);
        return;
    }
    unsigned char bytes[257];
    for (NSUInteger index = 0; index < sizeof(bytes); index++) {
        bytes[index] = (unsigned char)index;
    }
    IJSVGByteCache* cache = IJSVGByteCacheCreate(300, 128 * 1024);
    for (NSUInteger length = 0; length <= sizeof(bytes); length++) {
        unsigned char* slice = memory + page - length;
        memcpy(slice, bytes, length);
        XCTAssertEqual(IJSVGHashBytes(slice, length), IJSVGHashBytes(bytes, length));
        IJSVGByteCacheSetValue(cache, slice, length, (__bridge CFTypeRef) @(length));
        XCTAssertEqualObjects((__bridge id)IJSVGByteCacheGetValue(cache, bytes, length), @(length));
    }
    IJSVGByteCacheDestroy(cache);
    munmap(memory, page * 2);
}

- (void)testPathCommandScanRespectsSliceEndAndEmbeddedNUL
{
    size_t page = (size_t)getpagesize();
    char* memory = mmap(NULL, page * 2, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    XCTAssertNotEqual(memory, MAP_FAILED);
    if (memory == MAP_FAILED) {
        return;
    }
    int result = mprotect(memory + page, page, PROT_NONE);
    XCTAssertEqual(result, 0);
    if (result != 0) {
        munmap(memory, page * 2);
        return;
    }
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    CGMutablePathRef expected = CGPathCreateMutable();
    CGPathMoveToPoint(expected, NULL, 10, 20);
    CGPathAddLineToPoint(expected, NULL, 30, 40);
    for (NSUInteger padding = 0; padding < 64; padding++) {
        NSString* source = [NSString stringWithFormat:@"M1e1 2E1 %@L30 40",
            [@"" stringByPaddingToLength:padding
                              withString:@" "
                         startingAtIndex:0]];
        NSData* data = [source dataUsingEncoding:NSUTF8StringEncoding];
        char* slice = memory + page - data.length;
        memcpy(slice, data.bytes, data.length);
        CGMutablePathRef path = IJSVGCreatePathFromData(slice, data.length, stream);
        XCTAssertTrue(CGPathEqualToPath(path, expected), @"padding %lu", (unsigned long)padding);
        CGPathRelease(path);

        // A terminator inside a complete vector block must stop the scan too.
        NSMutableData* terminated = [data mutableCopy];
        const char suffix[] = "\0 L99 99                                 ";
        [terminated appendBytes:suffix length:sizeof(suffix) - 1];
        slice = memory + page - terminated.length;
        memcpy(slice, terminated.bytes, terminated.length);
        path = IJSVGCreatePathFromData(slice, terminated.length, stream);
        XCTAssertTrue(CGPathEqualToPath(path, expected), @"NUL padding %lu", (unsigned long)padding);
        CGPathRelease(path);
    }
    CGPathRelease(expected);
    IJSVGPathDataStreamRelease(stream);
    munmap(memory, page * 2);
}

- (void)testPathCommandScanRecognizesEveryCommandAtBlockBoundaries
{
    NSArray<NSString*>* commands = @[
        @"M10 20", @"l3 4", @"H50", @"v6", @"C10 20 30 40 50 60",
        @"s3 4 5 6", @"Q10 20 30 40", @"t3 4", @"A10 20 0 0 1 50 60",
        @"z", @"m1 2", @"L3 4", @"h5", @"V6", @"c1 2 3 4 5 6",
        @"S10 20 30 40", @"q1 2 3 4", @"T10 20", @"a10 20 0 1 0 5 6", @"Z"
    ];
    NSString* compact = [commands componentsJoinedByString:@" "];
    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
    CGMutablePathRef expected = IJSVGCreatePathFromData(compact.UTF8String, strlen(compact.UTF8String), stream);
    for (NSUInteger padding = 1; padding <= 32; padding++) {
        NSString* separator = [@"" stringByPaddingToLength:padding withString:@" " startingAtIndex:0];
        NSString* source = [commands componentsJoinedByString:separator];
        CGMutablePathRef path = IJSVGCreatePathFromData(source.UTF8String, strlen(source.UTF8String), stream);
        XCTAssertTrue(CGPathEqualToPath(path, expected), @"padding %lu", (unsigned long)padding);
        CGPathRelease(path);
    }
    CGPathRelease(expected);
    IJSVGPathDataStreamRelease(stream);
}

- (void)testCXMLStorageOwnsInputAndKeepsNamespacesAndText
{
    const char* source = "<svg xmlns:q='http://www.w3.org/1999/xlink'><g id='a' q:href='#b'/><text>one<![CDATA[ two]]> three</text></svg>";
    size_t length = strlen(source);
    char* bytes = malloc(length);
    memcpy(bytes, source, length);
    IJSVGXMLDocument* document = IJSVGXMLDocumentCreate(bytes, length);
    memset(bytes, '?', length);
    free(bytes);
    XCTAssertNotEqual(document, NULL);
    if (document == NULL) {
        return;
    }
    IJSVGXMLNode* root = IJSVGXMLRoot(document);
    IJSVGXMLNode* group = IJSVGXMLFirstChild(root);
    XCTAssertEqual(IJSVGXMLParent(group), root);
    XCTAssertEqual(IJSVGXMLChildCount(root), 2u);
    IJSVGXMLAttribute* href = IJSVGXMLAttributeNamed(group, @"q:href");
    XCTAssertEqualObjects(IJSVGXMLAttributeValue(href), @"#b");
    XCTAssertEqualObjects(IJSVGXMLAttributeURI(href), @"http://www.w3.org/1999/xlink");
    NSString* retained = IJSVGXMLAttributeValue(IJSVGXMLAttributeNamed(group, @"id"));
    XCTAssertEqualObjects(IJSVGXMLText(IJSVGXMLNext(group)), @"one two three");
    NSUInteger visited = 0;
    IJSVGXMLAttributeList groupAttributeIterator = IJSVGXMLAttributes(group);
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&groupAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&groupAttributeIterator)) {
        XCTAssertNotEqual(attribute, NULL);
        visited++;
        if (attribute->identifier == IJSVGNodeAttributeID) {
            break;
        }
    }
    XCTAssertEqual(visited, 1u);
    IJSVGXMLDocumentDestroy(document);
    XCTAssertEqualObjects(retained, @"a");
}

- (void)testXMLIdentifierLookupPreservesQualifiedNamesAndUnknownAttributes
{
    const char* source = "<svg xmlns:other='urn:other' other:media='ignored' media='screen' spreadMethod='repeat' requiredExtensions='urn:extension' systemLanguage='en' other:width='99' width='10' custom='value'/>";
    IJSVGXMLDocument* document = IJSVGXMLDocumentCreate(source, strlen(source));
    XCTAssertNotEqual(document, NULL);
    if (document == NULL) {
        return;
    }
    IJSVGXMLNode* root = IJSVGXMLRoot(document);
    XCTAssertEqualObjects(IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(root, IJSVGNodeAttributeMedia)), @"screen");
    XCTAssertEqualObjects(IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(root, IJSVGNodeAttributeSpreadMethod)), @"repeat");
    XCTAssertEqualObjects(IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(root, IJSVGNodeAttributeRequiredExtensions)), @"urn:extension");
    XCTAssertEqualObjects(IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(root, IJSVGNodeAttributeSystemLanguage)), @"en");
    XCTAssertEqualObjects(IJSVGXMLAttributeValue(IJSVGXMLAttributeForIdentifier(root, IJSVGNodeAttributeWidth)), @"10");
    XCTAssertEqual(IJSVGXMLAttributeForIdentifier(root, IJSVGNodeAttributeHeight), NULL);
    XCTAssertEqual(IJSVGXMLAttributeForIdentifier(root, IJSVGNodeAttributeUnknown), NULL);
    XCTAssertEqual(IJSVGXMLAttributeForIdentifier(root, IJSVGNodeAttributeCount), NULL);
    XCTAssertEqual(IJSVGXMLAttributeForIdentifier(NULL, IJSVGNodeAttributeWidth), NULL);
    XCTAssertEqualObjects(IJSVGXMLAttributeValue(IJSVGXMLAttributeNamed(root, @"other:media")), @"ignored");
    XCTAssertEqualObjects(IJSVGXMLAttributeValue(IJSVGXMLAttributeNamed(root, @"custom")), @"value");
    IJSVGXMLDocumentDestroy(document);
}

- (void)testCXMLRejectsMalformedInputAndCustomEntityReferences
{
    for (NSString* source in @[ @"<svg><g></svg>", @"<svg a='1' a='2'/>", @"<svg><q:g/></svg>", @"<svg>&missing;</svg>", @"<!DOCTYPE svg [<!ENTITY unused 'ignored'>]><svg/>", @"<!DOCTYPE svg [<!ENTITY external SYSTEM 'file:///nonexistent/entity'>]><svg>&external;</svg>", @"<!DOCTYPE svg [<!ENTITY % p '<!ELEMENT svg ANY>'>%p;]><svg/>" ]) {
        NSData* bytes = [source dataUsingEncoding:NSUTF8StringEncoding];
        IJSVGXMLDocument* document = IJSVGXMLDocumentCreate(bytes.bytes, bytes.length);
        XCTAssertEqual(document, NULL, @"%@", source);
        IJSVGXMLDocumentDestroy(document);
    }
    NSString* source = @"<!DOCTYPE svg [<!ENTITY greeting 'hello'>]><svg><title>&greeting;</title></svg>";
    NSData* bytes = [source dataUsingEncoding:NSUTF8StringEncoding];
    IJSVGXMLDocument* document = IJSVGXMLDocumentCreate(bytes.bytes, bytes.length);
    XCTAssertEqual(document, NULL);
    IJSVGXMLDocumentDestroy(document);
}

- (void)testCXMLIgnoresDoctypeAndPreservesStandardEscapes
{
    NSArray<NSString*>* declarations = @[ @"<!DOCTYPE svg>",
        @"<!DOCTYPE svg PUBLIC '-//W3C//DTD SVG 1.1//EN' 'http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd'>",
        @"<!DOCTYPE svg SYSTEM 'file:///nonexistent/ijsvg-test.dtd'>",
        @"<!DOCTYPE svg [<!ATTLIST svg fill CDATA 'red'>]>" ];
    for (NSString* declaration in declarations) {
        NSString* source = [declaration stringByAppendingString:@"<svg id='a&amp;b'><title>&lt;&gt;&amp;&quot;&apos;&#65;&#x42;</title></svg>"];
        for (NSNumber* encoding in @[ @(NSUTF8StringEncoding), @(NSUTF16StringEncoding) ]) {
            NSData* bytes = [source dataUsingEncoding:encoding.unsignedIntegerValue];
            IJSVGXMLDocument* document = IJSVGXMLDocumentCreate(bytes.bytes, bytes.length);
            XCTAssertNotEqual(document, NULL, @"%@", declaration);
            if (document == NULL) {
                continue;
            }
            IJSVGXMLNode* root = IJSVGXMLRoot(document);
            XCTAssertEqualObjects(IJSVGXMLAttributeValue(IJSVGXMLAttributeNamed(root, @"id")), @"a&b");
            XCTAssertEqual(IJSVGXMLAttributeNamed(root, @"fill"), NULL);
            XCTAssertEqualObjects(IJSVGXMLText(IJSVGXMLFirstChild(root)), @"<>&\"'AB");
            IJSVGXMLDocumentDestroy(document);
        }
    }
}

- (void)testBytePathCacheOwnsKeysSnapshotsAndEvicts
{
    IJSVGParsedPathCache* cache = IJSVGParsedPathCacheCreate();
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 0, 0);
    CGPathAddLineToPoint(path, NULL, 10, 10);
    char key[] = { 'p', 'a', 't', 'h' };
    IJSVGParsedPathCacheStoreBytes(cache, key, sizeof(key), IJSVGParsedPathData, path);
    memset(key, '?', sizeof(key));
    CGPathAddLineToPoint(path, NULL, 20, 20);
    CGPathRef snapshot = IJSVGParsedPathCacheCopyBytes(cache, "path", 4, IJSVGParsedPathData);
    XCTAssertNotEqual(snapshot, NULL);
    XCTAssertTrue(CGPointEqualToPoint(CGPathGetCurrentPoint(snapshot), CGPointMake(10, 10)));
    CGPathRelease(snapshot);
    XCTAssertEqual(IJSVGParsedPathCacheCopyBytes(cache, "path", 4, IJSVGParsedPathPolygon), NULL);
    for (NSUInteger i = 0; i < 4000; i++) {
        char buffer[32];
        int count = snprintf(buffer, sizeof(buffer), "key-%lu", (unsigned long)i);
        IJSVGParsedPathCacheStoreBytes(cache, buffer, count, IJSVGParsedPathPolyline, path);
    }
    XCTAssertEqual(IJSVGParsedPathCacheCopyBytes(cache, "path", 4, IJSVGParsedPathData), NULL);
    snapshot = IJSVGParsedPathCacheCopyBytes(cache, "key-3999", 8, IJSVGParsedPathPolyline);
    XCTAssertNotEqual(snapshot, NULL);
    CGPathRelease(snapshot);
    CGPathRelease(path);
    IJSVGParsedPathCacheDestroy(cache);
}

- (void)testBackgroundBoundsUseCompleteNumberLists
{
    IJSVGGraphicsNode* node = [[IJSVGGraphicsNode alloc] init];
    IJSVGApplyBackgroundAttribute(node, @"new 1,2 3 4");
    XCTAssertEqual(node.backgroundEnabled, IJSVGBackgroundEnabledNew);
    XCTAssertTrue(CGRectEqualToRect(node.backgroundBounds, CGRectMake(1, 2, 3, 4)));
    for (NSString* value in @[ @"new 1 2 3", @"new 1 2 3 4 5", @"new 1 2 3 bad", @"new 1 2 -3 4", @"new 1 2 3 1e999" ]) {
        IJSVGApplyBackgroundAttribute(node, value);
        XCTAssertEqual(node.backgroundEnabled, IJSVGBackgroundEnabledUnspecified);
        XCTAssertTrue(CGRectIsNull(node.backgroundBounds));
    }
}

- (void)testNumberEnumerationValidatesBeforeCallbacks
{
    for (NSString* invalid in @[ @"1,2,bad", @"1,", @",1", @"1,,2", @"1-2", @"1e+", @"1e999", @"1\f2", @"1\0 2", @"NaN", @"Infinity", @" " ]) {
        __block NSUInteger count = 0;
        XCTAssertFalse(IJSVGEnumerateNumbers(invalid, ^(CGFloat value) {
            count++;
        }),
            @"%@", invalid);
        XCTAssertEqual(count, 0);
    }
    NSMutableString* source = [@"1." mutableCopy];
    for (NSUInteger index = 1; index < 100; index++) {
        [source appendFormat:@",%lu", (unsigned long)(index + 1)];
    }
    __block NSUInteger count = 0;
    XCTAssertTrue(IJSVGEnumerateNumbers(source, ^(CGFloat value) {
        XCTAssertEqual(value, ++count);
        [source setString:@"changed"];
    }));
    XCTAssertEqual(count, 100);
    XCTAssertEqualObjects([IJSVGUtils numbersFromString:@"+1. .5 -2e1"], (@[ @1, @.5, @-20 ]));
}

- (void)testExtremeFloatsRespectByteBoundaries
{
    const char bytes[] = { '1', 'e', '-', '3', '1', '0', '9' };
    XCTAssertEqual(IJSVGParseFloatWithLength(bytes, 6), [@"1e-310" doubleValue]);
    XCTAssertTrue(isinf(IJSVGParseFloat("1e309")));
    CGFloat negative = IJSVGParseFloat("-1e-999");
    XCTAssertEqual(negative, 0);
    XCTAssertTrue(signbit(negative));
    NSString* longValue = [[@"" stringByPaddingToLength:256 withString:@"0" startingAtIndex:0] stringByAppendingString:@"1e-310"];
    XCTAssertEqual(IJSVGParseFloatWithLength(longValue.UTF8String, longValue.length), [@"1e-310" doubleValue]);
}

- (void)testLegacyMethodsOwnTrimmedCopies
{
    NSMutableString* source = [[NSMutableString alloc] init];
    for (NSUInteger index = 0; index < 64; index++) {
        [source appendString:@"translate ( 1 2 ) "];
    }
    NSUInteger count = 0;
    BOOL valid = NO;
    IJSVGParsingStringMethod** methods = IJSVGParsingMethodParseStringWithValidation(source.UTF8String, &count, &valid);
    [source setString:@"changed"];
    XCTAssertTrue(valid);
    XCTAssertEqual(count, 64);
    for (NSUInteger index = 0; index < count; index++) {
        XCTAssertEqual(strcmp(methods[index]->name, "translate"), 0);
        XCTAssertEqual(strcmp(methods[index]->parameters, "1 2"), 0);
    }
    IJSVGParsingStringMethodsRelease(methods, count);
}

- (void)testParsedLengthsKeepMutableInputAndCoordinateContextsIndependent
{
    NSMutableString* input = [[NSMutableString alloc] initWithString:@"2in"];
    for (NSUInteger iteration = 0; iteration < 3; iteration++) {
        [input setString:@"2in"];
        IJSVGUnitLength* user = [IJSVGUnitLength unitWithString:input fromUnitType:IJSVGUnitUserSpaceOnUse];
        IJSVGUnitLength* box = [IJSVGUnitLength unitWithString:input fromUnitType:IJSVGUnitObjectBoundingBox];
        XCTAssertEqual(user.value, 192);
        XCTAssertEqual(user.type, IJSVGUnitLengthTypeNumber);
        XCTAssertEqual(box.type, IJSVGUnitLengthTypePercentage);
        XCTAssertEqual(box.originalType, IJSVGUnitLengthTypeIN);
        user = [user lengthWithValue:99];
        XCTAssertEqual(box.value, 192);
        XCTAssertEqual([IJSVGUnitLength unitWithString:input].value, 192);
        [input setString:@"2em"];
        IJSVGUnitLength* font = [IJSVGUnitLength unitWithString:input fromUnitType:IJSVGUnitObjectBoundingBox];
        XCTAssertEqual(font.value, 2);
        XCTAssertEqual(font.type, IJSVGUnitLengthTypeEM);
        [input setString:@"inherit"];
        XCTAssertNil([IJSVGUnitLength unitWithString:input]);
        [input setString:@"25%"];
        XCTAssertEqualWithAccuracy([IJSVGUnitLength unitWithString:input].value, .25, .0001);
    }
}

- (void)testParsedLengthsRemainIndependentAcrossThreads
{
    NSUInteger failures[4] = { 0 };
    NSUInteger* counts = failures;
    dispatch_apply(4, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t worker) {
        @autoreleasepool {
            for (NSUInteger index = 0; index < 256; index++) {
                NSUInteger scalar = worker * 256 + index;
                NSString* input = [NSString stringWithFormat:@"%lu%%", scalar];
                IJSVGUnitLength* length = [IJSVGUnitLength unitWithString:input];
                if (length == nil || fabs(length.value - scalar / 100.0) > .000001 || length.originalType != IJSVGUnitLengthTypePercentage) {
                    counts[worker]++;
                }
                length = [length lengthWithValue:-1];
            }
        }
    });
    for (NSUInteger worker = 0; worker < 4; worker++) {
        XCTAssertEqual(failures[worker], 0);
    }
}

- (void)testScalarUnitFastPathMatchesGeneralParsing
{
    NSArray<NSString*>* values = @[ @"0", @"-0", @"+0", @"12.5", @"+.25", @"-.5", @"1.", @"1.e2", @"1e-10", @"-2E+3", @"25%", @"-.5%", @"1e2%", @"-0%", @"2em", @"2ex", @"12px", @"2in", @"inherit", @"invalid", @"1e309", @"-1e309", @"1e-320", @"1e", @"1.2.3" ];
    for (NSString* value in values) {
        IJSVGUnitLength* compact = [IJSVGUnitLength unitWithString:value];
        IJSVGUnitLength* spaced = [IJSVGUnitLength unitWithString:[NSString stringWithFormat:@" %@ ", value]];
        XCTAssertEqual(compact == nil, spaced == nil, @"%@", value);
        if (compact == nil || spaced == nil) {
            continue;
        }
        XCTAssertEqual(compact.value, spaced.value, @"%@", value);
        XCTAssertEqual(signbit(compact.value), signbit(spaced.value), @"%@", value);
        XCTAssertEqual(compact.type, spaced.type, @"%@", value);
        XCTAssertEqual(compact.originalType, spaced.originalType, @"%@", value);
        XCTAssertEqual(compact.inherit, spaced.inherit, @"%@", value);
    }
}

- (void)testSingleDigitLengthsKeepNumericUnitsAndIndependentReplacements
{
    for (NSUInteger digit = 0; digit <= 9; digit++) {
        NSString* value = [NSString stringWithFormat:@"%lu", digit];
        IJSVGUnitLength* first = [IJSVGUnitLength unitWithString:value];
        IJSVGUnitLength* second = [IJSVGUnitLength unitWithString:value];
        IJSVGUnitLength* bounded = [IJSVGUnitLength unitWithString:value fromUnitType:IJSVGUnitObjectBoundingBox];
        XCTAssertEqual(first.value, digit);
        XCTAssertEqual(first.type, IJSVGUnitLengthTypeNumber);
        XCTAssertEqual(first.originalType, IJSVGUnitLengthTypeNumber);
        XCTAssertFalse(first.inherit);
        XCTAssertEqual(bounded.value, digit);
        XCTAssertEqual(bounded.type, IJSVGUnitLengthTypePercentage);
        XCTAssertEqual(bounded.originalType, IJSVGUnitLengthTypeNumber);
        first = [first lengthWithValue:100];
        XCTAssertEqual(second.value, digit);
    }
    XCTAssertEqual([IJSVGUnitLength unitWithString:@"12"].value, 12);
    XCTAssertEqual([IJSVGUnitLength unitWithString:@"-1"].value, -1);
    XCTAssertEqual([IJSVGUnitLength unitWithString:@" 1 "].value, 1);
    XCTAssertEqualWithAccuracy([IJSVGUnitLength unitWithString:@"1%"].value, .01, .0001);
}

- (void)testBoundedFloatParsingStopsAtTheRequestedLength
{
    const char number[] = { '1', '2', '.', '5' };
    XCTAssertEqual(IJSVGParseFloatWithLength(number, sizeof(number)), 12.5);
    XCTAssertEqual(IJSVGParseFloatWithLength("12.5e2", 4), 12.5);
    XCTAssertEqual(IJSVGParseFloatWithLength("+4.25e2px", 7), 425.0);
    XCTAssertEqual(IJSVGParseFloatWithLength(number, 0), 0.0);
    XCTAssertEqualWithAccuracy(IJSVGParseFloatWithLength("1e-32099", 6), 1e-320, 1e-323);
    XCTAssertTrue(isinf(IJSVGParseFloatWithLength("1e999px", 5)));
}

- (void)testGeometryValidationMatchesLengthParsing
{
    for (NSString* keyword in @[ @" AUTO ", @"auto\u00a0", @"INITIAL", @" unset ", @"ReVeRt-LaYeR" ]) {
        XCTAssertTrue(IJSVGGeometryLengthIsValid(keyword, IJSVGNodeAttributeWidth), @"%@", keyword);
    }
    XCTAssertTrue(IJSVGGeometryLengthFromString(@" INHERIT ", IJSVGNodeAttributeWidth).inherit);
    XCTAssertFalse(IJSVGGeometryLengthIsValid(@"inherit\0junk", IJSVGNodeAttributeWidth));
    XCTAssertFalse(IJSVGGeometryLengthIsValid(@"initially", IJSVGNodeAttributeWidth));
    XCTAssertFalse(IJSVGGeometryLengthIsValid(@"auto junk", IJSVGNodeAttributeWidth));
    NSArray<NSArray*>* paintOrders = @[
        @[ @"stroke fill markers", @"stroke fill markers" ],
        @[ @" MARKERS\tFILL ", @"markers fill stroke" ],
        @[ @"fill", @"fill stroke markers" ],
        @[ @"stroke", @"stroke fill markers" ],
        @[ @"markers", @"markers fill stroke" ],
        @[ @"\u00a0FILL\u2003stroke", @"fill stroke markers" ],
        @[ @"INITIAL", @"fill stroke markers" ]
    ];
    for (NSArray* entry in paintOrders) {
        XCTAssertEqualObjects(IJSVGStringFromPaintOrder(IJSVGPaintOrderFromString(entry[0])), entry[1]);
    }
    for (NSString* invalid in @[ @"", @" ", @"stroke stroke", @"fill markers fill", @"normal fill", @"filler", @"fill\0stroke" ]) {
        XCTAssertEqual(IJSVGPaintOrderFromString(invalid), IJSVGPaintOrderInherit, @"%@", invalid);
    }

    NSArray<NSString*>* values = @[ @"12.5", @"-2em", @"50%", @"1e-320", @"-1e-999", @"auto", @"inherit", @"initial", @"1,2", @"1 2", @"1e999", @"4unknown", @"", @"1\0em", @" 2ex " ];
    for (NSNumber* attribute in @[ @(IJSVGNodeAttributeX), @(IJSVGNodeAttributeR), @(IJSVGNodeAttributeWidth) ]) {
        for (NSString* value in values) {
            XCTAssertEqual(IJSVGGeometryLengthIsValid(value, attribute.unsignedIntegerValue), IJSVGGeometryLengthFromString(value, attribute.unsignedIntegerValue) != nil, @"%@", value);
        }
    }
    XCTAssertFalse(IJSVGGeometryLengthIsValid(@"-1e-999", IJSVGNodeAttributeR));
    XCTAssertTrue(IJSVGGeometryLengthIsValid(@"-1e-999", IJSVGNodeAttributeX));
    XCTAssertFalse(IJSVGGeometryLengthIsValid(@"auto", IJSVGNodeAttributeR));
    XCTAssertTrue(IJSVGGeometryLengthIsValid(@"auto", IJSVGNodeAttributeWidth));
}

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
    CGFloat* values = [IJSVGUtils scanFloatsFromString:@"M10,-5.5.25e2 +3e-2" size:&count];

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
    CGFloat* values = IJSVGParsePathDataStreamSequence(command, strlen(command), stream, sequence, 7, &commandsFound);

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
    CGFloat* values = IJSVGParsePathDataStreamSequence(command, strlen(command), stream, sequence, 7, &commandsFound);

    XCTAssertEqual(values, NULL);
    XCTAssertEqual(commandsFound, NSNotFound);

    IJSVGPathDataStreamRelease(stream);
}

- (void)testPathDataStreamGrowsPastInitialFloatAndCharacterCapacity
{
    NSMutableString* command = [NSMutableString string];
    for (NSInteger i = 0; i < 75; i++) {
        [command appendFormat:@"%ld.125 ", (long)i];
    }

    IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(1, 3);
    NSInteger count = 0;
    CGFloat* values = IJSVGParsePathDataStreamSequence(command.UTF8String, strlen(command.UTF8String), stream, NULL, 1, &count);

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
    IJSVGParsingStringMethod** methods = IJSVGParsingMethodParseString(" translate ( 10, 20 ) rotate(45) "
                                                                       "scale( 2 ) ",
        &count);

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
    NSArray<IJSVGTransform*>* transforms = [IJSVGTransform transformsForString:@"translate(10 -5) "
                                                                                "rotate(45) "
                                                                                "scale(.5,2e1) "
                                                                                "unknown(1)"];

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

- (void)testCompactTransformDecimalsSurviveRoundTrip
{
    CGAffineTransform expected = CGAffineTransformMake(1, .2, .3, 1, 8, 3);
    NSString* compact = [IJSVGTransform affineTransformToSVGMatrixString:expected];
    NSArray<IJSVGTransform*>* transforms = [IJSVGTransform transformsForString:compact];
    XCTAssertEqual(transforms.count, 1);
    CGAffineTransform actual = IJSVGConcatTransforms(transforms);
    XCTAssertEqualWithAccuracy(actual.a, expected.a, .0001);
    XCTAssertEqualWithAccuracy(actual.b, expected.b, .0001);
    XCTAssertEqualWithAccuracy(actual.c, expected.c, .0001);
    XCTAssertEqualWithAccuracy(actual.d, expected.d, .0001);
    XCTAssertEqualWithAccuracy(actual.tx, expected.tx, .0001);
    XCTAssertEqualWithAccuracy(actual.ty, expected.ty, .0001);
}

- (void)testTransformArgumentsDistinguishSVGAndCSSUnits
{
    for (NSString* value in @[ @"skewY(24deg)", @"translate(2px 3)", @"rotate(20 1)", @"scale()", @"matrix(1 0 0 1 2)", @"scale(1junk)", @"translate(1,)", @"scale(0x10)", @"rotate(NaN)" ]) {
        XCTAssertEqual([IJSVGTransform transformsForString:value].count, 0, @"%@", value);
    }
    NSArray<IJSVGTransform*>* prefix = [IJSVGTransform transformsForString:@"translate(1 2) skewY(24deg) scale(2)"];
    XCTAssertEqual(prefix.count, 1);
    for (NSString* angle in @[ @"90deg", @"1.5707963267948966rad", @"100grad", @".25turn" ]) {
        NSString* value = [NSString stringWithFormat:@"rotate(%@)", angle];
        IJSVGTransform* transform = [IJSVGTransform transformsForString:value allowCSSUnits:YES].firstObject;
        XCTAssertNotNil(transform);
        XCTAssertEqualWithAccuracy(transform.parameters[0], 90, .00001);
    }
    IJSVGTransform* translation = [IJSVGTransform transformsForString:@"translate(2px,3px)" allowCSSUnits:YES].firstObject;
    XCTAssertEqualWithAccuracy(translation.parameters[0], 2, .00001);
    XCTAssertEqualWithAccuracy(translation.parameters[1], 3, .00001);
}

- (void)testTransformOriginSyntax
{
    for (NSString* value in @[ @"center", @"left top", @"top left", @"bottom", @"-2px 30%", @"20% -1em", @"center center 2px", @"TOP RiGhT", @"1EM 2PX", @"\tleft\f top\n" ]) {
        XCTAssertEqual(IJSVGTransformOriginFromString(value).count, 2, @"%@", value);
    }
    for (NSString* value in @[ @"", @"left right", @"top bottom", @"top 2px", @"2px left", @"2px junk", @"0 0 20%", @"0 0 0 0", @"0,0", @"left\0right" ]) {
        XCTAssertNil(IJSVGTransformOriginFromString(value), @"%@", value);
    }
}

- (void)testCombinedTransformUsesSVGListOrder
{
    NSArray<IJSVGTransform*>* transforms = [IJSVGTransform transformsForString:@"translate(10 20) scale(2 3)"];
    CGAffineTransform transform = IJSVGConcatTransforms(transforms);
    CGPoint point = CGPointApplyAffineTransform(CGPointMake(1.f, 2.f), transform);
    XCTAssertEqualWithAccuracy(point.x, 12.f, 0.0001f);
    XCTAssertEqualWithAccuracy(point.y, 26.f, 0.0001f);
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

- (void)testFontRelativeUnitParsingAndResolution
{
    NSArray<NSString*>* strings = @[ @"2em", @" 2EM ", @"2ex", @" 2Ex " ];
    for (NSUInteger index = 0; index < strings.count; index++) {
        IJSVGUnitLength* unit = [IJSVGUnitLength unitWithString:strings[index]];
        IJSVGUnitLengthType type = index < 2 ? IJSVGUnitLengthTypeEM : IJSVGUnitLengthTypeEX;
        XCTAssertEqual(unit.type, type);
        XCTAssertEqual(unit.originalType, type);
        XCTAssertEqualWithAccuracy(unit.value, 2, .000001);
        XCTAssertTrue(unit.isRelativeUnit);
        CGFloat resolved = [unit computeValue:200 fontSize:30 xHeight:12];
        XCTAssertEqualWithAccuracy(resolved, index < 2 ? 60 : 24, .000001);
        XCTAssertEqualWithAccuracy(unit.value, 2, .000001);
    }
}

- (void)testFontRelativeUnitsCopyAndSerialize
{
    for (NSString* string in @[ @"0em", @"0ex", @"-.5em", @"1.25ex" ]) {
        IJSVGUnitLength* unit = [IJSVGUnitLength unitWithString:string];
        IJSVGUnitLength* copy = unit.copy;
        XCTAssertEqual(copy.type, unit.type);
        XCTAssertEqual(copy.originalType, unit.originalType);
        XCTAssertEqualWithAccuracy(copy.value, unit.value, .000001);
        IJSVGUnitLength* roundTrip = [IJSVGUnitLength unitWithString:copy.stringValue];
        XCTAssertEqual(roundTrip.type, unit.type);
        XCTAssertEqualWithAccuracy(roundTrip.value, unit.value, .000001);
        XCTAssertEqual([unit lengthByMatchingPercentage].type, unit.type);
    }
    IJSVGFloatingPointOptions options = IJSVGFloatingPointOptionsMake(YES, 2);
    IJSVGUnitLength* unit = [IJSVGUnitLength unitWithString:@"1.234ex"];
    XCTAssertEqualObjects([unit stringValueWithFloatingPointOptions:options], @"1.23ex");
}

- (void)testFontMetricsDoNotChangeAbsoluteOrPercentageUnits
{
    NSArray<NSString*>* strings = @[ @"12", @"12px", @"2.54cm", @"25.4mm", @"1in", @"72pt", @"6pc", @"25%" ];
    CGFloat expected[] = { 12, 12, 96, 96, 96, 96, 96, 50 };
    for (NSUInteger index = 0; index < strings.count; index++) {
        IJSVGUnitLength* unit = [IJSVGUnitLength unitWithString:strings[index]];
        CGFloat value = [unit computeValue:200 fontSize:30 xHeight:12];
        XCTAssertEqualWithAccuracy(value, expected[index], .0001);
    }
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
    IJSVGViewBoxAlignment alignment = [IJSVGViewBox alignmentForString:@"xMaxYMid slice" meetOrSlice:&meetOrSlice];

    XCTAssertEqual(alignment, IJSVGViewBoxAlignmentXMaxYMid);
    XCTAssertEqual(meetOrSlice, IJSVGViewBoxMeetOrSliceSlice);
    XCTAssertEqualObjects([IJSVGViewBox aspectRatioWithAlignment:alignment meetOrSlice:meetOrSlice], @"xMaxYMid slice");
    XCTAssertEqual([IJSVGViewBox alignmentForString:@"none"], IJSVGViewBoxAlignmentNone);
    XCTAssertEqual([IJSVGViewBox meetOrSliceForString:@"meet"], IJSVGViewBoxMeetOrSliceMeet);
    XCTAssertEqual([IJSVGViewBox meetOrSliceForString:@"unknown"], IJSVGViewBoxMeetOrSliceUnknown);
}

- (void)testViewBoxComputeTransformForMeetSliceAndNone
{
    CGRect viewBox = CGRectMake(10.f, 20.f, 50.f, 100.f);
    CGRect drawingRect = CGRectMake(0.f, 0.f, 200.f, 200.f);

    CGAffineTransform meet = IJSVGViewBoxComputeTransform(viewBox, drawingRect, IJSVGViewBoxAlignmentXMidYMid, IJSVGViewBoxMeetOrSliceMeet);
    XCTAssertEqualWithAccuracy(meet.a, 2.f, 0.0001f);
    XCTAssertEqualWithAccuracy(meet.d, 2.f, 0.0001f);
    XCTAssertEqualWithAccuracy(meet.tx, 30.f, 0.0001f);
    XCTAssertEqualWithAccuracy(meet.ty, -40.f, 0.0001f);

    CGAffineTransform slice = IJSVGViewBoxComputeTransform(viewBox, drawingRect, IJSVGViewBoxAlignmentXMinYMin, IJSVGViewBoxMeetOrSliceSlice);
    XCTAssertEqualWithAccuracy(slice.a, 4.f, 0.0001f);
    XCTAssertEqualWithAccuracy(slice.d, 4.f, 0.0001f);
    XCTAssertEqualWithAccuracy(slice.tx, -40.f, 0.0001f);
    XCTAssertEqualWithAccuracy(slice.ty, -80.f, 0.0001f);

    CGAffineTransform none = IJSVGViewBoxComputeTransform(viewBox, drawingRect, IJSVGViewBoxAlignmentNone, IJSVGViewBoxMeetOrSliceMeet);
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
    XCTAssertEqual(copied, cm);
    XCTAssertThrowsSpecificNamed([cm setValue:@1 forKey:@"value"], NSException, NSUndefinedKeyException);
    XCTAssertEqual(copied.originalType, cm.originalType);
    XCTAssertEqualWithAccuracy(copied.value, cm.value, 0.0001f);
}

- (void)testGradientUnitLengthStringValueKeepsNormalizedPercentages
{
    IJSVGGradientUnitLength* gradient = [[IJSVGGradientUnitLength alloc] init];
    gradient = (IJSVGGradientUnitLength*)[gradient lengthWithValue:0.25f];
    gradient = (IJSVGGradientUnitLength*)[gradient lengthBySettingType:IJSVGUnitLengthTypePercentage];

    XCTAssertEqualObjects(gradient.stringValue, @"0.25");

    gradient = (IJSVGGradientUnitLength*)[gradient lengthBySettingType:IJSVGUnitLengthTypeNumber];
    XCTAssertEqualObjects(gradient.stringValue, @".25");
}

- (void)testUnitPointComputesRelativeCoordinatesAndSharesImmutableLengths
{
    IJSVGUnitPoint* point = [IJSVGUnitPoint pointWithX:[IJSVGUnitLength unitWithString:@"25%"] y:[IJSVGUnitLength unitWithString:@"10"]];
    CGPoint computed = [point computeValue:CGSizeMake(200.f, 300.f)];
    IJSVGUnitPoint* copy = point.copy;

    XCTAssertTrue(point.containsRelativeUnits);
    XCTAssertEqualWithAccuracy(computed.x, 50.f, 0.0001f);
    XCTAssertEqualWithAccuracy(computed.y, 10.f, 0.0001f);
    XCTAssertNotEqual(copy, point);
    XCTAssertEqual(copy.x, point.x);
    XCTAssertEqualWithAccuracy(copy.x.value, point.x.value, 0.0001f);

    [copy convertUnitsToLengthType:IJSVGUnitLengthTypePX];
    XCTAssertEqual(copy.x.type, IJSVGUnitLengthTypePX);
    XCTAssertEqual(copy.y.type, IJSVGUnitLengthTypePX);
    XCTAssertEqual(point.x.type, IJSVGUnitLengthTypePercentage);
}

- (void)testUnitSizeComputesRelativeDimensionsAndZeroState
{
    IJSVGUnitSize* zero = IJSVGUnitSize.zeroSize;
    IJSVGUnitSize* size = [IJSVGUnitSize sizeWithWidth:[IJSVGUnitLength unitWithString:@"50%"] height:[IJSVGUnitLength unitWithString:@"25%"]];
    CGSize computed = [size computeValue:CGSizeMake(120.f, 80.f)];
    IJSVGUnitSize* copy = size.copy;

    XCTAssertTrue(zero.isZeroSize);
    XCTAssertFalse(size.isZeroSize);
    XCTAssertTrue(size.containsRelativeUnits);
    XCTAssertEqualWithAccuracy(computed.width, 60.f, 0.0001f);
    XCTAssertEqualWithAccuracy(computed.height, 20.f, 0.0001f);
    XCTAssertEqual(copy.width, size.width);

    [copy convertUnitsToLengthType:IJSVGUnitLengthTypeNumber];
    XCTAssertEqual(copy.width.type, IJSVGUnitLengthTypeNumber);
    XCTAssertEqual(copy.height.type, IJSVGUnitLengthTypeNumber);
    XCTAssertEqual(size.width.type, IJSVGUnitLengthTypePercentage);
}

- (void)testUnitRectComputesRelativeValuesAndConvertsCopies
{
    IJSVGUnitPoint* origin = [IJSVGUnitPoint pointWithX:[IJSVGUnitLength unitWithString:@"10%"] y:[IJSVGUnitLength unitWithString:@"20%"]];
    IJSVGUnitSize* size = [IJSVGUnitSize sizeWithWidth:[IJSVGUnitLength unitWithString:@"50%"] height:[IJSVGUnitLength unitWithString:@"25%"]];
    IJSVGUnitRect* rect = [IJSVGUnitRect rectWithOrigin:origin size:size];
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

- (void)testArgumentUnwrappingPreservesBytes
{
    NSArray<NSArray<NSString*>*>* cases = @[ @[ @"  #paint  ", @"#paint", @"" ], @[ @" '#paint' ", @"#paint", @"'" ], @[ @"\t\"#café(x)\"\n", @"#café(x)", @"\"" ], @[ @"' #paint '", @" #paint ", @"'" ], @[ @"''", @"", @"'" ], @[ @"   ", @"", @"" ] ];
    for (NSArray<NSString*>* entry in cases) {
        const char* source = entry[0].UTF8String;
        const char* bytes = NULL;
        size_t length = 0;
        char quote = 0;
        XCTAssertTrue(IJSVGParsingUnwrapArgument(source, &bytes, &length, &quote));
        XCTAssertTrue(bytes >= source && bytes + length <= source + strlen(source));
        XCTAssertEqualObjects([[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding], entry[1]);
        XCTAssertEqual(quote, entry[2].UTF8String[0]);
        XCTAssertEqual(strcmp(source, entry[0].UTF8String), 0);
    }
    const char* invalid[] = { NULL, "'", "\"#paint'", "'#paint" };
    for (NSUInteger index = 0; index < sizeof(invalid) / sizeof(invalid[0]); index++) {
        const char* bytes = NULL;
        size_t length = 0;
        char quote = 0;
        XCTAssertFalse(IJSVGParsingUnwrapArgument(invalid[index], &bytes, &length, &quote));
        XCTAssertTrue(bytes == NULL);
        XCTAssertEqual(length, 0);
        XCTAssertEqual(quote, 0);
    }
}

- (void)testUtilsDefURL
{
    XCTAssertEqualObjects([IJSVGUtils defURL:@"url(#gradient)"], @"gradient");
    XCTAssertEqualObjects([IJSVGUtils defURL:@"url(mask)"], @"mask");
    XCTAssertEqualObjects([IJSVGUtils defURL:@"url(\'#gradient\')"], @"gradient");
    XCTAssertEqualObjects([IJSVGUtils defURL:@"url( \"#clip\" )"], @"clip");
    XCTAssertEqualObjects([IJSVGUtils defURL:@"url(\'#paint with spaces\')"], @"paint with spaces");
    XCTAssertNil([IJSVGUtils defURL:@"none"]);
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

- (void)testBitFlags64SetsEveryBitAndRejectsInvalidIndices
{
    IJSVGBitFlags64* flags = [[IJSVGBitFlags64 alloc] initWithLength:8];
    XCTAssertEqual(flags.length, 64);
    XCTAssertTrue(flags.storage == NULL);
    [flags setAllBits];
    XCTAssertEqual(flags.bitMask, UINT64_MAX);
    for (int bit = 0; bit < 64; bit++) {
        XCTAssertTrue([flags bitIsSet:bit]);
    }
    for (NSNumber* index in @[ @(-1), @64, @95 ]) {
        [flags unsetBit:index.intValue];
        XCTAssertEqual(flags.bitMask, UINT64_MAX);
        XCTAssertFalse([flags bitIsSet:index.intValue]);
    }
    [flags unsetBit:63];
    uint64_t expected = UINT64_MAX >> 1;
    XCTAssertEqual(flags.bitMask, expected);
    [flags setBit:-1];
    [flags setBit:64];
    XCTAssertEqual(flags.bitMask, expected);
    [flags addBits:flags];
    XCTAssertEqual(flags.bitMask, expected);
    [flags addBits:nil];
    XCTAssertEqual(flags.bitMask, expected);
}

- (void)testBitFlagsMergeBothRepresentationsAndRespectDestinationLength
{
    IJSVGBitFlags* wide = [[IJSVGBitFlags alloc] initWithLength:96];
    [wide setBit:0];
    [wide setBit:63];
    [wide setBit:64];
    [wide setBit:95];
    IJSVGBitFlags64* compact = [[IJSVGBitFlags64 alloc] init];
    [compact addBits:wide];
    XCTAssertEqual(compact.bitMask, (1ULL << 63) | 1ULL);
    [compact setAllBits];

    for (NSNumber* size in @[ @0, @8, @64, @96 ]) {
        int length = size.intValue;
        IJSVGBitFlags* destination = [[IJSVGBitFlags alloc] initWithLength:length];
        [destination addBits:compact];
        for (int bit = 0; bit < length; bit++) {
            XCTAssertEqual([destination bitIsSet:bit], bit < 64);
        }
        uint64_t mask = destination.bitMask;
        [destination setBit:-1];
        [destination setBit:length];
        [destination unsetBit:-1];
        [destination unsetBit:length];
        [destination addBits:nil];
        [destination addBits:destination];
        XCTAssertEqual(destination.bitMask, mask);
    }
    XCTAssertTrue([wide bitIsSet:64]);
    XCTAssertTrue([wide bitIsSet:95]);
}

- (void)testFeatureFlagsExposeDefaultStates
{
    IJSVGFeatureFlag* disabled = [IJSVGFeatureFlag featureFlagWithEnabled:NO];
    IJSVGFeatureFlags* flags = [[IJSVGFeatureFlags alloc] init];

    XCTAssertFalse(disabled.enabled);
    XCTAssertTrue(flags.viewBoxNormalization.enabled);
    XCTAssertTrue(flags.inferViewBoxes.enabled);
}

- (void)testByteUtilitiesRespectNonterminatedSpans
{
    const char attribute[] = { 'w', 'i', 'd', 't', 'h', '!' };
    XCTAssertEqual(IJSVGNodeAttributeForBytes(attribute, 5), IJSVGNodeAttributeWidth);
    XCTAssertEqual(IJSVGNodeAttributeForBytes(attribute, 6), NSNotFound);
    XCTAssertEqual(IJSVGNodeAttributeForBytes(NULL, 0), NSNotFound);
    const char length[] = { '1', '2', '.', '5', '%', '!' };
    IJSVGUnitLength* parsed = IJSVGLengthFromBytes(length, 5, YES);
    XCTAssertEqualWithAccuracy(parsed.value, .125, 1e-12);
    XCTAssertEqual(parsed.type, IJSVGUnitLengthTypePercentage);
    XCTAssertNil(IJSVGLengthFromBytes(length, 6, YES));
    const char numbers[] = { '1', ',', '-', '2', '!' };
    __block CGFloat sum = 0;
    XCTAssertTrue(IJSVGEnumerateNumbersFromBytes(numbers, 4, ^(CGFloat value) {
        sum += value;
    }));
    XCTAssertEqual(sum, -1);
    __block NSUInteger count = 0;
    XCTAssertFalse(IJSVGEnumerateNumbersFromBytes(numbers, 5, ^(CGFloat value) {
        count++;
    }));
    XCTAssertEqual(count, 0);
    const char exponent[] = { '1', 'e', '+' };
    const char* cursor = exponent;
    CGFloat value = 0;
    XCTAssertTrue(IJSVGParseLengthNumberInRange(&cursor, exponent + 3, YES, &value));
    XCTAssertEqual(cursor, exponent + 1);
    XCTAssertEqual(value, 1);
}

- (void)testByteLengthParsingRejectsEmbeddedNullAndNegativeUnderflow
{
    const char embedded[] = { '1', 0, '2' };
    XCTAssertNil(IJSVGLengthFromBytes(embedded, sizeof(embedded), YES));
    XCTAssertFalse(IJSVGUnitLengthsAreValidBytes(embedded, sizeof(embedded), YES, YES));
    const char underflow[] = "-1e-999";
    XCTAssertNil(IJSVGLengthFromBytes(underflow, sizeof(underflow) - 1, NO));
    const char expression[] = "calc(10px + 2px)!";
    XCTAssertNotNil(IJSVGLengthFromBytes(expression, sizeof(expression) - 2, YES));
    XCTAssertNil(IJSVGLengthFromBytes(expression, sizeof(expression) - 1, YES));
}

- (void)testByteTransformsConsumeOnlyTheirSpan
{
    const char bytes[] = "translate(12, 3) scale(2)!";
    NSArray<IJSVGTransform*>* transforms = [IJSVGTransform transformsForBytes:bytes length:sizeof(bytes) - 2 allowCSSUnits:NO];
    XCTAssertEqual(transforms.count, 2);
    XCTAssertEqual(transforms[0].parameters[0], 12);
    XCTAssertEqual(transforms[0].parameters[1], 3);
    XCTAssertEqual(transforms[1].parameters[0], 2);
}

- (void)testByteParsersDoNotReadBeyondAccessibleMemory
{
    size_t page = (size_t)getpagesize();
    char* memory = mmap(NULL, page * 2, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    XCTAssertNotEqual(memory, MAP_FAILED);
    if (memory == MAP_FAILED) {
        return;
    }
    int result = mprotect(memory + page, page, PROT_NONE);
    XCTAssertEqual(result, 0);
    if (result != 0) {
        munmap(memory, page * 2);
        return;
    }
    const char expression[] = "calc(10px + 2px)";
    size_t count = sizeof(expression) - 1;
    char* bytes = memory + page - count;
    memcpy(bytes, expression, count);
    IJSVGUnitLength* length = IJSVGLengthFromBytes(bytes, count, YES);
    XCTAssertNotNil(length);
    const char transform[] = "translate(12,3)";
    count = sizeof(transform) - 1;
    bytes = memory + page - count;
    memcpy(bytes, transform, count);
    NSArray<IJSVGTransform*>* transforms = [IJSVGTransform transformsForBytes:bytes length:count allowCSSUnits:NO];
    XCTAssertEqual(transforms.count, 1);
    bytes = memory + page - 1;
    *bytes = '7';
    __block CGFloat number = 0;
    XCTAssertTrue(IJSVGEnumerateNumbersFromBytes(bytes, 1, ^(CGFloat value) {
        number = value;
    }));
    XCTAssertEqual(number, 7);
    XCTAssertEqual(IJSVGNodeAttributeForBytes(bytes, 1), NSNotFound);
    munmap(memory, page * 2);
    XCTAssertEqualWithAccuracy([length computeValue:100], 12, 1e-12);
}

@end
