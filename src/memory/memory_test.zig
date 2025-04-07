const std = @import("std");
const testing = std.testing;
const MemoryManager = @import("memory.zig").MemoryManager;
const Value = @import("value.zig").Value;
const ValueType = @import("value.zig").ValueType;
const MemoryError = @import("memory.zig").MemoryError;

test "value allocation" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();

    const number = try memory.allocateNumber(42.0);
    try testing.expectEqual(@as(f64, 42.0), number.data.number);

    const text = try memory.allocateText("Hello, World!");
    try testing.expectEqualStrings("Hello, World!", text.data.text);

    // Test money with integer representation - $123.45 = 1234500 in the internal representation
    const money = try memory.allocateMoneyFromDecimal(123, 45, "USD");
    try testing.expectEqual(@as(i128, 1234500), money.data.money.amount);
    try testing.expectEqualStrings("USD", money.data.money.currency);
    
    // Test money formatting by checking whole and fractional parts
    try testing.expectEqual(@as(i64, 123), money.data.money.wholeUnits());
    try testing.expectEqual(@as(i64, 45), money.data.money.fractionalUnits());

    const time = try memory.allocateTime(12, 34, 56, 789);
    try testing.expectEqual(@as(u8, 12), time.data.time.hours);
    try testing.expectEqual(@as(u8, 34), time.data.time.minutes);
    try testing.expectEqual(@as(u8, 56), time.data.time.seconds);
    try testing.expectEqual(@as(u16, 789), time.data.time.milliseconds);

    const date = try memory.allocateDate(2024, 3, 14);
    try testing.expectEqual(@as(i32, 2024), date.data.date.year);
    try testing.expectEqual(@as(u8, 3), date.data.date.month);
    try testing.expectEqual(@as(u8, 14), date.data.date.day);

    const percentage = try memory.allocatePercentage(42.5);
    try testing.expectEqual(@as(f64, 42.5), percentage.data.percentage.value);

    const ratio = try memory.allocateRatio(22, 7);
    try testing.expectEqual(@as(f64, 22), ratio.data.ratio.numerator);
    try testing.expectEqual(@as(f64, 7), ratio.data.ratio.denominator);

    const boolean = try memory.allocateBoolean(true);
    try testing.expect(boolean.data.boolean);

    const unknown = try memory.allocateUnknown();
    try testing.expectEqual(ValueType.unknown, unknown.data);

    const nil = try memory.allocateNil();
    try testing.expectEqual(ValueType.nil, nil.data);
}

test "arithmetic operations" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();

    const a = try memory.allocateNumber(42.0);
    const b = try memory.allocateNumber(8.0);
    const c = try memory.allocateMoneyFromDecimal(10, 0, "USD"); // $10.00
    const d = try memory.allocatePercentage(20.0);

    const sum = try memory.add(a, b);
    try testing.expectEqual(@as(f64, 50.0), sum.data.number);

    const diff = try memory.subtract(a, b);
    try testing.expectEqual(@as(f64, 34.0), diff.data.number);

    const product = try memory.multiply(a, b);
    try testing.expectEqual(@as(f64, 336.0), product.data.number);

    const quotient = try memory.divide(a, b);
    try testing.expectEqual(@as(f64, 5.25), quotient.data.number);

    const money_sum = try memory.add(a, c);
    try testing.expectEqual(@as(i128, 520000), money_sum.data.money.amount); // 42 + 10 = 52 dollars = 520000 units
    try testing.expectEqualStrings("USD", money_sum.data.money.currency);

    const percentage_sum = try memory.add(a, d);
    try testing.expectEqual(@as(f64, 62.0), percentage_sum.data.percentage.value);

    const percentage_product = try memory.multiply(d, a);
    try testing.expectEqual(@as(f64, 840.0), percentage_product.data.percentage.value);
}

