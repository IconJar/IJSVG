//
//  IJSVGStyleSheetSelectorRaw.h
//  IJSVG
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IJSVGNode;
@class IJSVGStyleSheetPseudoClass;
@class IJSVGStyleSheetAttributeSelector;

typedef NS_ENUM(NSUInteger, IJSVGStyleSheetSelectorCombinator) {
    IJSVGStyleSheetSelectorCombinatorWildcard, // *
    IJSVGStyleSheetSelectorCombinatorDescendant, // space
    IJSVGStyleSheetSelectorCombinatorDirectDescendant, // >
    IJSVGStyleSheetSelectorCombinatorPrecededSibling, // ~
    IJSVGStyleSheetSelectorCombinatorNextSibling, // +
    IJSVGStyleSheetSelectorCombinatorColumn // ||
};

@interface IJSVGStyleSheetSelectorRaw : NSObject {
}

@property (nonatomic, assign) NSUInteger rootCount;
@property (nonatomic, copy) NSArray<IJSVGStyleSheetPseudoClass*>* pseudoClasses;
@property (nonatomic, copy) NSArray<NSString*>* identifiers;
@property (nonatomic) NSUInteger classCount;
@property (nonatomic, copy) NSString* tag;
@property (nonatomic, copy) NSString* namespaceURI;
@property (nonatomic) BOOL explicitType;
@property (nonatomic, copy) NSArray<IJSVGStyleSheetAttributeSelector*>* attributes;
@property (nonatomic, copy) NSString* identifier;
@property (nonatomic, readonly) NSString* combinatorString;
@property (nonatomic, strong) NSMutableSet<NSString*>* classes;
@property (nonatomic, assign) IJSVGStyleSheetSelectorCombinator combinator;

- (void)addClassName:(NSString*)className;

@end
