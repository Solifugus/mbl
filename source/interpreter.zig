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
    GotoExecuted, // Special error to signal goto was executed
};

pub const Interpreter = struct {
    memory: *Memory,
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    labels: std.HashMap([]const u8, usize, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    goto_target: ?[]const u8, // Track the target of a goto that was executed
    scope_stack: std.ArrayList(*memory.Record), // Stack of local scopes (deepest first)

    pub fn init(allocator: std.mem.Allocator, mem: *Memory) Interpreter {
        return Interpreter{
            .memory = mem,
            .allocator = allocator,
            .output = std.ArrayList(u8).init(allocator),
            .labels = std.HashMap([]const u8, usize, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .goto_target = null,
            .scope_stack = std.ArrayList(*memory.Record).init(allocator),
        };
    }

    pub fn deinit(self: *Interpreter) void {
        self.output.deinit();
        self.labels.deinit();
        self.scope_stack.deinit();
    }

    // Scope management methods
    pub fn pushScope(self: *Interpreter, scope: *memory.Record) !void {
        try self.scope_stack.append(scope);
        std.log.info("📦 Pushed scope, depth now: {}", .{self.scope_stack.items.len});
    }

    pub fn popScope(self: *Interpreter) void {
        if (self.scope_stack.items.len > 0) {
            _ = self.scope_stack.pop();
            std.log.info("📤 Popped scope, depth now: {}", .{self.scope_stack.items.len});
        }
    }

    // Variable resolution with scope chain
    pub fn getVariable(self: *Interpreter, name: []const u8) ?MBLValue {
        // First check local scopes (deepest first)
        var i: usize = self.scope_stack.items.len;
        while (i > 0) {
            i -= 1;
            const scope = self.scope_stack.items[i];
            if (scope.data.get(name)) |value| {
                std.log.info("🔍 Variable '{s}' found in local scope at depth {}", .{name, i});
                return value;
            }
        }

        // Then check program scope
        if (self.memory.program.data.get(name)) |value| {
            std.log.info("🔍 Variable '{s}' found in program scope", .{name});
            return value;
        }

        std.log.warn("🔍 Variable '{s}' not found in any scope", .{name});
        return null;
    }

    // Variable assignment with scope resolution
    pub fn setVariable(self: *Interpreter, name: []const u8, value: MBLValue) !void {
        // Check if variable exists in any local scope
        var i: usize = self.scope_stack.items.len;
        while (i > 0) {
            i -= 1;
            const scope = self.scope_stack.items[i];
            if (scope.data.contains(name)) {
                try scope.set(name, value);
                std.log.info("📝 Updated variable '{s}' in local scope at depth {}", .{name, i});
                return;
            }
        }

        // Check if exists in program scope
        if (self.memory.program.data.contains(name)) {
            try self.memory.program.set(name, value);
            std.log.info("📝 Updated variable '{s}' in program scope", .{name});
            return;
        }

        // New variable - create in current local scope if available, otherwise program scope
        if (self.scope_stack.items.len > 0) {
            const current_scope = self.scope_stack.items[self.scope_stack.items.len - 1];
            try current_scope.set(name, value);
            std.log.info("📝 Created variable '{s}' in local scope at depth {}", .{name, self.scope_stack.items.len - 1});
        } else {
            try self.memory.program.set(name, value);
            std.log.info("📝 Created variable '{s}' in program scope", .{name});
        }
    }

    pub fn execute(self: *Interpreter, statements: []Statement) !void {
        std.log.info("🔥 Executing {} MBL statements...", .{statements.len});

        // First pass: collect all labels
        for (statements, 0..) |stmt, i| {
            if (stmt == .label) {
                try self.labels.put(stmt.label.name, i);
                std.log.info("📍 Found label '{s}' at statement {}", .{stmt.label.name, i});
            }
        }

        // Second pass: execute statements with goto support
        var pc: usize = 0; // program counter
        while (pc < statements.len) {
            const stmt = statements[pc];

            if (stmt == .goto_stmt) {
                // Handle goto
                const target = stmt.goto_stmt.target;
                if (self.labels.get(target)) |label_pc| {
                    std.log.info("🔄 GOTO '{s}' - jumping from {} to {}", .{target, pc, label_pc});
                    pc = label_pc;
                    continue;
                } else {
                    std.log.err("❌ Label '{s}' not found for goto", .{target});
                    return InterpreterError.TypeError; // Could add specific GotoError
                }
            } else {
                if (self.executeStatement(stmt)) |_| {
                    std.log.info("✓ Statement {} completed", .{pc + 1});
                } else |err| switch (err) {
                    InterpreterError.GotoExecuted => {
                        // A goto was executed from within this statement
                        if (self.goto_target) |target| {
                            if (self.labels.get(target)) |label_pc| {
                                std.log.info("🔄 GOTO '{s}' from nested statement - jumping to {}", .{target, label_pc});
                                pc = label_pc;
                                self.goto_target = null; // Clear the goto target
                                continue;
                            } else {
                                std.log.err("❌ Label '{s}' not found for goto", .{target});
                                return InterpreterError.TypeError;
                            }
                        } else {
                            std.log.err("❌ Goto executed but no target set", .{});
                            return InterpreterError.TypeError;
                        }
                    },
                    else => return err,
                }
            }

            pc += 1;
        }

        std.log.info("✅ All statements executed successfully", .{});
    }

    fn executeStatement(self: *Interpreter, stmt: Statement) !void {
        switch (stmt) {
            .assignment => |assignment| {
                try self.executeAssignment(assignment);
            },
            .expression_stmt => |expr_stmt| {
                _ = try self.evaluateExpression(expr_stmt.expression);
            },
            .if_statement => |if_stmt| {
                try self.executeIfStatement(if_stmt);
            },
            .label => |label| {
                // Labels are no-ops during execution (handled in label discovery phase)
                std.log.info("📍 Label '{s}' reached", .{label.name});
            },
            .goto_stmt => |goto_stmt| {
                // Set the goto target and signal that a goto was executed
                self.goto_target = goto_stmt.target;
                std.log.info("🔄 GOTO '{s}' executed from nested statement", .{goto_stmt.target});
                return InterpreterError.GotoExecuted;
            },
            else => {
                std.log.warn("Statement type {s} not yet supported", .{@tagName(stmt)});
            },
        }
    }

    fn executeAssignment(self: *Interpreter, assignment: parser.Assignment) !void {
        const value = try self.evaluateExpression(assignment.value);

        switch (assignment.target) {
            .identifier => |identifier| {
                const var_name = identifier.name;
                try self.setVariable(var_name, value);
                std.log.info("  Assigned {s}", .{var_name});
            },
            .property_access => |prop_access| {
                try self.assignToProperty(prop_access, value);
            },
            else => {
                std.log.warn("  Complex assignment targets not yet supported", .{});
            }
        }
    }

    fn assignToProperty(self: *Interpreter, prop_access: parser.PropertyAccess, value: MBLValue) !void {
        // Handle scope resolution assignments with 'program' and 'super' keywords
        if (prop_access.object.* == .identifier) {
            const obj_name = prop_access.object.identifier.name;
            const prop_name = prop_access.property;

            if (std.mem.eql(u8, obj_name, "program")) {
                // Direct assignment to program scope
                try self.memory.program.set(prop_name, value);
                std.log.info("📝 Assigned 'program.{s}'", .{prop_name});
                return;
            } else if (std.mem.eql(u8, obj_name, "super")) {
                // Assignment to parent scope (one level up)
                if (self.scope_stack.items.len > 1) {
                    const parent_scope = self.scope_stack.items[self.scope_stack.items.len - 2];
                    if (parent_scope.data.contains(prop_name)) {
                        try parent_scope.set(prop_name, value);
                        std.log.info("📝 Assigned 'super.{s}' in parent scope", .{prop_name});
                        return;
                    }
                }
                // If not found in parent, assign to program scope
                try self.memory.program.set(prop_name, value);
                std.log.info("📝 Assigned 'super.{s}' (fallback to program)", .{prop_name});
                return;
            }
        }

        // For other property assignments, evaluate object and set property
        std.log.warn("  Property assignment to non-scope objects not yet supported", .{});
    }

    fn evaluateExpression(self: *Interpreter, expr: Expression) !MBLValue {
        switch (expr) {
            .literal => |literal| {
                return try self.evaluateLiteral(literal);
            },
            .identifier => |identifier| {
                if (self.getVariable(identifier.name)) |value| {
                    return value;
                } else {
                    std.log.warn("  Undefined variable: {s}", .{identifier.name});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            },
            .property_access => |prop_access| {
                return try self.evaluatePropertyAccess(prop_access);
            },
            .call => |call_expr| {
                return try self.evaluateCall(call_expr);
            },
            .binary => |binary_expr| {
                return try self.evaluateBinaryExpression(binary_expr);
            },
            .unary => |unary_expr| {
                return try self.evaluateUnaryExpression(unary_expr);
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

    fn evaluateUnaryExpression(self: *Interpreter, unary_expr: parser.UnaryExpression) anyerror!MBLValue {
        const operand = try self.evaluateExpression(unary_expr.operand.*);

        return switch (unary_expr.operator) {
            .minus => {
                switch (operand) {
                    .number => |num| {
                        return MBLValue{ .number = memory.Number{ .value = -num.value } };
                    },
                    else => return error.TypeError,
                }
            },
            .logical_not => {
                const is_truthy = self.isTruthy(operand);
                return MBLValue{ .boolean = memory.Boolean{ .value = !is_truthy } };
            },
        };
    }

    fn evaluatePropertyAccess(self: *Interpreter, prop_access: parser.PropertyAccess) anyerror!MBLValue {
        // Handle scope resolution with 'program' and 'super' keywords
        if (prop_access.object.* == .identifier) {
            const obj_name = prop_access.object.identifier.name;
            const prop_name = prop_access.property;

            if (std.mem.eql(u8, obj_name, "program")) {
                // Direct access to program scope
                if (self.memory.program.data.get(prop_name)) |value| {
                    std.log.info("🔍 Variable '{s}' accessed via program scope", .{prop_name});
                    return value;
                } else {
                    std.log.warn("🔍 Variable 'program.{s}' not found", .{prop_name});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            } else if (std.mem.eql(u8, obj_name, "super")) {
                // Access to parent scope (one level up)
                if (self.scope_stack.items.len > 1) {
                    const parent_scope = self.scope_stack.items[self.scope_stack.items.len - 2];
                    if (parent_scope.data.get(prop_name)) |value| {
                        std.log.info("🔍 Variable '{s}' accessed via super scope", .{prop_name});
                        return value;
                    }
                }
                // If not found in parent, check program scope
                if (self.memory.program.data.get(prop_name)) |value| {
                    std.log.info("🔍 Variable '{s}' accessed via super (fallback to program)", .{prop_name});
                    return value;
                } else {
                    std.log.warn("🔍 Variable 'super.{s}' not found", .{prop_name});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            }
        }

        // For other property access, evaluate the object and access its properties
        const obj_value = try self.evaluateExpression(prop_access.object.*);

        // Handle record property access
        switch (obj_value) {
            .record => |record| {
                if (record.data.get(prop_access.property)) |value| {
                    return value;
                } else {
                    std.log.warn("  Property '{s}' not found on record", .{prop_access.property});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            },
            else => {
                std.log.warn("  Cannot access property '{s}' on non-record value", .{prop_access.property});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
            }
        }
    }

    fn executeIfStatement(self: *Interpreter, if_stmt: parser.IfStatement) anyerror!void {
        const condition_value = try self.evaluateExpression(if_stmt.condition);
        const condition_truthy = self.isTruthy(condition_value);

        if (condition_truthy) {
            std.log.info("🔀 If condition is true, executing then branch", .{});

            // Create local scope for if-block
            var local_scope = memory.Record.init(self.allocator);
            defer local_scope.deinit();

            try self.pushScope(&local_scope);
            defer self.popScope();

            for (if_stmt.then_branch) |stmt| {
                if (self.executeStatement(stmt)) |_| {
                    // Statement executed normally
                } else |err| switch (err) {
                    InterpreterError.GotoExecuted => {
                        // Propagate the goto up to the main execution loop
                        return InterpreterError.GotoExecuted;
                    },
                    else => return err,
                }
            }
        } else {
            if (if_stmt.else_branch) |else_branch| {
                std.log.info("🔀 If condition is false, executing else branch", .{});

                // Create local scope for else-block
                var local_scope = memory.Record.init(self.allocator);
                defer local_scope.deinit();

                try self.pushScope(&local_scope);
                defer self.popScope();

                for (else_branch) |stmt| {
                    if (self.executeStatement(stmt)) |_| {
                        // Statement executed normally
                    } else |err| switch (err) {
                        InterpreterError.GotoExecuted => {
                            // Propagate the goto up to the main execution loop
                            return InterpreterError.GotoExecuted;
                        },
                        else => return err,
                    }
                }
            } else {
                std.log.info("🔀 If condition is false, no else branch", .{});
            }
        }
    }
};