test "special literals" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();
    
    // Test date literal parsing
    const date = try memory.allocateFromSpecialLiteral("@\"2024-03-15\"") orelse unreachable;
    try testing.expectEqual(ValueType.date, @as(ValueType, date.data));
    try testing.expectEqual(@as(i32, 2024), date.data.date.year);
    try testing.expectEqual(@as(u8, 3), date.data.date.month);
    try testing.expectEqual(@as(u8, 15), date.data.date.day);
    
    // Test time literal parsing  
    const time = try memory.allocateFromSpecialLiteral("@\"14:30:45.500\"") orelse unreachable;
    try testing.expectEqual(ValueType.time, @as(ValueType, time.data));
    try testing.expectEqual(@as(u8, 14), time.data.time.hours);
    try testing.expectEqual(@as(u8, 30), time.data.time.minutes);
    try testing.expectEqual(@as(u8, 45), time.data.time.seconds);
    try testing.expectEqual(@as(u16, 500), time.data.time.milliseconds);
    
    // Test datetime literal parsing
    const dt = try memory.allocateFromSpecialLiteral("@\"2024-03-15T14:30:45\"") orelse unreachable;
    try testing.expectEqual(ValueType.date_time, @as(ValueType, dt.data));
    try testing.expectEqual(@as(i32, 2024), dt.data.date_time.date.year);
    try testing.expectEqual(@as(u8, 3), dt.data.date_time.date.month);
    try testing.expectEqual(@as(u8, 15), dt.data.date_time.date.day);
    try testing.expectEqual(@as(u8, 14), dt.data.date_time.time.hours);
    try testing.expectEqual(@as(u8, 30), dt.data.date_time.time.minutes);
    
    // Test money literal parsing
    const money = try memory.allocateFromSpecialLiteral("@\"$123.45\"") orelse unreachable;
    try testing.expectEqual(ValueType.money, @as(ValueType, money.data));
    try testing.expectEqual(@as(i128, 1234500), money.data.money.amount);
    try testing.expectEqualStrings("USD", money.data.money.currency);
    try testing.expectEqual(@as(i64, 123), money.data.money.wholeUnits());
    try testing.expectEqual(@as(i64, 45), money.data.money.fractionalUnits());
    
    // Test negative money
    const neg_money = try memory.allocateFromSpecialLiteral("@\"$-42.99\"") orelse unreachable;
    try testing.expectEqual(ValueType.money, @as(ValueType, neg_money.data));
    try testing.expectEqual(@as(i128, -429900), neg_money.data.money.amount);
    try testing.expectEqual(@as(i64, -42), neg_money.data.money.wholeUnits());
    try testing.expectEqual(@as(i64, -99), neg_money.data.money.fractionalUnits());
    
    // Test invalid literals
    const invalid_date = try memory.allocateFromSpecialLiteral("@\"2024/03/15\"");
    try testing.expectEqual(@as(?*Value, null), invalid_date);
    
    const not_special = try memory.allocateFromSpecialLiteral("2024-03-15");
    try testing.expectEqual(@as(?*Value, null), not_special);
}

test "functions and triggers" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();
    
    const SourcePosition = @import("value.zig").SourcePosition;
    const AstNodeType = @import("value.zig").AstNodeType;
    const EventType = @import("value.zig").EventType;
    const OperatorType = @import("value.zig").OperatorType;
    
    // Create a simple AST for a function that returns a + b
    const unknown_pos = SourcePosition.unknown();
    
    // Create function parameters
    const _param_a = try memory.createIdentifier("a", unknown_pos);
    _ = _param_a; // Will be used in future implementation
    const _param_b = try memory.createIdentifier("b", unknown_pos);
    _ = _param_b; // Will be used in future implementation
    
    // Create function body: return a + b;
    const var_a = try memory.createIdentifier("a", unknown_pos);
    const var_b = try memory.createIdentifier("b", unknown_pos);
    const add_expr = try memory.createBinaryExpression(var_a, OperatorType.add, var_b, unknown_pos);
    const return_stmt = blk: {
        const _AstNode = @import("value.zig").AstNode;
        _ = _AstNode; // Will be used in future implementation
        var node = memory.createAstNode();
        node.* = .{
            .node_type = AstNodeType.return_stmt,
            .pos = unknown_pos,
            .data = .{ .return_stmt = add_expr },
        };
        break :blk node;
    };
    
    const body_stmts = [_]*@import("value.zig").AstNode{return_stmt};
    const body_block = try memory.createBlock(&body_stmts, unknown_pos);
    
    // Create the function
    const params = [_][]const u8{ "a", "b" };
    const func = try memory.allocateFunction("add", &params, body_block);
    
    // Verify the function was created correctly
    try testing.expectEqual(ValueType.function, @as(ValueType, func.data));
    try testing.expectEqualStrings("add", func.data.function.name);
    try testing.expectEqual(@as(usize, 2), func.data.function.parameters.len);
    try testing.expectEqualStrings("a", func.data.function.parameters[0]);
    try testing.expectEqualStrings("b", func.data.function.parameters[1]);
    
    // Create a simple trigger when a value > 100
    const value_id = try memory.createIdentifier("value", unknown_pos);
    const threshold = try memory.createNumberLiteral(100.0, unknown_pos);
    const condition = try memory.createBinaryExpression(value_id, OperatorType.gt, threshold, unknown_pos);
    
    // Action: setValue(value / 2)
    const set_value_id = try memory.createIdentifier("setValue", unknown_pos);
    const value_id2 = try memory.createIdentifier("value", unknown_pos);
    const two = try memory.createNumberLiteral(2.0, unknown_pos);
    const div_expr = try memory.createBinaryExpression(value_id2, OperatorType.divide, two, unknown_pos);
    const args = [_]*@import("value.zig").AstNode{div_expr};
    const call_expr = blk: {
        const _AstNode = @import("value.zig").AstNode;
        _ = _AstNode; // Will be used in future implementation
        var node = memory.createAstNode();
        node.* = .{
            .node_type = AstNodeType.call_expression,
            .pos = unknown_pos,
            .data = .{
                .call_expression = .{
                    .callee = set_value_id,
                    .arguments = args,
                },
            },
        };
        break :blk node;
    };
    
    const action_stmts = [_]*@import("value.zig").AstNode{call_expr};
    const action_block = try memory.createBlock(&action_stmts, unknown_pos);
    
    // Create the trigger
    const trigger = try memory.allocateTrigger("value_limiter", EventType.data_changed, 
                                             condition, action_block);
    
    // Verify the trigger was created correctly
    try testing.expectEqual(ValueType.trigger, @as(ValueType, trigger.data));
    try testing.expectEqualStrings("value_limiter", trigger.data.trigger.name);
    try testing.expectEqual(EventType.data_changed, trigger.data.trigger.event_type);
}

