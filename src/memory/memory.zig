const std = @import("std");
const value_module = @import("value.zig");

// Re-export all types from value.zig
pub const Value = value_module.Value;
pub const ValueType = value_module.ValueType;
pub const Environment = value_module.Environment;
pub const Interpreter = value_module.Interpreter;
pub const AstNode = value_module.AstNode;
pub const AstNodeType = value_module.AstNodeType;
pub const OperatorType = value_module.OperatorType;
pub const EventType = value_module.EventType;
pub const SourcePosition = value_module.SourcePosition;
pub const RuntimeError = value_module.RuntimeError;

pub const MemoryError = error{
    OutOfMemory,
    InvalidValue,
    InvalidOperation,
    DivisionByZero,
    KeyNotFound,
    InvalidParent,
};

pub const TriggerManager = struct {
    allocator: std.mem.Allocator,
    triggers: std.ArrayList(*Value),  // List of trigger values
    interpreter: ?*Interpreter,       // Interpreter used to execute triggers
    
    pub fn init(allocator: std.mem.Allocator) TriggerManager {
        return .{
            .allocator = allocator,
            .triggers = std.ArrayList(*Value).init(allocator),
            .interpreter = null,
        };
    }
    
    pub fn deinit(self: *TriggerManager) void {
        self.triggers.deinit();
    }
    
    pub fn setInterpreter(self: *TriggerManager, interpreter: *Interpreter) void {
        self.interpreter = interpreter;
    }
    
    pub fn registerTrigger(self: *TriggerManager, trigger: *Value) !void {
        if (trigger.data != .trigger) {
            return MemoryError.InvalidValue;
        }
        
        try self.triggers.append(trigger);
    }
    
    pub fn unregisterTrigger(self: *TriggerManager, name: []const u8) bool {
        for (self.triggers.items, 0..) |trigger, i| {
            if (trigger.data == .trigger and std.mem.eql(u8, trigger.data.trigger.name, name)) {
                _ = self.triggers.orderedRemove(i);
                return true;
            }
        }
        
        return false;
    }
    
    pub fn fireDataChangedEvent(self: *TriggerManager, context: *Value) !void {
        if (self.interpreter == null) {
            return;  // No interpreter set, so can't execute triggers
        }
        
        for (self.triggers.items) |trigger| {
            if (trigger.data != .trigger) continue;
            
            // Only process data_changed event triggers
            if (trigger.data.trigger.event_type != .data_changed) continue;
            
            // Execute the trigger with the context
            self.interpreter.?.executeTrigger(trigger, context) catch |err| {
                // For now, just ignore errors in triggers
                std.debug.print("Error executing trigger: {any}\n", .{err});
            };
        }
    }
};

