//
//  IJSVGTestSupport.h
//  IJSVG
//
//  Created by Curtis Hard on 03/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

// Exercise the same resource lookup used by the filter renderer.
FOUNDATION_EXPORT NSString* _Nullable IJSVGPackageShaderSource(NSString* _Nonnull name);

@class IJSVG;
FOUNDATION_EXPORT IJSVG* _Nonnull IJSVGWithPDFError(void);
