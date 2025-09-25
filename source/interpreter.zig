// MBL Interpreter - executes parsed MBL statements and expressions
const std = @import("std");
const memory = @import("memory.zig");
const parser = @import("parser.zig");

const Memory = memory.Memory;
const MBLValue = memory.MBLValue;
const Statement = parser.Statement;
const Expression = parser.Expression;

pub const InterpreterError = error{
    TypeError,
    DivisionByZero,
    OutOfMemory,
};

pub const Interpreter = struct {
    memory: *Memory,
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, mem: *Memory) Interpreter {
        return Interpreter{
            .memory = mem,
            .allocator = allocator,
            .output = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Interpreter) void {
        self.output.deinit();
    }

    pub fn execute(self: *Interpreter, statements: []Statement) !void {
        std.log.info("🔥 Executing {} MBL statements...", .{statements.len});

        for (statements, 0..) |stmt, i| {
            try self.executeStatement(stmt);
            std.log.info("✓ Statement {} completed", .{i + 1});
        }

        std.log.info("✅ All {} statements executed successfully", .{statements.len});
    }

    fn executeStatement(self: *Interpreter, stmt: Statement) !void {
        switch (stmt) {
            .assignment => |assignment| {
                try self.executeAssignment(assignment);
            },
            .expression_stmt => |expr_stmt| {
                _ = try self.evaluateExpression(expr_stmt.expression);
            },
            else => {
                std.log.warn("Statement type {s} not yet supported", .{@tagName(stmt)});
            },
        }
    }

    fn executeAssignment(self: *Interpreter, assignment: parser.Assignment) !void {
        const value = try self.evaluateExpression(assignment.value);

        // For now, only handle simple identifier assignments
        if (assignment.target == .identifier) {
            const var_name = assignment.target.identifier.name;
            try self.memory.program.set(var_name, value);
            std.log.info("  Assigned {s}", .{var_name});
        } else {
            std.log.warn("  Complex assignment targets not yet supported", .{});
        }
    }

    fn evaluateExpression(self: *Interpreter, expr: Expression) !MBLValue {
        switch (expr) {
            .literal => |literal| {
                return try self.evaluateLiteral(literal);
            },
            .identifier => |identifier| {
                if (self.memory.program.data.get(identifier.name)) |value| {
                    return value;
                } else {
                    std.log.warn("  Undefined variable: {s}", .{identifier.name});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            },
            .call => |call_expr| {
                return try self.evaluateCall(call_expr);
            },
            .binary => |binary_expr| {
                return try self.evaluateBinaryExpression(binary_expr);
            },
            else => {
                std.log.warn("  Expression type {s} not yet supported", .{@tagName(expr)});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "unsupported") };
            },
        }
    }

    fn evaluateLiteral(self: *Interpreter, literal: parser.Literal) !MBLValue {
        switch (literal) {
            .text => |text| {
                // Remove quotes from text literal
                var clean_text: []const u8 = text;
                if (text.len >= 2 and text[0] == '"' and text[text.len - 1] == '"') {
                    clean_text = text[1..text.len - 1];
                }
                return MBLValue{ .text = try memory.Text.init(self.allocator, clean_text) };
            },
            .number => |num| {
                return MBLValue{ .number = memory.Number{ .value = num } };
            },
            .boolean => |bool_val| {
                return MBLValue{ .boolean = memory.Boolean{ .value = bool_val } };
            },
            .money => |money_literal| {
                const currency = money_literal.currency orelse "USD";
                const cents = @as(i64, @intFromFloat(money_literal.amount * 100.0));
                const money = try memory.Money.init(self.allocator, cents, currency, "USD", 1.0);
                return MBLValue{ .money = money };
            },
            .empty => {
                // Return empty string
                return MBLValue{ .text = try memory.Text.init(self.allocator, "") };
            },
            else => {
                std.log.warn("  Literal type {s} not yet supported", .{@tagName(literal)});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "unsupported_literal") };
            },
        }
    }

    fn evaluateCall(self: *Interpreter, call_expr: parser.CallExpression) !MBLValue {
        // Handle program.write() specifically
        if (call_expr.callee.* == .property_access) {
            const prop_access = call_expr.callee.property_access;
            if (prop_access.object.* == .identifier) {
                const obj_name = prop_access.object.identifier.name;
                const prop_name = prop_access.property;

                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, prop_name, "write")) {
                    return try self.handleProgramWrite(call_expr.arguments);
                }
            }
        }

        std.log.warn("  Function call not supported", .{});
        return MBLValue{ .text = try memory.Text.init(self.allocator, "unsupported_call") };
    }

    fn handleProgramWrite(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len > 0) {
            const arg_value = self.evaluateExpression(arguments[0]) catch |err| {
                std.log.warn("Error evaluating argument: {!}", .{err});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            };

            // Convert any MBL value to string for output
            var output_text: []const u8 = undefined;
            switch (arg_value) {
                .text => |text| {
                    output_text = text.data;
                },
                .number => |num| {
                    const formatted = try std.fmt.allocPrint(self.allocator, "{d}", .{num.value});
                    output_text = formatted;
                },
                .boolean => |bool_val| {
                    output_text = if (bool_val.value) "true" else "false";
                },
                .money => |money| {
                    const dollars = @as(f64, @floatFromInt(money.value)) / 100.0;
                    const formatted = try std.fmt.allocPrint(self.allocator, "${d:.2} {s}", .{dollars, money.currency});
                    output_text = formatted;
                },
                else => {
                    output_text = "unsupported_type";
                },
            }

            try self.output.appendSlice(output_text);
            try self.output.append('\n');
            std.log.info("📤 program.write: {s}", .{output_text});
        }
        return MBLValue{ .text = try memory.Text.init(self.allocator, "") };
    }

    fn evaluateBinaryExpression(self: *Interpreter, binary_expr: parser.BinaryExpression) anyerror!MBLValue {
        const left = try self.evaluateExpression(binary_expr.left.*);
        const right = try self.evaluateExpression(binary_expr.right.*);

        return switch (binary_expr.operator) {
            // Arithmetic operations
            .add => self.performAddition(left, right),
            .subtract => self.performSubtraction(left, right),
            .multiply => self.performMultiplication(left, right),
            .divide => self.performDivision(left, right),
            .modulo => self.performModulo(left, right),

            // Comparison operations
            .equal => self.performEquality(left, right),
            .not_equal => self.performInequality(left, right),
            .less_than => self.performLessThan(left, right),
            .greater_than => self.performGreaterThan(left, right),
            .less_equal => self.performLessEqual(left, right),
            .greater_equal => self.performGreaterEqual(left, right),

            // Logical operations
            .logical_and => self.performLogicalAnd(left, right),
            .logical_or => self.performLogicalOr(left, right),
        };
    }

    fn performAddition(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        switch (left) {
            .number => |left_num| {
                switch (right) {
                    .number => |right_num| {
                        return MBLValue{ .number = memory.Number{ .value = left_num.value + right_num.value } };
                    },
                    .text => |right_text| {
                        // String concatenation: number + text
                        const left_str = try std.fmt.allocPrint(self.allocator, "{d}", .{left_num.value});
                        defer self.allocator.free(left_str);
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{left_str, right_text.data});
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                    else => return error.TypeError,
                }
            },
            .text => |left_text| {
                switch (right) {
                    .text => |right_text| {
                        // String concatenation
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{left_text.data, right_text.data});
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                    .number => |right_num| {
                        // String concatenation: text + number
                        const right_str = try std.fmt.allocPrint(self.allocator, "{d}", .{right_num.value});
                        defer self.allocator.free(right_str);
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{left_text.data, right_str});
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                    .boolean => |right_bool| {
                        // String concatenation: text + boolean
                        const right_str = if (right_bool.value) "true" else "false";
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{left_text.data, right_str});
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                    .money => |right_money| {
                        // String concatenation: text + money
                        const dollars = @as(f64, @floatFromInt(right_money.value)) / 100.0;
                        const right_str = try std.fmt.allocPrint(self.allocator, "${d:.2} {s}", .{dollars, right_money.currency});
                        defer self.allocator.free(right_str);
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{left_text.data, right_str});
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                    else => return error.TypeError,
                }
            },
            .money => |left_money| {
                switch (right) {
                    .money => |right_money| {
                        // Money addition (assuming same currency)
                        const result_value = left_money.value + right_money.value;
                        const result_money = try memory.Money.init(self.allocator, result_value, left_money.currency, left_money.currency, 1.0);
                        return MBLValue{ .money = result_money };
                    },
                    .text => |right_text| {
                        // String concatenation: money + text
                        const dollars = @as(f64, @floatFromInt(left_money.value)) / 100.0;
                        const left_str = try std.fmt.allocPrint(self.allocator, "${d:.2} {s}", .{dollars, left_money.currency});
                        defer self.allocator.free(left_str);
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{left_str, right_text.data});
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                    else => return error.TypeError,
                }
            },
            .boolean => |left_bool| {
                switch (right) {
                    .text => |right_text| {
                        // String concatenation: boolean + text
                        const left_str = if (left_bool.value) "true" else "false";
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{left_str, right_text.data});
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                    else => return error.TypeError,
                }
            },
            else => return error.TypeError,
        }
    }

    fn performSubtraction(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        switch (left) {
            .number => |left_num| {
                switch (right) {
                    .number => |right_num| {
                        return MBLValue{ .number = memory.Number{ .value = left_num.value - right_num.value } };
                    },
                    else => return error.TypeError,
                }
            },
            .money => |left_money| {
                switch (right) {
                    .money => |right_money| {
                        const result_value = left_money.value - right_money.value;
                        const result_money = try memory.Money.init(self.allocator, result_value, left_money.currency, left_money.currency, 1.0);
                        return MBLValue{ .money = result_money };
                    },
                    else => return error.TypeError,
                }
            },
            else => return error.TypeError,
        }
    }

    fn performMultiplication(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        _ = self;
        switch (left) {
            .number => |left_num| {
                switch (right) {
                    .number => |right_num| {
                        return MBLValue{ .number = memory.Number{ .value = left_num.value * right_num.value } };
                    },
                    else => return error.TypeError,
                }
            },
            else => return error.TypeError,
        }
    }

    fn performDivision(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        _ = self;
        switch (left) {
            .number => |left_num| {
                switch (right) {
                    .number => |right_num| {
                        if (right_num.value == 0) {
                            return error.DivisionByZero;
                        }
                        return MBLValue{ .number = memory.Number{ .value = left_num.value / right_num.value } };
                    },
                    else => return error.TypeError,
                }
            },
            else => return error.TypeError,
        }
    }

    fn performModulo(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        _ = self;
        switch (left) {
            .number => |left_num| {
                switch (right) {
                    .number => |right_num| {
                        if (right_num.value == 0) {
                            return error.DivisionByZero;
                        }
                        return MBLValue{ .number = memory.Number{ .value = @mod(left_num.value, right_num.value) } };
                    },
                    else => return error.TypeError,
                }
            },
            else => return error.TypeError,
        }
    }

    fn performEquality(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        _ = self;
        const result = switch (left) {
            .number => |left_num| switch (right) {
                .number => |right_num| left_num.value == right_num.value,
                else => false,
            },
            .text => |left_text| switch (right) {
                .text => |right_text| std.mem.eql(u8, left_text.data, right_text.data),
                else => false,
            },
            .boolean => |left_bool| switch (right) {
                .boolean => |right_bool| left_bool.value == right_bool.value,
                else => false,
            },
            .money => |left_money| switch (right) {
                .money => |right_money| left_money.value == right_money.value and
                    std.mem.eql(u8, left_money.currency, right_money.currency),
                else => false,
            },
            else => false,
        };
        return MBLValue{ .boolean = memory.Boolean{ .value = result } };
    }

    fn performInequality(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const equality = try self.performEquality(left, right);
        return MBLValue{ .boolean = memory.Boolean{ .value = !equality.boolean.value } };
    }

    fn performLessThan(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        _ = self;
        const result = switch (left) {
            .number => |left_num| switch (right) {
                .number => |right_num| left_num.value < right_num.value,
                else => return error.TypeError,
            },
            .money => |left_money| switch (right) {
                .money => |right_money| left_money.value < right_money.value,
                else => return error.TypeError,
            },
            else => return error.TypeError,
        };
        return MBLValue{ .boolean = memory.Boolean{ .value = result } };
    }

    fn performGreaterThan(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        _ = self;
        const result = switch (left) {
            .number => |left_num| switch (right) {
                .number => |right_num| left_num.value > right_num.value,
                else => return error.TypeError,
            },
            .money => |left_money| switch (right) {
                .money => |right_money| left_money.value > right_money.value,
                else => return error.TypeError,
            },
            else => return error.TypeError,
        };
        return MBLValue{ .boolean = memory.Boolean{ .value = result } };
    }

    fn performLessEqual(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const less = try self.performLessThan(left, right);
        const equal = try self.performEquality(left, right);
        return MBLValue{ .boolean = memory.Boolean{ .value = less.boolean.value or equal.boolean.value } };
    }

    fn performGreaterEqual(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const greater = try self.performGreaterThan(left, right);
        const equal = try self.performEquality(left, right);
        return MBLValue{ .boolean = memory.Boolean{ .value = greater.boolean.value or equal.boolean.value } };
    }

    fn performLogicalAnd(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const left_truthy = self.isTruthy(left);
        if (!left_truthy) {
            return MBLValue{ .boolean = memory.Boolean{ .value = false } };
        }
        const right_truthy = self.isTruthy(right);
        return MBLValue{ .boolean = memory.Boolean{ .value = right_truthy } };
    }

    fn performLogicalOr(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const left_truthy = self.isTruthy(left);
        if (left_truthy) {
            return MBLValue{ .boolean = memory.Boolean{ .value = true } };
        }
        const right_truthy = self.isTruthy(right);
        return MBLValue{ .boolean = memory.Boolean{ .value = right_truthy } };
    }

    fn isTruthy(self: *Interpreter, value: MBLValue) bool {
        _ = self;
        return switch (value) {
            .boolean => |b| b.value,
            .number => |n| n.value != 0.0,
            .text => |t| t.data.len > 0,
            .money => |m| m.value != 0,
            else => true, // Other types are considered truthy
        };
    }
};