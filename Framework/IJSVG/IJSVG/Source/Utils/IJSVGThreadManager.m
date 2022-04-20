//
//  IJSVGThreadManager.m
//  IJSVG
//
//  Created by Curtis Hard on 20/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGThreadManager.h"

@implementation IJSVGThreadManager

@synthesize CIContext = _CIContext;
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
            manager = [[[self alloc] initWithThread:thread] autorelease];
            [map setObject:manager forKey:thread];
        }
    }
    return manager;
}

+ (IJSVGThreadManager *)currentManager
{
    return [self managerForThread:NSThread.currentThread];
}

- (void)dealloc
{
    (void)[_userInfo release], _userInfo = nil;
    (void)[_thread release], _thread = nil;
    (void)[_CIContext release], _CIContext = nil;
    if(_pathDataStream != NULL) {
        (void)IJSVGPathDataStreamRelease(_pathDataStream), _pathDataStream = NULL;
    }
    [super dealloc];
}

- (id)initWithThread:(NSThread*)thread
{
    if((self = [super init]) != nil) {
        // store the thread
        _thread = thread.retain;
        
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

- (void)tearDownFromThreadExit
{
    NSMapTable* map = [self.class mapTable];
    @synchronized (map) {
        [map removeObjectForKey:_thread];
    }
}

- (CIContext*)CIContext
{
    if(_CIContext == nil) {
        // for high performance we can disable the color
        // management
        _CIContext = [CIContext contextWithOptions:@{
            kCIImageColorSpace: NSNull.null
        }].retain;
    }
    return _CIContext;
}

- (IJSVGPathDataStream*)pathDataStream
{
    if(_pathDataStream == NULL) {
        _pathDataStream = IJSVGPathDataStreamCreateDefault();
    }
    return _pathDataStream;
}

@end
