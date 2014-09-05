//
//  IJSVGGroup.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGNode.h"
#import "IJSVGPath.h"

@interface IJSVGGroup : IJSVGNode {
    
    NSMutableArray * children;
    
}

- (void)addChild:(id)child;
- (NSArray *)children;
- (void)purgeChildren;

@end
