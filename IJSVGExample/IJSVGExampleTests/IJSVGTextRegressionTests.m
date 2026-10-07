//
//  IJSVGTextRegressionTests.m
//  IJSVGExampleTests
//
//  Created on 07/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGCSSFontParserChecks.h"
#import <CoreText/CoreText.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGTextLayout.h>
#import <IJSVG/IJSVGStyleSheetSelectorRaw.h>

@interface IJSVGTextRegressionContext : NSObject

@property (nonatomic, strong) NSMutableArray<NSString*>* failures;
@property (nonatomic, strong) IJSVGRootNode* root;

@end

@implementation IJSVGTextRegressionContext

- (id)init
{
    if((self = [super init]) != nil) {
        _failures = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)require:(BOOL)condition
         message:(NSString*)message
{
    if(!condition) {
        [NSException raise:@"IJSVGRegressionFailure"
                    format:@"%@", message];
    }
}

- (void)check:(BOOL)condition
       message:(NSString*)message
{
    if(!condition) {
        [self.failures addObject:message];
    }
}

- (IJSVGTextLayout*)layout:(NSString*)body
{
    NSString* xml = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 400 200'>%@</svg>", body];
    NSError* error = nil;
    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml
                                                     fileURL:nil
                                                       error:&error];
    [self require:parser != nil
           message:error.description ?: @"Could not parse SVG"];
    self.root = [parser rootNodeWithSize:CGSizeMake(400, 200)];
    __block IJSVGText* text = nil;
    [IJSVGNode walkNodeTree:self.root
                   handler:^(IJSVGNode* node, BOOL* descend, BOOL* stop) {
        if([node isKindOfClass:IJSVGText.class]) {
            text = (IJSVGText*)node;
            *stop = YES;
        }
    }];
    [self require:text != nil
           message:@"Missing text node"];
    return [[IJSVGTextLayout alloc] initWithText:text
                                      viewport:CGSizeMake(400, 200)
                                  pathResolver:nil];
}

- (NSData*)pixels:(NSString*)body
{
    NSString* xml = [NSString stringWithFormat:
        @"<svg xmlns='http://www.w3.org/2000/svg' width='400' height='200'>%@</svg>", body];
    IJSVG* svg = [[IJSVG alloc] initWithSVGString:xml];
    [self require:svg != nil message:@"Could not parse render fixture"];
    svg.renderingBackingScaleHelper = ^CGFloat { return 1; };
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, 400, 200, 8, 1600, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    [self require:bitmap != NULL message:@"Could not create render bitmap"];
    CGContextSetRGBFillColor(bitmap, 1, 1, 1, 1);
    CGContextFillRect(bitmap, CGRectMake(0, 0, 400, 200));
    CGContextTranslateCTM(bitmap, 0, 200);
    CGContextScaleCTM(bitmap, 1, -1);
    [svg drawInRect:CGRectMake(0, 0, 400, 200) context:bitmap];
    NSData* pixels = [NSData dataWithBytes:CGBitmapContextGetData(bitmap)
                                    length:1600 * 200];
    CGContextRelease(bitmap);
    return pixels;
}

- (CGPoint)point:(NSUInteger)index
           layout:(IJSVGTextLayout*)layout
{
    [self require:index < layout.characterPositions.count
           message:@"Missing character position"];
    return layout.characterPositions[index].pointValue;
}

- (CGPathRef)decoration:(IJSVGTextLayout*)layout
{
    IJSVGPath* path = (IJSVGPath*)layout.group.children.lastObject;
    [self require:[path isKindOfClass:IJSVGPath.class] && path.path != NULL
           message:@"Missing decoration geometry"];
    return path.path;
}

- (void)compare:(IJSVGTextLayout*)actual
       reference:(IJSVGTextLayout*)reference
{
    [self check:[actual.characterPositions isEqualToArray:reference.characterPositions]
         message:@"Character positions differ"];
    [self check:CGRectEqualToRect(actual.group.bounds, reference.group.bounds)
         message:@"Geometry bounds differ"];
}

@end

#define IJSVGCheck(condition) [context check:(condition) message:@#condition]
#define IJSVGNear(actual, expected) IJSVGCheck(fabs((actual) - (expected)) < .001)

static void IJSVGAppendRegressionOutline(CGMutablePathRef destination, IJSVGGroup* group)
{
    for(IJSVGNode* child in group.children) {
        if([child isKindOfClass:IJSVGPath.class]) {
            CGPathRef path = ((IJSVGPath*)child).path;
            if(path != NULL) {
                CGPathAddPath(destination, NULL, path);
            }
        } else if([child isKindOfClass:IJSVGGroup.class]) {
            IJSVGAppendRegressionOutline(destination, (IJSVGGroup*)child);
        }
    }
}

static NSArray<NSNumber*>* IJSVGRegressionLines(IJSVGTextLayout* layout)
{
    NSMutableSet<NSNumber*>* lines = [[NSMutableSet alloc] init];
    for(NSValue* value in layout.characterPositions) {
        [lines addObject:@(value.pointValue.y)];
    }
    return [lines.allObjects sortedArrayUsingSelector:@selector(compare:)];
}

typedef void (^IJSVGTextRegressionCase)(IJSVGTextRegressionContext* context);

