//
//  IJSVGCommandParser.h
//  IJSVG
//
//  Created by Curtis Hard on 23/12/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IJSVGPathDataSequence) {
    kIJSVGPathDataSequenceTypeFloat,
    kIJSVGPathDataSequenceTypeFlag
};

static NSUInteger const IJSVG_STREAM_FLOAT_BLOCK_SIZE = 50;
static NSUInteger const IJSVG_STREAM_CHAR_BLOCK_SIZE = 20;

typedef struct {
    CGFloat* floatBuffer;
    NSInteger floatCount;
    char* charBuffer;
    NSInteger charCount;
} IJSVGPathDataStream;

@interface IJSVGCommandParser : NSObject

IJSVGPathDataStream* _Nullable IJSVGPathDataStreamCreateDefault(void);
IJSVGPathDataStream* _Nullable IJSVGPathDataStreamCreate(NSUInteger floatCount, NSUInteger charCount);
void IJSVGPathDataStreamRelease(IJSVGPathDataStream* _Nullable buffer);

IJSVGPathDataSequence* IJSVGPathDataSequenceCreateWithType(IJSVGPathDataSequence type, NSInteger length);
CGFloat* _Nullable IJSVGParsePathDataStreamSequence(const char* commandChars, NSInteger commandCharLength, IJSVGPathDataStream* _Nullable dataStream, IJSVGPathDataSequence* _Nullable sequence, NSInteger commandLength, NSInteger* _Nullable commandsFound);

// Each data stream starts at its own origin, even when the destination has
// geometry.
void IJSVGAppendPathData(CGMutablePathRef path, const char* characters, NSUInteger length, IJSVGPathDataStream* _Nullable dataStream);

// A false result rules out point subpaths in the appended data.
BOOL IJSVGAppendPathDataCheckingPointSubpaths(CGMutablePathRef path, const char* characters, NSUInteger length, IJSVGPathDataStream* _Nullable dataStream);

// Invalid point lists leave the destination unchanged.
BOOL IJSVGAppendPolyPoints(CGMutablePathRef path, const char* characters, NSUInteger length, BOOL closePath, IJSVGPathDataStream* _Nullable dataStream);

CGMutablePathRef IJSVGCreatePathFromData(const char* characters, NSUInteger length, IJSVGPathDataStream* _Nullable dataStream) CF_RETURNS_RETAINED;

// Visits authored commands, keeping an arcs cubic approximation in one segment.
void IJSVGEnumeratePathDataSegments(NSString* data, void (^handler)(char command, CGPathRef segment));
CGFloat IJSVGParseFloat(const char* buffer);
CGFloat IJSVGParseFloatWithLength(const char* buffer, NSUInteger length);

@end

NS_ASSUME_NONNULL_END
