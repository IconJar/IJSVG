//
//  IJSVGStyle.h
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <Foundation/Foundation.h>

@interface IJSVGStyleSheetStyle : NSObject {

@private
    NSMutableDictionary* _dict;
}

+ (IJSVGStyleSheetStyle*)parseStyleString:(NSString*)string;

- (void)setPropertyValue:(id)value
             forProperty:(NSString*)key;
- (id)property:(NSString*)key;

- (IJSVGStyleSheetStyle*)mergedStyle:(IJSVGStyleSheetStyle*)style;

@end
