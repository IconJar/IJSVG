//
//  IJSVGTextRegressionTests.m
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 07/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGCSSFontParserChecks.h"
#import <CoreText/CoreText.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGTextLayout.h>
#import <IJSVG/IJSVGStyleSheetSelectorRaw.h>
#import <IJSVG/IJSVGCommand.h>
#import <sys/mman.h>
#import <unistd.h>

static NSArray<NSArray<NSNumber*>*>* IJSVGRegressionPathElements(CGPathRef path)
{
    NSMutableArray<NSArray<NSNumber*>*>* result = [[NSMutableArray alloc] init];
    CGPathApplyWithBlock(path, ^(const CGPathElement* element) {
        NSUInteger count = 0;
        switch(element->type) {
            case kCGPathElementMoveToPoint:
            case kCGPathElementAddLineToPoint:
                count = 1;
                break;
            case kCGPathElementAddQuadCurveToPoint:
                count = 2;
                break;
            case kCGPathElementAddCurveToPoint:
                count = 3;
                break;
            case kCGPathElementCloseSubpath:
                break;
        }
        NSMutableArray<NSNumber*>* values = [NSMutableArray arrayWithObject:@(element->type)];
        for(NSUInteger index = 0; index < count; index++) {
            [values addObject:@(element->points[index].x)];
            [values addObject:@(element->points[index].y)];
        }
        [result addObject:values];
    });
    return result;
}

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
        entries[@"parserPolygonPrecisionAndEmptyPoints"] = ^(IJSVGTextRegressionContext* context) {
            NSString* xml = @"<svg xmlns='http://www.w3.org/2000/svg'><polygon points='0.123456789 0.987654321 2.123456789 3.987654321'/><polyline points=''/><polygon/><polyline points='1'/></svg>";
            IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml fileURL:nil error:nil];
            IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(10, 10)];
            IJSVGPath* polygon = (IJSVGPath*)root.children.firstObject;
            CGRect bounds = CGPathGetBoundingBox(polygon.path);
            IJSVGCheck(fabs(bounds.origin.x - .123456789) < 1e-9);
            IJSVGCheck(fabs(bounds.origin.y - .987654321) < 1e-9);
            IJSVGCheck(fabs(bounds.size.width - 2) < 1e-9);
            IJSVGCheck(fabs(bounds.size.height - 3) < 1e-9);
            for(NSUInteger index = 1; index < root.children.count; index++) {
                IJSVGPath* empty = (IJSVGPath*)root.children[index];
                IJSVGCheck(CGPathIsEmpty(empty.path));
            }
        };
        entries[@"parserCommandSpanStopsAtBufferBoundary"] = ^(IJSVGTextRegressionContext* context) {
            size_t pageSize = (size_t)getpagesize();
            char* memory = mmap(NULL, pageSize * 2, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
            [context require:memory != MAP_FAILED message:@"Could not allocate command test memory"];
            IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
            @try {
                [context require:mprotect(memory + pageSize, pageSize, PROT_NONE) == 0 message:@"Could not protect command boundary"];
                const char data[] = {'M', '1', '0', ' ', '2', '0'};
                char* start = memory + pageSize - sizeof(data);
                memcpy(start, data, sizeof(data));
                Class commandClass = [IJSVGCommand commandClassForCommandChar:'M'];
                IJSVGCommand* command = [[commandClass alloc] initWithCommandStringBuffer:start
                                                                                   length:sizeof(data)
                                                                               dataStream:stream];
                [context require:command.subCommands.count == 1 message:@"Missing bounded move command"];
                IJSVGCheck(command.subCommands.firstObject.parameters[0] == 10);
                IJSVGCheck(command.subCommands.firstObject.parameters[1] == 20);
            } @finally {
                IJSVGPathDataStreamRelease(stream);
                munmap(memory, pageSize * 2);
            }
        };
        entries[@"parserIncompleteCommandsDoNotReadMissingParameters"] = ^(IJSVGTextRegressionContext* context) {
            for(NSString* input in @[@"", @" ", @"M", @"M1", @"M0 0L10", @"M0 0C1 2 3", @"M0 0A1 1 0 2 0 3 4", @"M+ . L-"]) {
                NSArray<IJSVGCommand*>* commands = [IJSVGCommand commandsForDataCharacters:input.UTF8String];
                CGMutablePathRef path = [IJSVGCommand newPathForCommandsArray:commands];
                IJSVGCheck(path != NULL);
                CGPathRelease(path);
            }
            NSArray<IJSVGCommand*>* commands = [IJSVGCommand commandsForDataCharacters:"  M1e1 2e1L30 40z  "];
            IJSVGCheck(commands.count == 3);
            IJSVGCheck(commands.firstObject.subCommands.firstObject.parameters[0] == 10);
            IJSVGCheck(commands.firstObject.subCommands.firstObject.parameters[1] == 20);
        };
        entries[@"parserCachedGeometryRemainsIndependent"] = ^(IJSVGTextRegressionContext* context) {
            NSString* xml = @"<svg xmlns='http://www.w3.org/2000/svg'><path d='M0 0L10 10'/><path d='M0 0L10 10'/></svg>";
            IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGString:xml fileURL:nil error:nil];
            IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeMake(100, 100)];
            IJSVGPath* first = (IJSVGPath*)root.children[0];
            IJSVGPath* second = (IJSVGPath*)root.children[1];
            IJSVGCheck(first.path != second.path);
            CGPathAddLineToPoint(first.path, NULL, 80, 80);
            IJSVGCheck(CGPathGetBoundingBox(second.path).size.width == 10);
            IJSVGRootNode* reparsed = [parser rootNodeWithSize:CGSizeMake(100, 100)];
            IJSVGPath* fresh = (IJSVGPath*)reparsed.children.firstObject;
            IJSVGCheck(CGPathGetBoundingBox(fresh.path).size.width == 10);
        };
        entries[@"parserCachedStylesResolvePerInstance"] = ^(IJSVGTextRegressionContext* context) {
            NSData* actual = [context pixels:@"<style>.first{fill:red!important}.second{fill:blue!important}</style><rect class='first' width='20' height='20' style='fill:green'/><rect class='second' x='30' width='20' height='20' style='fill:green'/><rect x='60' width='20' height='20' style='fill:green'/>"];
            NSData* expected = [context pixels:@"<rect width='20' height='20' fill='red'/><rect x='30' width='20' height='20' fill='blue'/><rect x='60' width='20' height='20' fill='green'/>"];
            IJSVGCheck([actual isEqual:expected]);
            actual = [context pixels:@"<defs><path id='p' d='M0 0L20 0 20 20 0 20Z'/></defs><use href='#p' fill='red'/><use href='#p' x='30' fill='blue'/>"];
            expected = [context pixels:@"<rect width='20' height='20' fill='red'/><rect x='30' width='20' height='20' fill='blue'/>"];
            IJSVGCheck([actual isEqual:expected]);
        };
        entries[@"parserCSSIndexPreservesCascadeAndNewRules"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGStyleSheet* sheet = [[IJSVGStyleSheet alloc] init];
            [sheet parseStyleBlock:@"*{fill:black}.a,#chosen{fill:red}.a.b{fill:green}rect{fill:blue}"];
            IJSVGNode* node = [[IJSVGNode alloc] init];
            node.name = @"rect";
            node.classNameList = [NSSet setWithArray:@[@"a", @"b"]];
            IJSVGCheck([[[sheet styleForNode:node] property:@"fill"] isEqual:@"green"]);
            node.identifier = @"chosen";
            IJSVGCheck([[[sheet styleForNode:node] property:@"fill"] isEqual:@"red"]);
            [sheet parseStyleBlock:@"rect{fill:orange!important}#chosen{stroke:blue}"];
            IJSVGCheck([[[sheet styleForNode:node] property:@"fill"] isEqual:@"orange"]);
            IJSVGCheck([[[sheet styleForNode:node] property:@"stroke"] isEqual:@"blue"]);
            for(NSUInteger index = 0; index < 40; index++) {
                NSString* rule = [NSString stringWithFormat:@"rect{stroke-width:%lu}", index];
                [sheet parseStyleBlock:rule];
            }
            IJSVGCheck([[[sheet styleForNode:node] property:@"stroke-width"] isEqual:@"39"]);
            node.identifier = nil;
            node.classNameList = nil;
            node.name = @"circle";
            IJSVGCheck([[[sheet styleForNode:node] property:@"fill"] isEqual:@"black"]);
        };
        entries[@"parserCachedSelectorScopesKeepSiblingRules"] = ^(IJSVGTextRegressionContext* context) {
            NSData* actual = [context pixels:@"<style>.a + .b{fill:red}</style><defs><g id='g'><rect class='a' width='20' height='20'/><rect class='b' x='30' width='20' height='20'/></g></defs><use href='#g' fill='blue'/><use href='#g' y='30' fill='green'/>"];
            NSData* expected = [context pixels:@"<rect width='20' height='20' fill='blue'/><rect x='30' width='20' height='20' fill='red'/><rect y='30' width='20' height='20' fill='green'/><rect x='30' y='30' width='20' height='20' fill='red'/>"];
            IJSVGCheck([actual isEqual:expected]);
        };
        entries[@"parserDirectPathMatchesCommandObjects"] = ^(IJSVGTextRegressionContext* context) {
            NSMutableArray<NSString*>* paths = [@[
                @"M10 20 30 40 50 60m5 6 7 8z m2 3h4v5H40V50",
                @"M0 0C1 2 3 4 5 6S7 8 9 10s1 2 3 4c5 6 7 8 9 10s1 2 3 4",
                @"M0 0Q5 8 10 0T20 0 30 0q5 8 10 0t10 0 10 0L60 20T70 0",
                @"M10 10A20 30 40 0 1 80 50a20 30 40 1 0 20 30A0 10 0 0 0 10 10",
                @"M0 0A10 10 0 0110 10zM.5-.5L1e2-2e1",
                @"M0 0L10 0 10 10Zl5 5s1 2 3 4t5 6"
            ] mutableCopy];
            uint32_t seed = 12345;
            const char commands[] = "LlHhVvCcSsQqTtAaMmZz";
            for(NSUInteger sample = 0; sample < 100; sample++) {
                NSMutableString* path = [NSMutableString stringWithString:@"M10 20"];
                for(NSUInteger segment = 0; segment < 40; segment++) {
                    seed = seed * 1664525 + 1013904223;
                    char command = commands[seed % (sizeof(commands) - 1)];
                    [path appendFormat:@"%c", command];
                    Class commandClass = [IJSVGCommand commandClassForCommandChar:command];
                    NSInteger count = [commandClass requiredParameterCount];
                    for(NSInteger index = 0; index < count; index++) {
                        seed = seed * 1664525 + 1013904223;
                        BOOL flag = (command == 'a' || command == 'A') && (index == 3 || index == 4);
                        double value = flag ? seed % 2 : (double)(seed % 2000) / 13. - 50.;
                        [path appendFormat:@" %.8g", value];
                    }
                }
                [paths addObject:path];
            }
            IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
            @try {
                for(NSString* data in paths) {
                    const char* characters = data.UTF8String;
                    CGMutablePathRef actual = IJSVGCreatePathFromData(characters, strlen(characters), stream);
                    NSArray<IJSVGCommand*>* commands = [IJSVGCommand commandsForDataCharacters:characters];
                    CGMutablePathRef expected = [IJSVGCommand newPathForCommandsArray:commands];
                    NSArray<NSArray<NSNumber*>*>* actualElements = IJSVGRegressionPathElements(actual);
                    NSArray<NSArray<NSNumber*>*>* expectedElements = IJSVGRegressionPathElements(expected);
                    CGPathRelease(actual);
                    CGPathRelease(expected);
                    [context require:actualElements.count == expectedElements.count message:data];
                    for(NSUInteger index = 0; index < actualElements.count; index++) {
                        NSArray<NSNumber*>* a = actualElements[index];
                        NSArray<NSNumber*>* b = expectedElements[index];
                        [context require:a.count == b.count && [a[0] isEqual:b[0]] message:data];
                        for(NSUInteger value = 1; value < a.count; value++) {
                            double tolerance = 1e-8 * MAX(1., fabs(b[value].doubleValue));
                            [context require:fabs(a[value].doubleValue - b[value].doubleValue) <= tolerance message:data];
                        }
                    }
                }
            } @finally {
                IJSVGPathDataStreamRelease(stream);
            }
        };
        entries[@"parserDirectPathRespectsMemoryBoundary"] = ^(IJSVGTextRegressionContext* context) {
            size_t pageSize = (size_t)getpagesize();
            char* memory = mmap(NULL, pageSize * 2, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
            [context require:memory != MAP_FAILED message:@"Could not allocate path test memory"];
            IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(1, 1);
            @try {
                [context require:mprotect(memory + pageSize, pageSize, PROT_NONE) == 0 message:@"Could not protect path boundary"];
                for(NSString* data in @[@"", @"M", @"M0 0L10", @"M+ . L-", @"M10 20L30 40", @"M0 0A10 10 0 0110 10"]) {
                    NSUInteger length = [data lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
                    char* start = memory + pageSize - length;
                    memcpy(start, data.UTF8String, length);
                    CGMutablePathRef path = IJSVGCreatePathFromData(start, length, stream);
                    IJSVGCheck(path != NULL);
                    CGPathRelease(path);
                }
            } @finally {
                IJSVGPathDataStreamRelease(stream);
                munmap(memory, pageSize * 2);
            }
        };
        entries[@"parserNumericBuffersGrowAndReuseCapacity"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(1, 1);
            @try {
                NSMutableString* numbers = [[NSMutableString alloc] init];
                for(NSUInteger index = 0; index < 20000; index++) {
                    [numbers appendFormat:@"%lu ", index];
                }
                NSInteger count = 0;
                const char* bytes = numbers.UTF8String;
                CGFloat* values = IJSVGParsePathDataStreamSequence(bytes, strlen(bytes), stream, NULL, 1, &count);
                [context require:values != NULL message:@"Missing numeric values"];
                IJSVGCheck(count == 20000);
                IJSVGCheck(values[0] == 0 && values[19999] == 19999);
                free(values);
                IJSVGCheck(stream->floatCount >= count && stream->floatCount < count * 2);
                NSInteger capacity = stream->floatCount;
                values = IJSVGParsePathDataStreamSequence("1 2", 3, stream, NULL, 1, &count);
                IJSVGCheck(count == 2 && stream->floatCount == capacity);
                free(values);
                NSString* zeros = [@"" stringByPaddingToLength:200 withString:@"0" startingAtIndex:0];
                NSString* fraction = [NSString stringWithFormat:@"0.%@1", zeros];
                bytes = fraction.UTF8String;
                values = IJSVGParsePathDataStreamSequence(bytes, strlen(bytes), stream, NULL, 1, &count);
                IJSVGCheck(count == 1 && values != NULL && values[0] > 0);
                IJSVGCheck(stream->charCount > fraction.length && stream->charCount <= fraction.length * 2);
                free(values);
            } @finally {
                IJSVGPathDataStreamRelease(stream);
            }
        };
        entries[@"parserAppendsIndependentPathData"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGPathDataStream* stream = IJSVGPathDataStreamCreateDefault();
            CGMutablePathRef combined = CGPathCreateMutable();
            CGPathAddRect(combined, NULL, CGRectMake(80, 90, 10, 10));
            const char* data = "m2 3 4 5z";
            IJSVGAppendPathData(combined, data, strlen(data), stream);
            NSArray<NSArray<NSNumber*>*>* elements = IJSVGRegressionPathElements(combined);
            NSArray<NSNumber*>* move = elements[5];
            IJSVGCheck(move[0].integerValue == kCGPathElementMoveToPoint);
            IJSVGCheck(move[1].doubleValue == 2 && move[2].doubleValue == 3);
            IJSVGPathDataStreamRelease(stream);
            CGPathRelease(combined);
        };
        entries[@"parserPolygonAppendsWithoutPartialInvalidGeometry"] = ^(IJSVGTextRegressionContext* context) {
            IJSVGPathDataStream* stream = IJSVGPathDataStreamCreate(1, 1);
            CGMutablePathRef path = CGPathCreateMutable();
            CGPathAddRect(path, NULL, CGRectMake(80, 90, 10, 10));
            for(NSString* invalid in @[@"", @"1", @"1 2 3", @"1 2 3 1e999"]) {
                const char* bytes = invalid.UTF8String;
                IJSVGCheck(!IJSVGAppendPolyPoints(path, bytes, strlen(bytes), YES, stream));
                IJSVGCheck(IJSVGRegressionPathElements(path).count == 5);
            }
            const char points[] = {'1', ' ', '2', ' ', '3', ' ', '4'};
            IJSVGCheck(IJSVGAppendPolyPoints(path, points, sizeof(points), YES, stream));
            NSArray<NSArray<NSNumber*>*>* elements = IJSVGRegressionPathElements(path);
            IJSVGCheck(elements.count == 8);
            IJSVGCheck(elements[5][1].doubleValue == 1 && elements[5][2].doubleValue == 2);
            IJSVGCheck(elements.lastObject[0].integerValue == kCGPathElementCloseSubpath);
            IJSVGPathDataStreamRelease(stream);
            CGPathRelease(path);
        };
        entries[@"parserInlineTextPathMatchesReferencedGeometry"] = ^(IJSVGTextRegressionContext* context) {
            NSData* actual = [context pixels:@"<text font-family='Helvetica' font-size='20'><textPath path='M20 80 Q180 10 360 80'>Along the curve</textPath></text>"];
            NSData* expected = [context pixels:@"<defs><path id='curve' d='M20 80 Q180 10 360 80'/></defs><text font-family='Helvetica' font-size='20'><textPath href='#curve'>Along the curve</textPath></text>"];
            IJSVGCheck([actual isEqual:expected]);
            [context layout:@"<text><textPath path='M20 80 L360 80'>First</textPath><textPath path='M20 80 L360 80'>Second</textPath></text>"];
            NSMutableArray<IJSVGPath*>* paths = [[NSMutableArray alloc] init];
            [IJSVGNode walkNodeTree:context.root handler:^(IJSVGNode* node, BOOL* descend, BOOL* stop) {
                if([node isKindOfClass:IJSVGText.class] && ((IJSVGText*)node).textPath != nil) {
                    [paths addObject:((IJSVGText*)node).textPath];
                }
            }];
            [context require:paths.count == 2 message:@"Missing inline text paths"];
            CGPathAddLineToPoint(paths[0].path, NULL, 500, 500);
            IJSVGCheck(CGPathGetBoundingBox(paths[1].path).size.height == 0);
        };
        entries[@"pathImportsAndSelfAssignmentPreserveOwnership"] = ^(IJSVGTextRegressionContext* context) {
            CGMutablePathRef source = CGPathCreateMutable();
            CGPathMoveToPoint(source, NULL, 3, 5);
            CGPathAddLineToPoint(source, NULL, 20, 30);
            for(NSNumber* flipped in @[@NO, @YES]) {
                IJSVG* svg = [IJSVG SVGFromCGPathRef:source flipped:flipped.boolValue];
                IJSVGPath* imported = (IJSVGPath*)svg.rootNode.children.firstObject;
                CGPathRef expected = flipped.boolValue ? [IJSVGUtils newFlippedCGPath:source] : CGPathCreateCopy(source);
                IJSVGCheck(CGPathEqualToPath(imported.path, expected));
                imported.path = imported.path;
                IJSVGCheck(CGPathEqualToPath(imported.path, expected));
                CGPathRelease(expected);
            }
            IJSVG* svg = [IJSVG SVGFromCGPathRef:source];
            CGPathAddLineToPoint(source, NULL, 500, 500);
            IJSVGPath* imported = (IJSVGPath*)svg.rootNode.children.firstObject;
            IJSVGCheck(CGPathGetBoundingBox(imported.path).size.width == 17);
            CGPathRelease(source);
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