test "interpreter" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();
    
    const SourcePosition = @import("value.zig").SourcePosition;
    const AstNodeType = @import("value.zig").AstNodeType;
    const OperatorType = @import("value.zig").OperatorType;
    
    // Create an interpreter with a fresh environment
    const interpreter = try memory.createInterpreter();
    
    // Create a test function: function add(a, b) { return a + b; }
    const unknown_pos = SourcePosition.unknown();
    
    // Function parameters
    const param_names = [_][]const u8{ "a", "b" };
    
    // Function body: return a + b;
    const var_a = try memory.createIdentifier("a", unknown_pos);
    const var_b = try memory.createIdentifier("b", unknown_pos);
    const add_expr = try memory.createBinaryExpression(var_a, OperatorType.add, var_b, unknown_pos);
    const return_stmt = blk: {
        const _AstNode = @import("value.zig").AstNode;
        _ = _AstNode; // Will be used in future implementation
        var node = memory.createAstNode();
        node.* = .{
            .node_type = AstNodeType.return_stmt,
            .pos = unknown_pos,
            .data = .{ .return_stmt = add_expr },
        };
        break :blk node;
    };
    
    const body_stmts = [_]*@import("value.zig").AstNode{return_stmt};
    const body_block = try memory.createBlock(&body_stmts, unknown_pos);
    
    // Create the function
    const func = try memory.allocateFunction("add", &param_names, body_block);
    
    // Register the function in the environment
    try interpreter.environment.define("add", func);
    
    // Create arguments for calling the function
    const arg1 = try memory.allocateNumber(5);
    const arg2 = try memory.allocateNumber(7);
    const args = [_]*Value{ arg1, arg2 };
    
    // Call the function
    const result = try memory.executeFunction(interpreter, func, &args);
    
    // Verify the result
    try testing.expectEqual(ValueType.number, @as(ValueType, result.data));
    try testing.expectEqual(@as(f64, 12.0), result.data.number);
    
    // Test an expression with the interpreter: 10 + 20 * 2
    const num10 = try memory.createNumberLiteral(10.0, unknown_pos);
    const num20 = try memory.createNumberLiteral(20.0, unknown_pos);
    const num2 = try memory.createNumberLiteral(2.0, unknown_pos);
    
    const mul_expr = try memory.createBinaryExpression(num20, OperatorType.multiply, num2, unknown_pos);
    const add_expr2 = try memory.createBinaryExpression(num10, OperatorType.add, mul_expr, unknown_pos);
    
    const expr_result = try memory.evaluateAst(interpreter, add_expr2);
    
    // Verify the expression result: 10 + (20 * 2) = 50
    try testing.expectEqual(ValueType.number, @as(ValueType, expr_result.data));
    try testing.expectEqual(@as(f64, 50.0), expr_result.data.number);
    
    // Test a trigger
    const ctx = try memory.allocateRecord();
    try memory.recordSet(ctx, "value", try memory.allocateNumber(150.0));
    try memory.recordSet(ctx, "processed", try memory.allocateBoolean(false));
    
    // Create a trigger condition: context.value > 100
    const ctx_id = try memory.createIdentifier("context", unknown_pos);
    const value_access = blk: {
        const _AstNode = @import("value.zig").AstNode;
        _ = _AstNode; // Will be used in future implementation
        var node = memory.createAstNode();
        node.* = .{
            .node_type = AstNodeType.member_access,
            .pos = unknown_pos,
            .data = .{
                .member_access = .{
                    .object = ctx_id,
                    .member = "value",
                },
            },
        };
        break :blk node;
    };
    
    const num100 = try memory.createNumberLiteral(100.0, unknown_pos);
    const condition = try memory.createBinaryExpression(value_access, OperatorType.gt, num100, unknown_pos);
    
    // Create a trigger action that sets context.processed = true
    const ctx_id2 = try memory.createIdentifier("context", unknown_pos);
    const processed_access = blk: {
        const _AstNode = @import("value.zig").AstNode;
        _ = _AstNode; // Will be used in future implementation
        var node = memory.createAstNode();
        node.* = .{
            .node_type = AstNodeType.member_access,
            .pos = unknown_pos,
            .data = .{
                .member_access = .{
                    .object = ctx_id2,
                    .member = "processed",
                },
            },
        };
        break :blk node;
    };
    
    const true_val = try memory.createBooleanLiteral(true, unknown_pos);
    const assign_expr = try memory.createBinaryExpression(
        processed_access, OperatorType.assign, true_val, unknown_pos);
    
    const action_stmts = [_]*@import("value.zig").AstNode{assign_expr};
    const action_block = try memory.createBlock(&action_stmts, unknown_pos);
    
    // Create the trigger
    const EventType = @import("value.zig").EventType;
    const trigger = try memory.allocateTrigger("test_trigger", EventType.data_changed, 
                                             condition, action_block);
    
    // Execute the trigger with the context
    try memory.executeTrigger(interpreter, trigger, ctx);
    
    // Verify that the trigger action executed
    const processed = try memory.recordGet(ctx, "processed") orelse unreachable;
    try testing.expectEqual(ValueType.boolean, @as(ValueType, processed.data));
    try testing.expectEqual(true, processed.data.boolean);
}

