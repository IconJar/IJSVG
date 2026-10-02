//
//  IJSVGThreadManager.h
//  IJSVG
//
//  Created by Curtis Hard on 20/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreImage/CoreImage.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGCommandParser.h>
#import <IJSVG/IJSVGFeatureFlags.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGParser.h>

@interface IJSVGThreadManager : NSObject {
@private
    NSMutableDictionary* _userInfo;
    NSHashTable* _allocedSVGs;
}

@property (nonatomic, readonly) IJSVGFeatureFlags* featureFlags;
@property (nonatomic, readonly) NSThread* thread;
// Filter contexts require a Metal device and may be unavailable.
@property (nonatomic, readonly) CIContext* CIContext;
@property (nonatomic, readonly) IJSVGPathDataStream* pathDataStream;

+ (IJSVGThreadManager*)managerForThread:(NSThread*)thread;
+ (IJSVGThreadManager*)managerForSVG:(IJSVG*)svg;
+ (IJSVGThreadManager*)currentManager;

// Synchronous lease from a process wide pool of at most six contexts.
// The block is skipped when a Metal context cannot be created.
// The flag identifies contexts that support stitchable Metal kernels.
+ (void)performBlockWithCIContext:(void (^)(CIContext* context, BOOL supportsMetalKernels))block;

// Bounds simultaneous synchronous atlas outputs to two callers.
// Nested calls on the same thread reuse its slot. Do not dispatch work and wait
// inside the block or carry the scope across an asynchronous suspension.
+ (void)performCIOutputBlock:(dispatch_block_t)block;

- (void)adopt:(IJSVG*)svg;
- (void)remove:(IJSVG*)svg;
- (BOOL)manages:(IJSVG*)svg;

- (void)setUserInfoObject:(id)object
                   forKey:(id<NSCopying>)key;
- (id)userInfoObjectForKey:(id<NSCopying>)key;

@end
