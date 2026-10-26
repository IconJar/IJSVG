//
//  IJSVGImage.m
//  IJSVG
//
//  Created by Curtis Hard on 28/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGImage.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGNodeParsing.h>
#import <ImageIO/ImageIO.h>

// Image subdocuments are parsed synchronously and cannot load external resources.
// Bound nested data images as well, without sharing state between parsing threads.
static _Thread_local NSUInteger IJSVGEmbeddedImageDepth;

static BOOL IJSVGImageURLIsWhitespace(unsigned char character)
{
    return character == ' ' || (character >= '\t' && character <= '\r');
}

static NSString* IJSVGImageURLWithoutWhitespace(NSString* string)
{
    IJSVGStringBytes source = IJSVGStringGetBytes(string);
    BOOL whitespace = NO;
    for (NSUInteger index = 0; index < source.length; index++) {
        unsigned char character = source.bytes[index];
        if (character >= 128) {
            return [string stringByReplacingOccurrencesOfString:@"\\s+" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, string.length)];
        }
        whitespace |= IJSVGImageURLIsWhitespace(character);
    }
    if (!whitespace) {
        return string;
    }
    char* buffer = malloc(source.length);
    if (buffer == NULL) {
        return nil;
    }
    NSUInteger length = 0;
    for (NSUInteger index = 0; index < source.length; index++) {
        unsigned char character = source.bytes[index];
        if (!IJSVGImageURLIsWhitespace(character)) {
            buffer[length++] = character;
        }
    }
    return [[NSString alloc] initWithBytesNoCopy:buffer length:length encoding:NSUTF8StringEncoding freeWhenDone:YES];
}

@implementation IJSVGImage

- (IJSVGNodeTypeTraits)nodeTraits
{
    return IJSVGNodeTypeTraitPaint | IJSVGNodeTypeTraitGraphics | IJSVGNodeTypeTraitViewport | IJSVGNodeTypeTraitImage;
}

- (void)applyPropertiesFromNode:(IJSVGImage*)node
{
    [super applyPropertiesFromNode:node];
    self.reference = node.reference;
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeImage;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGImage* node = [super copyWithZone:zone];

    // Preserve the cached state without invoking setCGImage:,
    // which clears export metadata.
    node->_embeddedSVG = _embeddedSVG;
    node->_intrinsicSize = _intrinsicSize;
    node->_sourceData = [_sourceData copy];
    node->_sourceMIMEType = [_sourceMIMEType copy];

    // Each node owns a reference to the shared pixels.
    node->CGImage = CGImage != NULL ? CGImageRetain(CGImage) : NULL;
    return node;
}

- (void)dealloc
{
    if (CGImage != NULL) {
        CGImageRelease(CGImage);
        CGImage = NULL;
    }
}

- (void)setDefaults
{
    [super setDefaults];
    self.viewBoxAlignment = IJSVGViewBoxAlignmentXMidYMid;
    self.viewBoxMeetOrSlice = IJSVGViewBoxMeetOrSliceMeet;
    self.overflowVisibility = IJSVGOverflowVisibilityHidden;
}

- (void)loadFromString:(NSString*)encodedString
{
    if ([encodedString hasPrefix:@"data:"]) {
        encodedString = IJSVGImageURLWithoutWhitespace(encodedString);
    }
    NSURL* url = encodedString != nil ? [NSURL URLWithString:encodedString] : nil;
    if (url != nil) {
        [self loadFromURL:url];
    }
}

