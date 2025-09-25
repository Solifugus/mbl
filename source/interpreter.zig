// MBL Interpreter - executes parsed MBL statements and expressions
const std = @import("std");
const memory = @import("memory.zig");
const parser = @import("parser.zig");

const Memory = memory.Memory;
const MBLValue = memory.MBLValue;
const Statement = parser.Statement;
const Expression = parser.Expression;

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
};