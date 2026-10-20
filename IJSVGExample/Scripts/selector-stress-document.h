//
//  selector stress document.h
//  IJSVGExample
//
//  Created by Curtis Hard on 15/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

// Shared by the Objective C regression test and standalone Release benchmark.
// Deterministic inputs make browser comparisons and timing runs reproducible.
static NSString* IJSVGSelectorStressDocument(NSUInteger groups, NSUInteger siblings)
{
    NSMutableString* source = [[NSMutableString alloc] initWithString:
            @"<svg xmlns='http://www.w3.org/2000/svg' xmlns:v='http://www.w3.org/2000/svg' xmlns:m='urn:selector-metadata' xmlns:q='urn:selector-other' width='1000' height='1000' xml:lang='en-GB' data-theme='Light'><style>"
             "@namespace s 'http://www.w3.org/2000/svg'; @namespace meta 'urn:selector-metadata';"
             "* { stroke-width: 0; fill: #456789 }"
             "s|rect[data-state] { stroke-width: 1 }"
             "s|circle[data-state='READY' i] { stroke-width: 2 }"
             "[data-tags~='selected'] { stroke-width: 3 }"
             "[data-code|='en'] { stroke-width: 4 }"
             "[data-label^='Alpha'] { stroke-width: 5 }"
             "[data-label$='beta'] { stroke-width: 6 }"
             "[data-label*='PH' i] { stroke-width: 7 }"
             "[meta|role='primary'] { stroke-width: 8 }"
             "[*|role='secondary']:nth-child(3n) { stroke-width: 9 }"
             "s|g[data-depth='2'] > :is(rect,circle)[data-state] { stroke-width: 10 }"
             "[data-theme='Light'] g[data-band='even'] :where(rect,circle):not([data-empty]) { stroke-width: 11 }"
             "rect:nth-child(3n+1 of [data-state='ready' i]) { stroke-width: 12 }"
             "circle:nth-last-child(2n of :is([data-state],[meta|role])) { stroke-width: 13 }"
             "rect:has(+ circle[data-tags~='selected']) { stroke-width: 14 }"
             "g:has(> [meta|role='primary']) > rect:last-of-type { stroke-width: 15 }"
             "g[data-band='odd'] > g > rect:nth-of-type(5n) { stroke-width: 16 }"
             "rect:lang(fr) { stroke-width: 17 }"
             "circle:lang(en) { stroke-width: 18 }"
             "rect:lang(de):not([data-state]) { stroke-width: 19 }"
             "[data-empty='']:nth-last-of-type(7n) { stroke-width: 20 }"
             "rect:empty[data-code='en-US'] { stroke-width: 21 }"
             "rect:not(:empty)[data-state] { stroke-width: 22 }"
             "[data-label='a,b){}']:is(:first-child,:last-child) { stroke-width: 23 }"
             "</style>\n"];
    NSArray* languages = @[ @"en-US", @"fr-CA", @"de-Latn-DE", @"" ];
    NSArray* labels = @[ @"Alpha beta", @"alpha-BETA", @"a,b){}", @"Älpha", @"", @"omega" ];
    for (NSUInteger group = 0; group < groups; group++) {
        NSUInteger depth = group % 6 + 1;
        for (NSUInteger level = 0; level < depth; level++) {
            [source appendFormat:@"<g data-depth='%lu' data-band='%@' data-group='%lu' xml:lang='%@' m:role='%@'>\n", level, group % 2 == 0 ? @"even" : @"odd", group, languages[(group + level) % languages.count], level % 2 == 0 ? @"container" : @"primary"];
        }
        for (NSUInteger index = 0; index < siblings; index++) {
            NSUInteger number = group * siblings + index;
            BOOL circle = number % 5 == 4;
            NSString* tag = circle ? @"circle" : (number % 7 == 0 ? @"v:rect" : @"rect");
            [source appendFormat:@"<%@ id='n%lu' class='shape %@' %@ data-label='%@' data-code='%@' data-tags='%@' m:role='%@' q:role='%@'", tag, number, number % 3 == 0 ? @"chosen" : @"plain", circle ? @"cx='1' cy='1' r='1'" : @"x='1' y='1' width='1' height='1'", labels[number % labels.count], number % 3 == 0 ? @"en-US" : @"fr", number % 4 == 0 ? @"active&#9;selected&#10;shape" : @"shape plain", number % 11 == 0 ? @"primary" : @"secondary", number % 13 == 0 ? @"secondary" : @"other"];
            if (number % 3 != 0) {
                [source appendFormat:@" data-state='%@'", number % 2 == 0 ? @"ready" : @"READY"];
            }
            if (number % 4 == 0) {
                [source appendString:@" data-empty=''"];
            }
            if (number % 17 == 0) {
                [source appendFormat:@" xml:lang='%@'", languages[number % languages.count]];
            }
            if (number % 19 == 0) {
                [source appendFormat:@"> \n </%@>", tag];
            } else {
                [source appendString:@"/>"];
            }
            if (index % 31 == 0) {
                [source appendString:@"<!--not an element--><?selector-test ignored?>"];
            }
            [source appendString:@"\n"];
        }
        for (NSUInteger level = 0; level < depth; level++) {
            [source appendString:@"</g>\n"];
        }
    }
    [source appendString:@"</svg>"];
    return source;
}
