//
//  IJSVGStyleSheetRule.h
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVG/IJSVGStyleSheetSelector.h>
#import <Foundation/Foundation.h>

@class IJSVGNode;

@interface IJSVGStyleSheetRule : NSObject {
}

@property (nonatomic, strong) NSArray<IJSVGStyleSheetSelector*>* selectors;
@property (nonatomic, strong) IJSVGStyleSheetStyle* style;
@property (nonatomic, assign) NSUInteger sourceIndex;
@property (nonatomic, assign) BOOL matchesUniversalSelector;

@property (nonatomic, strong) NSMutableSet<NSString*>* matchingIdentifiers;
@property (nonatomic, strong) NSMutableSet<NSString*>* matchingClassNames;
@property (nonatomic, strong) NSMutableSet<NSString*>* matchingTagNames;

- (void)addMatchingSelector:(IJSVGStyleSheetSelector*)selector;
- (BOOL)canMatchNode:(IJSVGNode*)node;
- (BOOL)matchesNode:(IJSVGNode*)node
           selector:(IJSVGStyleSheetSelector**)matchedSelector;

@end
