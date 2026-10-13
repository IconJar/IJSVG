//
//  IJSVGInheritedElement.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IJSVGInheritedElement : NSObject
@property (nonatomic, strong, readonly) NSXMLElement* element;
@property (nonatomic, copy, readonly) NSArray<NSXMLNode*>* attributes;
@property (nonatomic, strong, readonly) NSXMLElement* childrenElement;
@property (nonatomic, readonly) BOOL hasReference;
- (instancetype)initWithElement:(NSXMLElement*)element fallback:(IJSVGInheritedElement*)fallback;
@end
