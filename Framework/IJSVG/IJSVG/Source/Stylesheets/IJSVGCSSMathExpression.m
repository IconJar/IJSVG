//
//  IJSVGCSSMathExpression.m
//  IJSVG
//
//  Created by Curtis Hard on 12/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGUnitLength.h>
#import <IJSVGCSSMathExpression.h>

typedef NS_ENUM(uint8_t, IJSVGCalculationOperation) { IJSVGCalculationLiteral,
    IJSVGCalculationAdd,
    IJSVGCalculationSubtract,
    IJSVGCalculationMultiply,
    IJSVGCalculationDivide,
    IJSVGCalculationMin,
    IJSVGCalculationMax,
    IJSVGCalculationClamp };

typedef NS_OPTIONS(uint8_t, IJSVGCalculationDependencies) { IJSVGCalculationPercentage = 1 << 0,
    IJSVGCalculationFont = 1 << 1,
    IJSVGCalculationLength = 1 << 2 };

enum { IJSVGCalculationInvalid = UINT32_MAX };

// Postorder storage: children precede their parent. Argument lists link
// indices, so reallocations and copying never leave dangling pointers.
typedef struct {
    CGFloat scalar;
    CGFloat constantValue;
    uint32_t first;
    uint32_t next;
    int32_t exponent;
    IJSVGCalculationOperation operation;
    IJSVGUnitLengthType unit;
    IJSVGCalculationDependencies dependencies;
    BOOL constant;
} IJSVGCalculationNode;

typedef struct {
    const IJSVGCSSComponent* tokens;
    IJSVGCalculationNode* nodes;
    uint32_t count;
    uint32_t capacity;
    BOOL validatesOnly;
} IJSVGCalculationParser;

static CGFloat IJSVGCalculationMinimum(CGFloat left, CGFloat right)
{
    // The C functions fmin and fmax need not distinguish signed zero, while CSS
    // calculations do.
    if (left == 0.f && right == 0.f) {
        return signbit(left) || signbit(right) ? -0.0 : 0.0;
    }
    return fmin(left, right);
}

static CGFloat IJSVGCalculationMaximum(CGFloat left, CGFloat right)
{
    if (left == 0.f && right == 0.f) {
        return signbit(left) && signbit(right) ? -0.0 : 0.0;
    }
    return fmax(left, right);
}

static CGFloat IJSVGCalculationEvaluate(const IJSVGCalculationNode* nodes, uint32_t index, IJSVGCSSCalculationContext context)
{
    const IJSVGCalculationNode* node = nodes + index;
    if (node->constant) {
        return node->constantValue;
    }
    if (node->operation == IJSVGCalculationLiteral) {
        switch (node->unit) {
            case IJSVGUnitLengthTypePercentage: {
                return node->scalar * context.percentage;
            }
            case IJSVGUnitLengthTypeEM: {
                return node->scalar * context.fontSize;
            }
            case IJSVGUnitLengthTypeEX: {
                return node->scalar * context.xHeight;
            }
            default: {
                return node->scalar;
            }
        }
    }
    uint32_t argument = node->first;
    CGFloat value = IJSVGCalculationEvaluate(nodes, argument, context);
    for (argument = nodes[argument].next; argument != IJSVGCalculationInvalid; argument = nodes[argument].next) {
        CGFloat next = IJSVGCalculationEvaluate(nodes, argument, context);
        if (isnan(value) || isnan(next)) {
            return NAN;
        }
        switch (node->operation) {
            case IJSVGCalculationAdd: {
                value += next;
                break;
            }
            case IJSVGCalculationSubtract: {
                value -= next;
                break;
            }
            case IJSVGCalculationMultiply: {
                value *= next;
                break;
            }
            case IJSVGCalculationDivide: {
                value /= next;
                break;
            }
            case IJSVGCalculationMin: {
                value = IJSVGCalculationMinimum(value, next);
                break;
            }
            case IJSVGCalculationMax: {
                value = IJSVGCalculationMaximum(value, next);
                break;
            }
            case IJSVGCalculationClamp: {
                CGFloat maximum = IJSVGCalculationEvaluate(nodes, nodes[argument].next, context);
                return isnan(maximum) ? NAN : IJSVGCalculationMaximum(value, IJSVGCalculationMinimum(next, maximum));
            }
            default: {
                break;
            }
        }
    }
    return value;
}