/// Loads declared SVG images directly and decodes recognized bitmap formats.
- (void)loadFromURL:(NSURL*)aURL
{
    BOOL dataURL = [aURL.scheme.lowercaseString isEqualToString:@"data"];
    if (IJSVGEmbeddedImageDepth >= 64 || (IJSVGEmbeddedImageDepth != 0 && !dataURL)) {
        return;
    }

    // If we are not a data URL, lets check what its trying to reach is actually
    // reachable, if not, just return as cant load it.
    if (!dataURL && ![aURL checkResourceIsReachableAndReturnError:nil]) {
#if DEBUG
        NSLog(@"<%@> references: \"%@\", which cannot be reached.", NSStringFromClass(self.class), aURL);
#endif
        return;
    }

    // Convert to data, if its nil, just return, nothing more can do.
    NSData* data = [NSData dataWithContentsOfURL:aURL];
    if (data == nil) {
        return;
    }

    NSString* mimeType = [IJSVGUtils MIMETypeForImageData:data sourceURL:aURL];
    BOOL declaredSVG = [mimeType.lowercaseString isEqualToString:@"image/svg+xml"];
    CGImageSourceRef source = declaredSVG ? NULL : CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    CGImageRef pixels = NULL;
    if (source != NULL && CGImageSourceGetType(source) != NULL) {
        NSDictionary* properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
        NSInteger orientation = [properties[(__bridge NSString*)kCGImagePropertyOrientation] integerValue];
        if (orientation > 1) {
            // Bake EXIF orientation into pixels without reducing the source resolution.
            NSNumber* width = properties[(__bridge NSString*)kCGImagePropertyPixelWidth];
            NSNumber* height = properties[(__bridge NSString*)kCGImagePropertyPixelHeight];
            NSDictionary* options = @{
                (__bridge NSString*)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                (__bridge NSString*)kCGImageSourceCreateThumbnailWithTransform : @YES,
                (__bridge NSString*)kCGImageSourceThumbnailMaxPixelSize : @(MAX(width.unsignedIntegerValue, height.unsignedIntegerValue))
            };
            pixels = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
        } else {
            pixels = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        }
    }
    if (source != NULL) {
        CFRelease(source);
    }
    if (pixels != NULL) {
        self.CGImage = pixels;
        CGImageRelease(pixels);
    } else {
        IJSVG* svg = nil;
        IJSVGEmbeddedImageDepth++;
        @try {
            svg = [[IJSVG alloc] initWithSVGData:data];
        } @finally {
            IJSVGEmbeddedImageDepth--;
        }
        if (svg == nil) {
            return;
        }
        self.CGImage = NULL;
        _embeddedSVG = svg;
        _intrinsicSize = svg.size;
        mimeType = @"image/svg+xml";
    }
    _sourceData = [data copy];
    _sourceMIMEType = [mimeType copy];
}

- (void)setCGImage:(CGImageRef)image
{
    // Retain first so assigning the current image is safe.
    CGImageRef retained = image != NULL ? CGImageRetain(image) : NULL;
    CGImageRelease(CGImage);
    CGImage = retained;
    _sourceData = nil;
    _sourceMIMEType = nil;
    _embeddedSVG = nil;
    _intrinsicSize = image != NULL ? CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image)) : CGSizeZero;
}

- (CGImageRef)CGImage
{
    return CGImage;
}

- (CGRect)intrinsicBounds
{
    CGRect rect = CGRectZero;
    rect.size.width = _intrinsicSize.width;
    rect.size.height = _intrinsicSize.height;
    return rect;
}

- (CGRect)bounds
{
    return CGRectMake(0.f, 0.f, self.width.value, self.height.value);
}

@end

#pragma mark - Parsing

@implementation IJSVGImage (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGGraphicsAttributes();
    [attributes setBit:IJSVGNodeAttributeX];
    [attributes setBit:IJSVGNodeAttributeY];
    [attributes setBit:IJSVGNodeAttributeWidth];
    [attributes setBit:IJSVGNodeAttributeHeight];
    [attributes setBit:IJSVGNodeAttributeHref];
    [attributes setBit:IJSVGNodeAttributeXLink];
    [attributes setBit:IJSVGNodeAttributePreserveAspectRatio];
    [attributes setBit:IJSVGNodeAttributeOverflow];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    self.reference = context->reference;
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
    IJSVGUnitLength* geometryLength = nil;
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeX, &geometryLength)) {
        self.x = geometryLength;
    }
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeY, &geometryLength)) {
        self.y = geometryLength;
    }
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeWidth, &geometryLength)) {
        self.width = geometryLength;
    }
    if (IJSVGReadGeometryLength(self, context, IJSVGNodeAttributeHeight, &geometryLength)) {
        self.height = geometryLength;
    }
    IJSVGParseBackgroundAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    IJSVGParsePaintAttributes(self, context);
    IJSVGParseEffectsAttributes(self, context);
    IJSVGParseTransformAttributes(self, context);
    IJSVGParseDisplayAttributes(self, context);
    IJSVGParseViewportAttributes(self, context);
}

@end