test "automatic triggers" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();
    
    const SourcePosition = @import("value.zig").SourcePosition;
    const AstNodeType = @import("value.zig").AstNodeType;
    const OperatorType = @import("value.zig").OperatorType;
    const EventType = @import("value.zig").EventType;
    
    // Create an interpreter
    const interpreter = try memory.createInterpreter();
    
    // Create a record to be monitored
    const user = try memory.allocateRecord();
    try memory.recordSet(user, "name", try memory.allocateText("John"));
    try memory.recordSet(user, "age", try memory.allocateNumber(30));
    try memory.recordSet(user, "balance", try memory.allocateMoneyFromDecimal(100, 0, "USD"));
    try memory.recordSet(user, "log", try memory.allocateList());
    
    // Create an audit log record
    const audit_log = try memory.allocateRecord();
    try memory.recordSet(audit_log, "entries", try memory.allocateList());
    
    // Create a trigger that logs when the user's balance changes
    const unknown_pos = SourcePosition.unknown();
    
    // Condition: context.key == "balance"
    const ctx_id = try memory.createIdentifier("context", unknown_pos);
    const key_access = blk: {
        const _AstNode = @import("value.zig").AstNode;
        _ = _AstNode; // Will be used in future implementation
        var node = memory.createAstNode();
        node.* = .{
            .node_type = AstNodeType.member_access,
            .pos = unknown_pos,
            .data = .{
                .member_access = .{
                    .object = ctx_id,
                    .member = "key",
                },
            },
        };
        break :blk node;
    };
    
    const balance_lit = try memory.createTextLiteral("balance", unknown_pos);
    const condition = try memory.createBinaryExpression(key_access, OperatorType.eq, balance_lit, unknown_pos);
    
    // Action: Add an entry to the audit log
    // audit_log.entries.push("Balance changed to " + context.value)
    
    // 1. Create the log message
    const msg_prefix = try memory.createTextLiteral("Balance changed to ", unknown_pos);
    const ctx_value = blk: {
        const _AstNode = @import("value.zig").AstNode;
        _ = _AstNode; // Will be used in future implementation
        var node = memory.createAstNode();
        node.* = .{
            .node_type = AstNodeType.member_access,
            .pos = unknown_pos,
            .data = .{
                .member_access = .{
                    .object = ctx_id,
                    .member = "value",
                },
            },
        };
        break :blk node;
    };
    
    const concat_expr = try memory.createBinaryExpression(msg_prefix, OperatorType.add, ctx_value, unknown_pos);
    
    // 2. Get the audit log entries array
    const audit_log_id = try memory.createIdentifier("audit_log", unknown_pos);
    const entries_access = blk: {
        const _AstNode = @import("value.zig").AstNode;
        _ = _AstNode; // Will be used in future implementation
        var node = memory.createAstNode();
        node.* = .{
            .node_type = AstNodeType.member_access,
            .pos = unknown_pos,
            .data = .{
                .member_access = .{
                    .object = audit_log_id,
                    .member = "entries",
                },
            },
        };
        break :blk node;
    };
    
    // 3. Create the push method call
    const _push_id = try memory.createIdentifier("push", unknown_pos);
    _ = _push_id; // Will be used in future implementation
    const push_member = blk: {
        const _AstNode = @import("value.zig").AstNode;
        _ = _AstNode; // Will be used in future implementation
        var node = memory.createAstNode();
        node.* = .{
            .node_type = AstNodeType.member_access,
            .pos = unknown_pos,
            .data = .{
                .member_access = .{
                    .object = entries_access,
                    .member = "push",
                },
            },
        };
        break :blk node;
    };
    
    const call_args = [_]*@import("value.zig").AstNode{concat_expr};
    const call_expr = blk: {
        const _AstNode = @import("value.zig").AstNode;
        _ = _AstNode; // Will be used in future implementation
        var node = memory.createAstNode();
        node.* = .{
            .node_type = AstNodeType.call_expression,
            .pos = unknown_pos,
            .data = .{
                .call_expression = .{
                    .callee = push_member,
                    .arguments = call_args,
                },
            },
        };
        break :blk node;
    };
    
    const action_block = blk: {
        const action_stmts = [_]*@import("value.zig").AstNode{call_expr};
        break :blk try memory.createBlock(&action_stmts, unknown_pos);
    };
    
    // Create the trigger
    const trigger = try memory.allocateTrigger("balance_change_logger", EventType.data_changed, 
                                             condition, action_block);
    
    // Register the trigger
    try memory.registerTrigger(trigger);
    
    // Add the audit_log to the environment so it can be accessed by the trigger
    try interpreter.environment.define("audit_log", audit_log);
    
    // Define the push method on lists
    const push_fn = try memory.createIdentifier("listPush", unknown_pos);
    try interpreter.environment.define("push", push_fn);
    
    // Change the user's balance a few times
    try memory.recordSet(user, "balance", try memory.allocateMoneyFromDecimal(200, 0, "USD"));
    try memory.recordSet(user, "balance", try memory.allocateMoneyFromDecimal(150, 0, "USD"));
    try memory.recordSet(user, "name", try memory.allocateText("John Doe"));  // This shouldn't trigger the log
    
    // Check that the audit log has exactly 2 entries
    const entries = try memory.recordGet(audit_log, "entries") orelse unreachable;
    try testing.expectEqual(ValueType.list, @as(ValueType, entries.data));
    try testing.expectEqual(@as(usize, 2), try memory.listLength(entries));
}

