//
//  IJSVGStyleSheetRule.h
//  IJSVGExample
//
//  Created by Curtis Hard on 16/01/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStyle.h>
#import <IJSVG/IJSVGStyleSheetSelector.h>
#import <Foundation/Foundation.h>

@class IJSVGNode;

@interface IJSVGStyleSheetRule : NSObject {
}

@property (nonatomic, strong) NSArray* selectors;
@property (nonatomic, strong) IJSVGStyle* style;

- (BOOL)matchesNode:(IJSVGNode*)node
           selector:(IJSVGStyleSheetSelector**)matchedSelector;

@end