static NSDictionary<NSString*, IJSVGTextRegressionCase>* IJSVGTextRegressionCases(void)
{
    static NSDictionary<NSString*, IJSVGTextRegressionCase>* cases;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary<NSString*, IJSVGTextRegressionCase>* entries = [[NSMutableDictionary alloc] init];
        for(NSString* decoration in @[ @"underline", @"overline", @"line-through" ]) {
            entries[[@"decorationsIncludeSpaces/" stringByAppendingString:decoration]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* result = [context layout:[NSString stringWithFormat:
                    @"<text font-family='Helvetica' font-size='30' y='60' text-decoration='%@'>A B</text>", decoration]];
                CGPathRef geometry = [context decoration:result];
                CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), 30, NULL);
                CGFloat offset = [decoration isEqual:@"underline"] ? CTFontGetUnderlinePosition(font) :
                    ([decoration isEqual:@"overline"] ? CTFontGetAscent(font) : CTFontGetXHeight(font) * .5);
                CGFloat thickness = MAX(.5, CTFontGetUnderlineThickness(font));
                CFRelease(font);
                CGPoint a = [context point:1 layout:result];
                CGPoint b = [context point:2 layout:result];
                CGPoint point = CGPointMake((a.x + b.x) * .5, 60 - offset - thickness * .5);
                IJSVGCheck(CGPathContainsPoint(geometry, NULL, point, NO));
            };
            entries[[@"combiningClustersHaveOneDecoration/" stringByAppendingString:decoration]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* result = [context layout:[NSString stringWithFormat:
                    @"<text font-family='Helvetica' font-size='40' text-decoration='%@'>x&#x301;&#x323;</text>", decoration]];
                IJSVGCheck(result.glyphCount > 1);
                CGPathRef geometry = [context decoration:result];
                __block NSUInteger rectangles = 0;
                CGPathApplyWithBlock(geometry, ^(const CGPathElement* element) {
                    if(element->type == kCGPathElementCloseSubpath) {
                        rectangles++;
                    }
                });
                IJSVGCheck(rectangles == 1);
                IJSVGNear(CGRectGetMinX(CGPathGetPathBoundingBox(geometry)), 0);
                IJSVGNear(CGRectGetWidth(CGPathGetPathBoundingBox(geometry)), result.advance);
            };
        }

        NSArray* capitals = @[
            @[ @"hel<tspan>lo</tspan>", @"Hello" ],
            @[ @"hELLO <tspan>wORLD</tspan>", @"HELLO WORLD" ],
            @[ @"he<![CDATA[llo]]> world", @"Hello World" ],
            @[ @"<tspan style='text-transform:none'>hel</tspan>lo", @"hello" ],
            @[ @"one <tspan>two</tspan> three", @"One Two Three" ]
        ];
        for(NSArray* fixture in capitals) {
            entries[[@"capitalizationPreservesWordBoundaries/" stringByAppendingString:fixture[0]]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* result = [context layout:[NSString stringWithFormat:
                    @"<text style='text-transform:capitalize'>%@</text>", fixture[0]]];
                IJSVGCheck([result.string isEqual:fixture[1]]);
            };
        }
        for(NSArray* fixture in @[ @[ @"150%", @30 ], @[ @"1.5em", @30 ], @[ @"1.5", @60 ] ]) {
            entries[[@"lineHeightInheritsComputedLengths/" stringByAppendingString:fixture[0]]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* result = [context layout:[NSString stringWithFormat:
                    @"<g font-size='20' style='line-height:%@'><text font-size='40' style='white-space:pre'>A\nB</text></g>", fixture[0]]];
                IJSVGNear([context point:2 layout:result].y - [context point:0 layout:result].y, [fixture[1] doubleValue]);
            };
        }
        for(NSArray* fixture in @[ @[ @20, @70, @2 ], @[ @(-10), @55, @1 ] ]) {
            entries[[NSString stringWithFormat:@"wordSpacingParticipatesInWrapping/%@", fixture[0]]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* result = [context layout:[NSString stringWithFormat:
                    @"<text font-family='Courier' font-size='20' style='inline-size:%@;word-spacing:%@'>AA BB</text>", fixture[1], fixture[0]]];
                IJSVGCheck(IJSVGRegressionLines(result).count == [fixture[2] unsignedIntegerValue]);
            };
        }
        entries[@"wordSpacingIsAppliedOnce"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGTextLayout* plain = [context layout:@"<text font-family='Courier' font-size='20'>A B</text>"];
            IJSVGTextLayout* spaced = [context layout:@"<text font-family='Courier' font-size='20' letter-spacing='2' word-spacing='15'>A B</text>"];
            IJSVGTextLayout* letter = [context layout:@"<text font-family='Courier' font-size='20' letter-spacing='2'>A B</text>"];
            IJSVGNear([context point:2 layout:spaced].x - [context point:2 layout:letter].x, 15);
            IJSVGNear([context point:2 layout:letter].x - [context point:2 layout:plain].x, 4);
        };
        for(NSNumber* degrees in @[ @0, @35, @90 ]) {
            entries[[NSString stringWithFormat:@"combiningMarksFollowClusterTransforms/%@", degrees]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* plain = [context layout:@"<text font-family='Helvetica' font-size='40'>x&#x301;&#x323;</text>"];
                IJSVGCheck(plain.glyphCount > 1);
                IJSVGTextLayout* adjusted = [context layout:[NSString stringWithFormat:
                    @"<text font-family='Helvetica' font-size='40' rotate='%@' textLength='%.17g' lengthAdjust='spacingAndGlyphs'>x&#x301;&#x323;</text>",
                    degrees, plain.advance * 2]];
                CGMutablePathRef original = CGPathCreateMutable();
                CGMutablePathRef actual = CGPathCreateMutable();
                IJSVGAppendRegressionOutline(original, plain.group);
                IJSVGAppendRegressionOutline(actual, adjusted.group);
                CGAffineTransform transform = CGAffineTransformScale(CGAffineTransformMakeRotation(degrees.doubleValue * M_PI / 180), 2, 1);
                CGPathRef expected = CGPathCreateCopyByTransformingPath(original, &transform);
                CGRect a = CGPathGetPathBoundingBox(actual);
                CGRect b = CGPathGetPathBoundingBox(expected);
                CGPathRelease(original);
                CGPathRelease(actual);
                CGPathRelease(expected);
                IJSVGNear(CGRectGetMinX(a), CGRectGetMinX(b));
                IJSVGNear(CGRectGetMinY(a), CGRectGetMinY(b));
                IJSVGNear(CGRectGetMaxX(a), CGRectGetMaxX(b));
                IJSVGNear(CGRectGetMaxY(a), CGRectGetMaxY(b));
            };
        }

        NSArray* shorthands = @[
            @[ @"medium Helvetica", @"font-size:medium;font-family:Helvetica" ],
            @[ @"+2e1PX / +1.25 Helvetica", @"font-size:20px;line-height:1.25;font-family:Helvetica" ],
            @[ @"1.25em / 2ex Helvetica", @"font-size:1.25em;line-height:2ex;font-family:Helvetica" ],
            @[ @".75em Helvetica", @"font-size:.75em;font-family:Helvetica" ],
            @[ @"20px &quot;不存在&quot;, Helvetica", @"font-size:20px;font-family:&quot;不存在&quot;, Helvetica" ],
            @[ @"20.5px / 1.25 Helvetica", @"font-size:20.5px;line-height:1.25;font-family:Helvetica" ],
            @[ @"italic 20px / 1.5 Helvetica", @"font-style:italic;font-size:20px;line-height:1.5;font-family:Helvetica" ],
            @[ @"20px/ 1.5 Helvetica", @"font-size:20px;line-height:1.5;font-family:Helvetica" ],
            @[ @"20px /1.5 Helvetica", @"font-size:20px;line-height:1.5;font-family:Helvetica" ],
            @[ @"600 20px/30px Helvetica", @"font-weight:600;font-size:20px;line-height:30px;font-family:Helvetica" ],
            @[ @"small-caps bold larger Helvetica", @"font-variant:small-caps;font-weight:bold;font-size:larger;font-family:Helvetica" ],
            @[ @"20px &quot;Helvetica Neue&quot;", @"font-size:20px;font-family:&quot;Helvetica Neue&quot;" ]
        ];
        for(NSArray* fixture in shorthands) {
            entries[[@"fontShorthandMatchesLonghands/" stringByAppendingString:fixture[0]]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* actual = [context layout:[NSString stringWithFormat:@"<text style='white-space:pre;font:%@'>Abc\nDef</text>", fixture[0]]];
                IJSVGTextLayout* expected = [context layout:[NSString stringWithFormat:@"<text style='white-space:pre;%@'>Abc\nDef</text>", fixture[1]]];
                [context compare:actual reference:expected];
            };
        }
        NSArray* declarations = @[
            @[ @"font-weight:bold;font:20px Helvetica", @"font-size:20px;font-family:Helvetica" ],
            @[ @"FONT-WEIGHT:bold;FONT:20px Helvetica", @"font-size:20px;font-family:Helvetica" ],
            @[ @"font:20px Helvetica;font-weight:bold", @"font-size:20px;font-family:Helvetica;font-weight:bold" ],
            @[ @"font:italic 30px Helvetica;font:bold", @"font-style:italic;font-size:30px;font-family:Helvetica" ],
            @[ @"font:italic 30px Helvetica;font:20px", @"font-style:italic;font-size:30px;font-family:Helvetica" ],
            @[ @"font:italic 30px Helvetica;font:20px / Helvetica", @"font-style:italic;font-size:30px;font-family:Helvetica" ],
            @[ @"font:italic 30px Helvetica;font:italic italic 20px Helvetica", @"font-style:italic;font-size:30px;font-family:Helvetica" ]
        ];
        for(NSArray* fixture in declarations) {
            entries[[@"fontDeclarationsRespectOrderAndValidity/" stringByAppendingString:fixture[0]]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* expected = [context layout:[NSString stringWithFormat:@"<text style='%@'>Text</text>", fixture[1]]];
                for(NSString* body in @[
                    [NSString stringWithFormat:@"<text style='%@'>Text</text>", fixture[0]],
                    [NSString stringWithFormat:@"<style>text { %@ }</style><text>Text</text>", fixture[0]]
                ]) {
                    [context compare:[context layout:body] reference:expected];
                }
            };
        }
        for(NSString* value in @[ @"", @"+", @".", @"20.", @"20e", @"20e+", @"20e999px", @"-20px",
                                  @"20p", @"20pxt", @"20a%", @"20px/", @"20px / +", @"20px / 1e+" ]) {
            entries[[@"malformedFontNumbersPreserveEarlierDeclarations/" stringByAppendingString:value]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* actual = [context layout:[NSString stringWithFormat:
                    @"<text style='font:italic 30px Helvetica;font:%@ Helvetica'>Text</text>", value]];
                IJSVGTextLayout* expected = [context layout:@"<text style='font:italic 30px Helvetica'>Text</text>"];
                [context compare:actual reference:expected];
            };
        }
        entries[@"fontShorthandResetsInheritedLineHeight"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGTextLayout* actual = [context layout:@"<g style='font-style:italic;font-weight:bold;line-height:3'><text style='white-space:pre;font:20px Helvetica'>Abc\nDef</text></g>"];
            IJSVGTextLayout* expected = [context layout:@"<text style='white-space:pre;font-size:20px;font-family:Helvetica'>Abc\nDef</text>"];
            [context compare:actual reference:expected];
        };
        entries[@"explicitLinesResetHeight"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGTextLayout* result = [context layout:@"<text font-size='20' style='white-space:pre;line-height:1'><tspan font-size='40'>A</tspan>\nB\nC</text>"];
            IJSVGNear([context point:2 layout:result].y - [context point:0 layout:result].y, 40);
            IJSVGNear([context point:4 layout:result].y - [context point:2 layout:result].y, 20);
        };
        entries[@"wrappedLinesResetHeight"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGTextLayout* result = [context layout:@"<text font-family='Helvetica' font-size='20' style='inline-size:60;line-height:1'><tspan font-size='40'>AA </tspan>BB CC DD EE</text>"];
            NSArray<NSNumber*>* lines = IJSVGRegressionLines(result);
            [context require:lines.count >= 3 message:@"Expected at least three lines"];
            IJSVGNear(lines[1].doubleValue - lines[0].doubleValue, 40);
            IJSVGNear(lines[2].doubleValue - lines[1].doubleValue, 20);
        };
        for(NSString* mode in @[ @"vertical-lr", @"vertical-rl" ]) {
            entries[[@"explicitVerticalLinesFollowWritingMode/" stringByAppendingString:mode]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* result = [context layout:[NSString stringWithFormat:@"<text font-size='20' writing-mode='%@' style='white-space:pre;line-height:1'>日\n本\n語</text>", mode]];
                CGFloat step = [mode isEqual:@"vertical-lr"] ? 20 : -20;
                IJSVGNear([context point:2 layout:result].x - [context point:0 layout:result].x, step);
                IJSVGNear([context point:4 layout:result].x - [context point:2 layout:result].x, step);
            };
        }
        for(NSArray* fixture in @[ @[ @300, @"bolder", @400 ], @[ @400, @"bolder", @700 ],
                                  @[ @700, @"bolder", @900 ], @[ @900, @"lighter", @700 ],
                                  @[ @700, @"lighter", @400 ], @[ @400, @"lighter", @100 ] ]) {
            entries[[NSString stringWithFormat:@"relativeWeightsResolveAgainstParent/%@/%@", fixture[0], fixture[1]]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* actual = [context layout:[NSString stringWithFormat:@"<text font-family='Helvetica Neue' font-size='40' font-weight='%@'><tspan font-weight='%@'><tspan>Weight</tspan></tspan></text>", fixture[0], fixture[1]]];
                IJSVGTextLayout* expected = [context layout:[NSString stringWithFormat:@"<text font-family='Helvetica Neue' font-size='40' font-weight='%@'>Weight</text>", fixture[2]]];
                IJSVGNear(actual.group.bounds.size.width, expected.group.bounds.size.width);
                IJSVGNear(actual.group.bounds.size.height, expected.group.bounds.size.height);
                IJSVGCheck([actual.characterPositions isEqualToArray:expected.characterPositions]);
            };
        }
        entries[@"numericWeightsSelectDistinctFaces"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGTextLayout* light = [context layout:@"<text font-family='Helvetica Neue' font-size='40' font-weight='300'>Weight</text>"];
            IJSVGTextLayout* regular = [context layout:@"<text font-family='Helvetica Neue' font-size='40' font-weight='400'>Weight</text>"];
            IJSVGTextLayout* medium = [context layout:@"<text font-family='Helvetica Neue' font-size='40' font-weight='500'>Weight</text>"];
            IJSVGCheck(!CGRectEqualToRect(light.group.bounds, regular.group.bounds));
            IJSVGCheck(!CGRectEqualToRect(medium.group.bounds, regular.group.bounds));
        };
        for(NSArray* fixture in @[ @[ @"embed", @"\u202B", @"\u202C" ],
                                  @[ @"bidi-override", @"\u202E", @"\u202C" ],
                                  @[ @"isolate", @"\u2067", @"\u2069" ],
                                  @[ @"isolate-override", @"\u2068\u202E", @"\u202C\u2069" ],
                                  @[ @"plaintext", @"\u2068", @"\u2069" ] ]) {
            entries[[@"bidiScopesMatchUnicodeControls/" stringByAppendingString:fixture[0]]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* actual = [context layout:[NSString stringWithFormat:@"<text font-family='Helvetica' font-size='24'>A<tspan direction='rtl' unicode-bidi='%@'>אב <tspan>12</tspan> C</tspan>Z</text>", fixture[0]]];
                IJSVGTextLayout* expected = [context layout:[NSString stringWithFormat:@"<text font-family='Helvetica' font-size='24'>A%@אב <tspan>12</tspan> C%@Z</text>", fixture[1], fixture[2]]];
                IJSVGCheck([actual.string isEqual:@"Aאב 12 CZ"]);
                IJSVGCheck(actual.characterPositions.count == 9);
                NSUInteger prefix = [fixture[1] length];
                NSUInteger suffix = [fixture[2] length];
                for(NSUInteger index = 0; index < actual.characterPositions.count; index++) {
                    NSUInteger reference = index == 0 ? 0 :
                        (index == actual.characterPositions.count - 1 ? index + prefix + suffix : index + prefix);
                    IJSVGNear([context point:index layout:actual].x, [context point:reference layout:expected].x);
                    IJSVGNear([context point:index layout:actual].y, [context point:reference layout:expected].y);
                }
            };
        }
        entries[@"bidiControlsDoNotConsumePositionsOrRotations"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGTextLayout* result = [context layout:@"<text x='10 40 70' rotate='0 15 30' text-anchor='end'><tspan unicode-bidi='isolate' direction='rtl'>ABC</tspan></text>"];
            IJSVGCheck([result.string isEqual:@"ABC"]);
            IJSVGCheck(result.characterPositions.count == 3);
            IJSVGCheck(result.glyphCount == 3);
            [context require:result.characterRotations.count == 3 message:@"Missing character rotations"];
            for(NSUInteger index = 0; index < 3; index++) {
                IJSVGCheck([context point:index layout:result].x == 10 + index * 30);
                IJSVGCheck(fabs(result.characterRotations[index].doubleValue - index * 15) < .00001);
            }
        };
        NSArray<NSString*>* maskFixtures = @[
            @"<g font-family='Helvetica' font-size='45' font-weight='bold' text-anchor='middle'><defs><mask id='m'><text x='175' y='55'>InnerShadow</text></mask></defs><text x='175' y='55'>InnerShadow</text><g mask='url(#m)'><rect width='350' height='75'/></g></g>",
            @"<g font-family='Helvetica' font-size='20'><defs font-size='150%' text-anchor='middle'><mask id='m'><text x='175' y='55'>InnerShadow</text></mask></defs><text font-size='30' text-anchor='middle' x='175' y='55'>InnerShadow</text></g><g font-size='80' mask='url(#m)'><rect width='350' height='75'/></g>",
            @"<style>.source {font-family:Helvetica;font-size:40px} .source defs {font-size:75%;text-anchor:middle}</style><g class='source'><defs><mask id='m'><text x='175' y='55'>InnerShadow</text></mask></defs></g><text font-family='Helvetica' font-size='30' text-anchor='middle' x='175' y='55'>InnerShadow</text><g font-size='80' mask='url(#m)'><rect width='350' height='75'/></g>"
        ];
        for(NSUInteger index = 0; index < maskFixtures.count; index++) {
            NSString* fixture = maskFixtures[index];
            entries[[NSString stringWithFormat:@"maskTextPreservesDefinitionAncestry/%lu", index]] = ^(IJSVGTextRegressionContext* context) {
                IJSVGTextLayout* expected = [context layout:fixture];
                __block IJSVGText* maskText = nil;
                [IJSVGNode walkNodeTree:context.root handler:^(IJSVGNode* node, BOOL* descend, BOOL* stop) {
                    if(node.mask == nil) {
                        return;
                    }
                    [IJSVGNode walkNodeTree:node.mask handler:^(IJSVGNode* child, BOOL* childDescend, BOOL* childStop) {
                        if([child isKindOfClass:IJSVGText.class]) {
                            maskText = (IJSVGText*)child;
                            *childStop = YES;
                        }
                    }];
                }];
                [context require:maskText != nil message:@"Missing mask text"];
                IJSVGTextLayout* actual = [[IJSVGTextLayout alloc] initWithText:maskText
                                                                      viewport:CGSizeMake(400, 200)
                                                                  pathResolver:nil];
                IJSVGNear(actual.advance, expected.advance);
                IJSVGCheck([actual.characterPositions isEqual:expected.characterPositions]);
            };
        }
        NSArray<NSString*>* maskShapes = @[
            @"<text x='63' y='91' font-family='Helvetica' font-size='45'>Mask F</text>",
            @"<path d='M43 31 H128 V57 H69 V112 H43 Z'/><rect x='173' y='67' width='41' height='19'/>"
        ];
        for(NSUInteger index = 0; index < maskShapes.count; index++) {
            NSString* shape = maskShapes[index];
            entries[[NSString stringWithFormat:@"maskRasterPreservesContentPlacement/%lu", index]] = ^(IJSVGTextRegressionContext* context) {
                NSString* body = [NSString stringWithFormat:
                    @"<defs><mask id='m'><g fill='white'>%@</g></mask></defs>"
                     "<g mask='url(#m)'><rect width='400' height='200'/></g>", shape];
                NSData* actual = [context pixels:body];
                NSData* expected = [context pixels:shape];
                const unsigned char* a = actual.bytes;
                const unsigned char* b = expected.bytes;
                double difference = 0;
                NSUInteger ink = 0;
                for(NSUInteger pixel = 0; pixel < actual.length; pixel += 4) {
                    if(a[pixel] != 255 || b[pixel] != 255) {
                        ink++;
                        difference += abs(a[pixel] - b[pixel]);
                    }
                }
                IJSVGCheck(ink > 100);
                IJSVGCheck(difference / (MAX(ink, 1) * 255.) < .03);
            };
        }
        NSArray<NSArray<NSString*>*>* referenceFixtures = @[
            @[@"filterInheritsDefinitionColorSpace",
              @"<g color-interpolation-filters='sRGB'><defs><filter id='f'><feGaussianBlur stdDeviation='3'/></filter></defs></g><g filter='url(#f)'><rect x='40' y='30' width='50' height='50' fill='red'/><rect x='90' y='30' width='50' height='50' fill='blue'/></g>",
              @"<defs><filter id='f' color-interpolation-filters='sRGB'><feGaussianBlur stdDeviation='3'/></filter></defs><g filter='url(#f)'><rect x='40' y='30' width='50' height='50' fill='red'/><rect x='90' y='30' width='50' height='50' fill='blue'/></g>"],
            @[@"maskInheritedPaintServer",
              @"<g fill='url(#white)'><defs><linearGradient id='white'><stop stop-color='white'/><stop offset='1' stop-color='white'/></linearGradient><mask id='m'><path d='M43 31 H128 V57 H69 V112 H43 Z'/></mask></defs><g fill='black' mask='url(#m)'><rect width='400' height='200'/></g></g>",
              @"<path d='M43 31 H128 V57 H69 V112 H43 Z'/>"],
            @[@"maskInheritedPaint",
              @"<g fill='white' stroke='white' stroke-width='4'><defs><mask id='m'><path d='M43 31 H128 V57 H69 V112 H43 Z'/></mask></defs></g><g fill='black' mask='url(#m)'><rect width='400' height='200'/></g>",
              @"<path d='M43 31 H128 V57 H69 V112 H43 Z' stroke='black' stroke-width='4'/>"],
            @[@"maskChildSelector",
              @"<style>.source > defs > mask > text {fill:white;font:40px Helvetica}</style><g class='source'><defs><mask id='m'><text x='40' y='90'>Mask F</text></mask></defs></g><g mask='url(#m)'><rect width='400' height='200'/></g>",
              @"<text x='40' y='90' font-family='Helvetica' font-size='40'>Mask F</text>"],
            @[@"maskAdjacentSiblingSelector",
              @"<style>.marker + mask {fill:white;font:40px Helvetica}</style><defs><g class='marker'/><mask id='m'><text x='40' y='90'>Mask F</text></mask></defs><g mask='url(#m)'><rect width='400' height='200'/></g>",
              @"<text x='40' y='90' font-family='Helvetica' font-size='40'>Mask F</text>"],
            @[@"maskAncestorSiblingSelector",
              @"<style>.marker ~ defs {fill:white;font:40px Helvetica}</style><g class='marker'/><defs><mask id='m'><text x='40' y='90'>Mask F</text></mask></defs><g font-size='80' mask='url(#m)'><rect width='400' height='200'/></g>",
              @"<text x='40' y='90' font-family='Helvetica' font-size='40'>Mask F</text>"],
            @[@"maskIgnoresSourceTransform",
              @"<g transform='translate(200 50)' opacity='.1' fill='white'><defs><mask id='m'><path d='M43 31 H128 V57 H69 V112 H43 Z'/></mask></defs></g><g mask='url(#m)'><rect width='400' height='200'/></g>",
              @"<path d='M43 31 H128 V57 H69 V112 H43 Z'/>"],
            @[@"clipInheritedText",
              @"<g font-family='Helvetica' font-size='40'><defs><clipPath id='c'><text x='40' y='90'>Clip F</text></clipPath></defs></g><g clip-path='url(#c)'><rect width='400' height='200'/></g>",
              @"<text x='40' y='90' font-family='Helvetica' font-size='40'>Clip F</text>"],
            @[@"useInheritsInstanceStyle",
              @"<defs font-size='12' fill='red'><text id='t' x='40' y='90'>Use F</text></defs><use href='#t' font-family='Helvetica' font-size='40' fill='black'/>",
              @"<text x='40' y='90' font-family='Helvetica' font-size='40'>Use F</text>"],
            @[@"useKeepsSpecifiedStyle",
              @"<defs><text id='t' x='40' y='90' font-family='Helvetica' font-size='40'>Use F</text></defs><use href='#t' font-size='80'/>",
              @"<text x='40' y='90' font-family='Helvetica' font-size='40'>Use F</text>"],
            @[@"useSelectorStopsAtShadowRoot",
              @"<style>use text, defs text {font-size:80px;fill:red}</style><defs><text id='t' x='40' y='90'>Use F</text></defs><use href='#t' font-family='Helvetica' font-size='40'/>",
              @"<text x='40' y='90' font-family='Helvetica' font-size='40'>Use F</text>"],
            @[@"useInternalSiblingSelector",
              @"<style>#icon > text + text {font-size:40px}</style><defs><g id='icon'><text x='40' y='50'>A</text><text x='40' y='100'>B</text></g></defs><use href='#icon' font-family='Helvetica' font-size='20'/>",
              @"<g font-family='Helvetica' font-size='20'><text x='40' y='50'>A</text><text x='40' y='100' font-size='40'>B</text></g>"]
        ];
        for(NSArray<NSString*>* fixture in referenceFixtures) {
            entries[fixture[0]] = ^(IJSVGTextRegressionContext* context) {
                NSData* actual = [context pixels:fixture[1]];
                NSData* expected = [context pixels:fixture[2]];
                const unsigned char* a = actual.bytes;
                const unsigned char* b = expected.bytes;
                double difference = 0;
                NSUInteger ink = 0;
                for(NSUInteger pixel = 0; pixel < actual.length; pixel += 4) {
                    BOOL marked = NO;
                    for(NSUInteger channel = 0; channel < 3; channel++) {
                        difference += abs(a[pixel + channel] - b[pixel + channel]);
                        marked |= a[pixel + channel] != 255 || b[pixel + channel] != 255;
                    }
                    ink += marked;
                }
                IJSVGCheck(ink > 100);
                IJSVGCheck(difference / (MAX(ink, 1) * 3. * 255.) < .03);
            };
        }
        entries[@"referenceStylesSurviveCopyWithoutRetainCycles"] = ^(IJSVGTextRegressionContext* context) {
            __weak IJSVGNode* weakAncestor = nil;
            __weak IJSVGNode* weakPaint = nil;
            @autoreleasepool {
                NSString* xml = @"<svg xmlns='http://www.w3.org/2000/svg' width='400' height='200'><g fill='url(#white)' stroke='url(#edge)' stroke-width='0' font-family='Helvetica' font-size='40'><defs><linearGradient id='edge'><stop stop-color='red'/></linearGradient><linearGradient id='white'><stop stop-color='white'/></linearGradient><mask id='m'><text x='40' y='90'>Mask F</text></mask></defs><g fill='black' mask='url(#m)'><rect width='400' height='200'/></g></g></svg>";
                IJSVGRootNode* copied = nil;
                @autoreleasepool {
                    IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml fileURL:nil error:nil];
                    copied = [parser rootNodeWithSize:CGSizeMake(400, 200)].copy;
                }
                [context require:copied.styleAncestors.count > 0 message:@"Missing owned style context"];
                __block IJSVGText* text = nil;
                [IJSVGNode walkNodeTree:copied handler:^(IJSVGNode* node, BOOL* descend, BOOL* stop) {
                    if(node.mask != nil) {
                        text = (IJSVGText*)node.mask.children.firstObject;
                    }
                }];
                [context require:text != nil message:@"Missing copied mask text"];
                IJSVGTextLayout* layout = [[IJSVGTextLayout alloc] initWithText:text
                                                                      viewport:CGSizeMake(400, 200)
                                                                  pathResolver:nil];
                IJSVGTextLayout* expected = [context layout:@"<text x='40' y='90' font-family='Helvetica' font-size='40'>Mask F</text>"];
                IJSVGNear(layout.advance, expected.advance);
                IJSVGCheck(text.fill != nil);
                IJSVGCheck(text.fill.styleParent != nil);
                IJSVGCheck(text.stroke.styleParent != nil);
                weakAncestor = text.parentNode.styleParent;
                weakPaint = text.fill;
                IJSVGCheck(weakAncestor != nil && weakPaint != nil);
            }
            IJSVGCheck(weakAncestor == nil);
            IJSVGCheck(weakPaint == nil);
        };
        entries[@"cyclicReferencesStopParsing"] = ^(IJSVGTextRegressionContext* context) {
            NSData* pixels = [context pixels:@"<defs><g id='a'><use href='#b'/></g><g id='b'><use href='#a'/></g></defs><use href='#a'/><rect x='20' y='20' width='30' height='40'/>"];
            NSData* expected = [context pixels:@"<rect x='20' y='20' width='30' height='40'/>"];
            IJSVGCheck([pixels isEqual:expected]);
        };
        entries[@"typedFilterCompositeOperator"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
            IJSVGCheck(primitive.compositeOperator == IJSVGFilterCompositeOperatorOver);
            NSArray<NSString*>* values = @[@"over", @"in", @"out", @"atop", @"xor", @"arithmetic", @"lighter"];
            const IJSVGFilterCompositeOperator expected[] = {IJSVGFilterCompositeOperatorOver, IJSVGFilterCompositeOperatorIn, IJSVGFilterCompositeOperatorOut, IJSVGFilterCompositeOperatorAtop, IJSVGFilterCompositeOperatorXor, IJSVGFilterCompositeOperatorArithmetic, IJSVGFilterCompositeOperatorLighter};
            for(NSUInteger index = 0; index < values.count; index++) {
                primitive.parameters = @{IJSVGAttributeOperator: values[index]};
                IJSVGCheck(primitive.compositeOperator == expected[index]);
                IJSVGFilterPrimitive* copy = primitive.copy;
                IJSVGCheck(copy.compositeOperator == expected[index]);
                IJSVGCheck([copy.parameters[IJSVGAttributeOperator] isEqualToString:values[index]]);
            }
            unichar characters[] = {'o', 0, 'x'};
            NSString* embeddedNull = [NSString stringWithCharacters:characters length:3];
            for(NSString* invalid in @[@"", @"invalid", embeddedNull]) {
                primitive.parameters = @{IJSVGAttributeOperator: invalid};
                IJSVGCheck(primitive.compositeOperator == IJSVGFilterCompositeOperatorOver);
            }
            primitive.parameters = nil;
            IJSVGCheck(primitive.compositeOperator == IJSVGFilterCompositeOperatorOver);
        };
        entries[@"typedFilterEdgeMode"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
            IJSVGCheck(primitive.edgeMode == IJSVGFilterEdgeModeNone);
            NSArray<NSString*>* values = @[@"none", @"duplicate", @"wrap"];
            const IJSVGFilterEdgeMode expected[] = {IJSVGFilterEdgeModeNone, IJSVGFilterEdgeModeDuplicate, IJSVGFilterEdgeModeWrap};
            for(NSUInteger index = 0; index < values.count; index++) {
                primitive.parameters = @{IJSVGAttributeEdgeMode: values[index]};
                IJSVGCheck(primitive.edgeMode == expected[index]);
                IJSVGFilterPrimitive* copy = primitive.copy;
                IJSVGCheck(copy.edgeMode == expected[index]);
                IJSVGCheck([copy.parameters[IJSVGAttributeEdgeMode] isEqualToString:values[index]]);
            }
            unichar characters[] = {'n', 0, 'x'};
            NSString* embeddedNull = [NSString stringWithCharacters:characters length:3];
            for(NSString* invalid in @[@"", @"invalid", embeddedNull]) {
                primitive.parameters = @{IJSVGAttributeEdgeMode: invalid};
                IJSVGCheck(primitive.edgeMode == IJSVGFilterEdgeModeNone);
            }
            primitive.parameters = nil;
            IJSVGCheck(primitive.edgeMode == IJSVGFilterEdgeModeNone);
        };
        entries[@"typedFilterColorMatrixType"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
            IJSVGCheck(primitive.colorMatrixType == IJSVGFilterColorMatrixTypeMatrix);
            NSArray<NSString*>* values = @[@"matrix", @"saturate", @"hueRotate", @"luminanceToAlpha"];
            const IJSVGFilterColorMatrixType expected[] = {IJSVGFilterColorMatrixTypeMatrix, IJSVGFilterColorMatrixTypeSaturate, IJSVGFilterColorMatrixTypeHueRotate, IJSVGFilterColorMatrixTypeLuminanceToAlpha};
            for(NSUInteger index = 0; index < values.count; index++) {
                primitive.parameters = @{IJSVGAttributeType: values[index]};
                IJSVGCheck(primitive.colorMatrixType == expected[index]);
                IJSVGFilterPrimitive* copy = primitive.copy;
                IJSVGCheck(copy.colorMatrixType == expected[index]);
                IJSVGCheck([copy.parameters[IJSVGAttributeType] isEqualToString:values[index]]);
            }
            unichar characters[] = {'m', 0, 'x'};
            NSString* embeddedNull = [NSString stringWithCharacters:characters length:3];
            for(NSString* invalid in @[@"", @"invalid", embeddedNull]) {
                primitive.parameters = @{IJSVGAttributeType: invalid};
                IJSVGCheck(primitive.colorMatrixType == IJSVGFilterColorMatrixTypeMatrix);
            }
            primitive.parameters = nil;
            IJSVGCheck(primitive.colorMatrixType == IJSVGFilterColorMatrixTypeMatrix);
        };
        entries[@"typedFilterTransferType"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
            IJSVGCheck(primitive.transferType == IJSVGFilterTransferTypeIdentity);
            NSArray<NSString*>* values = @[@"identity", @"table", @"discrete", @"linear", @"gamma"];
            const IJSVGFilterTransferType expected[] = {IJSVGFilterTransferTypeIdentity, IJSVGFilterTransferTypeTable, IJSVGFilterTransferTypeDiscrete, IJSVGFilterTransferTypeLinear, IJSVGFilterTransferTypeGamma};
            for(NSUInteger index = 0; index < values.count; index++) {
                primitive.parameters = @{IJSVGAttributeType: values[index]};
                IJSVGCheck(primitive.transferType == expected[index]);
                IJSVGFilterPrimitive* copy = primitive.copy;
                IJSVGCheck(copy.transferType == expected[index]);
                IJSVGCheck([copy.parameters[IJSVGAttributeType] isEqualToString:values[index]]);
            }
            unichar characters[] = {'i', 0, 'x'};
            NSString* embeddedNull = [NSString stringWithCharacters:characters length:3];
            for(NSString* invalid in @[@"", @"invalid", embeddedNull]) {
                primitive.parameters = @{IJSVGAttributeType: invalid};
                IJSVGCheck(primitive.transferType == IJSVGFilterTransferTypeIdentity);
            }
            primitive.parameters = nil;
            IJSVGCheck(primitive.transferType == IJSVGFilterTransferTypeIdentity);
        };
        entries[@"typedFilterMorphologyOperator"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
            IJSVGCheck(primitive.morphologyOperator == IJSVGFilterMorphologyOperatorErode);
            NSArray<NSString*>* values = @[@"erode", @"dilate"];
            const IJSVGFilterMorphologyOperator expected[] = {IJSVGFilterMorphologyOperatorErode, IJSVGFilterMorphologyOperatorDilate};
            for(NSUInteger index = 0; index < values.count; index++) {
                primitive.parameters = @{IJSVGAttributeOperator: values[index]};
                IJSVGCheck(primitive.morphologyOperator == expected[index]);
                IJSVGFilterPrimitive* copy = primitive.copy;
                IJSVGCheck(copy.morphologyOperator == expected[index]);
                IJSVGCheck([copy.parameters[IJSVGAttributeOperator] isEqualToString:values[index]]);
            }
            unichar characters[] = {'e', 0, 'x'};
            NSString* embeddedNull = [NSString stringWithCharacters:characters length:3];
            for(NSString* invalid in @[@"", @"invalid", embeddedNull]) {
                primitive.parameters = @{IJSVGAttributeOperator: invalid};
                IJSVGCheck(primitive.morphologyOperator == IJSVGFilterMorphologyOperatorErode);
            }
            primitive.parameters = nil;
            IJSVGCheck(primitive.morphologyOperator == IJSVGFilterMorphologyOperatorErode);
        };
        entries[@"typedFilterTurbulenceType"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
            IJSVGCheck(primitive.turbulenceType == IJSVGFilterTurbulenceTypeTurbulence);
            NSArray<NSString*>* values = @[@"turbulence", @"fractalNoise"];
            const IJSVGFilterTurbulenceType expected[] = {IJSVGFilterTurbulenceTypeTurbulence, IJSVGFilterTurbulenceTypeFractalNoise};
            for(NSUInteger index = 0; index < values.count; index++) {
                primitive.parameters = @{IJSVGAttributeType: values[index]};
                IJSVGCheck(primitive.turbulenceType == expected[index]);
                IJSVGFilterPrimitive* copy = primitive.copy;
                IJSVGCheck(copy.turbulenceType == expected[index]);
                IJSVGCheck([copy.parameters[IJSVGAttributeType] isEqualToString:values[index]]);
            }
            unichar characters[] = {'t', 0, 'x'};
            NSString* embeddedNull = [NSString stringWithCharacters:characters length:3];
            for(NSString* invalid in @[@"", @"invalid", embeddedNull]) {
                primitive.parameters = @{IJSVGAttributeType: invalid};
                IJSVGCheck(primitive.turbulenceType == IJSVGFilterTurbulenceTypeTurbulence);
            }
            primitive.parameters = nil;
            IJSVGCheck(primitive.turbulenceType == IJSVGFilterTurbulenceTypeTurbulence);
        };
        entries[@"typedFilterXChannel"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
            IJSVGCheck(primitive.xChannel == IJSVGFilterColorChannelAlpha);
            NSArray<NSString*>* values = @[@"R", @"G", @"B", @"A"];
            const IJSVGFilterColorChannel expected[] = {IJSVGFilterColorChannelRed, IJSVGFilterColorChannelGreen, IJSVGFilterColorChannelBlue, IJSVGFilterColorChannelAlpha};
            for(NSUInteger index = 0; index < values.count; index++) {
                primitive.parameters = @{IJSVGAttributeXChannelSelector: values[index]};
                IJSVGCheck(primitive.xChannel == expected[index]);
                IJSVGFilterPrimitive* copy = primitive.copy;
                IJSVGCheck(copy.xChannel == expected[index]);
                IJSVGCheck([copy.parameters[IJSVGAttributeXChannelSelector] isEqualToString:values[index]]);
            }
            unichar characters[] = {'R', 0, 'x'};
            NSString* embeddedNull = [NSString stringWithCharacters:characters length:3];
            for(NSString* invalid in @[@"", @"invalid", embeddedNull]) {
                primitive.parameters = @{IJSVGAttributeXChannelSelector: invalid};
                IJSVGCheck(primitive.xChannel == IJSVGFilterColorChannelAlpha);
            }
            primitive.parameters = nil;
            IJSVGCheck(primitive.xChannel == IJSVGFilterColorChannelAlpha);
        };
        entries[@"typedFilterYChannel"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
            IJSVGCheck(primitive.yChannel == IJSVGFilterColorChannelAlpha);
            NSArray<NSString*>* values = @[@"R", @"G", @"B", @"A"];
            const IJSVGFilterColorChannel expected[] = {IJSVGFilterColorChannelRed, IJSVGFilterColorChannelGreen, IJSVGFilterColorChannelBlue, IJSVGFilterColorChannelAlpha};
            for(NSUInteger index = 0; index < values.count; index++) {
                primitive.parameters = @{IJSVGAttributeYChannelSelector: values[index]};
                IJSVGCheck(primitive.yChannel == expected[index]);
                IJSVGFilterPrimitive* copy = primitive.copy;
                IJSVGCheck(copy.yChannel == expected[index]);
                IJSVGCheck([copy.parameters[IJSVGAttributeYChannelSelector] isEqualToString:values[index]]);
            }
            unichar characters[] = {'R', 0, 'x'};
            NSString* embeddedNull = [NSString stringWithCharacters:characters length:3];
            for(NSString* invalid in @[@"", @"invalid", embeddedNull]) {
                primitive.parameters = @{IJSVGAttributeYChannelSelector: invalid};
                IJSVGCheck(primitive.yChannel == IJSVGFilterColorChannelAlpha);
            }
            primitive.parameters = nil;
            IJSVGCheck(primitive.yChannel == IJSVGFilterColorChannelAlpha);
        };
        entries[@"typedFilterFilterBlendMode"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
            IJSVGCheck(primitive.filterBlendMode == IJSVGBlendModeNormal);
            NSArray<NSString*>* values = @[@"normal", @"multiply", @"screen", @"darken", @"lighten", @"overlay", @"color-dodge", @"color-burn", @"hard-light", @"soft-light", @"difference", @"exclusion", @"hue", @"saturation", @"color", @"luminosity"];
            const IJSVGBlendMode expected[] = {IJSVGBlendModeNormal, IJSVGBlendModeMultiply, IJSVGBlendModeScreen, IJSVGBlendModeDarken, IJSVGBlendModeLighten, IJSVGBlendModeOverlay, IJSVGBlendModeColorDodge, IJSVGBlendModeColorBurn, IJSVGBlendModeHardLight, IJSVGBlendModeSoftLight, IJSVGBlendModeDifference, IJSVGBlendModeExclusion, IJSVGBlendModeHue, IJSVGBlendModeSaturation, IJSVGBlendModeColor, IJSVGBlendModeLuminosity};
            for(NSUInteger index = 0; index < values.count; index++) {
                primitive.parameters = @{IJSVGAttributeMode: values[index]};
                IJSVGCheck(primitive.filterBlendMode == expected[index]);
                IJSVGFilterPrimitive* copy = primitive.copy;
                IJSVGCheck(copy.filterBlendMode == expected[index]);
                IJSVGCheck([copy.parameters[IJSVGAttributeMode] isEqualToString:values[index]]);
            }
            unichar characters[] = {'n', 0, 'x'};
            NSString* embeddedNull = [NSString stringWithCharacters:characters length:3];
            for(NSString* invalid in @[@"", @"invalid", embeddedNull]) {
                primitive.parameters = @{IJSVGAttributeMode: invalid};
                IJSVGCheck(primitive.filterBlendMode == IJSVGBlendModeNormal);
            }
            primitive.parameters = nil;
            IJSVGCheck(primitive.filterBlendMode == IJSVGBlendModeNormal);
        };
        entries[@"typedFilterDefaultsFollowPrimitiveType"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGFilterPrimitive* primitive = [[IJSVGFilterPrimitive alloc] init];
            primitive.type = IJSVGNodeTypeFilterConvolveMatrix;
            IJSVGCheck(primitive.edgeMode == IJSVGFilterEdgeModeDuplicate);
            primitive.type = IJSVGNodeTypeFilterGaussianBlur;
            IJSVGCheck(primitive.edgeMode == IJSVGFilterEdgeModeNone);
            primitive.parameters = @{IJSVGAttributeEdgeMode: @"wrap"};
            primitive.type = IJSVGNodeTypeFilterConvolveMatrix;
            IJSVGCheck(primitive.edgeMode == IJSVGFilterEdgeModeWrap);
            primitive.parameters = @{IJSVGAttributePreserveAlpha: @"true", IJSVGAttributeStitchTiles: @"stitch"};
            IJSVGCheck(primitive.preserveAlpha && primitive.stitchTiles);
            IJSVGCheck(primitive.edgeMode == IJSVGFilterEdgeModeDuplicate);
            primitive.parameters = nil;
            IJSVGCheck(!primitive.preserveAlpha && !primitive.stitchTiles);
        };
        entries[@"typedFilterColorInterpolation"] = ^(IJSVGTextRegressionContext* context) {
            NSArray<NSString*>* values = @[@"sRGB", @"linearRGB", @"inherit", @"unset", @"initial", @"auto", @" SRGB ", @"invalid", @""];
            const IJSVGColorInterpolation expected[] = {
                IJSVGColorInterpolationSRGB, IJSVGColorInterpolationLinearRGB,
                IJSVGColorInterpolationInherit, IJSVGColorInterpolationInherit,
                IJSVGColorInterpolationLinearRGB, IJSVGColorInterpolationAuto,
                IJSVGColorInterpolationSRGB, IJSVGColorInterpolationUnspecified,
                IJSVGColorInterpolationUnspecified
            };
            for(NSUInteger index = 0; index < values.count; index++) {
                IJSVGCheck(IJSVGColorInterpolationForString(values[index]) == expected[index]);
                IJSVGCheck(IJSVGColorInterpolationForString(IJSVGColorInterpolationString(expected[index])) == expected[index]);
            }
            IJSVGNode* parent = [[IJSVGNode alloc] init];
            IJSVGNode* child = [[IJSVGNode alloc] init];
            child.styleParent = parent;
            IJSVGCheck(child.resolvedFilterColorInterpolation == IJSVGColorInterpolationLinearRGB);
            parent.filterColorInterpolation = IJSVGColorInterpolationSRGB;
            IJSVGCheck(child.resolvedFilterColorInterpolation == IJSVGColorInterpolationSRGB);
            child.filterColorInterpolation = IJSVGColorInterpolationInherit;
            IJSVGCheck(child.resolvedFilterColorInterpolation == IJSVGColorInterpolationSRGB);
            child.filterColorInterpolation = IJSVGColorInterpolationLinearRGB;
            IJSVGCheck(child.resolvedFilterColorInterpolation == IJSVGColorInterpolationLinearRGB);
            IJSVGNode* copy = child.copy;
            IJSVGCheck(copy.filterColorInterpolation == IJSVGColorInterpolationLinearRGB);
        };
        entries[@"typedSelectorCombinatorStaysConsistent"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGStyleSheetSelectorRaw* selector = [[IJSVGStyleSheetSelectorRaw alloc] init];
            IJSVGCheck([selector.combinatorString isEqualToString:@" "]);
            selector.combinator = IJSVGStyleSheetSelectorCombinatorDirectDescendant;
            IJSVGCheck([selector.combinatorString isEqualToString:@">"]);
            selector.combinator = IJSVGStyleSheetSelectorCombinatorNextSibling;
            IJSVGCheck([selector.combinatorString isEqualToString:@"+"]);
        };
        cases = entries.copy;
    });
    return cases;
}

NSArray<NSString*>* IJSVGTextRegressionCaseNames(void)
{
    return [IJSVGTextRegressionCases().allKeys sortedArrayUsingSelector:@selector(compare:)];
}

NSArray<NSString*>* IJSVGRunTextRegressionCase(NSString* name)
{
    IJSVGTextRegressionContext* context = [[IJSVGTextRegressionContext alloc] init];
    @try {
        IJSVGTextRegressionCase test = IJSVGTextRegressionCases()[name];
        [context require:test != nil message:@"Unknown regression case"];
        test(context);
    } @catch(NSException* exception) {
        [context.failures addObject:exception.reason ?: exception.name];
    }
    return context.failures;
}
