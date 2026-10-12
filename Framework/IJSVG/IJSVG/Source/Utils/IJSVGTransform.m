//
//  IJSVGTransform.m
//  IJSVG
//
//  Created by Curtis Hard on 01/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGMath.h>
#import <IJSVG/IJSVGTransform.h>
#import <IJSVG/IJSVGParsing.h>
#import <IJSVGCSSParser.h>
#import <ctype.h>
#import <stdlib.h>

static NSInteger IJSVGTransformParameterCount(IJSVGTransformCommand command,
                                              NSInteger count)
{
    switch(command) {
        case IJSVGTransformCommandMatrix: {
            return count == 6 ? count : -1;
        }
        case IJSVGTransformCommandTranslate:
        case IJSVGTransformCommandScale: {
            return count == 1 || count == 2 ? count : -1;
        }
        case IJSVGTransformCommandRotate: {
            return count == 1 || count == 3 ? count : -1;
        }
        default: {
            return count == 1 ? count : -1;
        }
    }
}

static BOOL IJSVGTransformParameterValue(const IJSVGCSSComponents* components,
                                         const IJSVGCSSComponent* token,
                                         IJSVGTransformCommand command, BOOL css,
                                         NSInteger index, CGFloat* value)
{
    *value = token->number;
    if(token->kind == IJSVGCSSComponentNumber) {
        return YES;
    }
    if(!css || token->kind != IJSVGCSSComponentDimension) {
        return NO;
    }
    const char* unit = NULL;
    NSUInteger length = 0;
    BOOL angle = index == 0 && (command == IJSVGTransformCommandRotate ||
        command == IJSVGTransformCommandSkewX || command == IJSVGTransformCommandSkewY);
    if(angle) {
        switch(token->angleUnit) {
            case IJSVGCSSAngleUnitDegrees: {
                unit = "deg";
                length = 3;
                break;
            }
            case IJSVGCSSAngleUnitRadians: {
                unit = "rad";
                length = 3;
                *value *= 180 / M_PI;
                break;
            }
            case IJSVGCSSAngleUnitGradians: {
                unit = "grad";
                length = 4;
                *value *= .9;
                break;
            }
            case IJSVGCSSAngleUnitTurns: {
                unit = "turn";
                length = 4;
                *value *= 360;
                break;
            }
            default: {
                return NO;
            }
        }
    } else if(token->unit == IJSVGUnitLengthTypePX &&
              (command == IJSVGTransformCommandTranslate ||
               command == IJSVGTransformCommandTranslateX ||
               command == IJSVGTransformCommandTranslateY)) {
        unit = "px";
        length = 2;
    } else {
        return NO;
    }
    const char* bytes = components->bytes + token->offset;
    return token->length > length && memchr(bytes, '\\', token->length) == NULL &&
        memcmp(bytes + token->length - length, unit, length) == 0;
}

static NSInteger IJSVGTransformParseParameters(const IJSVGCSSComponents* components,
                                                NSUInteger index, IJSVGTransformCommand command,
                                                BOOL css, CGFloat values[IJSVGTransformParameterCapacity])
{
    const IJSVGCSSComponent* function = components->values + index++;
    const char* cursor = components->bytes + function->argumentOffset;
    const char* limit = cursor + function->argumentLength;
    NSInteger count = 0;
    while(cursor < limit && isspace((unsigned char)*cursor)) {
        cursor++;
    }
    while(index < function->next && count < IJSVGTransformParameterCapacity) {
        const IJSVGCSSComponent* token = components->values + index++;
        if(components->bytes + token->offset != cursor ||
           !IJSVGTransformParameterValue(components, token, command, css, count, values + count)) {
            return -1;
        }
        count++;
        cursor += token->length;
        BOOL whitespace = cursor < limit && isspace((unsigned char)*cursor);
        while(cursor < limit && isspace((unsigned char)*cursor)) {
            cursor++;
        }
        if(cursor < limit && *cursor == ',') {
            if(index == function->next || components->values[index].symbol != IJSVGCSSSymbolComma) {
                return -1;
            }
            index++;
            cursor++;
            while(cursor < limit && isspace((unsigned char)*cursor)) {
                cursor++;
            }
            if(cursor == limit) {
                return -1;
            }
        } else if(cursor < limit && !whitespace && *cursor != '+' && *cursor != '-' && *cursor != '.') {
            return -1;
        }
    }
    if(cursor != limit || index != function->next) {
        return -1;
    }
    return IJSVGTransformParameterCount(command, count);
}

