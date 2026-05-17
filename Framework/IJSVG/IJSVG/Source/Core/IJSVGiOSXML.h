//
//  IJSVGiOSXML.h
//  IJSVG
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSXMLNodeOptions) {
    NSXMLNodeOptionsNone = 0,
    NSXMLNodePrettyPrint = 1UL << 0,
    NSXMLNodeCompactEmptyElement = 1UL << 1
};

typedef NS_ENUM(NSUInteger, NSXMLNodeKind) {
    NSXMLInvalidKind = 0,
    NSXMLDocumentKind = 1,
    NSXMLElementKind = 2,
    NSXMLAttributeKind = 3,
    NSXMLTextKind = 4,
    NSXMLCommentKind = 5
};

@class IJSVGiOSXMLDocument;
@class IJSVGiOSXMLElement;

@interface IJSVGiOSXMLNode : NSObject <NSCopying>

@property (nonatomic, assign) NSXMLNodeKind kind;
@property (nonatomic, copy, nullable) NSString* name;
@property (nonatomic, copy, nullable) NSString* localName;
@property (nonatomic, copy, nullable) NSString* URI;
@property (nonatomic, copy, nullable) NSString* stringValue;
@property (nonatomic, weak, nullable) id parent;
@property (nonatomic, weak, nullable) IJSVGiOSXMLDocument* document;
@property (nonatomic, readonly, nullable) NSArray<IJSVGiOSXMLNode*>* attributes;
@property (nonatomic, readonly, nullable) NSArray<IJSVGiOSXMLNode*>* children;
@property (nonatomic, readonly) NSUInteger childCount;
@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, readonly, nullable) IJSVGiOSXMLNode* nextSibling;

- (instancetype)initWithKind:(NSXMLNodeKind)kind;
- (nullable IJSVGiOSXMLNode*)attributeForName:(NSString*)name;
- (nullable IJSVGiOSXMLNode*)attributeForLocalName:(NSString*)localName
                                            URI:(nullable NSString*)URI;
- (void)detach;

@end

@interface IJSVGiOSXMLElement : IJSVGiOSXMLNode

@property (nonatomic, readonly) NSArray<IJSVGiOSXMLNode*>* attributes;
@property (nonatomic, readonly) NSArray<IJSVGiOSXMLNode*>* children;
@property (nonatomic, readonly) NSUInteger childCount;

- (instancetype)initWithName:(nullable NSString*)name;
- (nullable IJSVGiOSXMLNode*)attributeForName:(NSString*)name;
- (nullable IJSVGiOSXMLNode*)attributeForLocalName:(NSString*)localName
                                            URI:(nullable NSString*)URI;
- (void)setAttributesAsDictionary:(NSDictionary<NSString*, NSString*>*)attributes;
- (void)addAttribute:(IJSVGiOSXMLNode*)attribute;
- (void)removeAttributeForName:(NSString*)name;
- (void)addChild:(IJSVGiOSXMLNode*)child;
- (void)setChildren:(nullable NSArray<IJSVGiOSXMLNode*>*)children;
- (void)insertChild:(IJSVGiOSXMLNode*)child
            atIndex:(NSUInteger)index;
- (void)removeChildAtIndex:(NSUInteger)index;
- (void)replaceChildAtIndex:(NSUInteger)index
                   withNode:(IJSVGiOSXMLNode*)node;

@end

@interface IJSVGiOSXMLDocument : NSObject

@property (nonatomic, copy, nullable) NSString* version;
@property (nonatomic, copy, nullable) NSString* characterEncoding;
@property (nonatomic, strong, nullable) IJSVGiOSXMLElement* rootElement;
@property (nonatomic, readonly) id rootDocument;

- (instancetype)initWithRootElement:(IJSVGiOSXMLElement*)rootElement;
- (instancetype)initWithXMLString:(NSString*)string
                           options:(NSXMLNodeOptions)options
                             error:(NSError**)error;
- (instancetype)initWithData:(NSData*)data
                      options:(NSXMLNodeOptions)options
                        error:(NSError**)error;
- (instancetype)initWithContentsOfURL:(NSURL*)URL
                               options:(NSXMLNodeOptions)options
                                 error:(NSError**)error;
- (NSArray<IJSVGiOSXMLElement*>*)nodesForXPath:(NSString*)xPath
                                      error:(NSError**)error;
- (NSString*)XMLStringWithOptions:(NSXMLNodeOptions)options;

@end

typedef IJSVGiOSXMLNode NSXMLNode;
typedef IJSVGiOSXMLElement NSXMLElement;
typedef IJSVGiOSXMLDocument NSXMLDocument;

NS_ASSUME_NONNULL_END

#endif