static void IJSVGCalculationUpdate(IJSVGCalculationNode* nodes, uint32_t index, BOOL evaluate)
{
    IJSVGCalculationNode* node = nodes + index;
    node->constant = NO;
    node->dependencies = 0;
    if (node->operation == IJSVGCalculationLiteral) {
        node->exponent = node->unit == IJSVGUnitLengthTypeNumber ? 0 : 1;
        if (node->unit == IJSVGUnitLengthTypePercentage) {
            node->dependencies = IJSVGCalculationPercentage;
        } else if (node->unit != IJSVGUnitLengthTypeNumber) {
            node->dependencies = IJSVGCalculationLength;
            if (node->unit == IJSVGUnitLengthTypeEM || node->unit == IJSVGUnitLengthTypeEX) {
                node->dependencies |= IJSVGCalculationFont;
            }
        }
    } else {
        for (uint32_t argument = node->first; argument != IJSVGCalculationInvalid; argument = nodes[argument].next) {
            node->dependencies |= nodes[argument].dependencies;
        }
    }
    if (evaluate && (node->dependencies & (IJSVGCalculationPercentage | IJSVGCalculationFont)) == 0) {
        node->constantValue = IJSVGCalculationEvaluate(nodes, index, (IJSVGCSSCalculationContext) { 0, 0, 0 });
        node->constant = YES;
    }
}

static uint32_t IJSVGCalculationAppend(IJSVGCalculationParser* parser, IJSVGCalculationNode node)
{
    if (parser->count == parser->capacity) {
        return IJSVGCalculationInvalid;
    }
    uint32_t index = parser->count++;
    node.next = IJSVGCalculationInvalid;
    parser->nodes[index] = node;
    IJSVGCalculationUpdate(parser->nodes, index, !parser->validatesOnly);
    return index;
}

static uint32_t IJSVGCalculationLiteralValue(IJSVGCalculationParser* parser, CGFloat value, IJSVGUnitLengthType unit)
{
    IJSVGCalculationNode node = { 0 };
    node.scalar = value;
    node.unit = unit;
    node.first = IJSVGCalculationInvalid;
    return IJSVGCalculationAppend(parser, node);
}

static uint32_t IJSVGCalculationMake(IJSVGCalculationParser* parser, IJSVGCalculationOperation operation, uint32_t first)
{
    int32_t exponent = parser->nodes[first].exponent;
    for (uint32_t argument = parser->nodes[first].next; argument != IJSVGCalculationInvalid; argument = parser->nodes[argument].next) {
        int32_t next = parser->nodes[argument].exponent;
        if (operation == IJSVGCalculationMultiply) {
            exponent += next;
        } else if (operation == IJSVGCalculationDivide) {
            exponent -= next;
        } else if (next != exponent) {
            return IJSVGCalculationInvalid;
        }
    }
    IJSVGCalculationNode node = { 0 };
    node.operation = operation;
    node.first = first;
    node.exponent = exponent;
    return IJSVGCalculationAppend(parser, node);
}

static uint32_t IJSVGCalculationSum(IJSVGCalculationParser* parser, NSUInteger* index, NSUInteger end);

