//
//  IJSVGInheritedElement.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVGXML.h>

@interface IJSVGInheritedElement : NSObject
@property (nonatomic, readonly) IJSVGXMLNode* element;
@property (nonatomic, readonly) IJSVGXMLAttributeList attributes;
@property (nonatomic, readonly) IJSVGXMLNode* childrenElement;
@property (nonatomic, readonly) BOOL hasReference;
- (instancetype)initWithElement:(IJSVGXMLNode*)element fallback:(IJSVGInheritedElement*)fallback;
@end
