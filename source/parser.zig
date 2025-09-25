// parser.zig
const std = @import("std");
const Memory = @import("memory.zig");
const Lexer = @import("lexer.zig");
const TokenType = Lexer.TokenType;
const Token = Lexer.Token;

// AST Node types
pub const Statement = union(enum) {
    expression_stmt: ExpressionStatement,
    assignment: Assignment,
    function_declaration: FunctionDeclaration,
    label: LabelStatement,
    goto_stmt: GotoStatement,
    if_statement: IfStatement,
    while_statement: WhileStatement,
    return_statement: ReturnStatement,
    activator_declaration: ActivatorDeclaration,

    pub fn deinit(self: *Statement, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .expression_stmt => |*stmt| stmt.deinit(allocator),
            .assignment => |*stmt| stmt.deinit(allocator),
            .function_declaration => |*stmt| stmt.deinit(allocator),
            .label => |*stmt| stmt.deinit(allocator),
            .goto_stmt => |*stmt| stmt.deinit(allocator),
            .if_statement => |*stmt| stmt.deinit(allocator),
            .while_statement => |*stmt| stmt.deinit(allocator),
            .return_statement => |*stmt| stmt.deinit(allocator),
            .activator_declaration => |*stmt| stmt.deinit(allocator),
        }
    }
};

pub const Expression = union(enum) {
    literal: Literal,
    identifier: Identifier,
    property_access: PropertyAccess,
    index_access: IndexAccess,
    binary: BinaryExpression,
    unary: UnaryExpression,
    call: CallExpression,
    record_literal: RecordLiteral,
    list_literal: ListLiteral,

    pub fn deinit(self: *Expression, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .literal => |*expr| expr.deinit(allocator),
            .identifier => |*expr| expr.deinit(allocator),
            .property_access => |*expr| expr.deinit(allocator),
            .index_access => |*expr| expr.deinit(allocator),
            .binary => |*expr| expr.deinit(allocator),
            .unary => |*expr| expr.deinit(allocator),
            .call => |*expr| expr.deinit(allocator),
            .record_literal => |*expr| expr.deinit(allocator),
            .list_literal => |*expr| expr.deinit(allocator),
        }
    }
};

pub const ExpressionStatement = struct {
    expression: Expression,

    pub fn deinit(self: *ExpressionStatement, allocator: std.mem.Allocator) void {
        self.expression.deinit(allocator);
    }
};

pub const Assignment = struct {
    target: Expression,  // Left side (identifier, property access, etc.)
    value: Expression,   // Right side

    pub fn deinit(self: *Assignment, allocator: std.mem.Allocator) void {
        self.target.deinit(allocator);
        self.value.deinit(allocator);
    }
};

pub const FunctionDeclaration = struct {
    name: []const u8,
    parameters: []Parameter,
    body: []Statement,

    pub fn deinit(self: *FunctionDeclaration, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.parameters) |*param| {
            param.deinit(allocator);
        }
        allocator.free(self.parameters);
        for (self.body) |*stmt| {
            stmt.deinit(allocator);
        }
        allocator.free(self.body);
    }
};

pub const Parameter = struct {
    name: []const u8,
    default_value: ?Expression,

    pub fn deinit(self: *Parameter, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.default_value) |*default| {
            default.deinit(allocator);
        }
    }
};

