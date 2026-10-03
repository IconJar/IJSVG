//
//  IJSVGForeignObject.h
//  IJSVG
//
//  Created by Curtis Hard on 02/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGForeignObject : IJSVGNode {
}

@property (nonatomic, copy, nullable) NSString* requiredExtension;

@end

NS_ASSUME_NONNULL_END
