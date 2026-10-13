//
//  IJSVGParserTextUtils.h
//  IJSVG
//
//  Created by Curtis Hard on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGText.h>

NS_ASSUME_NONNULL_BEGIN

IJSVGTextKeyword IJSVGTextKeywordForString(NSString* value);
IJSVGTextAttributeValue* IJSVGParseTextAttribute(NSString* value, IJSVGNodeAttribute attribute);
void IJSVGApplyTextAttributes(IJSVGNode* node, NSString* _Nullable __unsafe_unretained const attributeValues[_Nonnull kIJSVGNodeAttributeStorageLength], uint64_t textAttributes);

void IJSVGReadTextPositionAttribute(NSString* _Nullable __unsafe_unretained const* _Nonnull values, IJSVGNodeAttribute attribute, NSString* name, NSMutableDictionary<NSString*, IJSVGTextAttributeValue*>* _Nullable __strong* _Nonnull positioning);

NS_ASSUME_NONNULL_END
