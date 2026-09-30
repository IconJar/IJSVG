//
//  IJSVGThreadManager.m
//  IJSVG
//
//  Created by Curtis Hard on 20/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGThreadManager.h>
@import Metal;

// Contexts outlive GCD workers. Reserve a slot for the synchronous filter render;
// After six simultaneous leases, share the least busy context. CIContext supports
// concurrent use, so nested renders do not need to wait for an available slot.
@interface IJSVGCIContextSlot : NSObject {
    dispatch_once_t _contextToken;
    CIContext* _context;
    BOOL _supportsMetalKernels;
}

@property (nonatomic, assign) NSUInteger users;
@property (nonatomic, readonly) CIContext* context;
@property (nonatomic, readonly) BOOL supportsMetalKernels;
@end

@implementation IJSVGCIContextSlot

- (CIContext*)context
{
    dispatch_once(&_contextToken, ^{
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        self->_supportsMetalKernels = device != nil && device.supportsDynamicLibraries;
        if(device != nil) {
            self->_context = [CIContext contextWithMTLDevice:device options:@{}];
        }
    });
    return _context;
}

- (BOOL)supportsMetalKernels
{
    (void)self.context;
    return _supportsMetalKernels;
}

@end

static NSLock* IJSVGContextPoolLock;
static NSMutableArray<IJSVGCIContextSlot*>* IJSVGContextPool;

static IJSVGCIContextSlot* IJSVGAcquireContextSlot(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        IJSVGContextPoolLock = [[NSLock alloc] init];
        IJSVGContextPool = [[NSMutableArray alloc] init];
    });
    [IJSVGContextPoolLock lock];
    IJSVGCIContextSlot* selected = nil;
    for(IJSVGCIContextSlot* slot in IJSVGContextPool) {
        if(selected == nil || slot.users < selected.users) {
            selected = slot;
        }
    }
    if(selected == nil || (selected.users != 0 && IJSVGContextPool.count < 6)) {
        selected = [[IJSVGCIContextSlot alloc] init];
        [IJSVGContextPool addObject:selected];
    }
    selected.users++;
    [IJSVGContextPoolLock unlock];
    return selected;
}

static void IJSVGReleaseContextSlot(IJSVGCIContextSlot* slot)
{
    [IJSVGContextPoolLock lock];
    slot.users--;
    [IJSVGContextPoolLock unlock];
}

@implementation IJSVGThreadManager

@synthesize pathDataStream = _pathDataStream;

static NSMapTable<NSThread*, IJSVGThreadManager*>* managerMap;

+ (NSMapTable*)mapTable
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        managerMap = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsWeakMemory
                                               valueOptions:NSPointerFunctionsStrongMemory
                                                   capacity:1];
    });
    return managerMap;
}

+ (IJSVGThreadManager*)managerForThread:(NSThread*)thread
{
    IJSVGThreadManager* manager = nil;
    NSMapTable* map = [self mapTable];
    @synchronized (map) {
        if((manager = [map objectForKey:thread]) == nil) {
            manager = [[self alloc] initWithThread:thread];
            [map setObject:manager forKey:thread];
        }
    }
    return manager;
}

+ (IJSVGThreadManager*)managerForSVG:(IJSVG*)svg
{
    NSMapTable* map = [self mapTable];
    IJSVGThreadManager* found = nil;
    @synchronized (map) {
        for(IJSVGThreadManager* manager in map) {
            if([manager manages:svg] == YES) {
                found = manager;
                break;
            }
        }
    }
    return found;
}

+ (IJSVGThreadManager *)currentManager
{
    return [self managerForThread:NSThread.currentThread];
}

- (void)dealloc
{
    if(_pathDataStream != NULL) {
        (void)IJSVGPathDataStreamRelease(_pathDataStream), _pathDataStream = NULL;
    }
}

- (id)initWithThread:(NSThread*)thread
{
    if((self = [super init]) != nil) {
        // store the thread
        _thread = thread;
        
        // setup the feature flags
        _featureFlags = [[IJSVGFeatureFlags alloc] init];
        
        // hash table for the SVGs for this given thread
        _allocedSVGs = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory
                                                   capacity:1];
        
        // listen for teardown of the thread
        NSNotificationCenter* center = NSNotificationCenter.defaultCenter;
        [center addObserver:self
                   selector:@selector(tearDownFromThreadExit)
                       name:NSThreadWillExitNotification
                     object:_thread];
    }
    return self;
}

- (void)setUserInfoObject:(id)object
                   forKey:(id<NSCopying>)key
{
    if(_userInfo == nil) {
        _userInfo = [[NSMutableDictionary alloc] init];
    }
    _userInfo[key] = object;
}

- (id)userInfoObjectForKey:(id<NSCopying>)key
{
    if(_userInfo == nil) {
        return nil;
    }
    return _userInfo[key];
}

- (BOOL)manages:(IJSVG*)svg
{
    return [_allocedSVGs containsObject:svg];
}

- (void)adopt:(IJSVG*)svg
{
    if([self manages:svg] == YES) {
        return;
    }
    [_allocedSVGs addObject:svg];
}

- (void)remove:(IJSVG*)svg
{
    [_allocedSVGs removeObject:svg];
}

- (void)tearDownFromThreadExit
{
    // it is important that we call a transaction commit
    // at the end of the thread or any changes will cause a memory leak
    IJSVGPerformTransactionBlock(^{
        [self->_allocedSVGs removeAllObjects];
    });
    NSMapTable* map = [self.class mapTable];
    @synchronized (map) {
        [map removeObjectForKey:_thread];
    }
}

- (CIContext*)CIContext
{
    // Compatibility accessor. Callers can retain and concurrently use this context.
    IJSVGCIContextSlot* slot = IJSVGAcquireContextSlot();
    @try {
        return slot.context;
    } @finally {
        IJSVGReleaseContextSlot(slot);
    }
}

+ (void)performBlockWithCIContext:(void (^)(CIContext*, BOOL))block
{
    IJSVGCIContextSlot* slot = IJSVGAcquireContextSlot();
    @try {
        CIContext* context = slot.context;
        if(context != nil) {
            block(context, slot.supportsMetalKernels);
        }
    } @finally {
        IJSVGReleaseContextSlot(slot);
    }
}

- (IJSVGPathDataStream*)pathDataStream
{
    if(_pathDataStream == NULL) {
        _pathDataStream = IJSVGPathDataStreamCreateDefault();
    }
    return _pathDataStream;
}

@end
