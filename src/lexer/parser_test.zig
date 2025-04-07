const std = @import("std");
const testing = std.testing;
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const ParseError = @import("parser.zig").ParseError;

// Import memory manager and value types directly
const memory = @import("memory");
const value = @import("memory");

const MemoryManager = memory.MemoryManager;
const Value = memory.Value;
const AstNode = memory.AstNode;
const AstNodeType = memory.AstNodeType;
const OperatorType = memory.OperatorType;
const EventType = memory.EventType;

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

test "binary expression" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "2 + 3 * 4;");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.expression_stmt, stmt.node_type);
    
    const expr = stmt.data.expression_stmt;
    try testing.expectEqual(AstNodeType.binary_expression, expr.node_type);
    try testing.expectEqual(OperatorType.add, expr.data.binary_expression.operator);
    
    const left = expr.data.binary_expression.left;
    try testing.expectEqual(AstNodeType.number_literal, left.node_type);
    try testing.expectEqual(@as(f64, 2.0), left.data.number_literal);
    
    const right = expr.data.binary_expression.right;
    try testing.expectEqual(AstNodeType.binary_expression, right.node_type);
    try testing.expectEqual(OperatorType.multiply, right.data.binary_expression.operator);
    
    const mul_left = right.data.binary_expression.left;
    try testing.expectEqual(AstNodeType.number_literal, mul_left.node_type);
    try testing.expectEqual(@as(f64, 3.0), mul_left.data.number_literal);
    
    const mul_right = right.data.binary_expression.right;
    try testing.expectEqual(AstNodeType.number_literal, mul_right.node_type);
    try testing.expectEqual(@as(f64, 4.0), mul_right.data.number_literal);
}

test "block statement" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "{ var x = 1; var y = 2; }");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const block_stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.block, block_stmt.node_type);
    try testing.expectEqual(@as(usize, 2), block_stmt.data.block.statements.len);
    
    const var_x = block_stmt.data.block.statements[0];
    try testing.expectEqual(AstNodeType.variable_declaration, var_x.node_type);
    try testing.expectEqualStrings("x", var_x.data.variable_declaration.name);
    
    const var_y = block_stmt.data.block.statements[1];
    try testing.expectEqual(AstNodeType.variable_declaration, var_y.node_type);
    try testing.expectEqualStrings("y", var_y.data.variable_declaration.name);
}

test "if statement" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, 
        \\if x > 10 then
        \\  y = 20
        \\else
        \\  y = 30
    );
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const if_stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.if_stmt, if_stmt.node_type);
    
    const condition = if_stmt.data.if_stmt.condition;
    try testing.expectEqual(AstNodeType.binary_expression, condition.node_type);
    try testing.expectEqual(OperatorType.gt, condition.data.binary_expression.operator);
    
    const then_branch = if_stmt.data.if_stmt.then_branch;
    try testing.expectEqual(AstNodeType.expression_stmt, then_branch.node_type);
    
    const else_branch = if_stmt.data.if_stmt.else_branch.?;
    try testing.expectEqual(AstNodeType.expression_stmt, else_branch.node_type);
}

test "while statement" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, 
        \\while i < 10 do
        \\  i = i + 1
    );
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const while_stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.while_stmt, while_stmt.node_type);
    
    const condition = while_stmt.data.while_stmt.condition;
    try testing.expectEqual(AstNodeType.binary_expression, condition.node_type);
    try testing.expectEqual(OperatorType.lt, condition.data.binary_expression.operator);
    
    const body = while_stmt.data.while_stmt.body;
    try testing.expectEqual(AstNodeType.expression_stmt, body.node_type);
}

test "for statement" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, 
        \\for (var i = 0; i < 10; i = i + 1)
        \\  sum = sum + i
    );
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const for_stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.for_stmt, for_stmt.node_type);
    
    const init = for_stmt.data.for_stmt.init.?;
    try testing.expectEqual(AstNodeType.variable_declaration, init.node_type);
    try testing.expectEqualStrings("i", init.data.variable_declaration.name);
    
    const condition = for_stmt.data.for_stmt.condition.?;
    try testing.expectEqual(AstNodeType.binary_expression, condition.node_type);
    try testing.expectEqual(OperatorType.lt, condition.data.binary_expression.operator);
    
    const update = for_stmt.data.for_stmt.update.?;
    try testing.expectEqual(AstNodeType.binary_expression, update.node_type);
    try testing.expectEqual(OperatorType.assign, update.data.binary_expression.operator);
    
    const body = for_stmt.data.for_stmt.body;
    try testing.expectEqual(AstNodeType.expression_stmt, body.node_type);
}

