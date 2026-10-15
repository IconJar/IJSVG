//
//  IJSVGStyleSheetSelector.h
//  IJSVG
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGStyleSheetSelectorRaw.h>

#import <IJSVG/IJSVGNode.h>

// Match selectors against either render nodes or lightweight XML records.
@protocol IJSVGStyleSheetSelectorNode <NSObject>
- (NSString*)name;
- (NSString*)identifier;
- (NSSet<NSString*>*)classNameList;
- (id<IJSVGStyleSheetSelectorNode>)selectorParent;
- (id<IJSVGStyleSheetSelectorNode>)selectorPreviousSibling;
@optional
- (id<IJSVGStyleSheetSelectorNode>)selectorNextSibling;
- (id<IJSVGStyleSheetSelectorNode>)selectorFirstChild;
- (BOOL)selectorIsEmpty;
- (NSUInteger)selectorIndexOfType:(BOOL)ofType fromEnd:(BOOL)fromEnd;
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
@property (nonatomic, weak) id<IJSVGStyleSheetSelectorNode> selectorNextSibling;
@property (nonatomic, weak) id<IJSVGStyleSheetSelectorNode> selectorFirstChild;
@property (nonatomic, copy) NSString* namespaceURI;
@property (nonatomic) BOOL selectorHasContent;
@property (nonatomic) NSUInteger childIndex;
@property (nonatomic) NSUInteger childCount;
@property (nonatomic) NSUInteger typeIndex;
@property (nonatomic) NSUInteger typeCount;
@end

@interface IJSVGStyleSheetSelector : NSObject {
    NSString* selector;

@private
    NSMutableArray<IJSVGStyleSheetSelectorRaw*>* _rawSelectors;
}

// Packed, lexicographically ordered CSS specificity; compare rather than interpret numerically.
@property (nonatomic, assign) NSUInteger specificity;
@property (nonatomic, readonly) BOOL requiresSelectorTree;
@property (nonatomic, readonly) IJSVGStyleSheetSelectorRaw* matchingSelector;

+ (NSArray<IJSVGStyleSheetSelector*>*)selectorsWithString:(NSString*)string forgiving:(BOOL)forgiving;
- (id)initWithSelectorString:(NSString*)string;
- (BOOL)matchesNode:(id<IJSVGStyleSheetSelectorNode>)node;

@end