static IJSVGTransformCommand IJSVGTransformCommandForFunction(IJSVGCSSFunction function)
{
    switch(function) {
        case IJSVGCSSFunctionMatrix: {
            return IJSVGTransformCommandMatrix;
        }
        case IJSVGCSSFunctionTranslate: {
            return IJSVGTransformCommandTranslate;
        }
        case IJSVGCSSFunctionTranslateX: {
            return IJSVGTransformCommandTranslateX;
        }
        case IJSVGCSSFunctionTranslateY: {
            return IJSVGTransformCommandTranslateY;
        }
        case IJSVGCSSFunctionScale: {
            return IJSVGTransformCommandScale;
        }
        case IJSVGCSSFunctionRotate: {
            return IJSVGTransformCommandRotate;
        }
        case IJSVGCSSFunctionSkewX: {
            return IJSVGTransformCommandSkewX;
        }
        case IJSVGCSSFunctionSkewY: {
            return IJSVGTransformCommandSkewY;
        }
        default: {
            return IJSVGTransformCommandNotImplemented;
        }
    }
}

@implementation IJSVGTransform

- (CGFloat*)parameters
{
    return _parameters;
}

- (void)setParameters:(const CGFloat*)parameters
                 count:(NSInteger)count
{
    memset(_parameters, 0, sizeof(_parameters));
    NSInteger copiedCount = MIN(count, IJSVGTransformParameterCapacity);
    if(parameters != NULL && copiedCount > 0) {
        memcpy(_parameters, parameters, sizeof(CGFloat) * copiedCount);
    }
    _parameterCount = copiedCount;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGTransform* trans = [[self.class alloc] init];
    trans.command = _command;
    trans.sort = _sort;
    [trans setParameters:_parameters
                   count:_parameterCount];
    return trans;
}

void IJSVGConcatTransformsCTM(CGContextRef context, NSArray<IJSVGTransform*>* transforms)
{
    IJSVGApplyTransform(transforms, ^(IJSVGTransform* transform) {
        CGContextConcatCTM(context, transform.CGAffineTransform);
    });
}

CGAffineTransform IJSVGConcatTransforms(NSArray<IJSVGTransform*>* transforms)
{
    __block CGAffineTransform trans = CGAffineTransformIdentity;
    IJSVGApplyTransform(transforms, ^(IJSVGTransform* transform) {
        trans = CGAffineTransformConcat(transform.CGAffineTransform, trans);
    });
    return trans;
}

NSString* IJSVGTransformAttributeString(CGAffineTransform transform)
{
    return [IJSVGTransform affineTransformToSVGMatrixString:transform];
}

void IJSVGApplyTransform(NSArray<IJSVGTransform*>* transforms,
                         IJSVGTransformApplyBlock block)
{
    for (IJSVGTransform* transform in transforms) {
        block(transform);
    }
};

BOOL IJSVGAffineTransformScalesAndTranslates(CGAffineTransform transform)
{
    if(transform.tx != 0.f || transform.ty != 0.f) {
        CGFloat scaleX = sqrt(pow(transform.a, 2.f) + pow(transform.c, 2.f));
        CGFloat scaleY = sqrt(pow(transform.b, 2.f) + pow(transform.d, 2.f));
        return scaleX != 1.f || scaleY != 1.f;
    }
    return NO;
}

+ (IJSVGTransform*)transformByTranslatingX:(CGFloat)x
                                         y:(CGFloat)y
{
    IJSVGTransform* transform = [[self alloc] init];
    transform->_command = IJSVGTransformCommandTranslate;
    CGFloat params[2] = { x, y };
    [transform setParameters:params
                       count:2];
    return transform;
}

+ (IJSVGTransform*)transformByScaleX:(CGFloat)x
                                   y:(CGFloat)y
{
    IJSVGTransform* transform = [[self alloc] init];
    transform->_command = IJSVGTransformCommandScale;
    CGFloat params[2] = { x, y };
    [transform setParameters:params
                       count:2];
    return transform;
}

+ (IJSVGTransformCommand)commandForCommandCString:(char*)str
{
    return IJSVGTransformCommandForFunction(IJSVGCSSFunctionForName(str));
}

