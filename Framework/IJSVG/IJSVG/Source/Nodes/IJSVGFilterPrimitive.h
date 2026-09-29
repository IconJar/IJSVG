//
//  IJSVGFilterPrimitive.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

@interface IJSVGFilterPrimitive : IJSVGGroup

@property (nonatomic, copy) NSString* input;
@property (nonatomic, copy) NSString* result;
@property (nonatomic, copy) NSString* input2;
// Primitive-specific SVG attributes, retained for lossless vector export.
@property (nonatomic, copy) NSDictionary<NSString*, NSString*>* parameters;
@property (nonatomic, strong) IJSVGNode* imageNode;
@property (nonatomic, strong) NSImage* image;

+ (NSSet<NSString*>*)parameterNames;
+ (BOOL)isPrimitiveType:(IJSVGNodeType)type;
+ (BOOL)type:(IJSVGNodeType)parentType
    acceptsChildType:(IJSVGNodeType)childType;
- (NSArray<NSNumber*>*)numbersForParameter:(NSString*)name;
- (CGFloat)numberForParameter:(NSString*)name
                 defaultValue:(CGFloat)value;
- (CGSize)pairForParameter:(NSString*)name
              defaultValue:(CGSize)value;

@end
