//
//  IJSVGSwitch.h
//  IJSVG
//
//  Created by Curtis Hard on 10/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGSwitch : IJSVGGroup

// Select before parsing: display/visibility do not choose a later branch.
+ (NSXMLElement* _Nullable)selectedChildInElement:(NSXMLElement*)element preferredLanguages:(NSArray<NSString*>*)preferredLanguages;

@end

NS_ASSUME_NONNULL_END
