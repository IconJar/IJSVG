//
//  IJSVGExportDocument.m
//  IJSVG
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGExportDocument.h>
#import <IJSVGExportNodePrivate.h>

static NSStringEncoding IJSVGExportStringEncoding(NSString* name)
{
    CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)name);
    if (encoding == kCFStringEncodingInvalidId) {
        [NSException raise:NSInvalidArgumentException format:@"Unsupported export character encoding: %@", name];
    }
    return CFStringConvertEncodingToNSStringEncoding(encoding);
}

@implementation IJSVGExportDocument {
    xmlDocPtr _document;
}

- (instancetype)initWithRootElement:(IJSVGExportElement*)root
{
    if ((self = [super init])) {
        _document = xmlNewDoc(BAD_CAST "1.0");
        IJSVGExportCheckAllocation(_document);
        [root detach];
        _rootElement = root;
        xmlDocSetRootElement(_document, root->_node);
        _version = @"1.0";
        _characterEncoding = @"UTF-8";
    }
    return self;
}

- (void)dealloc
{
    // Nodes may outlive the document through a delegate or cleanup snapshot.
    if (_rootElement != nil && _rootElement->_node->doc == _document) {
        xmlUnlinkNode(_rootElement->_node);
        xmlSetTreeDoc(_rootElement->_node, NULL);
    }
    xmlFreeDoc(_document);
}

/// Serializes the document with its XML declaration.
- (NSData*)XMLDataWithPrettyPrinting:(BOOL)prettyPrint
{
    return [self XMLDataWithPrettyPrinting:prettyPrint includeXMLDeclaration:YES];
}

/// Serializes the document with the requested formatting and declaration options.
- (NSData*)XMLDataWithPrettyPrinting:(BOOL)prettyPrint includeXMLDeclaration:(BOOL)includeXMLDeclaration
{
    // Keep qualified names and xmlns declarations in attribute order while
    // building, just like other exporter attributes. This also lets detached
    // resource nodes carry xlink names before the root declaration is added.
    xmlFree((void*)_document->version);
    _document->version = xmlStrdup((const xmlChar*)self.version.UTF8String);
    xmlBufferPtr buffer = xmlBufferCreate();
    IJSVGExportCheckAllocation(buffer);
    int options = prettyPrint ? XML_SAVE_FORMAT : 0;
    if (!includeXMLDeclaration) {
        options |= XML_SAVE_NO_DECL;
    }
    xmlSaveCtxtPtr context = xmlSaveToBuffer(buffer, self.characterEncoding.UTF8String, options);
    if (context == NULL) {
        xmlBufferFree(buffer);
        [NSException raise:NSMallocException format:@"Unable to allocate export XML serializer"];
    }
    long result = xmlSaveDoc(context, _document);
    int closeResult = xmlSaveClose(context);
    if (result < 0 || closeResult < 0) {
        xmlBufferFree(buffer);
        [NSException raise:NSInternalInconsistencyException format:@"Unable to serialize export XML"];
    }
    NSUInteger length = xmlBufferLength(buffer);
    const xmlChar* bytes = xmlBufferContent(buffer);

    NSStringEncoding encoding = IJSVGExportStringEncoding(self.characterEncoding);
    if (!prettyPrint && encoding != NSUTF8StringEncoding) {
        // Trim characters rather than individual bytes in multibyte encodings.
        NSString* string = [[NSString alloc] initWithBytes:bytes length:length encoding:encoding];
        xmlBufferFree(buffer);
        if ([string hasSuffix:@"\n"]) {
            string = [string substringToIndex:string.length - 1];
        }
        if ([string hasPrefix:@"<?xml"]) {
            NSRange separator = [string rangeOfString:@"?>\n"];
            if (separator.location != NSNotFound) {
                string = [string stringByReplacingCharactersInRange:NSMakeRange(NSMaxRange(separator) - 1, 1) withString:@""];
            }
        }
        NSData* data = [string dataUsingEncoding:encoding];
        if (data == nil) {
            [NSException raise:NSInternalInconsistencyException format:@"Unable to encode export XML"];
        }
        return data;
    }

    // libxml appends a document newline even without formatting.
    if (!prettyPrint && length != 0 && bytes[length - 1] == '\n') {
        length--;
    }

    // Remove only the separator after the declaration, preserving content whitespace.
    if (!prettyPrint && length >= 5 && memcmp(bytes, "<?xml", 5) == 0) {
        for (NSUInteger index = 5; index + 2 < length; index++) {
            if (bytes[index] == '?' && bytes[index + 1] == '>') {
                if (bytes[index + 2] == '\n') {
                    memmove((xmlChar*)bytes + index + 2, bytes + index + 3, length - index - 3);
                    length--;
                }
                break;
            }
        }
    }

    // Each serialization owns a fresh buffer. Transfer its lifetime to NSData
    // rather than copying the full output, including large embedded images.
    return [[NSData alloc] initWithBytesNoCopy:(void*)bytes
                                        length:length
                                   deallocator:^(void* _, NSUInteger __) {
                                       xmlBufferFree(buffer);
                                   }];
}

- (NSString*)XMLStringWithPrettyPrinting:(BOOL)prettyPrint
{
    return [[NSString alloc] initWithData:[self XMLDataWithPrettyPrinting:prettyPrint] encoding:IJSVGExportStringEncoding(self.characterEncoding)];
}

@end