pub const LabelStatement = struct {
    name: []const u8,

    pub fn deinit(self: *LabelStatement, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

pub const GotoStatement = struct {
    target: []const u8,

    pub fn deinit(self: *GotoStatement, allocator: std.mem.Allocator) void {
        allocator.free(self.target);
    }
};

pub const IfStatement = struct {
    condition: Expression,
    then_branch: []Statement,
    else_branch: ?[]Statement,

    pub fn deinit(self: *IfStatement, allocator: std.mem.Allocator) void {
        self.condition.deinit(allocator);
        for (self.then_branch) |*stmt| {
            stmt.deinit(allocator);
        }
        allocator.free(self.then_branch);
        if (self.else_branch) |else_stmts| {
            for (else_stmts) |*stmt| {
                stmt.deinit(allocator);
            }
            allocator.free(else_stmts);
        }
    }
};

pub const WhileStatement = struct {
    condition: Expression,
    body: []Statement,

    pub fn deinit(self: *WhileStatement, allocator: std.mem.Allocator) void {
        self.condition.deinit(allocator);
        for (self.body) |*stmt| {
            stmt.deinit(allocator);
        }
        allocator.free(self.body);
    }
};

pub const ReturnStatement = struct {
    value: ?Expression,

    pub fn deinit(self: *ReturnStatement, allocator: std.mem.Allocator) void {
        if (self.value) |*expr| {
            expr.deinit(allocator);
        }
    }
};

pub const ActivatorDeclaration = struct {
    name: []const u8,
    condition: Expression,
    body: []Statement,

    pub fn deinit(self: *ActivatorDeclaration, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.condition.deinit(allocator);
        for (self.body) |*stmt| {
            stmt.deinit(allocator);
        }
        allocator.free(self.body);
    }
};

pub const Literal = union(enum) {
    text: []const u8,
    number: f64,
    money: MoneyLiteral,
    time: TimeLiteral,
    duration: DurationLiteral,
    boolean: bool,
    nothing: void,
    unknown: void,
    quote: void,
    empty: void,

    pub fn deinit(self: *Literal, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .text => |text| allocator.free(text),
            .money => |*money| money.deinit(allocator),
            .time => |*time| time.deinit(allocator),
            .duration => |*duration| duration.deinit(allocator),
            else => {}, // Other literals don't need cleanup
        }
    }
};

pub const MoneyLiteral = struct {
    amount: f64,
    currency: ?[]const u8,

    pub fn deinit(self: *MoneyLiteral, allocator: std.mem.Allocator) void {
        if (self.currency) |currency| {
            allocator.free(currency);
        }
    }
};

pub const TimeLiteral = struct {
    value: []const u8, // Store raw time string, will be parsed by interpreter

    pub fn deinit(self: *TimeLiteral, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
    }
};

pub const DurationLiteral = struct {
    value: f64,
    unit: []const u8, // "days", "hours", "minutes", "seconds"

    pub fn deinit(self: *DurationLiteral, allocator: std.mem.Allocator) void {
        allocator.free(self.unit);
    }
};

pub const Identifier = struct {
    name: []const u8,

    pub fn deinit(self: *Identifier, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

pub const PropertyAccess = struct {
    object: *Expression,
    property: []const u8,

    pub fn deinit(self: *PropertyAccess, allocator: std.mem.Allocator) void {
        self.object.deinit(allocator);
        allocator.destroy(self.object);
        allocator.free(self.property);
    }
};

pub const IndexAccess = struct {
    object: *Expression,
    index: *Expression,

    pub fn deinit(self: *IndexAccess, allocator: std.mem.Allocator) void {
        self.object.deinit(allocator);
        allocator.destroy(self.object);
        self.index.deinit(allocator);
        allocator.destroy(self.index);
    }
};

pub const BinaryExpression = struct {
    left: *Expression,
    operator: BinaryOperator,
    right: *Expression,

    pub fn deinit(self: *BinaryExpression, allocator: std.mem.Allocator) void {
        self.left.deinit(allocator);
        allocator.destroy(self.left);
        self.right.deinit(allocator);
        allocator.destroy(self.right);
    }
};

pub const UnaryExpression = struct {
    operator: UnaryOperator,
    operand: *Expression,

    pub fn deinit(self: *UnaryExpression, allocator: std.mem.Allocator) void {
        self.operand.deinit(allocator);
        allocator.destroy(self.operand);
    }
};

pub const BinaryOperator = enum {
    // Arithmetic
    add,
    subtract,
    multiply,
    divide,
    modulo,

    // Comparison
    equal,
    not_equal,
    less_than,
    greater_than,
    less_equal,
    greater_equal,

    // Logical
    logical_and,
    logical_or,
};

pub const UnaryOperator = enum {
    minus,
    logical_not,
};

pub const CallExpression = struct {
    callee: *Expression,
    arguments: []Expression,

    pub fn deinit(self: *CallExpression, allocator: std.mem.Allocator) void {
        self.callee.deinit(allocator);
        allocator.destroy(self.callee);
        for (self.arguments) |*arg| {
            arg.deinit(allocator);
        }
        allocator.free(self.arguments);
    }
};

pub const RecordLiteral = struct {
    fields: []RecordField,

    pub fn deinit(self: *RecordLiteral, allocator: std.mem.Allocator) void {
        for (self.fields) |*field| {
            field.deinit(allocator);
        }
        allocator.free(self.fields);
    }
};

pub const RecordField = struct {
    key: Expression, // Can be identifier or string
    value: Expression,

    pub fn deinit(self: *RecordField, allocator: std.mem.Allocator) void {
        self.key.deinit(allocator);
        self.value.deinit(allocator);
    }
};

pub const ListLiteral = struct {
    elements: []Expression,

    pub fn deinit(self: *ListLiteral, allocator: std.mem.Allocator) void {
        for (self.elements) |*element| {
            element.deinit(allocator);
        }
        allocator.free(self.elements);
    }
};

pub const ParseError = error{
    UnexpectedToken,
    ExpectedExpression,
    ExpectedStatement,
    ExpectedIdentifier,
    ExpectedColon,
    ExpectedParenthesis,
    UnexpectedEndOfFile,
    OutOfMemory,
};

pub const Parser = struct {
    tokens: []Token,
    current: usize,
    allocator: std.mem.Allocator,
    indent_level: usize,

    pub fn init(allocator: std.mem.Allocator, tokens: []Token) Parser {
        return Parser{
            .tokens = tokens,
            .current = 0,
            .allocator = allocator,
            .indent_level = 0,
        };
    }

    pub fn parse(self: *Parser) ParseError![]Statement {
        var statements = std.ArrayList(Statement).init(self.allocator);

        // Skip initial newlines and indents
        self.skipWhitespace();

        while (!self.isAtEnd()) {
            if (self.parseStatement()) |stmt| {
                try statements.append(stmt);
                self.skipWhitespace();
            } else |err| {
                // Cleanup on error
                for (statements.items) |*stmt| {
                    stmt.deinit(self.allocator);
                }
                statements.deinit();
                return err;
            }
        }

        return statements.toOwnedSlice();
    }

    fn parseStatement(self: *Parser) ParseError!Statement {
        // Handle indentation
        const _current_indent = self.countIndentation();
        _ = _current_indent;

        // Check if this is a label, function, or activator by looking ahead
        if (self.check(.identifier)) {
            const _name_token = self.peek();
            _ = _name_token;

            // Look ahead for pattern recognition
            if (self.checkNext(.colon)) {
                // Simple case: identifier : (label or activator)
                if (self.hasConditionAfterName()) {
                    return self.parseActivatorDeclaration();
                } else {
                    return self.parseLabelStatement();
                }
            } else if (self.checkNext(.left_paren)) {
                // Function case: identifier ( params ) :
                const saved_pos = self.current;
                _ = self.advance(); // Skip identifier
                _ = self.advance(); // Skip (

                // Skip parameters until )
                var paren_depth: usize = 1;
                while (!self.isAtEnd() and paren_depth > 0) {
                    if (self.check(.left_paren)) {
                        paren_depth += 1;
                    } else if (self.check(.right_paren)) {
                        paren_depth -= 1;
                    }
                    if (paren_depth > 0) {
                        _ = self.advance();
                    }
                }

                // Check if we have ) :
                if (self.check(.right_paren) and self.checkAt(self.current + 1, .colon)) {
                    self.current = saved_pos; // Restore position
                    return self.parseFunctionDeclaration();
                }

                // Restore position if not a function
                self.current = saved_pos;
            }
        }

        // Regular statements
        if (self.match(.if_kw)) {
            return Statement{ .if_statement = try self.parseIfStatement() };
        }
        if (self.match(.while_kw)) {
            return Statement{ .while_statement = try self.parseWhileStatement() };
        }
        if (self.match(.return_kw)) {
            return Statement{ .return_statement = try self.parseReturnStatement() };
        }
        if (self.match(.goto_kw)) {
            return Statement{ .goto_stmt = try self.parseGotoStatement() };
        }

        // Assignment or expression statement
        return self.parseAssignmentOrExpression();
    }

    fn hasConditionAfterName(self: *Parser) bool {
        // Scan ahead to see if there's a condition pattern after the name
        var pos = self.current + 1; // Skip identifier
        while (pos < self.tokens.len and self.tokens[pos].type != .colon) {
            const token_type = self.tokens[pos].type;
            if (token_type == .assign or token_type == .less_than or
               token_type == .greater_than or token_type == .not_equal or
               token_type == .and_kw or token_type == .or_kw) {
                return true;
            }
            pos += 1;
        }
        return false;
    }

    fn parseFunctionDeclaration(self: *Parser) ParseError!Statement {
        const name_token = try self.consume(.identifier, "Expected function name");
        const name = try self.allocator.dupe(u8, name_token.lexeme);

        _ = try self.consume(.left_paren, "Expected '(' after function name");

        var parameters = std.ArrayList(Parameter).init(self.allocator);

        // Parse parameters
        if (!self.check(.right_paren)) {
            while (true) {
                const param_name = try self.consume(.identifier, "Expected parameter name");
                var default_value: ?Expression = null;

                if (self.match(.assign)) {
                    default_value = try self.parseExpression();
                }

                try parameters.append(Parameter{
                    .name = try self.allocator.dupe(u8, param_name.lexeme),
                    .default_value = default_value,
                });

                if (!self.match(.comma)) break;
            }
        }

        _ = try self.consume(.right_paren, "Expected ')' after parameters");
        _ = try self.consume(.colon, "Expected ':' after function signature");

        const body = try self.parseBlock();

        return Statement{ .function_declaration = FunctionDeclaration{
            .name = name,
            .parameters = try parameters.toOwnedSlice(),
            .body = body,
        }};
    }

    fn parseActivatorDeclaration(self: *Parser) ParseError!Statement {
        const name_token = try self.consume(.identifier, "Expected activator name");
        const name = try self.allocator.dupe(u8, name_token.lexeme);

        // Parse condition (everything up to the colon)
        const condition = try self.parseExpression();

        _ = try self.consume(.colon, "Expected ':' after activator condition");

        const body = try self.parseBlock();

        return Statement{ .activator_declaration = ActivatorDeclaration{
            .name = name,
            .condition = condition,
            .body = body,
        }};
    }

    fn parseLabelStatement(self: *Parser) ParseError!Statement {
        const name_token = try self.consumeLabelName("Expected label name");
        const name = try self.allocator.dupe(u8, name_token.lexeme);
        _ = try self.consume(.colon, "Expected ':' after label name");

        return Statement{ .label = LabelStatement{ .name = name }};
    }

    fn parseStatementBlock(self: *Parser) ParseError![]Statement {
        var statements = std.ArrayList(Statement).init(self.allocator);

        // Skip initial newlines and consume indentation
        self.consumeNewlines();

        // Check if we have indented statements
        if (self.check(.indent)) {
            const expected_indent = self.countIndentation();

            while (!self.check(.else_kw) and !self.check(.end_kw) and !self.isAtEnd()) {
                const current_indent = self.countIndentation();

                // If indentation is less than expected, we've reached the end of this block
                if (current_indent < expected_indent) {
                    break;
                }

                // Consume the expected indentation tokens
                var consumed_indent: usize = 0;
                while (self.check(.indent) and consumed_indent < expected_indent) {
                    _ = self.advance();
                    consumed_indent += 1;
                }

                // Now parse the statement (no more INDENT tokens should be present)
                const stmt = try self.parseStatement();
                try statements.append(stmt);

                // Only consume newlines, preserve indentation for next iteration
                while (self.match(.newline)) {}
            }
        } else {
            // No indentation - parse statements on same line until else/end
            while (!self.check(.else_kw) and !self.check(.end_kw) and !self.isAtEnd() and !self.checkNewlineOrSemicolon()) {
                const stmt = try self.parseStatement();
                try statements.append(stmt);
                if (self.match(.semicolon)) {
                    continue;
                } else {
                    break;
                }
            }
        }

        return statements.toOwnedSlice();
    }

    fn parseIfStatement(self: *Parser) ParseError!IfStatement {
        const condition = try self.parseExpression();
        _ = try self.consume(.then_kw, "Expected 'then' after if condition");

        const then_branch = try self.parseStatementBlock();

        var else_branch: ?[]Statement = null;
        if (self.match(.else_kw)) {
            else_branch = try self.parseStatementBlock();
        }

        _ = try self.consume(.end_kw, "Expected 'end' to close if statement");

        return IfStatement{
            .condition = condition,
            .then_branch = then_branch,
            .else_branch = else_branch,
        };
    }

    fn parseWhileStatement(self: *Parser) ParseError!WhileStatement {
        const condition = try self.parseExpression();
        _ = try self.consume(.colon, "Expected ':' after while condition");

        const body = try self.parseBlock();

        return WhileStatement{
            .condition = condition,
            .body = body,
        };
    }

    fn parseReturnStatement(self: *Parser) ParseError!ReturnStatement {
        var value: ?Expression = null;
        if (!self.checkNewlineOrSemicolon()) {
            value = try self.parseExpression();
        }
        self.consumeStatementEnd();

        return ReturnStatement{ .value = value };
    }

    fn parseGotoStatement(self: *Parser) ParseError!GotoStatement {
        const target_token = try self.consumeLabelName("Expected label name after goto");
        const target = try self.allocator.dupe(u8, target_token.lexeme);
        self.consumeStatementEnd();

        return GotoStatement{ .target = target };
    }

    fn parseAssignmentOrExpression(self: *Parser) ParseError!Statement {
        // Save current position to potentially backtrack
        const saved_pos = self.current;

        // Try to parse as assignment target first
        const target = self.parseAssignmentTarget() catch {
            // If parsing as assignment target fails, reset and parse as full expression
            self.current = saved_pos;
            const expr = try self.parseExpression();
            self.consumeStatementEnd();
            return Statement{ .expression_stmt = ExpressionStatement{ .expression = expr }};
        };

        // Check if this is an assignment
        if (self.match(.assign)) {
            const value = try self.parseExpression();
            self.consumeStatementEnd();

            return Statement{ .assignment = Assignment{
                .target = target,
                .value = value,
            }};
        } else {
            // Not an assignment - check if we have more tokens that need parsing (like method calls)
            if (self.check(.left_paren) or self.check(.left_bracket)) {
                // We have more to parse, so reset and parse as full expression
                self.current = saved_pos;
                const expr = try self.parseExpression();
                self.consumeStatementEnd();
                return Statement{ .expression_stmt = ExpressionStatement{ .expression = expr }};
            } else {
                // Simple identifier or property access, use what we have
                self.consumeStatementEnd();
                return Statement{ .expression_stmt = ExpressionStatement{ .expression = target }};
            }
        }
    }

    fn parseAssignmentTarget(self: *Parser) ParseError!Expression {
        // Parse potential assignment targets: identifiers, property access, etc.
        // This is similar to parsePrimary but more limited
        if (self.match(.identifier)) {
            const name = try self.allocator.dupe(u8, self.previous().lexeme);
            var expr = Expression{ .identifier = Identifier{ .name = name }};

            // Handle property access
            while (self.match(.dot)) {
                const prop_name = try self.consume(.identifier, "Expected property name after '.'");
                const property = try self.allocator.dupe(u8, prop_name.lexeme);

                const object_ptr = try self.allocator.create(Expression);
                object_ptr.* = expr;

                expr = Expression{ .property_access = PropertyAccess{
                    .object = object_ptr,
                    .property = property,
                }};
            }

            return expr;
        }

        if (self.match(.program_kw)) {
            const name = try self.allocator.dupe(u8, "program");
            var expr = Expression{ .identifier = Identifier{ .name = name }};

            // Handle property access
            while (self.match(.dot)) {
                const prop_name = try self.consume(.identifier, "Expected property name after '.'");
                const property = try self.allocator.dupe(u8, prop_name.lexeme);

                const object_ptr = try self.allocator.create(Expression);
                object_ptr.* = expr;

                expr = Expression{ .property_access = PropertyAccess{
                    .object = object_ptr,
                    .property = property,
                }};
            }

            return expr;
        }

        // If not a simple assignment target, parse as full expression
        return self.parseLogicalOr();
    }

    fn parseBlock(self: *Parser) ParseError![]Statement {
        var statements = std.ArrayList(Statement).init(self.allocator);

        // Check if it's a single-line block or multi-line
        if (self.checkNewlineOrSemicolon()) {
            // Multi-line block - expect indentation
            self.consumeNewlines();
            const expected_indent = self.countIndentation() + 1;

            while (!self.isAtEnd() and self.countIndentation() >= expected_indent) {
                const stmt = try self.parseStatement();
                try statements.append(stmt);
                self.skipWhitespace();
            }
        } else {
            // Single line - parse statements until newline
            while (!self.checkNewlineOrSemicolon() and !self.isAtEnd()) {
                const stmt = try self.parseStatement();
                try statements.append(stmt);

                if (self.match(.semicolon)) {
                    continue; // More statements on this line
                } else {
                    break; // End of line
                }
            }
            self.consumeStatementEnd();
        }

        return statements.toOwnedSlice();
    }

    fn parseExpression(self: *Parser) ParseError!Expression {
        return self.parseLogicalOr();
    }

    fn parseLogicalOr(self: *Parser) ParseError!Expression {
        var expr = try self.parseLogicalAnd();

        while (self.match(.or_kw)) {
            const operator = BinaryOperator.logical_or;
            const right = try self.parseLogicalAnd();

            const left_ptr = try self.allocator.create(Expression);
            left_ptr.* = expr;
            const right_ptr = try self.allocator.create(Expression);
            right_ptr.* = right;

            expr = Expression{ .binary = BinaryExpression{
                .left = left_ptr,
                .operator = operator,
                .right = right_ptr,
            }};
        }

        return expr;
    }

    fn parseLogicalAnd(self: *Parser) ParseError!Expression {
        var expr = try self.parseEquality();

        while (self.match(.and_kw)) {
            const operator = BinaryOperator.logical_and;
            const right = try self.parseEquality();

            const left_ptr = try self.allocator.create(Expression);
            left_ptr.* = expr;
            const right_ptr = try self.allocator.create(Expression);
            right_ptr.* = right;

            expr = Expression{ .binary = BinaryExpression{
                .left = left_ptr,
                .operator = operator,
                .right = right_ptr,
            }};
        }

        return expr;
    }

    fn parseEquality(self: *Parser) ParseError!Expression {
        var expr = try self.parseComparison();


        while (self.match(.equal) or self.match(.not_equal)) {
            const operator = switch (self.previous().type) {
                .equal => BinaryOperator.equal,
                .not_equal => BinaryOperator.not_equal,
                else => unreachable,
            };
            const right = try self.parseComparison();

            const left_ptr = try self.allocator.create(Expression);
            left_ptr.* = expr;
            const right_ptr = try self.allocator.create(Expression);
            right_ptr.* = right;

            expr = Expression{ .binary = BinaryExpression{
                .left = left_ptr,
                .operator = operator,
                .right = right_ptr,
            }};
        }

        return expr;
    }

    fn parseComparison(self: *Parser) ParseError!Expression {
        var expr = try self.parseTerm();

        while (self.match(.greater_than) or self.match(.greater_equal) or
              self.match(.less_than) or self.match(.less_equal)) {
            const operator = switch (self.previous().type) {
                .greater_than => BinaryOperator.greater_than,
                .greater_equal => BinaryOperator.greater_equal,
                .less_than => BinaryOperator.less_than,
                .less_equal => BinaryOperator.less_equal,
                else => unreachable,
            };
            const right = try self.parseTerm();

            const left_ptr = try self.allocator.create(Expression);
            left_ptr.* = expr;
            const right_ptr = try self.allocator.create(Expression);
            right_ptr.* = right;

            expr = Expression{ .binary = BinaryExpression{
                .left = left_ptr,
                .operator = operator,
                .right = right_ptr,
            }};
        }

        return expr;
    }

    fn parseTerm(self: *Parser) ParseError!Expression {
        var expr = try self.parseFactor();

        while (self.match(.minus) or self.match(.plus)) {
            const operator = switch (self.previous().type) {
                .minus => BinaryOperator.subtract,
                .plus => BinaryOperator.add,
                else => unreachable,
            };
            const right = try self.parseFactor();

            const left_ptr = try self.allocator.create(Expression);
            left_ptr.* = expr;
            const right_ptr = try self.allocator.create(Expression);
            right_ptr.* = right;

            expr = Expression{ .binary = BinaryExpression{
                .left = left_ptr,
                .operator = operator,
                .right = right_ptr,
            }};
        }

        return expr;
    }

    fn parseFactor(self: *Parser) ParseError!Expression {
        var expr = try self.parseUnary();

        while (self.match(.divide) or self.match(.multiply) or self.match(.modulo)) {
            const operator = switch (self.previous().type) {
                .divide => BinaryOperator.divide,
                .multiply => BinaryOperator.multiply,
                .modulo => BinaryOperator.modulo,
                else => unreachable,
            };
            const right = try self.parseUnary();

            const left_ptr = try self.allocator.create(Expression);
            left_ptr.* = expr;
            const right_ptr = try self.allocator.create(Expression);
            right_ptr.* = right;

            expr = Expression{ .binary = BinaryExpression{
                .left = left_ptr,
                .operator = operator,
                .right = right_ptr,
            }};
        }

        return expr;
    }

    fn parseUnary(self: *Parser) ParseError!Expression {
        if (self.match(.not_kw) or self.match(.minus)) {
            const operator = switch (self.previous().type) {
                .not_kw => UnaryOperator.logical_not,
                .minus => UnaryOperator.minus,
                else => unreachable,
            };
            const right = try self.parseUnary();

            const right_ptr = try self.allocator.create(Expression);
            right_ptr.* = right;

            return Expression{ .unary = UnaryExpression{
                .operator = operator,
                .operand = right_ptr,
            }};
        }

        return self.parseCall();
    }

    fn parseCall(self: *Parser) ParseError!Expression {
        var expr = try self.parsePrimary();

        while (true) {
            if (self.match(.left_paren)) {
                expr = try self.finishCall(expr);
            } else if (self.match(.dot)) {
                // Accept identifiers and duration unit keywords as property names
                const name = if (self.match(.identifier) or self.match(.days_kw) or self.match(.hours_kw) or self.match(.minutes_kw) or self.match(.seconds_kw))
                    self.previous()
                else {
                    return ParseError.UnexpectedToken;
                };
                const property = try self.allocator.dupe(u8, name.lexeme);

                const object_ptr = try self.allocator.create(Expression);
                object_ptr.* = expr;

                expr = Expression{ .property_access = PropertyAccess{
                    .object = object_ptr,
                    .property = property,
                }};
            } else if (self.match(.left_bracket)) {
                const index = try self.parseExpression();
                _ = try self.consume(.right_bracket, "Expected ']' after index");

                const object_ptr = try self.allocator.create(Expression);
                object_ptr.* = expr;
                const index_ptr = try self.allocator.create(Expression);
                index_ptr.* = index;

                expr = Expression{ .index_access = IndexAccess{
                    .object = object_ptr,
                    .index = index_ptr,
                }};
            } else {
                break;
            }
        }

        return expr;
    }

    fn finishCall(self: *Parser, callee: Expression) ParseError!Expression {
        var arguments = std.ArrayList(Expression).init(self.allocator);

        if (!self.check(.right_paren)) {
            while (true) {
                const arg = try self.parseExpression();
                try arguments.append(arg);

                if (!self.match(.comma)) break;
            }
        }

        _ = try self.consume(.right_paren, "Expected ')' after arguments");

        const callee_ptr = try self.allocator.create(Expression);
        callee_ptr.* = callee;

        return Expression{ .call = CallExpression{
            .callee = callee_ptr,
            .arguments = try arguments.toOwnedSlice(),
        }};
    }

    fn parsePrimary(self: *Parser) ParseError!Expression {
        if (self.match(.true_kw)) {
            return Expression{ .literal = Literal{ .boolean = true }};
        }
        if (self.match(.false_kw)) {
            return Expression{ .literal = Literal{ .boolean = false }};
        }
        if (self.match(.nothing_kw)) {
            return Expression{ .literal = Literal{ .nothing = {} }};
        }
        if (self.match(.unknown_kw)) {
            return Expression{ .literal = Literal{ .unknown = {} }};
        }
        if (self.match(.quote_kw)) {
            return Expression{ .literal = Literal{ .quote = {} }};
        }
        if (self.match(.empty_kw)) {
            return Expression{ .literal = Literal{ .empty = {} }};
        }

        if (self.match(.number)) {
            const value = std.fmt.parseFloat(f64, self.previous().lexeme) catch {
                return ParseError.ExpectedExpression;
            };

            // Check if this number is followed by a duration unit
            if (self.check(.days_kw) or self.check(.hours_kw) or self.check(.minutes_kw) or self.check(.seconds_kw)) {
                const unit_token = self.advance();
                const unit = try self.allocator.dupe(u8, unit_token.lexeme);
                return Expression{ .literal = Literal{ .duration = DurationLiteral{ .value = value, .unit = unit }}};
            }

            return Expression{ .literal = Literal{ .number = value }};
        }

        if (self.match(.text)) {
            const text = try self.allocator.dupe(u8, self.previous().lexeme);
            return Expression{ .literal = Literal{ .text = text }};
        }

        if (self.match(.money)) {
            return try self.parseMoneyLiteral();
        }

        if (self.match(.time)) {
            const time_str = try self.allocator.dupe(u8, self.previous().lexeme);
            return Expression{ .literal = Literal{ .time = TimeLiteral{ .value = time_str }}};
        }

        if (self.match(.identifier)) {
            const name = try self.allocator.dupe(u8, self.previous().lexeme);
            return Expression{ .identifier = Identifier{ .name = name }};
        }

        if (self.match(.program_kw)) {
            const name = try self.allocator.dupe(u8, self.previous().lexeme);
            return Expression{ .identifier = Identifier{ .name = name }};
        }

        if (self.match(.left_paren)) {
            const expr = try self.parseExpression();
            _ = try self.consume(.right_paren, "Expected ')' after expression");
            return expr;
        }

        if (self.match(.left_brace)) {
            return try self.parseRecordLiteral();
        }

        if (self.match(.left_bracket)) {
            return try self.parseListLiteral();
        }

        return ParseError.ExpectedExpression;
    }

    fn parseMoneyLiteral(self: *Parser) ParseError!Expression {
        const money_token = self.previous().lexeme;

        // Parse $amount [currency] format
        // Skip the $ symbol
        var amount_str = money_token[1..];
        var currency: ?[]const u8 = null;

        // Look for currency designation
        var i: usize = 0;
        while (i < amount_str.len) {
            if (amount_str[i] == ' ') {
                const trimmed = std.mem.trim(u8, amount_str[i+1..], " ");
                currency = try self.allocator.dupe(u8, trimmed);
                amount_str = amount_str[0..i];
                break;
            }
            i += 1;
        }

        // Remove underscores from amount
        var clean_amount = std.ArrayList(u8).init(self.allocator);
        defer clean_amount.deinit();

        for (amount_str) |c| {
            if (c != '_') {
                try clean_amount.append(c);
            }
        }

        const amount = std.fmt.parseFloat(f64, clean_amount.items) catch {
            return ParseError.ExpectedExpression;
        };

        return Expression{ .literal = Literal{ .money = MoneyLiteral{
            .amount = amount,
            .currency = currency,
        }}};
    }

    fn parseRecordLiteral(self: *Parser) ParseError!Expression {
        var fields = std.ArrayList(RecordField).init(self.allocator);

        if (!self.check(.right_brace)) {
            while (true) {
                // Skip any newlines
                while (self.match(.newline)) {}

                // Key can be identifier or string
                var key: Expression = undefined;
                if (self.check(.identifier)) {
                    const name = try self.allocator.dupe(u8, self.advance().lexeme);
                    key = Expression{ .identifier = Identifier{ .name = name }};
                } else if (self.check(.text)) {
                    const text = try self.allocator.dupe(u8, self.advance().lexeme);
                    key = Expression{ .literal = Literal{ .text = text }};
                } else {
                    key = try self.parseExpression();
                }

                _ = try self.consume(.colon, "Expected ':' after record key");
                const value = try self.parseExpression();

                try fields.append(RecordField{
                    .key = key,
                    .value = value,
                });

                if (!self.match(.comma)) break;

                // Skip any newlines after comma
                while (self.match(.newline)) {}
            }
        }

        // Skip any final newlines before closing brace
        while (self.match(.newline)) {}

        _ = try self.consume(.right_brace, "Expected '}' after record fields");

        return Expression{ .record_literal = RecordLiteral{
            .fields = try fields.toOwnedSlice(),
        }};
    }

    fn parseListLiteral(self: *Parser) ParseError!Expression {
        var elements = std.ArrayList(Expression).init(self.allocator);

        if (!self.check(.right_bracket)) {
            while (true) {
                // Skip any newlines
                while (self.match(.newline)) {}

                const element = try self.parseExpression();
                try elements.append(element);

                if (!self.match(.comma)) break;

                // Skip any newlines after comma
                while (self.match(.newline)) {}
            }
        }

        // Skip any final newlines before closing bracket
        while (self.match(.newline)) {}

        _ = try self.consume(.right_bracket, "Expected ']' after list elements");

        return Expression{ .list_literal = ListLiteral{
            .elements = try elements.toOwnedSlice(),
        }};
    }

    // Helper functions
    fn match(self: *Parser, token_type: TokenType) bool {
        if (self.check(token_type)) {
            _ = self.advance();
            return true;
        }
        return false;
    }

    fn check(self: *Parser, token_type: TokenType) bool {
        if (self.isAtEnd()) return false;
        return self.peek().type == token_type;
    }

    fn checkAt(self: *Parser, position: usize, token_type: TokenType) bool {
        if (position >= self.tokens.len) return false;
        return self.tokens[position].type == token_type;
    }

    fn checkNext(self: *Parser, token_type: TokenType) bool {
        if (self.current + 1 >= self.tokens.len) return false;
        return self.tokens[self.current + 1].type == token_type;
    }

    fn advance(self: *Parser) Token {
        if (!self.isAtEnd()) self.current += 1;
        return self.previous();
    }

    fn isAtEnd(self: *Parser) bool {
        return self.peek().type == .eof;
    }

    fn peek(self: *Parser) Token {
        return self.tokens[self.current];
    }

    fn previous(self: *Parser) Token {
        return self.tokens[self.current - 1];
    }

    fn consume(self: *Parser, token_type: TokenType, message: []const u8) ParseError!Token {
        if (self.check(token_type)) return self.advance();

        std.log.err("Parse error at line {}: {s}. Got '{s}' instead.", .{
            self.peek().line, message, self.peek().lexeme
        });
        return ParseError.UnexpectedToken;
    }

    fn skipWhitespace(self: *Parser) void {
        while (self.check(.newline) or self.check(.indent)) {
            _ = self.advance();
        }
    }

    fn consumeNewlines(self: *Parser) void {
        while (self.match(.newline)) {}
    }

    fn consumeStatementEnd(self: *Parser) void {
        if (self.match(.semicolon) or self.match(.newline)) {
            return;
        }
        // Allow end of file as statement end
        if (self.isAtEnd()) {
            return;
        }
    }

    fn consumeLabelName(self: *Parser, message: []const u8) ParseError!Token {
        // Accept identifiers or keywords as label names
        const current_token = self.peek();

        // Check if it's an identifier
        if (current_token.type == .identifier) {
            return self.advance();
        }

        // Check if it's a keyword that can be used as a label
        switch (current_token.type) {
            .end_kw => {
                return self.advance();
            },
            else => {},
        }

        // If neither identifier nor acceptable keyword, report error
        std.log.err("{s}. Got '{s}' instead.", .{message, current_token.lexeme});
        return ParseError.UnexpectedToken;
    }

    fn checkNewlineOrSemicolon(self: *Parser) bool {
        return self.check(.newline) or self.check(.semicolon) or self.isAtEnd();
    }

    fn countIndentation(self: *Parser) usize {
        var count: usize = 0;
        var pos = self.current;


        // Count consecutive indent tokens
        while (pos < self.tokens.len and self.tokens[pos].type == .indent) {
            count += 1;
            pos += 1;
        }

        return count;
    }
};

// Test function
pub fn testParser() !void {
    const allocator = std.heap.page_allocator;

    const test_source =
        \\customer = { name: "John", balance: $500.50 }
        \\
        \\low_balance_alert customer.balance < $100:
        \\	program.write("Warning: Low balance")
        \\
        \\process_payment(amount):
        \\	if amount > customer.balance: return false
        \\	customer.balance -= amount; return true
    ;

    // First tokenize
    var lexer = Lexer.init(allocator, test_source);
    const tokens = try lexer.scanTokens();
    defer tokens.deinit();

    // Then parse
    var parser = Parser.init(allocator, tokens.items);
    const statements = try parser.parse();
    defer {
        for (statements) |*stmt| {
            stmt.deinit(allocator);
        }
        allocator.free(statements);
    }

    std.log.info("Parsed {} statements successfully!", .{statements.len});

    // Print basic info about parsed statements
    for (statements, 0..) |stmt, i| {
        const stmt_type = switch (stmt) {
            .assignment => "Assignment",
            .function_declaration => "Function",
            .activator_declaration => "Activator",
            .expression_stmt => "Expression",
            .label => "Label",
            .if_statement => "If Statement",
            .while_statement => "While Statement",
            .return_statement => "Return Statement",
            .goto_stmt => "Goto Statement",
        };
        std.log.info("  Statement {}: {s}", .{i, stmt_type});
    }
}
