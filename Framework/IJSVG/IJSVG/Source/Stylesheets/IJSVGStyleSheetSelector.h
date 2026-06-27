//
//  IJSVGStyleSheetSelector.h
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetSelectorRaw.h>
#import <Foundation/Foundation.h>

@class IJSVGNode;

@interface IJSVGStyleSheetSelector : NSObject {

    NSString* selector;
    
@private
    NSMutableArray<IJSVGStyleSheetSelectorRaw*>* _rawSelectors;
}

@property (nonatomic, assign) NSUInteger specificity;
@property (nonatomic, readonly) IJSVGStyleSheetSelectorRaw* matchingSelector;

- (id)initWithSelectorString:(NSString*)string;
- (BOOL)matchesNode:(IJSVGNode*)node;

@end
