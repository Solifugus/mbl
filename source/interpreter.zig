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
    BreakExecuted, // Special error to signal break was executed
    ContinueExecuted, // Special error to signal continue was executed
    ReturnExecuted, // Special error to signal return was executed
};

pub const Interpreter = struct {
    memory: *Memory,
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    labels: std.HashMap([]const u8, usize, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    goto_target: ?[]const u8, // Track the target of a goto that was executed
    scope_stack: std.ArrayList(*memory.Record), // Stack of local scopes (deepest first)
    functions: std.HashMap([]const u8, parser.FunctionDeclaration, std.hash_map.StringContext, std.hash_map.default_max_load_percentage), // Function registry
    return_value: ?MBLValue, // Store return value from functions
    quiet_mode: bool, // Suppress debug output when true

    pub fn init(allocator: std.mem.Allocator, mem: *Memory) Interpreter {
        return Interpreter{
            .memory = mem,
            .allocator = allocator,
            .output = std.ArrayList(u8).init(allocator),
            .labels = std.HashMap([]const u8, usize, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .goto_target = null,
            .scope_stack = std.ArrayList(*memory.Record).init(allocator),
            .functions = std.HashMap([]const u8, parser.FunctionDeclaration, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .return_value = null,
            .quiet_mode = false,
        };
    }

    pub fn deinit(self: *Interpreter) void {
        self.output.deinit();
        self.labels.deinit();
        self.scope_stack.deinit();

        // Clean up function registry (no need to free individual functions since we store references)
        self.functions.deinit();
    }

    fn log(self: *Interpreter, comptime fmt: []const u8, args: anytype) void {
        if (!self.quiet_mode) {
            std.log.info(fmt, args);
        }
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
            self.log("🔍 Variable '{s}' found in program scope", .{name});
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
            self.log("📝 Updated variable '{s}' in program scope", .{name});
            return;
        }

        // New variable - create in current local scope if available, otherwise program scope
        if (self.scope_stack.items.len > 0) {
            const current_scope = self.scope_stack.items[self.scope_stack.items.len - 1];
            try current_scope.set(name, value);
            std.log.info("📝 Created variable '{s}' in local scope at depth {}", .{name, self.scope_stack.items.len - 1});
        } else {
            try self.memory.program.set(name, value);
            self.log("📝 Created variable '{s}' in program scope", .{name});
        }
    }

    // Create a variable in the current local scope (for function parameters)
    pub fn createLocalVariable(self: *Interpreter, name: []const u8, value: MBLValue) !void {
        if (self.scope_stack.items.len > 0) {
            const current_scope = self.scope_stack.items[self.scope_stack.items.len - 1];
            try current_scope.set(name, value);
            std.log.info("📝 Created variable '{s}' in local scope at depth {}", .{name, self.scope_stack.items.len - 1});
        } else {
            // Fallback to program scope if no local scope exists
            try self.memory.program.set(name, value);
            self.log("📝 Created variable '{s}' in program scope", .{name});
        }
    }

    pub fn execute(self: *Interpreter, statements: []Statement) !void {
        self.log("🔥 Executing {} MBL statements...", .{statements.len});

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
                    self.log("✓ Statement {} completed", .{pc + 1});
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
                    InterpreterError.ReturnExecuted => {
                        // Return statement executed outside of function context
                        std.log.err("❌ Return statement can only be used inside functions", .{});
                        return InterpreterError.TypeError;
                    },
                    else => return err,
                }
            }

            pc += 1;
        }

        self.log("✅ All statements executed successfully", .{});
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
            .while_statement => |while_stmt| {
                try self.executeWhileStatement(while_stmt);
            },
            .for_statement => |for_stmt| {
                try self.executeForStatement(for_stmt);
            },
            .break_stmt => |_| {
                std.log.info("🔄 Break statement executed", .{});
                return InterpreterError.BreakExecuted;
            },
            .continue_stmt => |_| {
                std.log.info("🔄 Continue statement executed", .{});
                return InterpreterError.ContinueExecuted;
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
            .function_declaration => |func_decl| {
                try self.registerFunction(func_decl);
            },
            .return_statement => |return_stmt| {
                try self.executeReturnStatement(return_stmt);
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
                self.log("  Assigned {s}", .{var_name});
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
            .index_access => |index_access| {
                return try self.evaluateIndexAccess(index_access);
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
            .record_literal => |record_literal| {
                return try self.evaluateRecordLiteral(record_literal);
            },
            .list_literal => |list_literal| {
                return try self.evaluateListLiteral(list_literal);
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
            .time => |time_literal| {
                return try self.parseTimeString(time_literal.value);
            },
            .duration => |duration_literal| {
                return try self.parseDurationLiteral(duration_literal);
            },
            .nothing => {
                // Nothing converts to empty string
                return MBLValue{ .text = try memory.Text.init(self.allocator, "") };
            },
            .unknown => {
                // Unknown is a distinct value type
                return MBLValue{ .unknown = {} };
            },
            else => {
                std.log.warn("  Literal type {s} not yet supported", .{@tagName(literal)});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "unsupported_literal") };
            },
        }
    }

    fn parseTimeString(self: *Interpreter, time_str: []const u8) !MBLValue {
        // Remove the @ prefix if present
        var clean_str = time_str;
        if (time_str.len > 0 and time_str[0] == '@') {
            clean_str = time_str[1..];
        }

        // Handle special cases
        if (std.mem.eql(u8, clean_str, "now")) {
            return MBLValue{ .time = memory.Time.now() };
        }

        // Parse different time formats
        if (clean_str.len == 10 and clean_str[4] == '-' and clean_str[7] == '-') {
            // Date format: YYYY-MM-DD
            return try self.parseDate(clean_str);
        } else if (clean_str.len == 8 and clean_str[2] == ':' and clean_str[5] == ':') {
            // Time format: HH:MM:SS
            return try self.parseTime(clean_str);
        } else if (clean_str.len == 19 and clean_str[10] == 'T') {
            // DateTime format: YYYY-MM-DDTHH:MM:SS
            return try self.parseDateTime(clean_str);
        } else {
            // Try to parse as timestamp
            const timestamp = std.fmt.parseInt(i64, clean_str, 10) catch {
                std.log.warn("  Invalid time format: {s}", .{time_str});
                return MBLValue{ .time = memory.Time.init(0) };
            };
            return MBLValue{ .time = memory.Time.init(timestamp) };
        }
    }

    fn parseDate(self: *Interpreter, date_str: []const u8) !MBLValue {
        _ = self;
        // Parse YYYY-MM-DD format
        const year = std.fmt.parseInt(i32, date_str[0..4], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };
        const month = std.fmt.parseInt(u4, date_str[5..7], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };
        const day = std.fmt.parseInt(u5, date_str[8..10], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };

        // Convert to UNIX timestamp (simplified - assumes UTC)
        // This is a basic implementation, a full implementation would use std.time
        const days_since_epoch = daysSinceEpoch(year, month, day);
        const timestamp = days_since_epoch * 24 * 60 * 60; // Convert days to seconds

        return MBLValue{ .time = memory.Time.init(timestamp) };
    }

    fn parseTime(self: *Interpreter, time_str: []const u8) !MBLValue {
        _ = self;
        // Parse HH:MM:SS format - treat as seconds since midnight
        const hour = std.fmt.parseInt(u5, time_str[0..2], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };
        const minute = std.fmt.parseInt(u6, time_str[3..5], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };
        const second = std.fmt.parseInt(u6, time_str[6..8], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };

        const total_seconds = @as(i64, hour) * 3600 + @as(i64, minute) * 60 + @as(i64, second);
        return MBLValue{ .time = memory.Time.init(total_seconds) };
    }

    fn parseDateTime(self: *Interpreter, datetime_str: []const u8) !MBLValue {
        // Parse YYYY-MM-DDTHH:MM:SS format
        const date_part = datetime_str[0..10];
        const time_part = datetime_str[11..19];

        const date_val = try self.parseDate(date_part);
        const time_val = try self.parseTime(time_part);

        // Add time of day to the date
        const combined_timestamp = date_val.time.value + time_val.time.value;
        return MBLValue{ .time = memory.Time.init(combined_timestamp) };
    }

    fn parseDurationLiteral(self: *Interpreter, duration_literal: parser.DurationLiteral) !MBLValue {
        _ = self;

        if (std.mem.eql(u8, duration_literal.unit, "days")) {
            return MBLValue{ .duration = memory.Duration.fromDays(duration_literal.value) };
        } else if (std.mem.eql(u8, duration_literal.unit, "hours")) {
            return MBLValue{ .duration = memory.Duration.fromHours(duration_literal.value) };
        } else if (std.mem.eql(u8, duration_literal.unit, "minutes")) {
            return MBLValue{ .duration = memory.Duration.fromMinutes(duration_literal.value) };
        } else if (std.mem.eql(u8, duration_literal.unit, "seconds")) {
            return MBLValue{ .duration = memory.Duration.fromSeconds(duration_literal.value) };
        } else {
            std.log.warn("  Unknown duration unit: {s}", .{duration_literal.unit});
            return MBLValue{ .duration = memory.Duration.init(0) };
        }
    }

    fn evaluateRecordLiteral(self: *Interpreter, record_literal: parser.RecordLiteral) anyerror!MBLValue {
        var record = memory.Record.init(self.allocator);

        for (record_literal.fields) |field| {
            // Handle the key - identifiers should be treated as literal text
            const key_str = switch (field.key) {
                .identifier => |identifier| identifier.name,
                .literal => |literal| switch (literal) {
                    .text => |text| text,
                    else => {
                        std.log.warn("  Record key must be text, got {s}", .{@tagName(literal)});
                        return MBLValue{ .text = try memory.Text.init(self.allocator, "invalid_record") };
                    }
                },
                else => blk: {
                    // For computed keys, evaluate them
                    const key_value = try self.evaluateExpression(field.key);
                    break :blk switch (key_value) {
                        .text => |text| text.data,
                        else => {
                            std.log.warn("  Record key must evaluate to text, got {s}", .{@tagName(key_value)});
                            return MBLValue{ .text = try memory.Text.init(self.allocator, "invalid_record") };
                        }
                    };
                }
            };

            // Evaluate the value
            const value = try self.evaluateExpression(field.value);

            // Add to record
            try record.set(key_str, value);
        }

        return MBLValue{ .record = record };
    }

    fn evaluateListLiteral(self: *Interpreter, list_literal: parser.ListLiteral) anyerror!MBLValue {
        var list = memory.List.init(self.allocator);

        for (list_literal.elements) |element| {
            const value = try self.evaluateExpression(element);
            try list.append(value);
        }

        return MBLValue{ .list = list };
    }

    fn evaluateIndexAccess(self: *Interpreter, index_access: parser.IndexAccess) anyerror!MBLValue {
        const obj_value = try self.evaluateExpression(index_access.object.*);
        const index_value = try self.evaluateExpression(index_access.index.*);

        // Convert index to number
        const index_num = switch (index_value) {
            .number => |num| @as(usize, @intFromFloat(num.value)),
            else => {
                std.log.warn("  Index must be a number, got {s}", .{@tagName(index_value)});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "invalid_index") };
            }
        };

        // Handle list indexing
        switch (obj_value) {
            .list => |*list| {
                if (list.get(index_num)) |value| {
                    return value;
                } else {
                    std.log.warn("  List index {d} out of bounds", .{index_num});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "index_out_of_bounds") };
                }
            },
            else => {
                std.log.warn("  Cannot index into {s}", .{@tagName(obj_value)});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "not_indexable") };
            }
        }
    }

    fn daysSinceEpoch(year: i32, month: u4, day: u5) i64 {
        // Simplified calculation - assumes Gregorian calendar
        // This is a basic implementation for demonstration
        var total_days: i64 = 0;

        // Add days for complete years since 1970
        var y: i32 = 1970;
        while (y < year) : (y += 1) {
            total_days += if (isLeapYear(y)) 366 else 365;
        }

        // Add days for complete months in the current year
        const days_in_month = [_]u5{31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
        var m: u4 = 1;
        while (m < month) : (m += 1) {
            total_days += days_in_month[m - 1];
            if (m == 2 and isLeapYear(year)) {
                total_days += 1; // Add leap day
            }
        }

        // Add remaining days
        total_days += day - 1; // Day 1 is the first day of the month

        return total_days;
    }

    fn isLeapYear(year: i32) bool {
        return (@rem(year, 4) == 0 and @rem(year, 100) != 0) or (@rem(year, 400) == 0);
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

        // Handle user-defined function calls
        if (call_expr.callee.* == .identifier) {
            const func_name = call_expr.callee.identifier.name;
            return try self.callFunction(func_name, call_expr.arguments);
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
        // Addition rules:
        // number + string -> try convert string to number, else concatenate
        // string + anything -> concatenate (convert right to string)
        // number + number -> add
        // money + money -> add (same currency)
        // unknown + anything -> unknown

        if (left == .unknown or right == .unknown) {
            return MBLValue{ .unknown = {} };
        }

        switch (left) {
            .number => |left_num| {
                switch (right) {
                    .number => |right_num| {
                        return MBLValue{ .number = memory.Number{ .value = left_num.value + right_num.value } };
                    },
                    .text => |right_text| {
                        // Try to convert text to number for arithmetic, else concatenate
                        if (right_text.data.len == 0) {
                            // Empty string (Nothing) -> 0
                            return MBLValue{ .number = memory.Number{ .value = left_num.value + 0.0 } };
                        }
                        if (std.fmt.parseFloat(f64, right_text.data)) |num_val| {
                            return MBLValue{ .number = memory.Number{ .value = left_num.value + num_val } };
                        } else |_| {
                            // Can't parse as number, concatenate
                            const left_str = try std.fmt.allocPrint(self.allocator, "{d}", .{left_num.value});
                            const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_str, right_text.data });
                            defer self.allocator.free(left_str);
                            return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                        }
                    },
                    else => {
                        // Convert right to text and concatenate
                        const left_text = try left.convertToText(self.allocator);
                        const right_text = try right.convertToText(self.allocator);
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.text.data, right_text.text.data });
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                }
            },
            .text => |left_text| {
                // String concatenation: convert everything to text
                const right_text = try right.convertToText(self.allocator);
                const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.data, right_text.text.data });
                return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
            },
            .money => |left_money| {
                switch (right) {
                    .money => |right_money| {
                        // Money addition (assuming same currency)
                        const result_value = left_money.value + right_money.value;
                        const result_money = try memory.Money.init(self.allocator, result_value, left_money.currency, left_money.currency, 1.0);
                        return MBLValue{ .money = result_money };
                    },
                    else => {
                        // Convert to text and concatenate
                        const left_text = try left.convertToText(self.allocator);
                        const right_text = try right.convertToText(self.allocator);
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.text.data, right_text.text.data });
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                }
            },
            .time => |left_time| {
                switch (right) {
                    .time => |right_time| {
                        // Time arithmetic: time + time (duration)
                        const result_time = left_time.add(right_time);
                        return MBLValue{ .time = result_time };
                    },
                    .duration => |right_duration| {
                        // Time + duration = time
                        const result_time = left_time.addDuration(right_duration);
                        return MBLValue{ .time = result_time };
                    },
                    else => {
                        // Convert to text and concatenate
                        const left_text = try left.convertToText(self.allocator);
                        const right_text = try right.convertToText(self.allocator);
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.text.data, right_text.text.data });
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                }
            },
            .duration => |left_duration| {
                switch (right) {
                    .duration => |right_duration| {
                        // Duration arithmetic: duration + duration
                        const result_duration = left_duration.add(right_duration);
                        return MBLValue{ .duration = result_duration };
                    },
                    else => {
                        // Convert to text and concatenate
                        const left_text = try left.convertToText(self.allocator);
                        const right_text = try right.convertToText(self.allocator);
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.text.data, right_text.text.data });
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                }
            },
            else => {
                // Convert everything to text and concatenate
                const left_text = try left.convertToText(self.allocator);
                const right_text = try right.convertToText(self.allocator);
                const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.text.data, right_text.text.data });
                return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
            },
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
            .time => |left_time| {
                switch (right) {
                    .time => |right_time| {
                        // Time arithmetic: time - time (duration)
                        const result_time = left_time.subtract(right_time);
                        return MBLValue{ .time = result_time };
                    },
                    else => return error.TypeError,
                }
            },
            .duration => |left_duration| {
                switch (right) {
                    .duration => |right_duration| {
                        // Duration arithmetic: duration - duration
                        const result_duration = left_duration.subtract(right_duration);
                        return MBLValue{ .duration = result_duration };
                    },
                    else => return error.TypeError,
                }
            },
            else => return error.TypeError,
        }
    }

    fn performMultiplication(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        switch (left) {
            .number => |left_num| {
                switch (right) {
                    .number => |right_num| {
                        return MBLValue{ .number = memory.Number{ .value = left_num.value * right_num.value } };
                    },
                    .money => |right_money| {
                        // Number * Money -> Money
                        const new_value = @as(i64, @intFromFloat(left_num.value * @as(f64, @floatFromInt(right_money.value))));
                        const result_money = try memory.Money.init(self.allocator, new_value, right_money.currency, right_money.base, right_money.conversion);
                        return MBLValue{ .money = result_money };
                    },
                    else => return error.TypeError,
                }
            },
            .money => |left_money| {
                switch (right) {
                    .number => |right_num| {
                        // Money * Number -> Money
                        const new_value = @as(i64, @intFromFloat(@as(f64, @floatFromInt(left_money.value)) * right_num.value));
                        const result_money = try memory.Money.init(self.allocator, new_value, left_money.currency, left_money.base, left_money.conversion);
                        return MBLValue{ .money = result_money };
                    },
                    else => return error.TypeError,
                }
            },
            else => return error.TypeError,
        }
    }

    fn performDivision(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
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
            .money => |left_money| {
                switch (right) {
                    .number => |right_num| {
                        if (right_num.value == 0) {
                            return error.DivisionByZero;
                        }
                        // Divide money by number -> money
                        const new_value = @as(i64, @intFromFloat(@as(f64, @floatFromInt(left_money.value)) / right_num.value));
                        const result_money = try memory.Money.init(self.allocator, new_value, left_money.currency, left_money.base, left_money.conversion);
                        return MBLValue{ .money = result_money };
                    },
                    .money => |right_money| {
                        // Divide money by money -> number (ratio)
                        if (right_money.value == 0) {
                            return error.DivisionByZero;
                        }
                        const ratio = @as(f64, @floatFromInt(left_money.value)) / @as(f64, @floatFromInt(right_money.value));
                        return MBLValue{ .number = memory.Number{ .value = ratio } };
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
            .time => |left_time| switch (right) {
                .time => |right_time| left_time.value == right_time.value,
                else => false,
            },
            .duration => |left_duration| switch (right) {
                .duration => |right_duration| left_duration.value == right_duration.value,
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
            .time => |left_time| switch (right) {
                .time => |right_time| left_time.value < right_time.value, // Earlier time is "less than"
                else => return error.TypeError,
            },
            .duration => |left_duration| switch (right) {
                .duration => |right_duration| left_duration.value < right_duration.value, // Shorter duration is "less than"
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
            .time => |left_time| switch (right) {
                .time => |right_time| left_time.value > right_time.value, // Later time is "greater than"
                else => return error.TypeError,
            },
            .duration => |left_duration| switch (right) {
                .duration => |right_duration| left_duration.value > right_duration.value, // Longer duration is "greater than"
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
                const logic = operand.isTruthy();
                const result = switch (logic) {
                    .true_val => memory.TernaryLogic.false_val,
                    .false_val => memory.TernaryLogic.true_val,
                    .unknown => memory.TernaryLogic.unknown,
                };
                return switch (result) {
                    .true_val => MBLValue{ .boolean = memory.Boolean{ .value = true } },
                    .false_val => MBLValue{ .boolean = memory.Boolean{ .value = false } },
                    .unknown => MBLValue{ .unknown = {} },
                };
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
            .time => |time_value| {
                // Handle time property access (year, month, day, hour, minute, second)
                if (std.mem.eql(u8, prop_access.property, "year")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.year()) } };
                } else if (std.mem.eql(u8, prop_access.property, "month")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.month()) } };
                } else if (std.mem.eql(u8, prop_access.property, "day")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.day()) } };
                } else if (std.mem.eql(u8, prop_access.property, "hour")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.hour()) } };
                } else if (std.mem.eql(u8, prop_access.property, "minute")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.minute()) } };
                } else if (std.mem.eql(u8, prop_access.property, "second")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.second()) } };
                } else {
                    std.log.warn("  Property '{s}' not found on time value", .{prop_access.property});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            },
            .duration => |duration_value| {
                // Handle duration property access (days, hours, minutes, seconds)
                if (std.mem.eql(u8, prop_access.property, "days")) {
                    return MBLValue{ .number = memory.Number{ .value = duration_value.days() } };
                } else if (std.mem.eql(u8, prop_access.property, "hours")) {
                    return MBLValue{ .number = memory.Number{ .value = duration_value.hours() } };
                } else if (std.mem.eql(u8, prop_access.property, "minutes")) {
                    return MBLValue{ .number = memory.Number{ .value = duration_value.minutes() } };
                } else if (std.mem.eql(u8, prop_access.property, "seconds")) {
                    return MBLValue{ .number = memory.Number{ .value = duration_value.seconds() } };
                } else {
                    std.log.warn("  Property '{s}' not found on duration value", .{prop_access.property});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            },
            .list => |*list_value| {
                // Handle list property access (length)
                if (std.mem.eql(u8, prop_access.property, "length") or std.mem.eql(u8, prop_access.property, "len")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(list_value.len()) } };
                } else {
                    std.log.warn("  Property '{s}' not found on list value", .{prop_access.property});
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

    fn executeWhileStatement(self: *Interpreter, while_stmt: parser.WhileStatement) anyerror!void {

        var iteration_count: usize = 0;
        const max_iterations: usize = 10000; // Prevent infinite loops

        while (true) {
            // Check for infinite loop protection
            iteration_count += 1;
            if (iteration_count > max_iterations) {
                std.log.err("❌ While loop exceeded maximum iterations ({})", .{max_iterations});
                return InterpreterError.TypeError; // Could add specific InfiniteLoopError
            }

            // Evaluate the condition
            const condition_value = try self.evaluateExpression(while_stmt.condition);
            const condition_truthy = self.isTruthy(condition_value);

            if (!condition_truthy) {
                std.log.info("🔄 While condition is false, exiting loop", .{});
                break;
            }

            std.log.info("🔄 While iteration {}, condition is true", .{iteration_count});

            // Execute the loop body (no local scope needed for while loops)
            // Unlike for loops, while loops should work with existing variables
            for (while_stmt.body) |stmt| {
                if (self.executeStatement(stmt)) |_| {
                    // Statement executed normally
                } else |err| switch (err) {
                    InterpreterError.BreakExecuted => {
                        std.log.info("🔄 Break encountered, exiting while loop", .{});
                        return; // Exit the while loop entirely
                    },
                    InterpreterError.ContinueExecuted => {
                        std.log.info("🔄 Continue encountered, skipping to next while iteration", .{});
                        break; // Skip the rest of the loop body statements, continue with next iteration
                    },
                    InterpreterError.GotoExecuted => {
                        // Propagate the goto up to the main execution loop
                        return InterpreterError.GotoExecuted;
                    },
                    else => return err,
                }
            }
        }

        std.log.info("✓ While loop completed after {} iterations", .{iteration_count - 1});
    }

    fn executeForStatement(self: *Interpreter, for_stmt: parser.ForStatement) anyerror!void {
        std.log.info("🔄 Executing for loop with variable '{s}'", .{for_stmt.variable});

        // Evaluate the iterable expression (e.g., a list, record, etc.)
        const iterable_value = try self.evaluateExpression(for_stmt.iterable);

        switch (iterable_value) {
            .list => |list| {
                std.log.info("🔄 Iterating over list with {} elements", .{list.len()});

                // Iterate over each item in the list
                for (0..list.len()) |i| {
                    const item = list.get(i) orelse continue;

                    // Create local scope for this iteration
                    var local_scope = memory.Record.init(self.allocator);
                    defer local_scope.deinit();

                    // Set the loop variable in the local scope
                    try local_scope.set(for_stmt.variable, item);

                    try self.pushScope(&local_scope);
                    defer self.popScope();

                    std.log.info("🔄 For iteration {}, {s} = {s}", .{i, for_stmt.variable, @tagName(item)});

                    // Execute the loop body
                    for (for_stmt.body) |stmt| {
                        if (self.executeStatement(stmt)) |_| {
                            // Statement executed normally
                        } else |err| switch (err) {
                            InterpreterError.BreakExecuted => {
                                std.log.info("🔄 Break encountered, exiting for loop", .{});
                                return; // Exit the for loop entirely
                            },
                            InterpreterError.ContinueExecuted => {
                                std.log.info("🔄 Continue encountered, skipping to next for iteration", .{});
                                break; // Skip the rest of the loop body statements, continue with next iteration
                            },
                            InterpreterError.GotoExecuted => {
                                // Propagate the goto up to the main execution loop
                                return InterpreterError.GotoExecuted;
                            },
                            else => return err,
                        }
                    }
                }
            },
            .record => |record| {
                std.log.info("🔄 Iterating over record with {} fields", .{record.data.count()});

                // Iterate over record keys (we can add value iteration later)
                var iterator = record.data.iterator();
                var i: usize = 0;
                while (iterator.next()) |entry| {
                    // Create MBLValue for the key (record iteration yields keys)
                    const key_value = MBLValue{ .text = try memory.Text.init(self.allocator, entry.key_ptr.*) };

                    // Create local scope for this iteration
                    var local_scope = memory.Record.init(self.allocator);
                    defer local_scope.deinit();

                    // Set the loop variable to the key
                    try local_scope.set(for_stmt.variable, key_value);

                    try self.pushScope(&local_scope);
                    defer self.popScope();

                    std.log.info("🔄 For iteration {}, {s} = {s}", .{i, for_stmt.variable, entry.key_ptr.*});

                    // Execute the loop body
                    for (for_stmt.body) |stmt| {
                        if (self.executeStatement(stmt)) |_| {
                            // Statement executed normally
                        } else |err| switch (err) {
                            InterpreterError.BreakExecuted => {
                                std.log.info("🔄 Break encountered, exiting for loop", .{});
                                return; // Exit the for loop entirely
                            },
                            InterpreterError.ContinueExecuted => {
                                std.log.info("🔄 Continue encountered, skipping to next for iteration", .{});
                                break; // Skip the rest of the loop body statements, continue with next iteration
                            },
                            InterpreterError.GotoExecuted => {
                                // Propagate the goto up to the main execution loop
                                return InterpreterError.GotoExecuted;
                            },
                            else => return err,
                        }
                    }
                    i += 1;
                }
            },
            else => {
                std.log.err("❌ Cannot iterate over {s} type", .{@tagName(iterable_value)});
                return InterpreterError.TypeError;
            }
        }

        std.log.info("✓ For loop completed", .{});
    }

    // Function management methods
    fn registerFunction(self: *Interpreter, func_decl: parser.FunctionDeclaration) !void {
        std.log.info("🔧 Registering function '{s}' with {} parameters", .{func_decl.name, func_decl.parameters.len});

        // Store reference to original function declaration to avoid double-free issues
        // The original AST owns the memory, we just keep a reference
        try self.functions.put(func_decl.name, func_decl);
        std.log.info("✅ Function '{s}' registered successfully", .{func_decl.name});
    }

    fn executeReturnStatement(self: *Interpreter, return_stmt: parser.ReturnStatement) !void {
        if (return_stmt.value) |return_expr| {
            // Explicit return with value - make deep copy to avoid scope cleanup issues
            const expr_value = try self.evaluateExpression(return_expr);
            self.return_value = try expr_value.clone(self.allocator);
            std.log.info("🔄 Return statement executed with value", .{});
        } else {
            // Return without value (should return function's data scope)
            self.return_value = null;
            std.log.info("🔄 Return statement executed without value (will return data scope)", .{});
        }
        return InterpreterError.ReturnExecuted;
    }

    fn callFunction(self: *Interpreter, func_name: []const u8, arguments: []parser.Expression) anyerror!MBLValue {
        // Look up function
        const func_decl = self.functions.get(func_name) orelse {
            std.log.err("❌ Function '{s}' not found", .{func_name});
            return InterpreterError.TypeError;
        };

        std.log.info("📞 Calling function '{s}' with {} arguments", .{func_name, arguments.len});

        // Create function's data scope (record for local variables)
        var function_scope = memory.Record.init(self.allocator);
        // Note: Not using defer deinit() here to allow deep copy of return values

        // Push function scope
        try self.pushScope(&function_scope);
        defer self.popScope();

        // Bind parameters to arguments
        for (func_decl.parameters, 0..) |param, i| {
            const arg_value = if (i < arguments.len)
                try self.evaluateExpression(arguments[i])
            else if (param.default_value) |default_expr|
                try self.evaluateExpression(default_expr)
            else {
                std.log.err("❌ Missing argument for parameter '{s}'", .{param.name});
                return InterpreterError.TypeError;
            };

            try self.createLocalVariable(param.name, arg_value);
            std.log.info("📝 Bound parameter '{s}' to argument", .{param.name});
        }

        // Clear return value before executing function body
        self.return_value = null;

        // Execute function body
        for (func_decl.body) |stmt| {
            if (self.executeStatement(stmt)) |_| {
                // Statement executed normally
            } else |err| switch (err) {
                InterpreterError.ReturnExecuted => {
                    // Function returned explicitly
                    break;
                },
                else => return err,
            }
        }

        // Determine return value and handle cleanup
        if (self.return_value) |return_val| {
            // Explicit return value - clean up function scope after extracting return value
            std.log.info("✅ Function '{s}' returned explicit value", .{func_name});
            function_scope.deinit(); // Clean up now that we have the return value
            return return_val;
        } else {
            // Implicit return: return a deep copy of function's data scope (record)
            std.log.info("✅ Function '{s}' returning data scope (record)", .{func_name});
            const cloned_record = try function_scope.clone();
            function_scope.deinit(); // Clean up the original scope after cloning
            return MBLValue{ .record = cloned_record };
        }
    }

    fn performLogicalAnd(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const left_logic = left.isTruthy();
        const right_logic = right.isTruthy();

        // Ternary logic AND truth table
        const result = switch (left_logic) {
            .true_val => switch (right_logic) {
                .true_val => memory.TernaryLogic.true_val,
                .false_val => memory.TernaryLogic.false_val,
                .unknown => memory.TernaryLogic.unknown,
            },
            .false_val => memory.TernaryLogic.false_val, // false dominates
            .unknown => switch (right_logic) {
                .false_val => memory.TernaryLogic.false_val, // false dominates
                else => memory.TernaryLogic.unknown,
            },
        };

        return switch (result) {
            .true_val => MBLValue{ .boolean = memory.Boolean{ .value = true } },
            .false_val => MBLValue{ .boolean = memory.Boolean{ .value = false } },
            .unknown => MBLValue{ .unknown = {} },
        };
    }

    fn performLogicalOr(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const left_logic = left.isTruthy();
        const right_logic = right.isTruthy();

        // Ternary logic OR truth table
        const result = switch (left_logic) {
            .true_val => memory.TernaryLogic.true_val, // true dominates
            .false_val => switch (right_logic) {
                .true_val => memory.TernaryLogic.true_val,
                .false_val => memory.TernaryLogic.false_val,
                .unknown => memory.TernaryLogic.unknown,
            },
            .unknown => switch (right_logic) {
                .true_val => memory.TernaryLogic.true_val, // true dominates
                else => memory.TernaryLogic.unknown,
            },
        };

        return switch (result) {
            .true_val => MBLValue{ .boolean = memory.Boolean{ .value = true } },
            .false_val => MBLValue{ .boolean = memory.Boolean{ .value = false } },
            .unknown => MBLValue{ .unknown = {} },
        };
    }

    fn isTruthy(self: *Interpreter, value: MBLValue) bool {
        // Legacy support - convert TernaryLogic to bool for older code
        return switch (value.isTruthy()) {
            .true_val => true,
            .false_val, .unknown => false,
        };
    }
};