test "for-in statement" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, 
        \\for item in items
        \\  sum = sum + item
    );
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const for_stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.for_stmt, for_stmt.node_type);
    
    // Note: The implementation just creates a placeholder for for-in loops
    try testing.expectEqual(@as(?*AstNode, null), for_stmt.data.for_stmt.init);
    try testing.expectEqual(@as(?*AstNode, null), for_stmt.data.for_stmt.condition);
    try testing.expectEqual(@as(?*AstNode, null), for_stmt.data.for_stmt.update);
    
    const body = for_stmt.data.for_stmt.body;
    try testing.expectEqual(AstNodeType.expression_stmt, body.node_type);
}

test "function declaration" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, 
        \\function add(a, b) {
        \\  return a + b
        \\}
    );
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const func_def = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.function_def, func_def.node_type);
    try testing.expectEqualStrings("add", func_def.data.function_def.name);
    
    const params = func_def.data.function_def.parameters;
    try testing.expectEqual(@as(usize, 2), params.len);
    
    try testing.expectEqual(AstNodeType.parameter_def, params[0].node_type);
    try testing.expectEqualStrings("a", params[0].data.parameter_def.name);
    
    try testing.expectEqual(AstNodeType.parameter_def, params[1].node_type);
    try testing.expectEqualStrings("b", params[1].data.parameter_def.name);
    
    const body = func_def.data.function_def.body;
    try testing.expectEqual(AstNodeType.block, body.node_type);
    try testing.expectEqual(@as(usize, 1), body.data.block.statements.len);
    
    const return_stmt = body.data.block.statements[0];
    try testing.expectEqual(AstNodeType.return_stmt, return_stmt.node_type);
}

test "trigger declaration" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, 
        \\trigger balance_changed on data_changed
        \\  when context.key == "balance" then
        \\    log(context.value)
        \\  end
    );
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    // Currently, trigger declarations are just placeholders in the parser
    const trigger_decl = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.variable_declaration, trigger_decl.node_type);
    try testing.expectEqual(true, std.mem.startsWith(u8, trigger_decl.data.variable_declaration.name, "trigger:"));
}

test "list literal" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "[1, 2, 3]");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.expression_stmt, stmt.node_type);
    
    const list = stmt.data.expression_stmt;
    try testing.expectEqual(AstNodeType.list_literal, list.node_type);
    try testing.expectEqual(@as(usize, 3), list.data.list_literal.len);
    
    try testing.expectEqual(AstNodeType.number_literal, list.data.list_literal[0].node_type);
    try testing.expectEqual(@as(f64, 1.0), list.data.list_literal[0].data.number_literal);
    
    try testing.expectEqual(AstNodeType.number_literal, list.data.list_literal[1].node_type);
    try testing.expectEqual(@as(f64, 2.0), list.data.list_literal[1].data.number_literal);
    
    try testing.expectEqual(AstNodeType.number_literal, list.data.list_literal[2].node_type);
    try testing.expectEqual(@as(f64, 3.0), list.data.list_literal[2].data.number_literal);
}

test "record literal" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "{ name: \"John\", age: 42 }");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.expression_stmt, stmt.node_type);
    
    const record = stmt.data.expression_stmt;
    try testing.expectEqual(AstNodeType.record_literal, record.node_type);
    
    try testing.expectEqual(@as(usize, 2), record.data.record_literal.keys.len);
    try testing.expectEqual(@as(usize, 2), record.data.record_literal.values.len);
    
    try testing.expectEqualStrings("name", record.data.record_literal.keys[0]);
    try testing.expectEqualStrings("age", record.data.record_literal.keys[1]);
    
    try testing.expectEqual(AstNodeType.text_literal, record.data.record_literal.values[0].node_type);
    try testing.expectEqualStrings("John", record.data.record_literal.values[0].data.text_literal);
    
    try testing.expectEqual(AstNodeType.number_literal, record.data.record_literal.values[1].node_type);
    try testing.expectEqual(@as(f64, 42.0), record.data.record_literal.values[1].data.number_literal);
}

