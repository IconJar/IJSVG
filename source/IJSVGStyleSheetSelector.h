//
//  IJSVGStyleSheetSelector.h
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGStyleSheetSelectorRaw.h"

@class IJSVGNode;

@interface IJSVGStyleSheetSelector : NSObject {
    
    NSString * selector;
    NSUInteger specificity;
@private
    NSMutableArray * _rawSelectors;
    
}

@property (nonatomic, assign) NSUInteger specificity;

- (id)initWithSelectorString:(NSString *)string;
- (BOOL)matchesNode:(IJSVGNode *)node;

@end
