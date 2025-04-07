const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const AstNode = @import("../memory/value.zig").AstNode;
const AstNodeType = @import("../memory/value.zig").AstNodeType;
const OperatorType = @import("../memory/value.zig").OperatorType;
const SourcePosition = @import("../memory/value.zig").SourcePosition;
const EventType = @import("../memory/value.zig").EventType;
const Value = @import("../memory/value.zig").Value;
const MemoryManager = @import("../memory/memory.zig").MemoryManager;

// Re-exports for testing
pub const TestHelpers = struct {
    pub const MemoryManager = @import("../memory/memory.zig").MemoryManager;
    pub const AstNode = @import("../memory/value.zig").AstNode;
    pub const AstNodeType = @import("../memory/value.zig").AstNodeType;
    pub const OperatorType = @import("../memory/value.zig").OperatorType;
    pub const EventType = @import("../memory/value.zig").EventType;
};

// Define constants for operators that are Zig keywords
const AND_OP = @as(u8, 8); // Assuming and is the 8th enum value
const OR_OP = @as(u8, 9);  // Assuming or is the 9th enum value

pub const ParseError = error{
    UnexpectedToken,
    InvalidExpression,
    InvalidStatement,
    MissingClosingParen,
    MissingClosingBrace,
    MissingOpeningBrace,
    MissingIdentifier,
    MissingKeyword,
    UnsupportedOperation,
    OutOfMemory,
};