+ (NSInteger)sortForTransformCommand:(IJSVGTransformCommand)command
{
    switch (command) {
    case IJSVGTransformCommandScale:
        return 0;
    case IJSVGTransformCommandRotate:
        return 1;
    case IJSVGTransformCommandMatrix:
        return 2;
    case IJSVGTransformCommandTranslateX:
    case IJSVGTransformCommandTranslateY:
    case IJSVGTransformCommandTranslate:
        return -1;
    default:
        return 10;
    }
    return 10;
}

+ (NSArray<IJSVGTransform*>*)transformsForString:(NSString*)string
{
    return [self transformsForString:string
                       allowCSSUnits:NO];
}

+ (NSArray<IJSVGTransform*>*)transformsForString:(NSString*)string
                                   allowCSSUnits:(BOOL)allowCSSUnits
{
    NSMutableArray<IJSVGTransform*>* transforms = nil;
    transforms = [[NSMutableArray alloc] init];
    
    IJSVGStringBytes source = IJSVGStringGetBytes(string);
    IJSVGCSSComponents components;
    IJSVGCSSComponentsCreateWithOptions(source.bytes, source.length,
                                        IJSVGCSSParserOptionSVG, &components);
    for(NSUInteger index = 0; index < components.count;) {
        const IJSVGCSSComponent* component = components.values + index;
        if(component->kind != IJSVGCSSComponentFunction || component->next <= index) {
            break;
        }
        IJSVGTransformCommand commandType = IJSVGTransformCommandForFunction(component->function);
        CGFloat params[IJSVGTransformParameterCapacity];
        NSInteger parameterCount = IJSVGTransformParseParameters(&components, index,
                                                                 commandType, allowCSSUnits, params);
        if(commandType == IJSVGTransformCommandNotImplemented || parameterCount < 0) {
            break;
        }
        IJSVGTransform* transform = [[self.class alloc] init];
        transform->_command = commandType;
        transform->_sort = [self.class sortForTransformCommand:commandType];
        [transform setParameters:params
                           count:parameterCount];
        [transforms addObject:transform];
        index = component->next;
    }
    IJSVGCSSComponentsRelease(&components);
    return transforms;
}

+ (NSArray<IJSVGTransform*>*)transformsForString:(NSString*)string
                                           units:(IJSVGUnitType)units
                                          bounds:(CGRect)bounds
{
    NSArray<IJSVGTransform*>* transforms = [self transformsForString:string];
    for(IJSVGTransform* transform in transforms) {
        [transform applyBounds:bounds
              withContentUnits:units];
    }
    return transforms;
}

- (IJSVGTransform*)transformByApplyingUnits:(IJSVGUnitType)units
                                     bounds:(CGRect)bounds
{
    IJSVGTransform* transform = self.copy;
    [transform applyBounds:bounds
          withContentUnits:units];
    return transform;
}

- (void)applyBounds:(CGRect)bounds
   withContentUnits:(IJSVGUnitType)contentUnits
{
    if(contentUnits != IJSVGUnitObjectBoundingBox) {
        return;
    }
    
    // tx and ty of a transform are coordinates, so they
    // have to be scaled into their bounding box if the units
    // dicate so.
    switch(self.command) {
        case IJSVGTransformCommandTranslate: {
            self.parameters[0] *= CGRectGetWidth(bounds);
            if(self.parameterCount == 2) {
                self.parameters[1] *= CGRectGetHeight(bounds);
            }
            break;
        }
        case IJSVGTransformCommandMatrix: {
            self.parameters[4] *= CGRectGetWidth(bounds);
            self.parameters[5] *= CGRectGetHeight(bounds);
            break;
        }
        default:
            break;
    }
}

- (CGAffineTransform)CGAffineTransform
{
    return [self stackIdentity:CGAffineTransformIdentity];
}

