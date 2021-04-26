//
//  IJSVGDef.h
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <Foundation/Foundation.h>

@interface IJSVGDef : NSObject {

@private
    NSMutableDictionary* _dict;
}

- (void)addDef:(IJSVGNode*)aDef;
- (IJSVGDef*)defForID:(NSString*)anID;

@end
