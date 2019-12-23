//
//  IJSVGCommandParser.h
//  IJSVG
//
//  Created by Curtis Hard on 23/12/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <xlocale.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IJSVGPathDataSequence) {
    kIJSVGPathDataSequenceTypeFloat,
    kIJSVGPathDataSequenceTypeFlag
};

static NSUInteger const IJSVG_DATA_STREAM_DEFAULT_BUFFER_COUNT_FLOAT = 50;
static NSUInteger const IJSVG_DATA_STREAM_DEFAULT_BUFFER_COUNT_CHAR = 20;

typedef struct {
    CGFloat* floatBuffer;
    NSInteger floatCount;
    char* charBuffer;
    NSInteger charCount;
} IJSVGParsePathDataStream;

@interface IJSVGCommandParser : NSObject

IJSVGParsePathDataStream* IJSVGParsePathDataStreamCreateDefault(void);
IJSVGParsePathDataStream* IJSVGParsePathDataStramCreate(NSUInteger floatCount, NSUInteger charCount);
void IJSVGParsePathDataStreamRelease(IJSVGParsePathDataStream* buffer);

IJSVGPathDataSequence* IJSVGPathDataSequenceCreateWithType(IJSVGPathDataSequence type, NSInteger length);
CGFloat* _Nullable IJSVGParsePathDataSequence(NSString* string, IJSVGParsePathDataStream* parseBuffer, IJSVGPathDataSequence* _Nullable sequence,
    NSInteger commandLength, NSInteger* _Nullable commandsFound);

@end

NS_ASSUME_NONNULL_END
