//
//  IJSVGParserTextUtils.h
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGText.h>

NS_ASSUME_NONNULL_BEGIN

IJSVGTextKeyword IJSVGTextKeywordForString(NSString* value);
IJSVGTextAttributeValue* IJSVGParseTextAttribute(NSString* value,
                                                 IJSVGNodeAttribute attribute);
void IJSVGApplyTextAttributes(IJSVGNode* node,
                              NSString* _Nullable __unsafe_unretained const attributeValues[_Nonnull kIJSVGNodeAttributeStorageLength]);

NS_ASSUME_NONNULL_END
