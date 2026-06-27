//
//  IJSVGParserAttributeMacros.h
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#ifndef IJSVGParserAttributeMacros_h
#define IJSVGParserAttributeMacros_h

#import <IJSVG/IJSVGParserUtils.h>

#define IJSVGStoreStyleAttributes(style) \
    do { \
        NSDictionary* properties = [(style) properties]; \
        for(NSString* key in properties) { \
            NSUInteger attribute = IJSVGNodeAttributeForName(key); \
            if(attribute == NSNotFound || IJSVGAttributeMaskContains(activeAttributes, attribute) == NO) { \
                continue; \
            } \
            NSString* value = properties[key]; \
            if(value.length == 0) { \
                continue; \
            } \
            attributeValues[attribute] = value; \
            presentAttributes |= (1ULL << attribute); \
        } \
    } while(0)

#define IJSVGAttributeValue(attribute) attributeValues[(attribute)]
#define IJSVGParseAttribute(attribute, ...) \
    do { \
        value = IJSVGAttributeValue((attribute)); \
        if(value.length != 0) { \
            __VA_ARGS__; \
        } \
    } while(0)
#define IJSVGApplyTransform(value) \
    do { \
        NSMutableArray<IJSVGTransform*>* transforms = [[NSMutableArray alloc] init]; \
        [transforms addObjectsFromArray:[IJSVGTransform transformsForString:(value)]]; \
        if(node.transforms != nil) { \
            [transforms addObjectsFromArray:node.transforms]; \
        } \
        node.transforms = transforms; \
    } while(0)

#endif