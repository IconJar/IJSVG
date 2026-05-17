//
//  IJSVGXML.h
//  IJSVG
//

#import <TargetConditionals.h>

#if TARGET_OS_IOS

#import <IJSVG/IJSVGiOSXML.h>

typedef IJSVGiOSXMLNode IJSVGXMLNode;
typedef IJSVGiOSXMLElement IJSVGXMLElement;
typedef IJSVGiOSXMLDocument IJSVGXMLDocument;

#endif