- (CGAffineTransform)stackIdentity:(CGAffineTransform)identity
{
    switch (_command) {

    // translate
    case IJSVGTransformCommandTranslate: {
        if(_parameterCount == 1) {
            return CGAffineTransformTranslate(identity, _parameters[0], 0.f);
        }
        return CGAffineTransformTranslate(identity, _parameters[0], _parameters[1]);
    }

    // translateX
    case IJSVGTransformCommandTranslateX: {
        return CGAffineTransformTranslate(identity, _parameters[0], 0.f);
    }

    // translateY
    case IJSVGTransformCommandTranslateY: {
        return CGAffineTransformTranslate(identity, 0.f, _parameters[0]);
    }

    // rotate
    case IJSVGTransformCommandRotate: {
        if(_parameterCount == 1) {
            return CGAffineTransformRotate(identity, (_parameters[0] / 180) * M_PI);
        }
        CGFloat p0 = _parameters[0];
        CGFloat p1 = _parameters[1];
        CGFloat p2 = _parameters[2];
        CGFloat angle = p0 * (M_PI / 180.f);

        identity = CGAffineTransformTranslate(identity, p1, p2);
        identity = CGAffineTransformRotate(identity, angle);
        return CGAffineTransformTranslate(identity, -p1, -p2);
    }

    // scale
    case IJSVGTransformCommandScale: {
        CGFloat p0 = _parameters[0];
        if(_parameterCount == 1) {
            return CGAffineTransformScale(identity, p0, p0);
        }
        CGFloat p1 = _parameters[1];
        return CGAffineTransformScale(identity, p0, p1);
    }

    // matrix
    case IJSVGTransformCommandMatrix: {
        CGFloat p0 = _parameters[0];
        CGFloat p1 = _parameters[1];
        CGFloat p2 = _parameters[2];
        CGFloat p3 = _parameters[3];
        CGFloat p4 = _parameters[4];
        CGFloat p5 = _parameters[5];
        return CGAffineTransformMake(p0, p1, p2, p3, p4, p5);
    }

    // skewX
    case IJSVGTransformCommandSkewX: {
        CGFloat degrees = _parameters[0];
        CGFloat radians = degrees * M_PI / 180.f;
        return CGAffineTransformMake(1.f, 0.f, tan(radians), 1.f, 0.f, 0.f);
    }

    // skewY
    case IJSVGTransformCommandSkewY: {
        CGFloat degrees = _parameters[0];
        CGFloat radians = degrees * M_PI / 180.f;
        return CGAffineTransformMake(1.f, tan(radians), 0.f, 1.f, 0.f, 0.f);
    }

    case IJSVGTransformCommandNotImplemented: {
        return CGAffineTransformIdentity;
    }
    }
    return CGAffineTransformIdentity;
}

+ (NSArray<IJSVGTransform*>*)transformsFromAffineTransform:(CGAffineTransform)affineTransform
{
    NSString* matrix = [self affineTransformToSVGMatrixString:affineTransform];
    return [self transformsForString:matrix];
}

+ (NSString*)affineTransformToSVGTransformComponentString:(CGAffineTransform)transform
                                     floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    NSArray<NSDictionary<NSString*, id>*>* trans = [self affineTransformToSVGTransformComponents:transform];
    trans = [self filterUselessAffineTransformComponents:trans];
    NSMutableArray<NSString*>* strings = [[NSMutableArray alloc] initWithCapacity:trans.count];
    for (NSDictionary<NSString*, id>* dict in trans) {
        NSArray<NSNumber*>* data = dict[@"data"];
        NSString* method = dict[@"name"];
        NSMutableArray<NSString*>* dataStrings = [[NSMutableArray alloc] initWithCapacity:data.count];
        for (NSNumber* number in data) {
            [dataStrings addObject:IJSVGShortFloatStringWithOptions(number.doubleValue,
                                                                    floatingPointOptions)];
        }
        [strings addObject:[NSString stringWithFormat:@"%@(%@)", method,
                                     IJSVGCompressFloatParameterArray(dataStrings)]];
    }
    NSString* componentsString = [strings componentsJoinedByString:@" "];
    NSString* matrixString = [self affineTransformToSVGMatrixString:transform
                                               floatingPointOptions:floatingPointOptions];
    return componentsString.length < matrixString.length ? componentsString : matrixString;
}

