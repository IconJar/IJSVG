//
//  IJSVGStyleSheetSelectorRaw.h
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IJSVGNode;

@interface IJSVGStyleSheetSelectorRaw : NSObject {

    NSString * tag;
    NSString * identifier;
    NSMutableArray * classes;
    
}

@property (nonatomic, copy) NSString * tag;
@property (nonatomic, copy) NSString * identifier;
@property (nonatomic, retain) NSArray * classes;

- (void)addClassName:(NSString *)className;

@end