test "comparison operations" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();

    const a = try memory.allocateNumber(42.0);
    const b = try memory.allocateNumber(42.0);
    const c = try memory.allocateNumber(43.0);
    const d = try memory.allocateMoneyFromDecimal(42, 0, "USD"); // $42.00
    const e = try memory.allocateText("Hello");
    const f = try memory.allocateText("World");
    const g = try memory.allocatePercentage(42.0);

    try testing.expectEqual(@as(i32, 0), try MemoryManager.compare(a, b));
    try testing.expectEqual(@as(i32, -1), try MemoryManager.compare(a, c));
    try testing.expectEqual(@as(i32, 1), try MemoryManager.compare(c, a));
    try testing.expectEqual(@as(i32, 0), try MemoryManager.compare(a, d));
    try testing.expectEqual(@as(i32, -1), try MemoryManager.compare(e, f));
    try testing.expectEqual(@as(i32, 0), try MemoryManager.compare(a, g));
}

test "type conversion" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();

    const number = try memory.allocateNumber(42.0);
    const money = try memory.allocateMoneyFromDecimal(123, 45, "USD");
    const percentage = try memory.allocatePercentage(20.0);
    const ratio = try memory.allocateRatio(22, 7);

    const number_to_money = try memory.convert(number, .money);
    try testing.expectEqual(@as(i128, 420000), number_to_money.data.money.amount); // 42.0 -> 420000 units
    try testing.expectEqualStrings("USD", number_to_money.data.money.currency);

    const money_to_number = try memory.convert(money, .number);
    try testing.expectEqual(@as(f64, 123.45), money_to_number.data.number);

    const number_to_percentage = try memory.convert(number, .percentage);
    try testing.expectEqual(@as(f64, 42.0), number_to_percentage.data.percentage.value);

    const percentage_to_number = try memory.convert(percentage, .number);
    try testing.expectEqual(@as(f64, 20.0), percentage_to_number.data.number);

    const ratio_to_number = try memory.convert(ratio, .number);
    try testing.expectApproxEqAbs(@as(f64, 3.142857142857143), ratio_to_number.data.number, 0.000000000000001);
}

