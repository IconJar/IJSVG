//
//  IJSVGXMLTypes.h
//  IJSVG
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#pragma once
#import <Foundation/Foundation.h>

typedef NS_ENUM(uint32_t, IJSVGXMLNodeKind) {
    IJSVGXMLNodeKindInvalid = 0,
    IJSVGXMLNodeKindElement = 2,
    IJSVGXMLNodeKindAttribute = 3,
    IJSVGXMLNodeKindProcessingInstruction = 5,
    IJSVGXMLNodeKindComment = 6,
    IJSVGXMLNodeKindText = 7,
    IJSVGXMLNodeKindCDATA = 8
};
