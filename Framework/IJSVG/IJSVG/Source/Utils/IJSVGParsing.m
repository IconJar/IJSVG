//
//  IJSVGParsing.m
//  IJSVG
//
//  Created by Curtis Hard on 04/02/2021.
//  Copyright © 2021 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGParsing.h>
#import <IJSVG/IJSVGUtils.h>

IJSVGParsingStringMethod* IJSVGParsingStringMethodCreate(void)
{
    IJSVGParsingStringMethod* method = (IJSVGParsingStringMethod*)malloc(sizeof(IJSVGParsingStringMethod));
    method->name = NULL;
    method->parameters = NULL;
    return method;
}

void IJSVGParsingStringMethodRelease(IJSVGParsingStringMethod* stringMethod)
{
    if(stringMethod->name != NULL) {
        (void)free(stringMethod->name), stringMethod->name = NULL;
    }
    if(stringMethod->parameters != NULL) {
        (void)free(stringMethod->parameters), stringMethod->parameters = NULL;
    }
    if(stringMethod != NULL) {
        (void)free(stringMethod), stringMethod = NULL;
    }
}

void IJSVGParsingStringMethodsRelease(IJSVGParsingStringMethod** methods,
                                      NSUInteger count)
{
    for(int i = 0; i < count; i++) {
        IJSVGParsingStringMethodRelease(methods[i]);
    }
    (void)free(methods), methods = NULL;
}

IJSVGParsingStringMethod** IJSVGParsingMethodParseString(const char* string,
                                                         NSUInteger* count)
{
    BOOL valid;
    return IJSVGParsingMethodParseStringWithValidation(string, count, &valid);
}

IJSVGParsingStringMethod** IJSVGParsingMethodParseStringWithValidation(const char* string,
                                                                       NSUInteger* count,
                                                                       BOOL* valid)
{
    *valid = YES;
    *count = 0;
    if(string == NULL) {
        *valid = NO;
        return NULL;
    }
    const char* charString = string;
    unsigned long length = strlen(string);
    char* buffer = (char*)calloc(sizeof(char), length + 1);
    char* originBuffer = buffer;
    int bufferIndex = 0;
    char quote = 0;
    BOOL escaped = NO;
    
    const size_t defBufferSize = 5;
    size_t currentBufferSize = defBufferSize;
    NSUInteger methodCount = 0;
    
    IJSVGParsingStringMethod* method = NULL;
    IJSVGParsingStringMethod** methods = NULL;
    methods = (IJSVGParsingStringMethod**)malloc(sizeof(IJSVGParsingStringMethod*)*currentBufferSize);
    
    // each command requires a name and parameters, store for later use
    for(int i = 0; i < length; i++) {
        char currentChar = *charString++;
        
        // Quoted parameters can contain parentheses without ending the method.
        if(quote != 0) {
            *buffer++ = currentChar;
            bufferIndex++;
            if(escaped) {
                escaped = NO;
            } else if(currentChar == '\\') {
                escaped = YES;
            } else if(currentChar == quote) {
                quote = 0;
            }
            continue;
        }
        if(method != NULL && (currentChar == '\'' || currentChar == '"')) {
            quote = currentChar;
            *buffer++ = currentChar;
            bufferIndex++;
            continue;
        }

        // Start parameters and retain the method name.
        if(currentChar == '(') {
            if(method != NULL) {
                *valid = NO;
            }
            // Reset the pointer to the beginning.
            buffer = originBuffer;
            
            //write here
            if(method == NULL) {
                method = IJSVGParsingStringMethodCreate();
                method->name = (char*)calloc(sizeof(char),bufferIndex+1);
                memcpy(method->name, buffer, sizeof(char)*bufferIndex);
                if(bufferIndex != 0) {
                    IJSVGTrimCharBuffer(method->name);
                }
                if(method->name[0] == '\0') {
                    *valid = NO;
                }
            }
            
            // write null up until the limit we reached
            memset(buffer, '\0', bufferIndex);
            bufferIndex = 0;
            continue;
        }
        
        // end of params, store the params into the buffer
        if(currentChar == ')') {
            // rest the pointer to beginning
            buffer = originBuffer;
        
            // there has to be a method at this point, if not, something is wrong
            // in the syntax
            if(method != NULL) {
                method->parameters = (char*)calloc(sizeof(char),bufferIndex+1);
                memcpy(method->parameters, buffer, sizeof(char)*bufferIndex);
                if(bufferIndex != 0) {
                    IJSVGTrimCharBuffer(method->parameters);
                }
                
                // now we can add
                if(methodCount + 1 > currentBufferSize) {
                    currentBufferSize += defBufferSize;
                    methods = (IJSVGParsingStringMethod**)realloc(methods, sizeof(IJSVGParsingStringMethod*)*currentBufferSize);
                }
                methods[methodCount++] = method;
                method = NULL;
            } else {
                *valid = NO;
            }
            
            // write null up until the limit we reached
            memset(buffer, '\0', bufferIndex);
            bufferIndex = 0;
            continue;
        }
        
        // increment the buffer count
        *buffer++ = currentChar;
        bufferIndex++;
    }
    
    // left over
    if(method != NULL) {
        *valid = NO;
        (void)IJSVGParsingStringMethodRelease(method), method = NULL;
    }
    
    for(int i = 0; i < bufferIndex; i++) {
        if(isspace((unsigned char)originBuffer[i]) == 0) {
            *valid = NO;
            break;
        }
    }
    buffer = originBuffer;
    *count = methodCount;
    (void)free(buffer), buffer = NULL;
    return methods;
}

@implementation IJSVGParsing

@end