test "member access" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "person.name");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.expression_stmt, stmt.node_type);
    
    const member_access = stmt.data.expression_stmt;
    try testing.expectEqual(AstNodeType.member_access, member_access.node_type);
    try testing.expectEqualStrings("name", member_access.data.member_access.member);
    
    const object = member_access.data.member_access.object;
    try testing.expectEqual(AstNodeType.identifier, object.node_type);
    try testing.expectEqualStrings("person", object.data.identifier);
}

test "index access" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "items[0]");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.expression_stmt, stmt.node_type);
    
    const index_expr = stmt.data.expression_stmt;
    try testing.expectEqual(AstNodeType.index_expression, index_expr.node_type);
    
    const array = index_expr.data.index_expression.array;
    try testing.expectEqual(AstNodeType.identifier, array.node_type);
    try testing.expectEqualStrings("items", array.data.identifier);
    
    const index = index_expr.data.index_expression.index;
    try testing.expectEqual(AstNodeType.number_literal, index.node_type);
    try testing.expectEqual(@as(f64, 0.0), index.data.number_literal);
}

test "call expression" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "add(1, 2)");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.expression_stmt, stmt.node_type);
    
    const call_expr = stmt.data.expression_stmt;
    try testing.expectEqual(AstNodeType.call_expression, call_expr.node_type);
    
    const callee = call_expr.data.call_expression.callee;
    try testing.expectEqual(AstNodeType.identifier, callee.node_type);
    try testing.expectEqualStrings("add", callee.data.identifier);
    
    const args = call_expr.data.call_expression.arguments;
    try testing.expectEqual(@as(usize, 2), args.len);
    
    try testing.expectEqual(AstNodeType.number_literal, args[0].node_type);
    try testing.expectEqual(@as(f64, 1.0), args[0].data.number_literal);
    
    try testing.expectEqual(AstNodeType.number_literal, args[1].node_type);
    try testing.expectEqual(@as(f64, 2.0), args[1].data.number_literal);
}

test "method call" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "list.push(42)");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 1), ast.data.block.statements.len);
    
    const stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.expression_stmt, stmt.node_type);
    
    const call_expr = stmt.data.expression_stmt;
    try testing.expectEqual(AstNodeType.call_expression, call_expr.node_type);
    
    const callee = call_expr.data.call_expression.callee;
    try testing.expectEqual(AstNodeType.member_access, callee.node_type);
    try testing.expectEqualStrings("push", callee.data.member_access.member);
    
    const object = callee.data.member_access.object;
    try testing.expectEqual(AstNodeType.identifier, object.node_type);
    try testing.expectEqualStrings("list", object.data.identifier);
    
    const args = call_expr.data.call_expression.arguments;
    try testing.expectEqual(@as(usize, 1), args.len);
    
    try testing.expectEqual(AstNodeType.number_literal, args[0].node_type);
    try testing.expectEqual(@as(f64, 42.0), args[0].data.number_literal);
}

test "unary expression" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "-42; !true");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 2), ast.data.block.statements.len);
    
    // Test negative number
    const neg_stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.expression_stmt, neg_stmt.node_type);
    
    const neg_expr = neg_stmt.data.expression_stmt;
    try testing.expectEqual(AstNodeType.unary_expression, neg_expr.node_type);
    try testing.expectEqual(OperatorType.subtract, neg_expr.data.unary_expression.operator);
    
    const neg_operand = neg_expr.data.unary_expression.operand;
    try testing.expectEqual(AstNodeType.number_literal, neg_operand.node_type);
    try testing.expectEqual(@as(f64, 42.0), neg_operand.data.number_literal);
    
    // Test logical not
    const not_stmt = ast.data.block.statements[1];
    try testing.expectEqual(AstNodeType.expression_stmt, not_stmt.node_type);
    
    const not_expr = not_stmt.data.expression_stmt;
    try testing.expectEqual(AstNodeType.unary_expression, not_expr.node_type);
    try testing.expectEqual(OperatorType.not, not_expr.data.unary_expression.operator);
    
    const not_operand = not_expr.data.unary_expression.operand;
    try testing.expectEqual(AstNodeType.boolean_literal, not_operand.node_type);
    try testing.expectEqual(true, not_operand.data.boolean_literal);
}

