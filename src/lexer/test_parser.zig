const std = @import("std");
const testing = std.testing;
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const ParseError = @import("parser.zig").ParseError;

const AstNodeType = @import("parser.zig").TestHelpers.AstNodeType;
const AstNode = @import("parser.zig").TestHelpers.AstNode;
const OperatorType = @import("parser.zig").TestHelpers.OperatorType;
const MemoryManager = @import("parser.zig").TestHelpers.MemoryManager;

fn parseCode(allocator: std.mem.Allocator, code: []const u8) !*AstNode {
    var lexer = Lexer.init(allocator, code);
    defer lexer.deinit();
    
    const tokens = try lexer.scanTokens();
    
    var memory_manager = MemoryManager.init(allocator);
    defer memory_manager.deinit();
    
    var parser = Parser.init(tokens, &memory_manager);
    return try parser.parse();
}

test "empty program" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 0), ast.data.block.statements.len);
}

test "simple expression" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "42;");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.expression_stmt, stmt.node_type);
    
    const expr = stmt.data.expression_stmt;
    try testing.expectEqual(AstNodeType.number_literal, expr.node_type);
    try testing.expectEqual(@as(f64, 42.0), expr.data.number_literal);
}

test "variable declaration" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "var x = 42;");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.variable_declaration, stmt.node_type);
    try testing.expectEqualStrings("x", stmt.data.variable_declaration.name);
    
    const initial_value = stmt.data.variable_declaration.initial_value.?;
    try testing.expectEqual(AstNodeType.number_literal, initial_value.node_type);
    try testing.expectEqual(@as(f64, 42.0), initial_value.data.number_literal);
}