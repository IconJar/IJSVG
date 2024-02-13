//
//  NSString+macOS.h
//  IconJar
//
//  Created by François Lamboley on 2024/02/13.
//
//

#if __has_include(<UIKit/UIKit.h>)

@import Foundation;

inline NSString *NSStringFromRect(CGRect rect) {
    return [NSString stringWithFormat:@"{%f, %f, %f, %f}", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

#endif