test "date time operations" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();
    
    // Test date string parsing
    const date_str = try memory.allocateDateFromString("2024-03-15");
    try testing.expectEqual(@as(i32, 2024), date_str.data.date.year);
    try testing.expectEqual(@as(u8, 3), date_str.data.date.month);
    try testing.expectEqual(@as(u8, 15), date_str.data.date.day);
    
    // Test time string parsing
    const time_str = try memory.allocateTimeFromString("14:30:45.500");
    try testing.expectEqual(@as(u8, 14), time_str.data.time.hours);
    try testing.expectEqual(@as(u8, 30), time_str.data.time.minutes);
    try testing.expectEqual(@as(u8, 45), time_str.data.time.seconds);
    try testing.expectEqual(@as(u16, 500), time_str.data.time.milliseconds);
    
    // Test datetime string parsing (with space separator)
    const dt_str1 = try memory.allocateDateTimeFromString("2024-03-15 14:30:45.500");
    try testing.expectEqual(@as(i32, 2024), dt_str1.data.date_time.date.year);
    try testing.expectEqual(@as(u8, 3), dt_str1.data.date_time.date.month);
    try testing.expectEqual(@as(u8, 15), dt_str1.data.date_time.date.day);
    try testing.expectEqual(@as(u8, 14), dt_str1.data.date_time.time.hours);
    try testing.expectEqual(@as(u8, 30), dt_str1.data.date_time.time.minutes);
    try testing.expectEqual(@as(u8, 45), dt_str1.data.date_time.time.seconds);
    try testing.expectEqual(@as(u16, 500), dt_str1.data.date_time.time.milliseconds);
    
    // Test datetime string parsing (with T separator)
    const dt_str2 = try memory.allocateDateTimeFromString("2024-03-15T14:30:45");
    try testing.expectEqual(@as(i32, 2024), dt_str2.data.date_time.date.year);
    try testing.expectEqual(@as(u8, 3), dt_str2.data.date_time.date.month);
    try testing.expectEqual(@as(u8, 15), dt_str2.data.date_time.date.day);
    try testing.expectEqual(@as(u8, 14), dt_str2.data.date_time.time.hours);
    try testing.expectEqual(@as(u8, 30), dt_str2.data.date_time.time.minutes);
    try testing.expectEqual(@as(u8, 45), dt_str2.data.date_time.time.seconds);
    
    // Test basic DateTime creation
    const dt = try memory.allocateDateTime(2024, 3, 15, 14, 30, 45, 500);
    try testing.expectEqual(@as(i32, 2024), dt.data.date_time.date.year);
    try testing.expectEqual(@as(u8, 3), dt.data.date_time.date.month);
    try testing.expectEqual(@as(u8, 15), dt.data.date_time.date.day);
    try testing.expectEqual(@as(u8, 14), dt.data.date_time.time.hours);
    try testing.expectEqual(@as(u8, 30), dt.data.date_time.time.minutes);
    try testing.expectEqual(@as(u8, 45), dt.data.date_time.time.seconds);
    try testing.expectEqual(@as(u16, 500), dt.data.date_time.time.milliseconds);
    
    // Test DateTime creation from separate Date and Time values
    const date = try memory.allocateDate(2024, 4, 1);
    const time = try memory.allocateTime(9, 15, 0, 0);
    const dt2 = try memory.allocateDateTimeFromParts(date, time);
    
    try testing.expectEqual(@as(i32, 2024), dt2.data.date_time.date.year);
    try testing.expectEqual(@as(u8, 4), dt2.data.date_time.date.month);
    try testing.expectEqual(@as(u8, 1), dt2.data.date_time.date.day);
    try testing.expectEqual(@as(u8, 9), dt2.data.date_time.time.hours);
    try testing.expectEqual(@as(u8, 15), dt2.data.date_time.time.minutes);
    
    // Test day of week functionality
    const friday = dt.data.date_time.date.dayOfWeek();
    try testing.expectEqual(@as(u3, 5), @intFromEnum(friday)); // March 15, 2024 is a Friday
    
    // Test DateTime addition
    const added_time = dt.data.date_time.addTime(2, 30, 15, 500);
    try testing.expectEqual(@as(u8, 17), added_time.time.hours); // 14 + 2 = 16 hours
    try testing.expectEqual(@as(u8, 1), added_time.time.minutes); // 30 + 30 = 60 -> 0 minutes, carry 1 hour
    try testing.expectEqual(@as(u8, 1), added_time.time.seconds); // 45 + 15 = 60 -> 0 seconds, carry 1 minute
    try testing.expectEqual(@as(u16, 0), added_time.time.milliseconds); // 500 + 500 = 1000 -> 0 milliseconds, carry 1 second
    
    // Test time overflow to next day
    const overnight = dt.data.date_time.addTime(10, 0, 0, 0);
    try testing.expectEqual(@as(u8, 0), overnight.time.hours); // 14 + 10 = 24 -> 0 hours, carry 1 day
    try testing.expectEqual(@as(u8, 16), overnight.date.day); // 15 + 1 = 16
    
    // Test next/previous day of week
    const next_monday = dt.data.date_time.nextDayOfWeek(.monday);
    try testing.expectEqual(@as(u8, 18), next_monday.date.day); // Next Monday is March 18, 2024
    
    const prev_monday = dt.data.date_time.previousDayOfWeek(.monday);
    try testing.expectEqual(@as(u8, 11), prev_monday.date.day); // Previous Monday is March 11, 2024
    
    // Test adding days/months/years
    const plus_days = dt.data.date_time.addDays(10);
    try testing.expectEqual(@as(u8, 25), plus_days.date.day); // March 15 + 10 days = March 25
    
    const plus_months = dt.data.date_time.addMonths(2);
    try testing.expectEqual(@as(u8, 5), plus_months.date.month); // March + 2 months = May
    
    const plus_years = dt.data.date_time.addYears(1);
    try testing.expectEqual(@as(i32, 2025), plus_years.date.year); // 2024 + 1 = 2025
    
    // Test comparison
    const later = try memory.allocateDateTime(2024, 3, 15, 15, 0, 0, 0);
    try testing.expectEqual(@as(i32, -1), try MemoryManager.compare(dt, later));
    
    const earlier = try memory.allocateDateTime(2024, 3, 15, 14, 0, 0, 0);
    try testing.expectEqual(@as(i32, 1), try MemoryManager.compare(dt, earlier));
    
    const same_time = try memory.allocateDateTime(2024, 3, 15, 14, 30, 45, 500);
    try testing.expectEqual(@as(i32, 0), try MemoryManager.compare(dt, same_time));
    
    // Test deep copy
    const dt_copy = try memory.deepCopy(dt);
    try testing.expectEqual(@as(i32, 0), try MemoryManager.compare(dt, dt_copy));
    
    // Test conversion between Date, Time, and DateTime
    const dt_to_date = try memory.convert(dt, .date);
    try testing.expectEqual(ValueType.date, @as(ValueType, dt_to_date.data));
    try testing.expectEqual(@as(i32, 2024), dt_to_date.data.date.year);
    try testing.expectEqual(@as(u8, 3), dt_to_date.data.date.month);
    try testing.expectEqual(@as(u8, 15), dt_to_date.data.date.day);
    
    const dt_to_time = try memory.convert(dt, .time);
    try testing.expectEqual(ValueType.time, @as(ValueType, dt_to_time.data));
    try testing.expectEqual(@as(u8, 14), dt_to_time.data.time.hours);
    try testing.expectEqual(@as(u8, 30), dt_to_time.data.time.minutes);
    try testing.expectEqual(@as(u8, 45), dt_to_time.data.time.seconds);
    
    const date_to_dt = try memory.convert(date, .date_time);
    try testing.expectEqual(ValueType.date_time, @as(ValueType, date_to_dt.data));
    try testing.expectEqual(@as(i32, 2024), date_to_dt.data.date_time.date.year);
    try testing.expectEqual(@as(u8, 4), date_to_dt.data.date_time.date.month);
    try testing.expectEqual(@as(u8, 1), date_to_dt.data.date_time.date.day);
    try testing.expectEqual(@as(u8, 0), date_to_dt.data.date_time.time.hours);  // Default time is 00:00:00.000
}