static uint32_t IJSVGCalculationFunctionValue(IJSVGCalculationParser* parser, const IJSVGCSSComponent* token, NSUInteger child)
{
    if (!IJSVGCSSFunctionIsCalculation(token->function)) {
        return IJSVGCalculationInvalid;
    }
    uint32_t first = IJSVGCalculationInvalid, last = IJSVGCalculationInvalid;
    NSUInteger count = 0;
    do {
        uint32_t value = IJSVGCalculationSum(parser, &child, token->next);
        if (value == IJSVGCalculationInvalid) {
            return value;
        }
        if (first == IJSVGCalculationInvalid) {
            first = value;
        } else {
            parser->nodes[last].next = value;
        }
        last = value;
        count++;
        if (child == token->next) {
            break;
        }
        const IJSVGCSSComponent* comma = parser->tokens + child;
        if (comma->kind != IJSVGCSSComponentDelimiter || comma->symbol != IJSVGCSSSymbolComma) {
            return IJSVGCalculationInvalid;
        }
        child = comma->next;
    } while (child <= token->next);
    switch (token->function) {
        case IJSVGCSSFunctionCalc:
            return count == 1 ? first : IJSVGCalculationInvalid;
        case IJSVGCSSFunctionMin:
            return IJSVGCalculationMake(parser, IJSVGCalculationMin, first);
        case IJSVGCSSFunctionMax:
            return IJSVGCalculationMake(parser, IJSVGCalculationMax, first);
        case IJSVGCSSFunctionClamp:
            return count == 3 ? IJSVGCalculationMake(parser, IJSVGCalculationClamp, first) : IJSVGCalculationInvalid;
        default: {
            return IJSVGCalculationInvalid;
        }
    }
}

static uint32_t IJSVGCalculationKeywordValue(IJSVGCalculationParser* parser, IJSVGCSSNumericKeyword keyword)
{
    CGFloat value;
    switch (keyword) {
        case IJSVGCSSNumericKeywordPi: {
            value = M_PI;
            break;
        }
        case IJSVGCSSNumericKeywordE: {
            value = M_E;
            break;
        }
        case IJSVGCSSNumericKeywordInfinity: {
            value = INFINITY;
            break;
        }
        case IJSVGCSSNumericKeywordNegativeInfinity: {
            value = -INFINITY;
            break;
        }
        case IJSVGCSSNumericKeywordNaN: {
            value = NAN;
            break;
        }
        default: {
            return IJSVGCalculationInvalid;
        }
    }
    return IJSVGCalculationLiteralValue(parser, value, IJSVGUnitLengthTypeNumber);
}

static uint32_t IJSVGCalculationValue(IJSVGCalculationParser* parser, NSUInteger* index, NSUInteger end)
{
    if (*index >= end) {
        return IJSVGCalculationInvalid;
    }
    const IJSVGCSSComponent* token = parser->tokens + *index;
    NSUInteger child = *index + 1;
    *index = token->next;
    switch (token->kind) {
        case IJSVGCSSComponentFunction: {
            return IJSVGCalculationFunctionValue(parser, token, child);
        }
        case IJSVGCSSComponentBlock: {
            if (token->symbol != IJSVGCSSSymbolParenthesis) {
                return IJSVGCalculationInvalid;
            }
            uint32_t result = IJSVGCalculationSum(parser, &child, token->next);
            return child == token->next ? result : IJSVGCalculationInvalid;
        }
        case IJSVGCSSComponentNumber:
            return IJSVGCalculationLiteralValue(parser, token->number, IJSVGUnitLengthTypeNumber);
        case IJSVGCSSComponentPercentage:
            return IJSVGCalculationLiteralValue(parser, token->number / 100.f, IJSVGUnitLengthTypePercentage);
        case IJSVGCSSComponentDimension: {
            if (token->unit == IJSVGUnitLengthTypeNumber) {
                return IJSVGCalculationInvalid;
            }
            CGFloat number = IJSVGConvertUnitValue(token->number, token->unit);
            IJSVGUnitLengthType unit = token->unit;
            if (unit != IJSVGUnitLengthTypeEM && unit != IJSVGUnitLengthTypeEX) {
                unit = IJSVGUnitLengthTypePX;
            }
            return IJSVGCalculationLiteralValue(parser, number, unit);
        }
        case IJSVGCSSComponentIdentifier: {
            return IJSVGCalculationKeywordValue(parser, token->numericKeyword);
        }
        default: {
            return IJSVGCalculationInvalid;
        }
    }
}