test "special literals" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, "var date = @\"2023-01-15\"; var money = @\"$123.45\";");
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 2), ast.data.block.statements.len);
    
    // Date literal
    const date_stmt = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.variable_declaration, date_stmt.node_type);
    try testing.expectEqualStrings("date", date_stmt.data.variable_declaration.name);
    
    const date_value = date_stmt.data.variable_declaration.initial_value.?;
    try testing.expectEqual(AstNodeType.text_literal, date_value.node_type);
    try testing.expectEqualStrings("2023-01-15", date_value.data.text_literal);
    
    // Money literal
    const money_stmt = ast.data.block.statements[1];
    try testing.expectEqual(AstNodeType.variable_declaration, money_stmt.node_type);
    try testing.expectEqualStrings("money", money_stmt.data.variable_declaration.name);
    
    const money_value = money_stmt.data.variable_declaration.initial_value.?;
    try testing.expectEqual(AstNodeType.text_literal, money_value.node_type);
    try testing.expectEqualStrings("$123.45", money_value.data.text_literal);
}

test "complex program" {
    const allocator = testing.allocator;
    const ast = try parseCode(allocator, 
        \\function calculateTotal(items) {
        \\  var total = @"$0.00"
        \\  for item in items do
        \\    total = total + item.price
        \\  return total
        \\}
        \\
        \\var inventory = [
        \\  { name: "Widget", price: @"$10.99" },
        \\  { name: "Gadget", price: @"$15.49" }
        \\]
        \\
        \\var grandTotal = calculateTotal(inventory)
    );
    
    try testing.expectEqual(AstNodeType.block, ast.node_type);
    try testing.expectEqual(@as(usize, 3), ast.data.block.statements.len);
    
    // Check the function declaration
    const func_def = ast.data.block.statements[0];
    try testing.expectEqual(AstNodeType.function_def, func_def.node_type);
    try testing.expectEqualStrings("calculateTotal", func_def.data.function_def.name);
    
    // Check the inventory variable
    const inventory = ast.data.block.statements[1];
    try testing.expectEqual(AstNodeType.variable_declaration, inventory.node_type);
    try testing.expectEqualStrings("inventory", inventory.data.variable_declaration.name);
    
    const list_value = inventory.data.variable_declaration.initial_value.?;
    try testing.expectEqual(AstNodeType.list_literal, list_value.node_type);
    try testing.expectEqual(@as(usize, 2), list_value.data.list_literal.len);
    
    // Check the grandTotal assignment
    const grand_total = ast.data.block.statements[2];
    try testing.expectEqual(AstNodeType.variable_declaration, grand_total.node_type);
    try testing.expectEqualStrings("grandTotal", grand_total.data.variable_declaration.name);
    
    const call_expr = grand_total.data.variable_declaration.initial_value.?;
    try testing.expectEqual(AstNodeType.call_expression, call_expr.node_type);
    try testing.expectEqualStrings("calculateTotal", call_expr.data.call_expression.callee.data.identifier);
}

test "error handling - unexpected token" {
    const allocator = testing.allocator;
    
    // Test for a missing closing paren
    const parse_result = parseCode(allocator, "function add(a, b { return a + b; }");
    try testing.expectError(ParseError.MissingClosingParen, parse_result);
    
    // Test for a missing identifier
    const parse_result2 = parseCode(allocator, "var = 42;");
    try testing.expectError(ParseError.MissingIdentifier, parse_result2);
    
    // Test for a missing closing brace
    const parse_result3 = parseCode(allocator, "{ var x = 1;");
    try testing.expectError(ParseError.MissingClosingBrace, parse_result3);
}