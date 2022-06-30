//
//  IJSVGStyleSheet.h
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetRule.h>
#import <IJSVG/IJSVGStyleSheetSelector.h>
#import <Foundation/Foundation.h>

@class IJSVGNode;

@interface IJSVGStyleSheet : NSObject {

@private
    NSMutableDictionary* _selectors;
    NSMutableArray* _rules;
}

- (void)parseStyleBlock:(NSString*)string;
- (IJSVGStyleSheetStyle*)styleForNode:(IJSVGNode*)node;

@end