static uint32_t IJSVGCalculationProduct(IJSVGCalculationParser* parser, NSUInteger* index, NSUInteger end)
{
    uint32_t result = IJSVGCalculationValue(parser, index, end);
    while (result != IJSVGCalculationInvalid && *index < end) {
        const IJSVGCSSComponent* token = parser->tokens + *index;
        if (token->kind != IJSVGCSSComponentDelimiter || (token->symbol != IJSVGCSSSymbolMultiply && token->symbol != IJSVGCSSSymbolDivide)) {
            break;
        }
        *index = token->next;
        uint32_t right = IJSVGCalculationValue(parser, index, end);
        if (right == IJSVGCalculationInvalid) {
            return right;
        }
        parser->nodes[result].next = right;
        result = IJSVGCalculationMake(parser, token->symbol == IJSVGCSSSymbolMultiply ? IJSVGCalculationMultiply : IJSVGCalculationDivide, result);
    }
    return result;
}

static uint32_t IJSVGCalculationSum(IJSVGCalculationParser* parser, NSUInteger* index, NSUInteger end)
{
    uint32_t result = IJSVGCalculationProduct(parser, index, end);
    while (result != IJSVGCalculationInvalid && *index < end) {
        const IJSVGCSSComponent* token = parser->tokens + *index;
        if (token->kind != IJSVGCSSComponentDelimiter || (token->symbol != IJSVGCSSSymbolAdd && token->symbol != IJSVGCSSSymbolSubtract)) {
            break;
        }
        *index = token->next;
        if (!token->precedingWhitespace || *index == end || !parser->tokens[*index].precedingWhitespace) {
            return IJSVGCalculationInvalid;
        }
        uint32_t right = IJSVGCalculationProduct(parser, index, end);
        if (right == IJSVGCalculationInvalid) {
            return right;
        }
        parser->nodes[result].next = right;
        result = IJSVGCalculationMake(parser, token->symbol == IJSVGCSSSymbolAdd ? IJSVGCalculationAdd : IJSVGCalculationSubtract, result);
    }
    return result;
}

static BOOL IJSVGCalculationIsArithmetic(IJSVGCalculationOperation operation)
{
    return operation >= IJSVGCalculationAdd && operation <= IJSVGCalculationDivide;
}

// Export is outside the evaluation path and appends into one buffer.
static void IJSVGCalculationSerialize(const IJSVGCalculationNode* nodes, uint32_t index, NSMutableString* string)
{
    const IJSVGCalculationNode* node = nodes + index;
    if (node->operation == IJSVGCalculationLiteral) {
        NSString* unit = @"";
        switch (node->unit) {
            case IJSVGUnitLengthTypePercentage: {
                unit = @"%";
                break;
            }
            case IJSVGUnitLengthTypeEM: {
                unit = @"em";
                break;
            }
            case IJSVGUnitLengthTypeEX: {
                unit = @"ex";
                break;
            }
            case IJSVGUnitLengthTypePX: {
                unit = @"px";
                break;
            }
            default: {
                break;
            }
        }
        if (!isfinite(node->scalar)) {
            NSString* keyword = isnan(node->scalar) ? @"NaN" : (node->scalar < 0 ? @"-infinity" : @"infinity");
            if (unit.length == 0) {
                [string appendString:keyword];
            } else {
                [string appendFormat:@"calc(%@ * 1%@)", keyword, unit];
            }
        } else {
            CGFloat scalar = node->unit == IJSVGUnitLengthTypePercentage ? node->scalar * 100.f : node->scalar;
            [string appendFormat:@"%.17g%@", (double)scalar, unit];
        }
        return;
    }
    BOOL arithmetic = IJSVGCalculationIsArithmetic(node->operation);
    if (!arithmetic) {
        NSString* name = node->operation == IJSVGCalculationMin ? @"min" : (node->operation == IJSVGCalculationMax ? @"max" : @"clamp");
        [string appendFormat:@"%@(", name];
    }
    NSUInteger precedence = node->operation <= IJSVGCalculationSubtract ? 1 : 2;
    NSUInteger count = 0;
    for (uint32_t argument = node->first; argument != IJSVGCalculationInvalid; argument = nodes[argument].next) {
        const IJSVGCalculationNode* child = nodes + argument;
        if (count != 0) {
            if (arithmetic) {
                static NSString* const separators[] = { @"", @" + ", @" - ", @" * ", @" / " };
                [string appendString:separators[node->operation]];
            } else {
                [string appendString:@", "];
            }
        }
        NSUInteger childPrecedence = child->operation <= IJSVGCalculationSubtract ? 1 : 2;
        BOOL parentheses = arithmetic && IJSVGCalculationIsArithmetic(child->operation) && (childPrecedence < precedence || (count != 0 && childPrecedence == precedence));
        if (parentheses) {
            [string appendString:@"("];
        }
        IJSVGCalculationSerialize(nodes, argument, string);
        if (parentheses) {
            [string appendString:@")"];
        }
        count++;
    }
    if (!arithmetic) {
        [string appendString:@")"];
    }
}

