//
//  IJSVGColorNode.h
//  IJSVG
//
//  Created by Curtis Hard on 29/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGXEntities.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGColorNode : IJSVGNode {
    
}

@property (nonatomic, strong, nullable) XColor* color;
@property (nonatomic, assign) BOOL isNoneOrTransparent;

+ (IJSVGNode*)colorNodeWithColor:(XColor* _Nullable)color;

- (instancetype)initWithColor:(XColor* _Nullable)color;

@end

NS_ASSUME_NONNULL_END