pub const Parser = struct {
    tokens: []const Token,
    current: usize,
    memory_manager: *MemoryManager,
    had_error: bool = false,
    
    pub fn init(tokens: []const Token, memory_manager: *MemoryManager) Parser {
        return .{
            .tokens = tokens,
            .current = 0,
            .memory_manager = memory_manager,
            .had_error = false,
        };
    }
    
    pub fn parse(self: *Parser) ParseError!*AstNode {
        return self.parseProgram();
    }
    
    fn parseProgram(self: *Parser) ParseError!*AstNode {
        var statements = std.ArrayList(*AstNode).init(self.memory_manager.allocator);
        defer statements.deinit();
        
        while (!self.isAtEnd() and self.peek().type != .eof) {
            const stmt = try self.parseStatement();
            try statements.append(stmt);
            
            // Skip any newlines between statements
            while (!self.isAtEnd() and self.peek().type == .newline) {
                _ = self.advance();
            }
        }
        
        // Convert ArrayList to slice for the block node
        const stmts_slice = statements.toOwnedSlice() catch |err| {
            std.debug.print("Error creating statements slice: {any}\n", .{err});
            return ParseError.InvalidStatement;
        };
        
        // Create a block node for the program statements
        const pos = if (stmts_slice.len > 0) 
            self.tokenToSourcePosition(self.tokens[0]) 
        else 
            SourcePosition.unknown();
            
        return self.memory_manager.createBlock(stmts_slice, pos);
    }
    
    fn parseStatement(self: *Parser) ParseError!*AstNode {
        // Skip newlines
        while (!self.isAtEnd() and self.peek().type == .newline) {
            _ = self.advance();
        }
        
        return switch (self.peek().type) {
            .var_, .const_ => self.parseVariableDeclaration(),
            .function => self.parseFunctionDeclaration(),
            .trigger => self.parseTriggerDeclaration(),
            .if_ => self.parseIfStatement(),
            .while_ => self.parseWhileStatement(),
            .for_ => self.parseForStatement(),
            .return_ => self.parseReturnStatement(),
            .left_brace => self.parseBlock(),
            else => self.parseExpressionStatement(),
        };
    }
    
    fn parseVariableDeclaration(self: *Parser) ParseError!*AstNode {
        // Consume 'var' or 'const'
        _ = self.advance();
        
        if (self.peek().type != .identifier) {
            std.debug.print("Expected identifier after var/const, got {any}\n", .{self.peek().type});
            return ParseError.MissingIdentifier;
        }
        
        const name_token = self.advance();
        var initial_value: ?*AstNode = null;
        
        // Check for initialization
        if (self.match(.assign)) {
            initial_value = try self.parseExpression();
        }
        
        // Semicolon is optional
        _ = self.match(.semicolon);
        
        // Create a variable declaration node
        var node = self.memory_manager.createAstNode();
        node.* = .{
            .node_type = .variable_declaration,
            .pos = self.tokenToSourcePosition(name_token),
            .data = .{
                .variable_declaration = .{
                    .name = try self.memory_manager.allocator.dupe(u8, name_token.lexeme),
                    .initial_value = initial_value,
                },
            },
        };
        
        return node;
    }
    
    fn parseBlock(self: *Parser) ParseError!*AstNode {
        // Consume '{'
        const left_brace = self.advance();
        
        var statements = std.ArrayList(*AstNode).init(self.memory_manager.allocator);
        defer statements.deinit();
        
        // Skip initial newlines
        while (!self.isAtEnd() and self.peek().type == .newline) {
            _ = self.advance();
        }
        
        while (!self.isAtEnd() and self.peek().type != .right_brace) {
            const stmt = try self.parseStatement();
            try statements.append(stmt);
            
            // Skip newlines between statements
            while (!self.isAtEnd() and self.peek().type == .newline) {
                _ = self.advance();
            }
        }
        
        if (self.isAtEnd() or self.peek().type != .right_brace) {
            std.debug.print("Expected '}' to close block\n", .{});
            return ParseError.MissingClosingBrace;
        }
        
        // Consume '}'
        _ = self.advance();
        
        // Convert ArrayList to slice for the block node
        const stmts_slice = statements.toOwnedSlice() catch |err| {
            std.debug.print("Error creating statements slice: {any}\n", .{err});
            return ParseError.InvalidStatement;
        };
        
        return self.memory_manager.createBlock(stmts_slice, self.tokenToSourcePosition(left_brace));
    }
    
    fn parseFunctionDeclaration(self: *Parser) ParseError!*AstNode {
        // Consume 'function'
        const function_token = self.advance();
        
        if (self.peek().type != .identifier) {
            std.debug.print("Expected function name, got {any}\n", .{self.peek().type});
            return ParseError.MissingIdentifier;
        }
        
        const name_token = self.advance();
        
        if (self.peek().type != .left_paren) {
            std.debug.print("Expected '(' after function name, got {any}\n", .{self.peek().type});
            return ParseError.MissingClosingParen;
        }
        
        // Consume '('
        _ = self.advance();
        
        var parameters = std.ArrayList(*AstNode).init(self.memory_manager.allocator);
        defer parameters.deinit();
        
        // Parse parameters
        if (self.peek().type != .right_paren) {
            while (true) {
                if (self.peek().type != .identifier) {
                    std.debug.print("Expected parameter name, got {any}\n", .{self.peek().type});
                    return ParseError.MissingIdentifier;
                }
                
                const param_token = self.advance();
                
                // Create parameter node
                var param_node = self.memory_manager.createAstNode();
                param_node.* = .{
                    .node_type = .parameter_def,
                    .pos = self.tokenToSourcePosition(param_token),
                    .data = .{
                        .parameter_def = .{
                            .name = try self.memory_manager.allocator.dupe(u8, param_token.lexeme),
                            .type_name = null,
                        },
                    },
                };
                
                try parameters.append(param_node);
                
                if (self.match(.comma)) {
                    // Continue to the next parameter
                } else {
                    break;
                }
            }
        }
        
        if (self.peek().type != .right_paren) {
            std.debug.print("Expected ')' after function parameters, got {any}\n", .{self.peek().type});
            return ParseError.MissingClosingParen;
        }
        
        // Consume ')'
        _ = self.advance();
        
        // Parse body
        var body: *AstNode = undefined;
        
        if (self.peek().type == .left_brace) {
            body = try self.parseBlock();
        } else {
            std.debug.print("Expected '{{' to start function body, got {any}\n", .{self.peek().type});
            return ParseError.MissingOpeningBrace;
        }
        
        // Convert parameters to slice
        const params_slice = parameters.toOwnedSlice() catch |err| {
            std.debug.print("Error creating parameters slice: {any}\n", .{err});
            return ParseError.InvalidStatement;
        };
        
        // Create function declaration node
        var node = self.memory_manager.createAstNode();
        node.* = .{
            .node_type = .function_def,
            .pos = self.tokenToSourcePosition(function_token),
            .data = .{
                .function_def = .{
                    .name = try self.memory_manager.allocator.dupe(u8, name_token.lexeme),
                    .parameters = params_slice,
                    .body = body,
                },
            },
        };
        
        return node;
    }
    
    fn parseTriggerDeclaration(self: *Parser) ParseError!*AstNode {
        // Consume 'trigger'
        const trigger_token = self.advance();
        
        if (self.peek().type != .identifier) {
            std.debug.print("Expected trigger name, got {any}\n", .{self.peek().type});
            return ParseError.MissingIdentifier;
        }
        
        const name_token = self.advance();
        
        if (self.peek().type != .on) {
            std.debug.print("Expected 'on' after trigger name, got {any}\n", .{self.peek().type});
            return ParseError.MissingKeyword;
        }
        
        // Consume 'on'
        _ = self.advance();
        
        if (self.peek().type != .identifier) {
            std.debug.print("Expected event type, got {any}\n", .{self.peek().type});
            return ParseError.MissingIdentifier;
        }
        
        const event_token = self.advance();
        const event_type = self.parseEventType(event_token);
        
        if (self.peek().type != .when) {
            std.debug.print("Expected 'when' after event type, got {any}\n", .{self.peek().type});
            return ParseError.MissingKeyword;
        }
        
        // Consume 'when'
        _ = self.advance();
        
        // Parse condition
        const condition = try self.parseExpression();
        
        if (self.peek().type != .then) {
            std.debug.print("Expected 'then' after condition, got {any}\n", .{self.peek().type});
            return ParseError.MissingKeyword;
        }
        
        // Consume 'then'
        _ = self.advance();
        
        // Skip newlines
        while (!self.isAtEnd() and self.peek().type == .newline) {
            _ = self.advance();
        }
        
        // Parse body until 'end'
        var statements = std.ArrayList(*AstNode).init(self.memory_manager.allocator);
        defer statements.deinit();
        
        while (!self.isAtEnd() and self.peek().type != .end) {
            const stmt = try self.parseStatement();
            try statements.append(stmt);
            
            // Skip newlines between statements
            while (!self.isAtEnd() and self.peek().type == .newline) {
                _ = self.advance();
            }
        }
        
        if (self.isAtEnd() or self.peek().type != .end) {
            std.debug.print("Expected 'end' to close trigger body\n", .{});
            return ParseError.MissingKeyword;
        }
        
        // Consume 'end'
        _ = self.advance();
        
        // Convert statements to slice for the block node
        const stmts_slice = statements.toOwnedSlice() catch |err| {
            std.debug.print("Error creating statements slice: {any}\n", .{err});
            return ParseError.InvalidStatement;
        };
        
        // Create block node for the body
        const _action = try self.memory_manager.createBlock(stmts_slice, self.tokenToSourcePosition(trigger_token));
        _ = _action; // Will be used in future implementation
        
        // Create a simplified AST node that will be converted to a proper trigger later
        _ = condition; // Will be used in future implementation
        
        var node = self.memory_manager.createAstNode();
        node.* = .{
            .node_type = .variable_declaration,
            .pos = self.tokenToSourcePosition(trigger_token),
            .data = .{
                .variable_declaration = .{
                    .name = try std.fmt.allocPrint(
                        self.memory_manager.allocator, 
                        "trigger:{s}:{s}",
                        .{ name_token.lexeme, @tagName(event_type) }
                    ),
                    .initial_value = null,
                },
            },
        };
        
        // This is a placeholder. In a real implementation, we would:
        // 1. Create a trigger
        // 2. Register it with the trigger manager
        // But those operations require a more complete runtime environment.
        // For now, we'll just return the node.
        
        return node;
    }
    
    fn parseEventType(self: *Parser, token: Token) EventType {
        _ = self; // Unused parameter, but kept for consistency
        if (std.mem.eql(u8, token.lexeme, "data_changed")) {
            return .data_changed;
        } else if (std.mem.eql(u8, token.lexeme, "timer")) {
            return .timer;
        } else if (std.mem.eql(u8, token.lexeme, "startup")) {
            return .startup;
        } else if (std.mem.eql(u8, token.lexeme, "shutdown")) {
            return .shutdown;
        } else {
            return .custom;
        }
    }
    
    fn parseIfStatement(self: *Parser) ParseError!*AstNode {
        // Consume 'if'
        const if_token = self.advance();
        
        // Parse condition
        const condition = try self.parseExpression();
        
        if (self.peek().type != .then) {
            std.debug.print("Expected 'then' after if condition, got {any}\n", .{self.peek().type});
            return ParseError.MissingKeyword;
        }
        
        // Consume 'then'
        _ = self.advance();
        
        // Skip newlines
        while (!self.isAtEnd() and self.peek().type == .newline) {
            _ = self.advance();
        }
        
        // Parse then branch
        const then_branch = try self.parseStatement();
        
        // Check for else
        var else_branch: ?*AstNode = null;
        
        // Skip newlines before else
        while (!self.isAtEnd() and self.peek().type == .newline) {
            _ = self.advance();
        }
        
        if (self.match(.else_)) {
            // Skip newlines after else
            while (!self.isAtEnd() and self.peek().type == .newline) {
                _ = self.advance();
            }
            
            else_branch = try self.parseStatement();
        }
        
        return self.memory_manager.createIfStatement(
            condition,
            then_branch,
            else_branch,
            self.tokenToSourcePosition(if_token)
        );
    }
    
    fn parseWhileStatement(self: *Parser) ParseError!*AstNode {
        // Consume 'while'
        const while_token = self.advance();
        
        // Parse condition
        const condition = try self.parseExpression();
        
        if (self.peek().type != .do_) {
            std.debug.print("Expected 'do' after while condition, got {any}\n", .{self.peek().type});
            return ParseError.MissingKeyword;
        }
        
        // Consume 'do'
        _ = self.advance();
        
        // Skip newlines
        while (!self.isAtEnd() and self.peek().type == .newline) {
            _ = self.advance();
        }
        
        // Parse body
        const body = try self.parseStatement();
        
        // Create while statement node
        var node = self.memory_manager.createAstNode();
        node.* = .{
            .node_type = .while_stmt,
            .pos = self.tokenToSourcePosition(while_token),
            .data = .{
                .while_stmt = .{
                    .condition = condition,
                    .body = body,
                },
            },
        };
        
        return node;
    }
    
    fn parseForStatement(self: *Parser) ParseError!*AstNode {
        // Consume 'for'
        const for_token = self.advance();
        
        // C-style for loop: for (init; condition; update) body
        if (self.match(.left_paren)) {
            return self.parseTraditionalForLoop(for_token);
        }
        
        // Iterator-style for loop: for item in collection body
        if (self.peek().type == .identifier) {
            return self.parseIteratorForLoop(for_token);
        }
        
        std.debug.print("Expected '(' or identifier after 'for', got {any}\n", .{self.peek().type});
        return ParseError.InvalidStatement;
    }
    
    fn parseTraditionalForLoop(self: *Parser, for_token: Token) ParseError!*AstNode {
        // Parse initializer (optional)
        var initializer: ?*AstNode = null;
        if (self.peek().type != .semicolon) {
            initializer = try self.parseVariableDeclaration();
        } else {
            // Skip the semicolon
            _ = self.advance();
        }
        
        // Parse condition (optional)
        var condition: ?*AstNode = null;
        if (self.peek().type != .semicolon) {
            condition = try self.parseExpression();
        }
        
        if (self.peek().type != .semicolon) {
            std.debug.print("Expected ';' after for condition, got {any}\n", .{self.peek().type});
            return ParseError.InvalidStatement;
        }
        
        // Skip the semicolon
        _ = self.advance();
        
        // Parse increment (optional)
        var increment: ?*AstNode = null;
        if (self.peek().type != .right_paren) {
            increment = try self.parseExpression();
        }
        
        if (self.peek().type != .right_paren) {
            std.debug.print("Expected ')' after for clauses, got {any}\n", .{self.peek().type});
            return ParseError.MissingClosingParen;
        }
        
        // Skip the closing paren
        _ = self.advance();
        
        // Parse body
        const body = try self.parseStatement();
        
        // Create for statement node
        var node = self.memory_manager.createAstNode();
        node.* = .{
            .node_type = .for_stmt,
            .pos = self.tokenToSourcePosition(for_token),
            .data = .{
                .for_stmt = .{
                    .init = initializer,
                    .condition = condition,
                    .update = increment,
                    .body = body,
                },
            },
        };
        
        return node;
    }
    
    fn parseIteratorForLoop(self: *Parser, for_token: Token) ParseError!*AstNode {
        // This is a simplified implementation that transforms:
        //    for item in collection { body }
        // into:
        //    { 
        //      var __iterator = collection.iterator();
        //      while (__iterator.moveNext()) {
        //        var item = __iterator.current;
        //        body
        //      }
        //    }
        
        // But for now, we'll just create a for statement placeholder node
        
        // Consume the item name
        const _item_token = self.advance();
        _ = _item_token; // Will be used in future implementation
        
        if (self.peek().type != .in_) {
            std.debug.print("Expected 'in' after for item name, got {any}\n", .{self.peek().type});
            return ParseError.MissingKeyword;
        }
        
        // Consume 'in'
        _ = self.advance();
        
        // Parse collection expression
        const _collection = try self.parseExpression();
        _ = _collection; // Will be used in future implementation
        
        // Parse body
        const body = try self.parseStatement();
        
        // Create simplified for statement node as a placeholder
        var node = self.memory_manager.createAstNode();
        node.* = .{
            .node_type = .for_stmt,
            .pos = self.tokenToSourcePosition(for_token),
            .data = .{
                .for_stmt = .{
                    .init = null,
                    .condition = null,
                    .update = null,
                    .body = body,
                },
            },
        };
        
        return node;
    }
    
    fn parseReturnStatement(self: *Parser) ParseError!*AstNode {
        // Consume 'return'
        const return_token = self.advance();
        
        var value: ?*AstNode = null;
        
        // If there's an expression following return, parse it
        if (!self.isAtEnd() and 
            self.peek().type != .semicolon and 
            self.peek().type != .newline) {
            value = try self.parseExpression();
        }
        
        // Semicolon is optional
        _ = self.match(.semicolon);
        
        // Create return statement node
        var node = self.memory_manager.createAstNode();
        node.* = .{
            .node_type = .return_stmt,
            .pos = self.tokenToSourcePosition(return_token),
            .data = .{ .return_stmt = value },
        };
        
        return node;
    }
    
    fn parseExpressionStatement(self: *Parser) ParseError!*AstNode {
        const expr = try self.parseExpression();
        
        // Semicolon is optional
        _ = self.match(.semicolon);
        
        // Create expression statement node
        var node = self.memory_manager.createAstNode();
        node.* = .{
            .node_type = .expression_stmt,
            .pos = expr.pos,
            .data = .{ .expression_stmt = expr },
        };
        
        return node;
    }
    
    fn parseExpression(self: *Parser) ParseError!*AstNode {
        return self.parseAssignment();
    }
    
    fn parseAssignment(self: *Parser) ParseError!*AstNode {
        const expr = try self.parseLogicalOr();
        
        if (self.match(.assign)) {
            const value = try self.parseAssignment();
            
            // Check valid assignment target
            switch (expr.node_type) {
                .identifier, .member_access, .index_expression => {
                    return self.memory_manager.createBinaryExpression(expr, .assign, value, expr.pos);
                },
                else => {
                    std.debug.print("Invalid assignment target\n", .{});
                    return ParseError.InvalidExpression;
                },
            }
        }
        
        return expr;
    }
    
    fn parseLogicalOr(self: *Parser) ParseError!*AstNode {
        var expr = try self.parseLogicalAnd();
        
        while (self.match(.or_)) {
            const right = try self.parseLogicalAnd();
            expr = try self.memory_manager.createBinaryExpression(expr, @as(OperatorType, @enumFromInt(OR_OP)), right, expr.pos);
        }
        
        return expr;
    }
    
    fn parseLogicalAnd(self: *Parser) ParseError!*AstNode {
        var expr = try self.parseEquality();
        
        while (self.match(.and_)) {
            const right = try self.parseEquality();
            expr = try self.memory_manager.createBinaryExpression(expr, @as(OperatorType, @enumFromInt(AND_OP)), right, expr.pos);
        }
        
        return expr;
    }
    
    fn parseEquality(self: *Parser) ParseError!*AstNode {
        var expr = try self.parseComparison();
        
        while (self.match(.equal_to) or self.match(.not_equal_to)) {
            const operator: OperatorType = if (self.previous().type == .equal_to) .eq else .neq;
            const right = try self.parseComparison();
            expr = try self.memory_manager.createBinaryExpression(expr, operator, right, expr.pos);
        }
        
        return expr;
    }
    
    fn parseComparison(self: *Parser) ParseError!*AstNode {
        var expr = try self.parseTerm();
        
        while (self.match(.less_than) or 
               self.match(.less_equal_to) or 
               self.match(.greater_than) or 
               self.match(.greater_equal_to)) {
            const operator: OperatorType = switch (self.previous().type) {
                .less_than => .lt,
                .less_equal_to => .lte,
                .greater_than => .gt,
                .greater_equal_to => .gte,
                else => unreachable,
            };
            const right = try self.parseTerm();
            expr = try self.memory_manager.createBinaryExpression(expr, operator, right, expr.pos);
        }
        
        return expr;
    }
    
    fn parseTerm(self: *Parser) ParseError!*AstNode {
        var expr = try self.parseFactor();
        
        while (self.match(.plus) or self.match(.minus)) {
            const operator: OperatorType = if (self.previous().type == .plus) .add else .subtract;
            const right = try self.parseFactor();
            expr = try self.memory_manager.createBinaryExpression(expr, operator, right, expr.pos);
        }
        
        return expr;
    }
    
    fn parseFactor(self: *Parser) ParseError!*AstNode {
        var expr = try self.parseUnary();
        
        while (self.match(.multiply) or self.match(.divide) or self.match(.modulo)) {
            const operator: OperatorType = switch (self.previous().type) {
                .multiply => .multiply,
                .divide => .divide,
                .modulo => .modulo,
                else => unreachable,
            };
            const right = try self.parseUnary();
            expr = try self.memory_manager.createBinaryExpression(expr, operator, right, expr.pos);
        }
        
        return expr;
    }
    
    fn parseUnary(self: *Parser) ParseError!*AstNode {
        if (self.match(.not_) or self.match(.minus)) {
            const operator: OperatorType = if (self.previous().type == .not_) .not else .subtract;
            const right = try self.parseUnary();
            
            // Create unary expression node
            var node = self.memory_manager.createAstNode();
            node.* = .{
                .node_type = .unary_expression,
                .pos = right.pos,
                .data = .{
                    .unary_expression = .{
                        .operator = operator,
                        .operand = right,
                    },
                },
            };
            
            return node;
        }
        
        return self.parseCall();
    }
    
    fn parseCall(self: *Parser) ParseError!*AstNode {
        var expr = try self.parsePrimary();
        
        while (true) {
            if (self.match(.left_paren)) {
                expr = try self.finishCall(expr);
            } else if (self.match(.dot)) {
                if (self.peek().type != .identifier) {
                    std.debug.print("Expected property name after '.', got {any}\n", .{self.peek().type});
                    return ParseError.MissingIdentifier;
                }
                
                const name_token = self.advance();
                
                // Create member access node
                var node = self.memory_manager.createAstNode();
                node.* = .{
                    .node_type = .member_access,
                    .pos = self.tokenToSourcePosition(name_token),
                    .data = .{
                        .member_access = .{
                            .object = expr,
                            .member = try self.memory_manager.allocator.dupe(u8, name_token.lexeme),
                        },
                    },
                };
                
                expr = node;
            } else if (self.match(.left_bracket)) {
                const index = try self.parseExpression();
                
                if (self.peek().type != .right_bracket) {
                    std.debug.print("Expected ']' after index, got {any}\n", .{self.peek().type});
                    return ParseError.MissingClosingBrace;
                }
                
                // Consume ']'
                _ = self.advance();
                
                // Create index expression node
                var node = self.memory_manager.createAstNode();
                node.* = .{
                    .node_type = .index_expression,
                    .pos = expr.pos,
                    .data = .{
                        .index_expression = .{
                            .array = expr,
                            .index = index,
                        },
                    },
                };
                
                expr = node;
            } else {
                break;
            }
        }
        
        return expr;
    }
    
    fn finishCall(self: *Parser, callee: *AstNode) ParseError!*AstNode {
        var arguments = std.ArrayList(*AstNode).init(self.memory_manager.allocator);
        defer arguments.deinit();
        
        if (self.peek().type != .right_paren) {
            // Parse arguments
            while (true) {
                const arg = try self.parseExpression();
                try arguments.append(arg);
                
                if (!self.match(.comma)) {
                    break;
                }
            }
        }
        
        if (self.peek().type != .right_paren) {
            std.debug.print("Expected ')' after function arguments, got {any}\n", .{self.peek().type});
            return ParseError.MissingClosingParen;
        }
        
        // Consume ')'
        const paren = self.advance();
        
        // Convert arguments to slice
        const args_slice = arguments.toOwnedSlice() catch |err| {
            std.debug.print("Error creating arguments slice: {any}\n", .{err});
            return ParseError.InvalidExpression;
        };
        
        // Create call expression node
        var node = self.memory_manager.createAstNode();
        node.* = .{
            .node_type = .call_expression,
            .pos = self.tokenToSourcePosition(paren),
            .data = .{
                .call_expression = .{
                    .callee = callee,
                    .arguments = args_slice,
                },
            },
        };
        
        return node;
    }
    
    fn parsePrimary(self: *Parser) ParseError!*AstNode {
        const _token = self.peek();
        _ = _token; // Will be used in future implementation
        
        if (self.match(.false_)) {
            return self.memory_manager.createBooleanLiteral(false, self.tokenToSourcePosition(self.previous()));
        }
        
        if (self.match(.true_)) {
            return self.memory_manager.createBooleanLiteral(true, self.tokenToSourcePosition(self.previous()));
        }
        
        if (self.match(.nil_)) {
            // Create nil literal node
            var node = self.memory_manager.createAstNode();
            node.* = .{
                .node_type = .nil_literal,
                .pos = self.tokenToSourcePosition(self.previous()),
                .data = .{ .nil_literal = {} },
            };
            return node;
        }
        
        if (self.match(.number)) {
            const value = std.fmt.parseFloat(f64, self.previous().lexeme) catch {
                std.debug.print("Invalid number: {s}\n", .{self.previous().lexeme});
                return ParseError.InvalidExpression;
            };
            return self.memory_manager.createNumberLiteral(value, self.tokenToSourcePosition(self.previous()));
        }
        
        if (self.match(.text)) {
            if (self.previous().literal) |literal| {
                return self.memory_manager.createTextLiteral(literal, self.tokenToSourcePosition(self.previous()));
            } else {
                std.debug.print("Missing literal value for text token\n", .{});
                return ParseError.InvalidExpression;
            }
        }
        
        if (self.match(.special_literal)) {
            if (self.previous().literal) |literal| {
                // Special literals will be handled by the interpreter
                return self.memory_manager.createTextLiteral(literal, self.tokenToSourcePosition(self.previous()));
            } else {
                std.debug.print("Missing literal value for special literal token\n", .{});
                return ParseError.InvalidExpression;
            }
        }
        
        if (self.match(.identifier)) {
            return self.memory_manager.createIdentifier(self.previous().lexeme, self.tokenToSourcePosition(self.previous()));
        }
        
        if (self.match(.left_paren)) {
            const expr = try self.parseExpression();
            
            if (self.peek().type != .right_paren) {
                std.debug.print("Expected ')' after expression, got {any}\n", .{self.peek().type});
                return ParseError.MissingClosingParen;
            }
            
            // Consume ')'
            _ = self.advance();
            
            return expr;
        }
        
        if (self.match(.left_bracket)) {
            return self.parseListLiteral();
        }
        
        if (self.match(.left_brace)) {
            return self.parseRecordLiteral();
        }
        
        std.debug.print("Unexpected token: {any}\n", .{self.peek().type});
        return ParseError.UnexpectedToken;
    }
    
    fn parseListLiteral(self: *Parser) ParseError!*AstNode {
        const left_bracket = self.previous();
        
        var items = std.ArrayList(*AstNode).init(self.memory_manager.allocator);
        defer items.deinit();
        
        if (self.peek().type != .right_bracket) {
            // Parse list items
            while (true) {
                const item = try self.parseExpression();
                try items.append(item);
                
                if (!self.match(.comma)) {
                    break;
                }
            }
        }
        
        if (self.peek().type != .right_bracket) {
            std.debug.print("Expected ']' after list items, got {any}\n", .{self.peek().type});
            return ParseError.MissingClosingBrace;
        }
        
        // Consume ']'
        _ = self.advance();
        
        // Convert items to slice
        const items_slice = items.toOwnedSlice() catch |err| {
            std.debug.print("Error creating list items slice: {any}\n", .{err});
            return ParseError.InvalidExpression;
        };
        
        // Create list literal node
        var node = self.memory_manager.createAstNode();
        node.* = .{
            .node_type = .list_literal,
            .pos = self.tokenToSourcePosition(left_bracket),
            .data = .{ .list_literal = items_slice },
        };
        
        return node;
    }
    
    fn parseRecordLiteral(self: *Parser) ParseError!*AstNode {
        const left_brace = self.previous();
        
        var keys = std.ArrayList([]const u8).init(self.memory_manager.allocator);
        defer keys.deinit();
        
        var values = std.ArrayList(*AstNode).init(self.memory_manager.allocator);
        defer values.deinit();
        
        if (self.peek().type != .right_brace) {
            // Parse record fields
            while (true) {
                // Parse key
                if (self.peek().type != .identifier and self.peek().type != .text) {
                    std.debug.print("Expected field name, got {any}\n", .{self.peek().type});
                    return ParseError.MissingIdentifier;
                }
                
                const key_token = self.advance();
                const key = if (key_token.type == .identifier)
                    try self.memory_manager.allocator.dupe(u8, key_token.lexeme)
                else if (key_token.literal) |literal|
                    try self.memory_manager.allocator.dupe(u8, literal)
                else {
                    std.debug.print("Missing literal value for text token\n", .{});
                    return ParseError.InvalidExpression;
                };
                
                try keys.append(key);
                
                if (self.peek().type != .colon) {
                    std.debug.print("Expected ':' after field name, got {any}\n", .{self.peek().type});
                    return ParseError.InvalidExpression;
                }
                
                // Consume ':'
                _ = self.advance();
                
                // Parse value
                const value = try self.parseExpression();
                try values.append(value);
                
                if (!self.match(.comma)) {
                    break;
                }
            }
        }
        
        if (self.peek().type != .right_brace) {
            std.debug.print("Expected '}}' after record fields, got {any}\n", .{self.peek().type});
            return ParseError.MissingClosingBrace;
        }
        
        // Consume '}'
        _ = self.advance();
        
        // Convert keys and values to slices
        const keys_slice = keys.toOwnedSlice() catch |err| {
            std.debug.print("Error creating record keys slice: {any}\n", .{err});
            return ParseError.InvalidExpression;
        };
        
        const values_slice = values.toOwnedSlice() catch |err| {
            std.debug.print("Error creating record values slice: {any}\n", .{err});
            return ParseError.InvalidExpression;
        };
        
        // Create record literal node
        var node = self.memory_manager.createAstNode();
        node.* = .{
            .node_type = .record_literal,
            .pos = self.tokenToSourcePosition(left_brace),
            .data = .{
                .record_literal = .{
                    .keys = keys_slice,
                    .values = values_slice,
                },
            },
        };
        
        return node;
    }
    
    fn match(self: *Parser, type_: TokenType) bool {
        if (self.check(type_)) {
            _ = self.advance();
            return true;
        }
        return false;
    }
    
    fn check(self: *Parser, type_: TokenType) bool {
        if (self.isAtEnd()) return false;
        return self.peek().type == type_;
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
    
    fn tokenToSourcePosition(self: *Parser, token: Token) SourcePosition {
        _ = self; // Unused parameter, but kept for consistency
        return SourcePosition.init(null, token.line, token.column);
    }
};