//
//  IJSVGStyleSheetSelectorRaw.h
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IJSVGNode;

typedef NS_ENUM(NSUInteger, IJSVGStyleSheetSelectorCombinator) {
    IJSVGStyleSheetSelectorCombinatorWildcard, // *
    IJSVGStyleSheetSelectorCombinatorDescendant, // space
    IJSVGStyleSheetSelectorCombinatorDirectDescendant, // >
    IJSVGStyleSheetSelectorCombinatorPrecededSibling, // ~
    IJSVGStyleSheetSelectorCombinatorNextSibling // +
};

@interface IJSVGStyleSheetSelectorRaw : NSObject {
}

@property (nonatomic, copy) NSString* tag;
@property (nonatomic, copy) NSString* identifier;
@property (nonatomic, copy) NSString* combinatorString;
@property (nonatomic, strong) NSMutableSet<NSString*>* classes;
@property (nonatomic, assign) IJSVGStyleSheetSelectorCombinator combinator;

- (void)addClassName:(NSString*)className;

@end