static uint32_t IJSVGCalculationParseRoot(IJSVGCalculationParser* parser, NSUInteger index, NSUInteger end)
{
    uint32_t root = IJSVGCalculationValue(parser, &index, end);
    if (root == IJSVGCalculationInvalid || index != end || (parser->nodes[root].exponent != 0 && parser->nodes[root].exponent != 1)) {
        return IJSVGCalculationInvalid;
    }
    return root;
}

BOOL IJSVGCSSMathExpressionIsValid(const IJSVGCSSComponents* components, NSUInteger index)
{
    if (index >= components->count || components->values[index].kind != IJSVGCSSComponentFunction) {
        return NO;
    }
    NSUInteger end = components->values[index].next;
    uint32_t capacity = (uint32_t)(end - index);
    IJSVGCalculationNode inlineNodes[IJSVGCSSParserInlineCapacity];
    IJSVGCalculationNode* nodes = capacity <= IJSVGCSSParserInlineCapacity ? inlineNodes : malloc(capacity * sizeof(*nodes));
    if (nodes == NULL) {
        return NO;
    }
    IJSVGCalculationParser parser = { components->values, nodes, 0, capacity, YES };
    BOOL valid = IJSVGCalculationParseRoot(&parser, index, end) != IJSVGCalculationInvalid;
    if (nodes != inlineNodes) {
        free(nodes);
    }
    return valid;
}

BOOL IJSVGCSSMathExpressionEvaluateNumber(const IJSVGCSSComponents* components, NSUInteger index, CGFloat percentage, IJSVGCSSNumericValue* result)
{
    if (index >= components->count || components->values[index].kind != IJSVGCSSComponentFunction) {
        return NO;
    }
    NSUInteger end = components->values[index].next;
    uint32_t capacity = (uint32_t)(end - index);
    IJSVGCalculationNode inlineNodes[IJSVGCSSParserInlineCapacity];
    IJSVGCalculationNode* nodes = capacity <= IJSVGCSSParserInlineCapacity ? inlineNodes : malloc(capacity * sizeof(*nodes));
    if (nodes == NULL) {
        return NO;
    }
    IJSVGCalculationParser parser = { components->values, nodes, 0, capacity, YES };
    uint32_t root = IJSVGCalculationParseRoot(&parser, index, end);
    BOOL valid = root != IJSVGCalculationInvalid && (nodes[root].dependencies & (IJSVGCalculationLength | IJSVGCalculationFont)) == 0;
    if (valid) {
        result->value = IJSVGCalculationEvaluate(nodes, root, (IJSVGCSSCalculationContext) { percentage, 0, 0 });
        result->percentage = nodes[root].exponent == 1;
    }
    if (nodes != inlineNodes) {
        free(nodes);
    }
    return valid;
}

@implementation IJSVGCSSMathExpression {
    IJSVGCalculationNode* _nodes;
    uint32_t _count;
    uint32_t _root;
}

+ (instancetype)expressionWithComponents:(const IJSVGCSSComponents*)components atIndex:(NSUInteger)index
{
    if (index >= components->count || components->values[index].kind != IJSVGCSSComponentFunction) {
        return nil;
    }
    NSUInteger end = components->values[index].next;
    uint32_t capacity = (uint32_t)(end - index);
    IJSVGCalculationNode* nodes = malloc(capacity * sizeof(*nodes));
    if (nodes == NULL) {
        return nil;
    }
    IJSVGCalculationParser parser = { components->values, nodes, 0, capacity, NO };
    uint32_t root = IJSVGCalculationParseRoot(&parser, index, end);
    if (root == IJSVGCalculationInvalid) {
        free(nodes);
        return nil;
    }
    IJSVGCSSMathExpression* result = [[self alloc] init];
    result->_nodes = nodes;
    result->_count = parser.count;
    result->_root = root;
    return result;
}

