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
    IJSVGStyleSheetSelectorCombinatorDescendant, // space
    IJSVGStyleSheetSelectorCombinatorDirectDescendant, // >
    IJSVGStyleSheetSelectorCombinatorPrecededSibling, // ~
    IJSVGStyleSheetSelectorCombinatorNextSibling // +
};

@interface IJSVGStyleSheetSelectorRaw : NSObject {

    NSString * tag;
    NSString * identifier;
    
    NSMutableArray * classes;
    
    IJSVGStyleSheetSelectorCombinator combinator;
    NSString * combinatorString;
    
}

@property (nonatomic, copy) NSString * tag;
@property (nonatomic, copy) NSString * identifier;
@property (nonatomic, copy) NSString * combinatorString;
@property (nonatomic, retain) NSArray * classes;
@property (nonatomic, assign) IJSVGStyleSheetSelectorCombinator combinator;
- (void)addClassName:(NSString *)className;

@end
