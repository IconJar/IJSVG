//
//  IJSVGExportNodePrivate.h
//  IJSVG
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#pragma once
#import <IJSVG/IJSVGExportElement.h>

@import libxml2;

@interface IJSVGExportNode () {
@package
    xmlNodePtr _node;
    IJSVGExportNode* _nextOwned;
}

- (instancetype)initWithXMLNode:(xmlNodePtr)node;
- (void)unlink;
@end

@interface IJSVGExportElement () {
@package
    IJSVGExportNode* _firstChild;
    IJSVGExportNode* _firstAttribute;
    NSUInteger _childCount;
}
@end

static inline IJSVGExportNode* IJSVGExportWrapper(xmlNodePtr node)
{
    return node == NULL || node->type == XML_DOCUMENT_NODE ? nil : (__bridge IJSVGExportNode*)node->_private;
}

static inline void IJSVGExportCheckAllocation(const void* pointer)
{
    if (pointer == NULL) {
        [NSException raise:NSMallocException format:@"Unable to allocate an export XML node"];
    }
}