pub const MemoryManager = struct {
    allocator: std.mem.Allocator,
    values: std.ArrayList(*Value),
    trigger_manager: TriggerManager,
    
    pub fn init(allocator: std.mem.Allocator) MemoryManager {
        return .{
            .allocator = allocator,
            .values = std.ArrayList(*Value).init(allocator),
            .trigger_manager = TriggerManager.init(allocator),
        };
    }

    pub fn deinit(self: *MemoryManager) void {
        // Clean up all allocated values first
        for (self.values.items) |value| {
            value.deinit(self.allocator);
            self.allocator.destroy(value);
        }
        self.values.deinit();
        
        // Clean up the trigger manager
        self.trigger_manager.deinit();
    }

    pub fn allocateValue(self: *MemoryManager, value: Value) !*Value {
        const new_value = try self.allocator.create(Value);
        new_value.* = value;
        try self.values.append(new_value);
        return new_value;
    }

    pub fn allocateNumber(self: *MemoryManager, number: f64) !*Value {
        return self.allocateValue(Value.initNumber(number));
    }

    pub fn allocateText(self: *MemoryManager, text: []const u8) !*Value {
        // Always create owned text to prevent use-after-free errors
        const value = try Value.initOwnedText(self.allocator, text);
        return self.allocateValue(value);
    }

    pub fn allocateMoney(self: *MemoryManager, amount: i128, currency: []const u8) !*Value {
        // Always create owned currency to prevent use-after-free errors
        const value = try Value.initOwnedMoney(self.allocator, amount, currency);
        return self.allocateValue(value);
    }
    
    pub fn allocateMoneyFromDecimal(self: *MemoryManager, dollars: i64, cents: i64, currency: []const u8) !*Value {
        const amount = dollars * 10000 + cents * 100;
        return self.allocateMoney(amount, currency);
    }

    pub fn allocateTime(self: *MemoryManager, hours: u8, minutes: u8, seconds: u8, milliseconds: u16) !*Value {
        return self.allocateValue(Value.initTime(hours, minutes, seconds, milliseconds));
    }

    pub fn allocateDate(self: *MemoryManager, year: i32, month: u8, day: u8) !*Value {
        return self.allocateValue(Value.initDate(year, month, day));
    }
    
    pub fn allocateDateTime(self: *MemoryManager, year: i32, month: u8, day: u8, hours: u8, minutes: u8, seconds: u8, milliseconds: u16) !*Value {
        return self.allocateValue(Value.initDateTime(year, month, day, hours, minutes, seconds, milliseconds));
    }
    
    pub fn allocateDateTimeFromParts(self: *MemoryManager, date: *Value, time: *Value) !*Value {
        if (date.data != .date or time.data != .time) return error.InvalidValue;
        return self.allocateValue(Value.initDateTimeFromParts(date.data.date, time.data.time));
    }
    
    // Parse a date from a string in the format "YYYY-MM-DD"
    pub fn allocateDateFromString(self: *MemoryManager, str: []const u8) !*Value {
        const date = try @import("value.zig").Date.parse(str);
        return self.allocateValue(Value.initDate(date.year, date.month, date.day));
    }
    
    // Parse a time from a string in the format "HH:MM:SS" or "HH:MM:SS.mmm" 
    pub fn allocateTimeFromString(self: *MemoryManager, str: []const u8) !*Value {
        const time = try @import("value.zig").Time.parse(str);
        return self.allocateValue(Value.initTime(time.hours, time.minutes, time.seconds, time.milliseconds));
    }
    
    // Parse a datetime from a string in ISO 8601 format
    pub fn allocateDateTimeFromString(self: *MemoryManager, str: []const u8) !*Value {
        const datetime = try @import("value.zig").DateTime.parse(str);
        return self.allocateValue(Value.initDateTimeFromParts(datetime.date, datetime.time));
    }
    
    // Parse a special @ literal like @"2024-03-15" (date) or @"$123.45" (money)
    pub fn allocateFromSpecialLiteral(self: *MemoryManager, str: []const u8) !?*Value {
        const ValueMod = @import("value.zig").Value;
        
        if (try ValueMod.tryParseSpecialLiteral(self.allocator, str)) |value| {
            return try self.allocateValue(value);
        }
        
        return null;
    }
    
    // Functions for creating and managing AST nodes
    
    pub fn createAstNode(self: *MemoryManager) *@import("value.zig").AstNode {
        const node = self.allocator.create(@import("value.zig").AstNode) catch {
            @panic("Out of memory creating AST node");
        };
        return node;
    }
    
    pub fn createNumberLiteral(self: *MemoryManager, value: f64, pos: @import("value.zig").SourcePosition) !*@import("value.zig").AstNode {
        const AstNodeTypeEnum = @import("value.zig").AstNodeType;
        
        var node = self.createAstNode();
        node.* = .{
            .node_type = AstNodeTypeEnum.number_literal,
            .pos = pos,
            .data = .{ .number_literal = value },
        };
        return node;
    }
    
    pub fn createTextLiteral(self: *MemoryManager, value: []const u8, pos: @import("value.zig").SourcePosition) !*@import("value.zig").AstNode {
        const AstNodeTypeEnum = @import("value.zig").AstNodeType;
        
        const text_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(text_copy);
        
        var node = self.createAstNode();
        node.* = .{
            .node_type = AstNodeTypeEnum.text_literal,
            .pos = pos,
            .data = .{ .text_literal = text_copy },
        };
        return node;
    }
    
    pub fn createBooleanLiteral(self: *MemoryManager, value: bool, pos: @import("value.zig").SourcePosition) !*@import("value.zig").AstNode {
        const AstNodeTypeEnum = @import("value.zig").AstNodeType;
        
        var node = self.createAstNode();
        node.* = .{
            .node_type = AstNodeTypeEnum.boolean_literal,
            .pos = pos,
            .data = .{ .boolean_literal = value },
        };
        return node;
    }
    
    pub fn createIdentifier(self: *MemoryManager, name: []const u8, pos: @import("value.zig").SourcePosition) !*@import("value.zig").AstNode {
        const AstNodeTypeEnum = @import("value.zig").AstNodeType;
        
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        
        var node = self.createAstNode();
        node.* = .{
            .node_type = AstNodeTypeEnum.identifier,
            .pos = pos,
            .data = .{ .identifier = name_copy },
        };
        return node;
    }
    
    pub fn createBinaryExpression(self: *MemoryManager, left: *@import("value.zig").AstNode, 
                                 operator: @import("value.zig").OperatorType, 
                                 right: *@import("value.zig").AstNode, 
                                 pos: @import("value.zig").SourcePosition) !*@import("value.zig").AstNode {
        const AstNodeTypeEnum = @import("value.zig").AstNodeType;
        
        var node = self.createAstNode();
        node.* = .{
            .node_type = AstNodeTypeEnum.binary_expression,
            .pos = pos,
            .data = .{
                .binary_expression = .{
                    .left = left,
                    .operator = operator,
                    .right = right,
                },
            },
        };
        return node;
    }
    
    pub fn createBlock(self: *MemoryManager, statements: []const *@import("value.zig").AstNode, 
                     pos: @import("value.zig").SourcePosition) !*@import("value.zig").AstNode {
        const AstNodeTypeEnum = @import("value.zig").AstNodeType;
        
        var stmts_copy = try self.allocator.alloc(*@import("value.zig").AstNode, statements.len);
        errdefer self.allocator.free(stmts_copy);
        
        for (statements, 0..) |stmt, i| {
            stmts_copy[i] = stmt;
        }
        
        var node = self.createAstNode();
        node.* = .{
            .node_type = AstNodeTypeEnum.block,
            .pos = pos,
            .data = .{ .block = stmts_copy },
        };
        return node;
    }
    
    pub fn createIfStatement(self: *MemoryManager, condition: *@import("value.zig").AstNode, 
                           then_branch: *@import("value.zig").AstNode, 
                           else_branch: ?*@import("value.zig").AstNode, 
                           pos: @import("value.zig").SourcePosition) !*@import("value.zig").AstNode {
        const AstNodeTypeEnum = @import("value.zig").AstNodeType;
        
        var node = self.createAstNode();
        node.* = .{
            .node_type = AstNodeTypeEnum.if_stmt,
            .pos = pos,
            .data = .{
                .if_stmt = .{
                    .condition = condition,
                    .then_branch = then_branch,
                    .else_branch = else_branch,
                },
            },
        };
        return node;
    }
    
    // Functions for creating and managing functions and triggers
    
    pub fn allocateFunction(self: *MemoryManager, name: []const u8, 
                          params: []const []const u8, 
                          body: *@import("value.zig").AstNode) !*Value {
        const ValueMod = @import("value.zig").Value;
        const value = try ValueMod.initFunction(self.allocator, name, params, body);
        return try self.allocateValue(value);
    }
    
    pub fn allocateTrigger(self: *MemoryManager, name: []const u8, 
                         event_type: @import("value.zig").EventType, 
                         condition: *@import("value.zig").AstNode, 
                         action: *@import("value.zig").AstNode) !*Value {
        const ValueMod = @import("value.zig").Value;
        const value = try ValueMod.initTrigger(self.allocator, name, event_type, condition, action);
        return try self.allocateValue(value);
    }
    
    pub fn allocateConstraint(self: *MemoryManager, name: []const u8,
                             condition: *@import("value.zig").AstNode,
                             healing_action: ?*@import("value.zig").AstNode) !*Value {
        const ValueMod = @import("value.zig").Value;
        const value = try ValueMod.initConstraint(self.allocator, name, condition, healing_action);
        return try self.allocateValue(value);
    }
    
    // Interpreter functionality
    
    // Create a new interpreter environment
    pub fn createEnvironment(self: *MemoryManager) !*Environment {
        const env = try self.allocator.create(Environment);
        env.* = Environment.init(self.allocator, @ptrCast(self));
        
        return env;
    }
    
    // Create an interpreter with a fresh environment
    pub fn createInterpreter(self: *MemoryManager) !*Interpreter {
        // Create a new environment
        const env = try self.createEnvironment();
        
        // Create the interpreter
        const interpreter = try self.allocator.create(Interpreter);
        interpreter.* = Interpreter.init(self.allocator, @ptrCast(self), env);
        
        // Set the interpreter for the trigger manager
        self.trigger_manager.setInterpreter(interpreter);
        
        return interpreter;
    }
    
    // Execute a function with arguments
    pub fn executeFunction(self: *MemoryManager, interpreter: *Interpreter, 
                         func: *Value, args: []const *Value) !*Value {
        _ = self;
        return interpreter.executeFunction(func, args) catch |err| switch (err) {
            RuntimeError.DivisionByZero => return MemoryError.DivisionByZero,
            RuntimeError.InvalidArguments => return MemoryError.InvalidValue,
            RuntimeError.InvalidCall => return MemoryError.InvalidOperation,
            else => return MemoryError.InvalidOperation,
        };
    }
    
    // Trigger management
    
    pub fn registerTrigger(self: *MemoryManager, trigger: *Value) !void {
        return self.trigger_manager.registerTrigger(trigger);
    }
    
    pub fn unregisterTrigger(self: *MemoryManager, name: []const u8) bool {
        return self.trigger_manager.unregisterTrigger(name);
    }
    
    pub fn fireDataChangedEvent(self: *MemoryManager, context: *Value) !void {
        return self.trigger_manager.fireDataChangedEvent(context);
    }
    
    // Execute a trigger with a context
    pub fn executeTrigger(self: *MemoryManager, interpreter: *Interpreter, 
                        trigger: *Value, context: *Value) !void {
        _ = self;
        return interpreter.executeTrigger(trigger, context) catch |err| switch (err) {
            RuntimeError.DivisionByZero => return MemoryError.DivisionByZero,
            RuntimeError.InvalidCall => return MemoryError.InvalidOperation,
            else => return MemoryError.InvalidOperation,
        };
    }
    
    // Evaluate AST node
    pub fn evaluateAst(self: *MemoryManager, interpreter: *Interpreter, 
                      node: *AstNode) !*Value {
        _ = self;
        return interpreter.evaluate(node) catch |err| switch (err) {
            RuntimeError.DivisionByZero => return MemoryError.DivisionByZero,
            RuntimeError.InvalidCall => return MemoryError.InvalidOperation,
            RuntimeError.UndefinedVariable => return MemoryError.InvalidValue,
            else => return MemoryError.InvalidOperation,
        };
    }

    pub fn allocatePercentage(self: *MemoryManager, value: f64) !*Value {
        return self.allocateValue(Value.initPercentage(value));
    }

    pub fn allocateRatio(self: *MemoryManager, numerator: f64, denominator: f64) !*Value {
        if (denominator == 0) return MemoryError.DivisionByZero;
        return self.allocateValue(Value.initRatio(numerator, denominator));
    }

    pub fn allocateBoolean(self: *MemoryManager, value: bool) !*Value {
        return self.allocateValue(Value.initBoolean(value));
    }

    pub fn allocateUnknown(self: *MemoryManager) !*Value {
        return self.allocateValue(Value.initUnknown());
    }

    pub fn allocateNil(self: *MemoryManager) !*Value {
        return self.allocateValue(Value.initNil());
    }
    
    pub fn allocateList(self: *MemoryManager) !*Value {
        return self.allocateValue(Value.initList(self.allocator));
    }
    
    pub fn allocateRecord(self: *MemoryManager) !*Value {
        return self.allocateValue(Value.initRecord(self.allocator));
    }
    
    pub fn allocateRecordWithParent(self: *MemoryManager, parent: *Value) !*Value {
        const value = try Value.initRecordWithParent(self.allocator, parent);
        return self.allocateValue(value);
    }
    
    // List operations
    pub fn listPush(_: *MemoryManager, list: *Value, item: *Value) !void {
        if (list.data != .list) return MemoryError.InvalidValue;
        try list.data.list.push(item);
    }
    
    pub fn listPop(_: *MemoryManager, list: *Value) !?*Value {
        if (list.data != .list) return MemoryError.InvalidValue;
        return list.data.list.pop();
    }
    
    pub fn listGet(_: *MemoryManager, list: *Value, index: usize) !?*Value {
        if (list.data != .list) return MemoryError.InvalidValue;
        return list.data.list.get(index);
    }
    
    pub fn listSet(_: *MemoryManager, list: *Value, index: usize, item: *Value) !void {
        if (list.data != .list) return MemoryError.InvalidValue;
        try list.data.list.set(index, item);
    }
    
    pub fn listLength(_: *MemoryManager, list: *Value) !usize {
        if (list.data != .list) return MemoryError.InvalidValue;
        return list.data.list.length();
    }
    
    pub fn listSlice(self: *MemoryManager, list: *Value, start_idx: usize, slice_len: usize) !*Value {
        if (list.data != .list) return MemoryError.InvalidValue;
        
        var new_list = try list.data.list.slice(start_idx, slice_len);
        var value = Value{
            .data = .{ .list = new_list },
            .owns_memory = true,
        };
        
        return self.allocateValue(value);
    }
    
    pub fn listSplice(_: *MemoryManager, list: *Value, start_idx: usize, remove_len: usize, items: ?[]*Value) !void {
        if (list.data != .list) return MemoryError.InvalidValue;
        try list.data.list.splice(start_idx, remove_len, items);
    }
    
    // Record operations
    pub fn recordSet(self: *MemoryManager, record: *Value, key: []const u8, value: *Value) !void {
        if (record.data != .record) return MemoryError.InvalidValue;
        
        // Check if the field value is actually changing
        var old_value: ?*Value = null;
        if (record.data.record.getOwn(key)) |existing| {
            old_value = existing;
        }
        
        // Set the new value
        try record.data.record.set(key, value);
        
        // Fire data change event if this is an actual change
        const is_real_change = if (old_value) |v| 
            MemoryManager.compare(v, value) catch null != @as(?i32, 0)
        else 
            true;  // Field didn't exist before, so it's a change
            
        if (is_real_change) {
            // Create a change context record
            const context = try self.allocateRecord();
            try self.recordSet(context, "record", record);
            try self.recordSet(context, "key", try self.allocateText(key));
            try self.recordSet(context, "value", value);
            if (old_value) |v| {
                try self.recordSet(context, "old_value", v);
            }
            
            // Fire the data changed event
            _ = self.fireDataChangedEvent(context) catch {};
        }
    }
    
    pub fn recordGet(_: *MemoryManager, record: *Value, key: []const u8) !?*Value {
        if (record.data != .record) return MemoryError.InvalidValue;
        return record.data.record.get(key);
    }
    
    pub fn recordGetOwn(_: *MemoryManager, record: *Value, key: []const u8) !?*Value {
        if (record.data != .record) return MemoryError.InvalidValue;
        return record.data.record.getOwn(key);
    }
    
    pub fn recordRemove(_: *MemoryManager, record: *Value, key: []const u8) !bool {
        if (record.data != .record) return MemoryError.InvalidValue;
        return record.data.record.remove(key);
    }
    
    pub fn recordKeys(_: *MemoryManager, record: *Value) !std.ArrayList([]const u8) {
        if (record.data != .record) return MemoryError.InvalidValue;
        return record.data.record.keys();
    }
    
    // Creates a deep copy of a record
    pub fn recordCopy(self: *MemoryManager, record: *Value) !*Value {
        if (record.data != .record) return MemoryError.InvalidValue;
        
        var new_record = try record.data.record.copy(self.allocator);
        var value = Value{
            .data = .{ .record = new_record },
            .owns_memory = true,
        };
        
        return self.allocateValue(value);
    }
    
    // Creates a deep copy of any value
    pub fn deepCopy(self: *MemoryManager, value: *Value) !*Value {
        return switch (value.data) {
            .number => |n| self.allocateNumber(n),
            .text => |t| self.allocateText(t),
            .money => |m| self.allocateMoney(m.amount, m.currency),
            .time => |t| self.allocateTime(t.hours, t.minutes, t.seconds, t.milliseconds),
            .date => |d| self.allocateDate(d.year, d.month, d.day),
            .date_time => |dt| self.allocateDateTime(
                dt.date.year, dt.date.month, dt.date.day,
                dt.time.hours, dt.time.minutes, dt.time.seconds, dt.time.milliseconds
            ),
            .percentage => |p| self.allocatePercentage(p.value),
            .ratio => |r| self.allocateRatio(r.numerator, r.denominator),
            .boolean => |b| self.allocateBoolean(b),
            .unknown => self.allocateUnknown(),
            .nil => self.allocateNil(),
            .list => blk: {
                const new_list = try self.allocateList();
                
                // For each item in the list, create a deep copy and add it to the new list
                var i: usize = 0;
                while (i < value.data.list.length()) : (i += 1) {
                    if (value.data.list.get(i)) |item| {
                        const copied_item = try self.deepCopy(item);
                        try new_list.data.list.push(copied_item);
                    }
                }
                
                break :blk new_list;
            },
            .record => blk: {
                const new_record = try self.allocateRecord();
                
                // Handle parent if present
                if (value.data.record.parent) |parent| {
                    const copied_parent = try self.deepCopy(parent);
                    new_record.data.record.parent = copied_parent;
                }
                
                // For each field in the record, create a deep copy and add it to the new record
                var keys_list = try value.data.record.keys();
                defer keys_list.deinit();
                
                for (keys_list.items) |key| {
                    if (value.data.record.getOwn(key)) |field_value| {
                        const copied_value = try self.deepCopy(field_value);
                        try new_record.data.record.set(key, copied_value);
                    }
                }
                
                break :blk new_record;
            },
        };
    }

    pub fn add(self: *MemoryManager, a: *Value, b: *Value) !*Value {
        return switch (a.data) {
            .number => |n1| switch (b.data) {
                .number => |n2| self.allocateNumber(n1 + n2),
                .money => |m2| {
                    // Convert number to money units (integer with 4 decimal places)
                    const n1_as_money = @as(i128, @intFromFloat(n1 * 10000));
                    return self.allocateMoney(n1_as_money + m2.amount, m2.currency);
                },
                .percentage => |p2| self.allocatePercentage(n1 + p2.value),
                else => MemoryError.InvalidOperation,
            },
            .money => |m1| switch (b.data) {
                .number => |n2| {
                    // Convert number to money units (integer with 4 decimal places)
                    const n2_as_money = @as(i128, @intFromFloat(n2 * 10000));
                    return self.allocateMoney(m1.amount + n2_as_money, m1.currency);
                },
                .money => |m2| if (std.mem.eql(u8, m1.currency, m2.currency)) 
                    self.allocateMoney(m1.amount + m2.amount, m1.currency)
                else 
                    MemoryError.InvalidOperation,
                else => MemoryError.InvalidOperation,
            },
            .percentage => |p1| switch (b.data) {
                .number => |n2| self.allocatePercentage(p1.value + n2),
                .percentage => |p2| self.allocatePercentage(p1.value + p2.value),
                else => MemoryError.InvalidOperation,
            },
            else => MemoryError.InvalidOperation,
        };
    }

    pub fn subtract(self: *MemoryManager, a: *Value, b: *Value) !*Value {
        return switch (a.data) {
            .number => |n1| switch (b.data) {
                .number => |n2| self.allocateNumber(n1 - n2),
                .money => |m2| {
                    // Convert number to money units (integer with 4 decimal places)
                    const n1_as_money = @as(i128, @intFromFloat(n1 * 10000));
                    return self.allocateMoney(n1_as_money - m2.amount, m2.currency);
                },
                .percentage => |p2| self.allocatePercentage(n1 - p2.value),
                else => MemoryError.InvalidOperation,
            },
            .money => |m1| switch (b.data) {
                .number => |n2| {
                    // Convert number to money units (integer with 4 decimal places)
                    const n2_as_money = @as(i128, @intFromFloat(n2 * 10000));
                    return self.allocateMoney(m1.amount - n2_as_money, m1.currency);
                },
                .money => |m2| if (std.mem.eql(u8, m1.currency, m2.currency)) 
                    self.allocateMoney(m1.amount - m2.amount, m1.currency)
                else 
                    MemoryError.InvalidOperation,
                else => MemoryError.InvalidOperation,
            },
            .percentage => |p1| switch (b.data) {
                .number => |n2| self.allocatePercentage(p1.value - n2),
                .percentage => |p2| self.allocatePercentage(p1.value - p2.value),
                else => MemoryError.InvalidOperation,
            },
            else => MemoryError.InvalidOperation,
        };
    }

    pub fn multiply(self: *MemoryManager, a: *Value, b: *Value) !*Value {
        return switch (a.data) {
            .number => |n1| switch (b.data) {
                .number => |n2| self.allocateNumber(n1 * n2),
                .money => |m2| {
                    // Scale the money amount by the number
                    const scaled_amount = @as(i128, @intFromFloat(@as(f64, @floatFromInt(m2.amount)) * n1));
                    return self.allocateMoney(scaled_amount, m2.currency);
                },
                .percentage => |p2| self.allocatePercentage(n1 * p2.value),
                .ratio => |r2| self.allocateRatio(n1 * r2.numerator, r2.denominator),
                else => MemoryError.InvalidOperation,
            },
            .money => |m1| switch (b.data) {
                .number => |n2| {
                    // Scale the money amount by the number
                    const scaled_amount = @as(i128, @intFromFloat(@as(f64, @floatFromInt(m1.amount)) * n2));
                    return self.allocateMoney(scaled_amount, m1.currency);
                },
                .percentage => |p2| {
                    // Apply percentage (scale by p2.value / 100.0)
                    const scaled_amount = @as(i128, @intFromFloat(@as(f64, @floatFromInt(m1.amount)) * (p2.value / 100.0)));
                    return self.allocateMoney(scaled_amount, m1.currency);
                },
                else => MemoryError.InvalidOperation,
            },
            .percentage => |p1| switch (b.data) {
                .number => |n2| self.allocatePercentage(p1.value * n2),
                .percentage => |p2| self.allocatePercentage(p1.value * p2.value / 100.0),
                else => MemoryError.InvalidOperation,
            },
            .ratio => |r1| switch (b.data) {
                .number => |n2| self.allocateRatio(r1.numerator * n2, r1.denominator),
                .ratio => |r2| self.allocateRatio(r1.numerator * r2.numerator, r1.denominator * r2.denominator),
                else => MemoryError.InvalidOperation,
            },
            else => MemoryError.InvalidOperation,
        };
    }

    pub fn divide(self: *MemoryManager, a: *Value, b: *Value) !*Value {
        return switch (a.data) {
            .number => |n1| switch (b.data) {
                .number => |n2| if (n2 == 0) MemoryError.DivisionByZero else self.allocateNumber(n1 / n2),
                .money => |m2| if (m2.amount == 0) MemoryError.DivisionByZero else {
                    // Convert money to decimal for division
                    const m2_decimal = @as(f64, @floatFromInt(m2.amount)) / 10000.0;
                    return self.allocateNumber(n1 / m2_decimal);
                },
                .percentage => |p2| if (p2.value == 0) MemoryError.DivisionByZero else self.allocateNumber(n1 / (p2.value / 100.0)),
                .ratio => |r2| if (r2.numerator == 0) MemoryError.DivisionByZero else self.allocateRatio(n1 * r2.denominator, r2.numerator),
                else => MemoryError.InvalidOperation,
            },
            .money => |m1| switch (b.data) {
                .number => |n2| if (n2 == 0) MemoryError.DivisionByZero else {
                    // Scale the money amount by dividing by the number
                    const scaled_amount = @as(i128, @intFromFloat(@as(f64, @floatFromInt(m1.amount)) / n2));
                    return self.allocateMoney(scaled_amount, m1.currency);
                },
                .money => |m2| if (m2.amount == 0) MemoryError.DivisionByZero else if (std.mem.eql(u8, m1.currency, m2.currency)) {
                    // When dividing money by money, we get a unitless ratio
                    const ratio = @as(f64, @floatFromInt(m1.amount)) / @as(f64, @floatFromInt(m2.amount));
                    return self.allocateNumber(ratio);
                } else 
                    MemoryError.InvalidOperation,
                else => MemoryError.InvalidOperation,
            },
            .percentage => |p1| switch (b.data) {
                .number => |n2| if (n2 == 0) MemoryError.DivisionByZero else self.allocatePercentage(p1.value / n2),
                .percentage => |p2| if (p2.value == 0) MemoryError.DivisionByZero else self.allocatePercentage(p1.value / p2.value),
                else => MemoryError.InvalidOperation,
            },
            .ratio => |r1| switch (b.data) {
                .number => |n2| if (n2 == 0) MemoryError.DivisionByZero else self.allocateRatio(r1.numerator, r1.denominator * n2),
                .ratio => |r2| if (r2.numerator == 0) MemoryError.DivisionByZero else self.allocateRatio(r1.numerator * r2.denominator, r1.denominator * r2.numerator),
                else => MemoryError.InvalidOperation,
            },
            else => MemoryError.InvalidOperation,
        };
    }

    pub fn compare(a: *Value, b: *Value) !i32 {
        return switch (a.data) {
            .number => |n1| switch (b.data) {
                .number => |n2| if (n1 < n2) -1 else if (n1 > n2) 1 else 0,
                .money => |m2| {
                    // Convert number to money units for comparison
                    const n1_as_money = n1 * 10000.0;
                    const m2_as_float = @as(f64, @floatFromInt(m2.amount));
                    if (n1_as_money < m2_as_float) return -1;
                    if (n1_as_money > m2_as_float) return 1;
                    return 0;
                },
                .percentage => |p2| if (n1 < p2.value) -1 else if (n1 > p2.value) 1 else 0,
                else => MemoryError.InvalidOperation,
            },
            .money => |m1| switch (b.data) {
                .number => |n2| {
                    // Convert number to money units for comparison
                    const n2_as_money = @as(i128, @intFromFloat(n2 * 10000.0));
                    if (m1.amount < n2_as_money) return -1;
                    if (m1.amount > n2_as_money) return 1;
                    return 0;
                },
                .money => |m2| if (!std.mem.eql(u8, m1.currency, m2.currency)) 
                    MemoryError.InvalidOperation
                else if (m1.amount < m2.amount) -1 
                else if (m1.amount > m2.amount) 1 
                else 0,
                else => MemoryError.InvalidOperation,
            },
            .date => |d1| switch (b.data) {
                .date => |d2| @intCast(d1.compare(d2)),
                .date_time => |dt2| if (d1.equals(dt2.date)) 0 else @intCast(d1.compare(dt2.date)),
                else => MemoryError.InvalidOperation,
            },
            .time => |t1| switch (b.data) {
                .time => |t2| if (t1.hours < t2.hours) -1 
                       else if (t1.hours > t2.hours) 1
                       else if (t1.minutes < t2.minutes) -1
                       else if (t1.minutes > t2.minutes) 1
                       else if (t1.seconds < t2.seconds) -1
                       else if (t1.seconds > t2.seconds) 1
                       else if (t1.milliseconds < t2.milliseconds) -1
                       else if (t1.milliseconds > t2.milliseconds) 1
                       else 0,
                else => MemoryError.InvalidOperation,
            },
            .date_time => |dt1| switch (b.data) {
                .date => |d2| if (dt1.date.equals(d2)) 0 else @intCast(dt1.date.compare(d2)),
                .date_time => |dt2| @intCast(dt1.compare(dt2)),
                else => MemoryError.InvalidOperation,
            },
            .percentage => |p1| switch (b.data) {
                .number => |n2| if (p1.value < n2) -1 else if (p1.value > n2) 1 else 0,
                .percentage => |p2| if (p1.value < p2.value) -1 else if (p1.value > p2.value) 1 else 0,
                else => MemoryError.InvalidOperation,
            },
            .text => |t1| switch (b.data) {
                .text => |t2| switch (std.mem.order(u8, t1, t2)) {
                    .lt => -1,
                    .eq => 0,
                    .gt => 1,
                },
                else => MemoryError.InvalidOperation,
            },
            .boolean => |b1| switch (b.data) {
                .boolean => |b2| if (b1 == b2) 0 else if (b1) 1 else -1,
                else => MemoryError.InvalidOperation,
            },
            else => MemoryError.InvalidOperation,
        };
    }

    pub fn convert(self: *MemoryManager, value: *Value, target_type: ValueType) !*Value {
        return switch (target_type) {
            .number => switch (value.data) {
                .number => |n| self.allocateNumber(n),
                .money => |m| {
                    // Convert money to decimal value
                    const amount_as_float = @as(f64, @floatFromInt(m.amount)) / 10000.0;
                    return self.allocateNumber(amount_as_float);
                },
                .percentage => |p| self.allocateNumber(p.value),
                .ratio => |r| self.allocateNumber(r.numerator / r.denominator),
                else => MemoryError.InvalidOperation,
            },
            .money => switch (value.data) {
                .number => |n| {
                    // Convert number to money (fixed-point) representation
                    const amount_as_int = @as(i128, @intFromFloat(n * 10000.0));
                    return self.allocateMoney(amount_as_int, "USD");
                },
                .money => |m| self.allocateMoney(m.amount, m.currency),
                else => MemoryError.InvalidOperation,
            },
            .percentage => switch (value.data) {
                .number => |n| self.allocatePercentage(n),
                .percentage => |p| self.allocatePercentage(p.value),
                else => MemoryError.InvalidOperation,
            },
            .ratio => switch (value.data) {
                .number => |n| self.allocateRatio(n, 1),
                .ratio => |r| self.allocateRatio(r.numerator, r.denominator),
                else => MemoryError.InvalidOperation,
            },
            .date_time => switch (value.data) {
                .date => |d| self.allocateDateTime(
                    d.year, d.month, d.day, 0, 0, 0, 0
                ),
                .date_time => |dt| self.allocateDateTime(
                    dt.date.year, dt.date.month, dt.date.day,
                    dt.time.hours, dt.time.minutes, dt.time.seconds, dt.time.milliseconds
                ),
                else => MemoryError.InvalidOperation,
            },
            .date => switch (value.data) {
                .date => |d| self.allocateDate(d.year, d.month, d.day),
                .date_time => |dt| self.allocateDate(dt.date.year, dt.date.month, dt.date.day),
                else => MemoryError.InvalidOperation,
            },
            .time => switch (value.data) {
                .time => |t| self.allocateTime(t.hours, t.minutes, t.seconds, t.milliseconds),
                .date_time => |dt| self.allocateTime(
                    dt.time.hours, dt.time.minutes, dt.time.seconds, dt.time.milliseconds
                ),
                else => MemoryError.InvalidOperation,
            },
            else => MemoryError.InvalidOperation,
        };
    }
}; 