test "error handling" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();

    const zero = try memory.allocateNumber(0.0);
    const one = try memory.allocateNumber(1.0);

    _ = memory.divide(one, zero) catch |err| {
        try testing.expectEqual(MemoryError.DivisionByZero, err);
    };

    const usd = try memory.allocateMoneyFromDecimal(10, 0, "USD");
    const eur = try memory.allocateMoneyFromDecimal(10, 0, "EUR");

    _ = memory.add(usd, eur) catch |err| {
        try testing.expectEqual(MemoryError.InvalidOperation, err);
    };

    const text = try memory.allocateText("Hello");
    const number = try memory.allocateNumber(42.0);

    _ = memory.add(text, number) catch |err| {
        try testing.expectEqual(MemoryError.InvalidOperation, err);
    };
}

test "list operations" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();

    // Create a list
    const list = try memory.allocateList();
    
    // Initial length should be 0
    try testing.expectEqual(@as(usize, 0), try memory.listLength(list));
    
    // Add items to the list
    const num1 = try memory.allocateNumber(42);
    const text1 = try memory.allocateText("Hello");
    const bool1 = try memory.allocateBoolean(true);
    
    try memory.listPush(list, num1);
    try memory.listPush(list, text1);
    try memory.listPush(list, bool1);
    
    // Check length
    try testing.expectEqual(@as(usize, 3), try memory.listLength(list));
    
    // Get items
    const item0 = try memory.listGet(list, 0);
    try testing.expectEqual(@as(f64, 42), if (item0) |i| i.data.number else @as(f64, 0));
    
    const item1 = try memory.listGet(list, 1);
    try testing.expectEqualStrings("Hello", if (item1) |i| i.data.text else "");
    
    const item2 = try memory.listGet(list, 2);
    try testing.expect(if (item2) |i| i.data.boolean else false);
    
    // Test out of bounds
    const item3 = try memory.listGet(list, 3);
    try testing.expectEqual(@as(?*Value, null), item3);
    
    // Set item
    const num2 = try memory.allocateNumber(100);
    try memory.listSet(list, 0, num2);
    
    const updated_item0 = try memory.listGet(list, 0);
    try testing.expectEqual(@as(f64, 100), if (updated_item0) |i| i.data.number else @as(f64, 0));
    
    // Pop item
    const popped = try memory.listPop(list);
    try testing.expect(if (popped) |p| p.data.boolean else false);
    try testing.expectEqual(@as(usize, 2), try memory.listLength(list));
    
    // Slice
    const slice = try memory.listSlice(list, 0, 1);
    try testing.expectEqual(@as(usize, 1), try memory.listLength(slice));
    
    const slice_item0 = try memory.listGet(slice, 0);
    try testing.expectEqual(@as(f64, 100), if (slice_item0) |i| i.data.number else @as(f64, 0));
    
    // Splice - remove item
    try memory.listSplice(list, 0, 1, null);
    try testing.expectEqual(@as(usize, 1), try memory.listLength(list));
    
    // Splice - insert item
    const money = try memory.allocateMoneyFromDecimal(10, 0, "USD");
    var items_to_insert = [_]*Value{money};
    try memory.listSplice(list, 0, 0, &items_to_insert);
    try testing.expectEqual(@as(usize, 2), try memory.listLength(list));
    
    const first = try memory.listGet(list, 0);
    if (first) |f| {
        try testing.expectEqual(ValueType.money, @as(ValueType, f.data));
    } else {
        try testing.expect(false);
    }
}

