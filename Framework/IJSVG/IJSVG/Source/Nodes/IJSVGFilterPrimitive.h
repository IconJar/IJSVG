//
//  IJSVGFilterPrimitive.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGFilterPrimitive : IJSVGGroup

@property (nonatomic, copy, nullable) NSString* input;
@property (nonatomic, copy, nullable) NSString* result;
@property (nonatomic, copy, nullable) NSString* input2;
// Primitive specific SVG attributes, retained for lossless vector export.
@property (nonatomic, copy, nullable) NSDictionary<NSString*, NSString*>* parameters;
@property (nonatomic, strong, nullable) IJSVGNode* imageNode;
@property (nonatomic, strong, nullable) NSImage* image;

+ (NSSet<NSString*>*)parameterNames;
+ (BOOL)isPrimitiveType:(IJSVGNodeType)type;
+ (BOOL)type:(IJSVGNodeType)parentType
    acceptsChildType:(IJSVGNodeType)childType;

// Immutable derived setup, discarded whenever parameters are replaced.
- (id _Nullable)preparedValueForKey:(NSString*)key
                  builder:(id _Nullable (^)(void))builder;
- (NSArray<NSNumber*>*)numbersForParameter:(NSString*)name;
- (CGFloat)numberForParameter:(NSString*)name
                 defaultValue:(CGFloat)value;
- (CGSize)pairForParameter:(NSString*)name
              defaultValue:(CGSize)value;

@end

NS_ASSUME_NONNULL_END
