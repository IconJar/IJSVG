//
//  IJSVGStyleSheet.h
//  IJSVG
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGStyleSheetRule.h>
#import <IJSVG/IJSVGStyleSheetSelector.h>

@class IJSVGNode;

@interface IJSVGStyleSheet : NSObject {
@private
    NSMutableDictionary<NSString*, IJSVGStyleSheetSelector*>* _selectors;
    NSMutableArray<IJSVGStyleSheetRule*>* _rules;
}

@property (nonatomic, readonly) NSUInteger ruleCount;
@property (nonatomic, readonly) BOOL requiresSelectorTree;

- (void)parseStyleBlock:(NSString*)string;
- (IJSVGStyleSheetStyle*)styleForNode:(id<IJSVGStyleSheetSelectorNode>)node;

@end