+ (NSString*)affineTransformToSVGTransformComponentString:(CGAffineTransform)transform
{
    NSArray<NSDictionary<NSString*, id>*>* trans = [self affineTransformToSVGTransformComponents:transform];
    trans = [self filterUselessAffineTransformComponents:trans];
    NSMutableArray<NSString*>* strings = [[NSMutableArray alloc] initWithCapacity:trans.count];
    for (NSDictionary<NSString*, id>* dict in trans) {
        NSArray<NSNumber*>* data = dict[@"data"];
        NSString* method = dict[@"name"];
        NSMutableArray<NSString*>* dataStrings = [[NSMutableArray alloc] initWithCapacity:data.count];
        for (NSNumber* number in data) {
            [dataStrings addObject:IJSVGShortFloatString(number.doubleValue)];
        }
        [strings addObject:[NSString stringWithFormat:@"%@(%@)", method,
                                     IJSVGCompressFloatParameterArray(dataStrings)]];
    }
    NSString* componentsString = [strings componentsJoinedByString:@" "];
    NSString* matrixString = [self affineTransformToSVGMatrixString:transform];
    return componentsString.length < matrixString.length ? componentsString : matrixString;
}

+ (NSString*)affineTransformToSVGMatrixString:(CGAffineTransform)transform
                         floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions
{
    NSArray<NSString*>* numbers = @[
        IJSVGShortFloatStringWithOptions(transform.a, floatingPointOptions),
        IJSVGShortFloatStringWithOptions(transform.b, floatingPointOptions),
        IJSVGShortFloatStringWithOptions(transform.c, floatingPointOptions),
        IJSVGShortFloatStringWithOptions(transform.d, floatingPointOptions),
        IJSVGShortFloatStringWithOptions(transform.tx, floatingPointOptions),
        IJSVGShortFloatStringWithOptions(transform.ty, floatingPointOptions)
    ];
    return [NSString stringWithFormat:@"matrix(%@)",
                IJSVGCompressFloatParameterArray(numbers)];
}

+ (NSString*)affineTransformToSVGMatrixString:(CGAffineTransform)transform
{
    NSArray<NSString*>* numbers = @[
        IJSVGShortFloatString(transform.a),
        IJSVGShortFloatString(transform.b),
        IJSVGShortFloatString(transform.c),
        IJSVGShortFloatString(transform.d),
        IJSVGShortFloatString(transform.tx),
        IJSVGShortFloatString(transform.ty)
    ];
    return [NSString stringWithFormat:@"matrix(%@)",
                IJSVGCompressFloatParameterArray(numbers)];
}

+ (NSArray<NSDictionary<NSString*, id>*>*)filterUselessAffineTransformComponents:(NSArray<NSDictionary<NSString*, id>*>*)components
{
    NSMutableArray<NSDictionary<NSString*, id>*>* comps = [[NSMutableArray alloc] initWithCapacity:components.count];
    NSArray<NSString*>* names = @[ @"translate", @"rotate", @"skewX", @"skewY" ];
    for (NSDictionary<NSString*, id>* transform in components) {
        NSString* name = transform[@"name"];
        NSArray<NSNumber*>* data = transform[@"data"];
        if([names containsObject:name] && (data.count == 1 || [name isEqualToString:@"rotate"]) &&
            data[0].floatValue == 0.f) {
            continue;
        } else if([name isEqualToString:@"translate"] && data[0].floatValue == 0.f &&
                   data[1].floatValue == 0.f) {
            continue;
        } else if([name isEqualToString:@"scale"] && data[0].floatValue == 1.f
                   && (data.count < 2 || (data.count == 2 && data[1].floatValue == 1.f))) {
            continue;
        } else if([name isEqualToString:@"matrix"] && data[0].floatValue == 1.f &&
                   data[3].floatValue == 1.f && !(data[1].floatValue != 0.f ||
                                                  data[2].floatValue != 0.f ||
                                                  data[4].floatValue != 0.f ||
                                                  data[5].floatValue != 0.f)) {
            continue;
        }
        [comps addObject:transform];
    }
    return comps;
}

