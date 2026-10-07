//
//  IJSVGStyleSheetSelector.h
//  IJSVG
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyleSheetSelectorRaw.h>
#import <Foundation/Foundation.h>

#import <IJSVG/IJSVGNode.h>

// Match selectors against either render nodes or lightweight XML records.
@protocol IJSVGStyleSheetSelectorNode <NSObject>
- (NSString*)name;
- (NSString*)identifier;
- (NSSet<NSString*>*)classNameList;
- (id<IJSVGStyleSheetSelectorNode>)selectorParent;
- (id<IJSVGStyleSheetSelectorNode>)selectorPreviousSibling;
@end

@interface IJSVGNode (IJSVGStyleSheetSelectorNode) <IJSVGStyleSheetSelectorNode>
@end

// The parser keeps these records alive through its map.
// Parent and sibling links are weak to avoid retaining the tree.
@interface IJSVGStyleSheetSelectorRecord : NSObject <IJSVGStyleSheetSelectorNode>
@property (nonatomic, copy) NSString* name;
@property (nonatomic, copy) NSString* identifier;
@property (nonatomic, copy) NSSet<NSString*>* classNameList;
@property (nonatomic, weak) id<IJSVGStyleSheetSelectorNode> selectorParent;
@property (nonatomic, weak) id<IJSVGStyleSheetSelectorNode> selectorPreviousSibling;
@end

@interface IJSVGStyleSheetSelector : NSObject {

    NSString* selector;
    
@private
    NSMutableArray<IJSVGStyleSheetSelectorRaw*>* _rawSelectors;
}

@property (nonatomic, assign) NSUInteger specificity;
@property (nonatomic, readonly) BOOL requiresSelectorTree;
@property (nonatomic, readonly) IJSVGStyleSheetSelectorRaw* matchingSelector;

- (id)initWithSelectorString:(NSString*)string;
- (BOOL)matchesNode:(id<IJSVGStyleSheetSelectorNode>)node;

@end