- (void)dealloc
{
    free(_nodes);
}

- (NSInteger)lengthExponent
{
    return _nodes[_root].exponent;
}

- (BOOL)usesPercentage
{
    return (_nodes[_root].dependencies & IJSVGCalculationPercentage) != 0;
}

- (BOOL)usesFontMetrics
{
    return (_nodes[_root].dependencies & IJSVGCalculationFont) != 0;
}

- (BOOL)usesLength
{
    return (_nodes[_root].dependencies & IJSVGCalculationLength) != 0;
}

- (CGFloat)evaluate:(IJSVGCSSCalculationContext)context
{
    return IJSVGCalculationEvaluate(_nodes, _root, context);
}

- (IJSVGCSSMathExpression*)copyArena
{
    IJSVGCSSMathExpression* result = [[self.class alloc] init];
    result->_nodes = malloc((_count + 2) * sizeof(*_nodes));
    if (result->_nodes == NULL) {
        [NSException raise:NSMallocException format:@"Unable to copy CSS calculation"];
    }
    memcpy(result->_nodes, _nodes, _count * sizeof(*_nodes));
    result->_count = _count;
    result->_root = _root;
    return result;
}

- (IJSVGCSSMathExpression*)expressionByResolvingFontSize:(CGFloat)fontSize xHeight:(CGFloat)xHeight
{
    if (!self.usesFontMetrics) {
        return self;
    }
    IJSVGCSSMathExpression* result = [self copyArena];
    for (uint32_t index = 0; index < _count; index++) {
        IJSVGCalculationNode* node = result->_nodes + index;
        if (node->operation == IJSVGCalculationLiteral && (node->unit == IJSVGUnitLengthTypeEM || node->unit == IJSVGUnitLengthTypeEX)) {
            node->scalar *= node->unit == IJSVGUnitLengthTypeEM ? fontSize : xHeight;
            node->unit = IJSVGUnitLengthTypePX;
        }
        IJSVGCalculationUpdate(result->_nodes, index, YES);
    }
    return result;
}

- (IJSVGCSSMathExpression*)expressionByScalingLengths:(CGFloat)scale
{
    if (scale == 1.f) {
        return self;
    }
    IJSVGCSSMathExpression* result = [self copyArena];
    if (self.lengthExponent == 0) {
        // Only the final SVG number is a length in user units. Intermediate numbers
        // remain dimensionless multipliers.
        IJSVGCalculationParser parser = { NULL, result->_nodes, _count, _count + 2, NO };
        uint32_t multiplier = IJSVGCalculationLiteralValue(&parser, scale, IJSVGUnitLengthTypeNumber);
        result->_nodes[_root].next = multiplier;
        result->_root = IJSVGCalculationMake(&parser, IJSVGCalculationMultiply, _root);
        result->_count = parser.count;
    } else {
        for (uint32_t index = 0; index < _count; index++) {
            IJSVGCalculationNode* node = result->_nodes + index;
            if (node->operation == IJSVGCalculationLiteral && node->unit != IJSVGUnitLengthTypeNumber && node->unit != IJSVGUnitLengthTypePercentage) {
                node->scalar *= scale;
            }
            IJSVGCalculationUpdate(result->_nodes, index, YES);
        }
    }
    return result;
}

- (NSString*)stringValue
{
    NSMutableString* result = [[NSMutableString alloc] init];
    BOOL arithmetic = IJSVGCalculationIsArithmetic(_nodes[_root].operation);
    if (arithmetic) {
        [result appendString:@"calc("];
    }
    IJSVGCalculationSerialize(_nodes, _root, result);
    if (arithmetic) {
        [result appendString:@")"];
    }
    return result;
}

@end
