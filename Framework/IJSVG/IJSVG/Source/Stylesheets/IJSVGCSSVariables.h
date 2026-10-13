//
//  IJSVGCSSVariables.h
//  IJSVG
//
//  Created by Curtis Hard on 12/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, IJSVGCSSVariableSyntax) { IJSVGCSSVariableSyntaxInvalid,
    IJSVGCSSVariableSyntaxLiteral,
    IJSVGCSSVariableSyntaxReferences };

BOOL IJSVGCSSValueMayContainVariables(NSString* value);
NSString* IJSVGCSSResolvedPaintValue(NSString* value, NSUInteger attribute);
IJSVGCSSVariableSyntax IJSVGCSSValidateVariables(NSString* value);
NSDictionary<NSString*, id>* IJSVGCSSResolveCustomProperties(NSDictionary<NSString*, NSString*>* declarations, NSDictionary<NSString*, id>* inherited);
NSString* IJSVGCSSResolveVariables(NSString* value, NSDictionary<NSString*, id>* properties);
NSString* IJSVGCSSResolveDeclarationVariables(NSString* value, NSDictionary<NSString*, id>* properties);
