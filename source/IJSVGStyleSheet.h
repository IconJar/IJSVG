//
//  IJSVGStyleSheet.h
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGStyleSheetSelector.h"
#import "IJSVGStyleSheetRule.h"

@class IJSVGNode;

@interface IJSVGStyleSheet : NSObject {
    
@private
    NSMutableDictionary * _selectors;
    NSMutableArray * _rules;
}

- (void)parseStyleBlock:(NSString *)string;
- (IJSVGStyle *)styleForNode:(IJSVGNode *)node;

@end
