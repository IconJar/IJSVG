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

@interface IJSVGThreadManager : NSObject {
    
@private
    NSMutableDictionary* _userInfo;
}

@property (nonatomic, readonly) IJSVGFeatureFlags* featureFlags;
@property (nonatomic, readonly) NSThread* thread;
@property (nonatomic, readonly) CIContext* CIContext;
@property (nonatomic, readonly) IJSVGPathDataStream* pathDataStream;
 
+ (IJSVGThreadManager*)managerForThread:(NSThread*)thread;
+ (IJSVGThreadManager*)currentManager;

- (void)setUserInfoObject:(id)object
                   forKey:(id<NSCopying>)key;
- (id)userInfoObjectForKey:(id<NSCopying>)key;

@end