+ (NSArray<NSDictionary<NSString*, id>*>*)affineTransformToSVGTransformComponents:(CGAffineTransform)transform
{
    CGFloat data[6] = {
        transform.a,
        transform.b,
        transform.c,
        transform.d,
        transform.tx,
        transform.ty
    };

    CGFloat sx = hypot(data[0], data[1]);
    // A collapsed first axis cannot be decomposed by dividing through its scale.
    if(sx == 0.f) {
        return @[@{
          @"name": @"matrix",
          @"data": @[@(data[0]), @(data[1]), @(data[2]),
                     @(data[3]), @(data[4]), @(data[5])]
        }];
    }
    CGFloat sy = ((data[0] * data[3] - data[1] * data[2]) / sx);
    CGFloat colSum = data[0] * data[2] + data[1] * data[3];
    CGFloat rowSum = data[0] * data[1] + data[2] * data[3];
    // Keep the determinant's sign for reflections. Inferring both scale signs
    // from the diagonal loses the negative axis at a 45-degree page fold.
    BOOL scaleBefore = rowSum != 0.f || sx == sy || sy < 0.f;

    NSMutableArray<NSDictionary<NSString*, id>*>* transforms = [[NSMutableArray alloc] init];

    // tx, ty to translate
    if(data[4] != 0.f || data[5] != 0.f) {
        [transforms addObject:@{
            @"name" : @"translate",
            @"data" : @[ @(data[4]), @(data[5]) ]
        }];
    }

    // [sx, 0, tan(a).sy, sy, 0, 0] to skewX(a).scale(sx,sy)
    if(data[1] == 0.f && data[2] != 0.f) {
        [transforms addObject:@{
            @"name" : @"skewX",
            @"data" : @[ @(IJSVGMathAtan(data[2] / sy))]
        }];

        // [sx, sy.tan(a), 0, sy, 0, 0] to skewX(a).scale(sx, sy)
    } else if(data[1] != 0.f && data[2] == 0.f) {
        [transforms addObject:@{
            @"name" : @"skewY",
            @"data" : @[ @(IJSVGMathAtan(data[1] / data[0]))]
        }];
        sx = data[0];
        sy = data[3];
    } else if(colSum == 0.f || (sx == 1.f && sy == 1.f) || !scaleBefore) {
        if(!scaleBefore) {
            sx = (data[0] < 0.f ? -1.f : 1.f) * hypotf(data[0], data[2]);
            sy = (data[3] < 0.f ? -1.f : 1.f) * hypotf(data[1], data[3]);
            if(sx != 1.f || sy != 1.f) {
                [transforms addObject:@{
                    @"name" : @"scale",
                    @"data" : (sx == sy) ? @[ @(sx) ] : @[ @(sx), @(sy) ]
                }];
            }
        }

        CGFloat angle = MIN(MAX(-1.f, data[0] / sx), 1.f);
        NSMutableArray<NSNumber*>* rotate = [[NSMutableArray alloc] initWithCapacity:3];
        [rotate addObject:@(IJSVGMathAcos(angle) * ((scaleBefore ? 1.f : sy) * data[1] < 0.f ? -1.f: 1.f))];

        if(rotate[0].floatValue != 0.f) {
            [transforms addObject:@{
                @"name" : @"rotate",
                @"data" : rotate
            }];
        }

        if(rowSum != 0.f && colSum != 0.f) {
            [transforms addObject:@{
                @"name" : @"skewX",
                @"data" : @[ @(IJSVGMathAtan(colSum / (sx * sx)))]
            }];
        }

        // rotate can consume translate
        if(rotate[0].floatValue != 0.f && (data[4] != 0.f || data[5] != 0.f)) {
            [transforms removeObjectAtIndex:0];
            CGFloat cos = data[0] / sx;
            CGFloat sin = data[1] / (scaleBefore ? sx : sy);
            CGFloat x = data[4] * (scaleBefore ? 1.f : sy);
            CGFloat y = data[5] * (scaleBefore ? 1.f : sx);
            CGFloat denom = (powf(1.f - cos, 2.f) + powf(sin, 2.f)) * (scaleBefore ? 1.f : (sx * sy));
            [rotate addObject:@(((1.f - cos) * x - sin * y) / denom)];
            [rotate addObject:@(((1.f - cos) * y + sin * x) / denom)];
        }
    } else if(data[1] != 0.f || data[2] != 0.f) {
        NSDictionary<NSString*, id>* trans = @{
            @"name" : @"matrix",
            @"data" : @[ @(data[0]), @(data[1]), @(data[2]), @(data[3]), @(data[4]), @(data[5]) ]
        };
        return @[ trans ];
    }

    if(scaleBefore == YES && ((sx != 1.f || sy != 1.f) || transforms.count == 0)) {
        NSDictionary<NSString*, id>* trans = @{
            @"name" : @"scale",
            @"data" : (sx == sy) ? @[ @(sx) ] : @[ @(sx), @(sy) ]
        };
        [transforms addObject:trans];
    }

    return transforms;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ %@", [super description],
            [self.class affineTransformToSVGTransformComponentString:self.CGAffineTransform]];
}

@end
