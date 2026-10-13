//
//  IJSVGReference.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGReference : NSObject <NSCopying>

@property (nonatomic, copy, readonly, nullable) NSString* href;
@property (nonatomic, copy, readonly, nullable) NSString* fragmentIdentifier;

- (instancetype)initWithHref:(nullable NSString*)href;

@end

@protocol IJSVGReferenceNode <NSObject>

@property (nonatomic, strong, nullable) IJSVGReference* reference;

@end

NS_ASSUME_NONNULL_END