test "record operations" {
    const allocator = testing.allocator;
    var memory = MemoryManager.init(allocator);
    defer memory.deinit();

    // Create a record
    const record = try memory.allocateRecord();
    
    // Set fields
    const name = try memory.allocateText("John Doe");
    const age = try memory.allocateNumber(42);
    const is_employed = try memory.allocateBoolean(true);
    
    try memory.recordSet(record, "name", name);
    try memory.recordSet(record, "age", age);
    try memory.recordSet(record, "is_employed", is_employed);
    
    // Get fields
    const retrieved_name = try memory.recordGet(record, "name");
    if (retrieved_name) |n| {
        try testing.expectEqualStrings("John Doe", n.data.text);
    } else {
        try testing.expect(false);
    }
    
    const retrieved_age = try memory.recordGet(record, "age");
    if (retrieved_age) |a| {
        try testing.expectEqual(@as(f64, 42), a.data.number);
    } else {
        try testing.expect(false);
    }
    
    // Overwrite a field
    const new_age = try memory.allocateNumber(43);
    try memory.recordSet(record, "age", new_age);
    
    const updated_age = try memory.recordGet(record, "age");
    if (updated_age) |a| {
        try testing.expectEqual(@as(f64, 43), a.data.number);
    } else {
        try testing.expect(false);
    }
    
    // Remove a field
    const removed = try memory.recordRemove(record, "is_employed");
    try testing.expect(removed);
    
    const missing_field = try memory.recordGet(record, "is_employed");
    try testing.expectEqual(@as(?*Value, null), missing_field);
    
    // Get keys
    var keys = try memory.recordKeys(record);
    defer keys.deinit();
    
    try testing.expectEqual(@as(usize, 2), keys.items.len);
    
    // Create a record with inheritance
    const person = try memory.allocateRecord();
    try memory.recordSet(person, "type", try memory.allocateText("person"));
    try memory.recordSet(person, "can_speak", try memory.allocateBoolean(true));
    
    const employee = try memory.allocateRecordWithParent(person);
    try memory.recordSet(employee, "job_title", try memory.allocateText("Engineer"));
    
    // Test inheritance
    const job = try memory.recordGet(employee, "job_title");
    if (job) |j| {
        try testing.expectEqualStrings("Engineer", j.data.text);
    } else {
        try testing.expect(false);
    }
    
    // Field from parent
    const can_speak = try memory.recordGet(employee, "can_speak");
    if (can_speak) |cs| {
        try testing.expect(cs.data.boolean);
    } else {
        try testing.expect(false);
    }
    
    // Test copy vs reference
    try memory.recordSet(person, "name", try memory.allocateText("Generic Person"));
    
    // The employee should inherit the name from person
    const inherited_name = try memory.recordGet(employee, "name");
    if (inherited_name) |n| {
        try testing.expectEqualStrings("Generic Person", n.data.text);
    } else {
        try testing.expect(false);
    }
    
    // Create a deep copy
    const employee_copy = try memory.deepCopy(employee);
    
    // Modify the original person, should not affect the copy
    try memory.recordSet(person, "name", try memory.allocateText("Changed Person"));
    
    // Original employee inherits the change
    const updated_name = try memory.recordGet(employee, "name");
    if (updated_name) |n| {
        try testing.expectEqualStrings("Changed Person", n.data.text);
    } else {
        try testing.expect(false);
    }
    
    // But the copy shouldn't change, as its parent is a deep copy of the original person
    const copy_name = try memory.recordGet(employee_copy, "name");
    if (copy_name) |n| {
        try testing.expectEqualStrings("Generic Person", n.data.text);
    } else {
        try testing.expect(false);
    }
} 