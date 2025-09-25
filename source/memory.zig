// memory.zig
const std = @import("std");

// Forward declarations to avoid circular imports
pub const Statement = opaque {};
pub const Expression = opaque {};

pub const Text = struct {
    data: []const u8,

    pub fn init(allocator: std.mem.Allocator, text: []const u8) !Text {
        const owned = try allocator.dupe(u8, text);
        return Text{ .data = owned };
    }

    pub fn deinit(self: *Text, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    pub fn len(self: Text) usize {
        return self.data.len;
    }

    pub fn upper(self: Text, allocator: std.mem.Allocator) !Text {
        var upper_text = try allocator.alloc(u8, self.data.len);
        for (self.data, 0..) |char, i| {
            upper_text[i] = std.ascii.toUpper(char);
        }
        return Text{ .data = upper_text };
    }

    pub fn lower(self: Text, allocator: std.mem.Allocator) !Text {
        var lower_text = try allocator.alloc(u8, self.data.len);
        for (self.data, 0..) |char, i| {
            lower_text[i] = std.ascii.toLower(char);
        }
        return Text{ .data = lower_text };
    }

    pub fn split(self: Text, allocator: std.mem.Allocator, delimiter: []const u8) !List {
        var result = List.init(allocator);
        var iterator = std.mem.split(u8, self.data, delimiter);

        while (iterator.next()) |part| {
            const part_value = MBLValue{ .text = try Text.init(allocator, part) };
            try result.append(part_value);
        }

        return result;
    }

    pub fn replace(self: Text, allocator: std.mem.Allocator, search: []const u8, replacement: []const u8) !Text {
        const result = try std.mem.replaceOwned(u8, allocator, self.data, search, replacement);
        return Text{ .data = result };
    }
};

pub const Number = struct {
    value: f64,

    pub fn init(value: f64) Number {
        return Number{ .value = value };
    }
};

pub const Boolean = struct {
    value: bool,

    pub fn init(value: bool) Boolean {
        return Boolean{ .value = value };
    }

    pub fn toNumber(self: Boolean) Number {
        return Number.init(if (self.value) 1.0 else 0.0);
    }
};

pub const Money = struct {
    value: i64, // Value in smallest currency unit (e.g., pennies)
    currency: []const u8,
    base: []const u8,
    conversion: f64, // Exchange rate to USD penny
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, value: i64, currency: []const u8, base: []const u8, conversion: f64) !Money {
        const owned_currency = try allocator.dupe(u8, currency);
        const owned_base = try allocator.dupe(u8, base);
        return Money{
            .value = value,
            .currency = owned_currency,
            .base = owned_base,
            .conversion = conversion,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Money) void {
        self.allocator.free(self.currency);
        self.allocator.free(self.base);
    }

    pub fn toDollars(self: Money) f64 {
        return @as(f64, @floatFromInt(self.value)) / 100.0; // Convert pennies to dollars
    }

    pub fn add(self: Money, other: Money) Money {
        return Money{
            .value = self.value + other.value,
            .currency = self.currency,
            .base = self.base,
            .conversion = self.conversion,
            .allocator = self.allocator,
        };
    }

    pub fn subtract(self: Money, other: Money) Money {
        return Money{
            .value = self.value - other.value,
            .currency = self.currency,
            .base = self.base,
            .conversion = self.conversion,
            .allocator = self.allocator,
        };
    }
};

pub const Time = struct {
    value: i64, // UNIX timestamp for absolute times, seconds for durations

    pub fn init(value: i64) Time {
        return Time{ .value = value };
    }

    pub fn now() Time {
        return Time{ .value = std.time.timestamp() };
    }

    pub fn add(self: Time, duration: Time) Time {
        return Time{ .value = self.value + duration.value };
    }

    pub fn subtract(self: Time, duration: Time) Time {
        return Time{ .value = self.value - duration.value };
    }

    // Computed fields would be implemented as methods
    pub fn year(self: Time) i32 {
        const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(self.value) };
        _ = epoch.getDaySeconds();
        const epoch_day = epoch.getEpochDay();
        const year_day = epoch_day.calculateYearDay();
        return year_day.year;
    }

    pub fn month(self: Time) u4 {
        const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(self.value) };
        const epoch_day = epoch.getEpochDay();
        const year_day = epoch_day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();
        return month_day.month.numeric();
    }

    pub fn day(self: Time) u5 {
        const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(self.value) };
        const epoch_day = epoch.getEpochDay();
        const year_day = epoch_day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();
        return month_day.day_index + 1;
    }
};

pub const Record = struct {
    data: std.HashMap([]const u8, MBLValue, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    super: ?*Record, // For inheritance
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Record {
        return Record{
            .data = std.HashMap([]const u8, MBLValue, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .super = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Record) void {
        var iterator = self.data.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.data.deinit();
    }

    pub fn set(self: *Record, key: []const u8, value: MBLValue) !void {
        const owned_key = try self.allocator.dupe(u8, key);
        try self.data.put(owned_key, value);
    }

    pub fn get(self: *Record, key: []const u8) ?MBLValue {
        if (self.data.get(key)) |value| {
            return value;
        }
        // Check inheritance chain
        if (self.super) |super_record| {
            return super_record.get(key);
        }
        return null;
    }

    pub fn has(self: *Record, key: []const u8) bool {
        return self.data.contains(key) or (self.super != null and self.super.?.has(key));
    }
};

pub const List = struct {
    data: std.ArrayList(MBLValue),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) List {
        return List{
            .data = std.ArrayList(MBLValue).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *List) void {
        for (self.data.items) |*item| {
            item.deinit(self.allocator);
        }
        self.data.deinit();
    }

    pub fn append(self: *List, value: MBLValue) !void {
        try self.data.append(value);
    }

    pub fn get(self: *List, index: usize) ?MBLValue {
        if (index < self.data.items.len) {
            return self.data.items[index];
        }
        return null;
    }

    pub fn set(self: *List, index: usize, value: MBLValue) !void {
        if (index >= self.data.items.len) {
            // Expand list with Nothing values if needed
            const old_len = self.data.items.len;
            try self.data.resize(index + 1);
            for (self.data.items[old_len..index]) |*item| {
                const nothing_text = try Text.init(self.allocator, "Nothing");
                item.* = MBLValue{ .text = nothing_text };
            }
        }
        self.data.items[index] = value;
    }

    pub fn len(self: *List) usize {
        return self.data.items.len;
    }
};

pub const Function = struct {
    name: []const u8,
    parameters: [][]const u8,
    body: *const anyopaque, // Opaque pointer to AST statements
    local_scope: Record,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, parameters: []const []const u8, body: *const anyopaque) !Function {
        const owned_name = try allocator.dupe(u8, name);
        var owned_params = try allocator.alloc([]const u8, parameters.len);
        for (parameters, 0..) |param, i| {
            owned_params[i] = try allocator.dupe(u8, param);
        }

        return Function{
            .name = owned_name,
            .parameters = owned_params,
            .body = body,
            .local_scope = Record.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Function) void {
        self.allocator.free(self.name);
        for (self.parameters) |param| {
            self.allocator.free(param);
        }
        self.allocator.free(self.parameters);
        self.local_scope.deinit();
    }

    pub fn call(self: *Function, args: []MBLValue) !MBLValue {
        // Bind parameters to arguments in local scope
        for (self.parameters, 0..) |param, i| {
            const arg_value = if (i < args.len) args[i] else blk: {
                const nothing_text = try Text.init(self.allocator, "Nothing");
                break :blk MBLValue{ .text = nothing_text };
            };
            try self.local_scope.set(param, arg_value);
        }

        // Execute function body would be handled by the interpreter
        // Return placeholder for now
        const result_text = try Text.init(self.allocator, "function_result");
        return MBLValue{ .text = result_text };
    }
};

pub const Activator = struct {
    name: []const u8,
    condition: *const anyopaque, // Opaque pointer to condition expression
    body: *const anyopaque, // Opaque pointer to AST statements
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, condition: *const anyopaque, body: *const anyopaque) !Activator {
        const owned_name = try allocator.dupe(u8, name);
        return Activator{
            .name = owned_name,
            .condition = condition,
            .body = body,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Activator) void {
        self.allocator.free(self.name);
        // Note: condition and body are owned by the parser, not duplicated here
    }

    pub fn shouldExecute(self: *Activator, interpreter: anytype) !bool {
        // This would evaluate the condition using the interpreter
        // Return false for now as placeholder
        _ = self;
        _ = interpreter;
        return false;
    }

    pub fn execute(self: *Activator, interpreter: anytype) !void {
        // This would execute the body using the interpreter
        _ = self;
        _ = interpreter;
    }
};

pub const MBLValue = union(enum) {
    text: Text,
    number: Number,
    boolean: Boolean,
    money: Money,
    time: Time,
    record: Record,
    list: List,
    function: Function,
    activator: Activator,

    pub fn deinit(self: *MBLValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .text => |*t| t.deinit(allocator),
            .number => {}, // No cleanup needed
            .boolean => {}, // No cleanup needed
            .money => |*m| m.deinit(),
            .time => {}, // No cleanup needed
            .record => |*r| r.deinit(),
            .list => |*l| l.deinit(),
            .function => |*f| f.deinit(),
            .activator => |*a| a.deinit(),
        }
    }

    pub fn toString(self: MBLValue, allocator: std.mem.Allocator) !Text {
        switch (self) {
            .text => |t| return Text.init(allocator, t.data),
            .number => |n| {
                const str = try std.fmt.allocPrint(allocator, "{d}", .{n.value});
                return Text{ .data = str };
            },
            .boolean => |b| {
                const str = if (b.value) "true" else "false";
                return Text.init(allocator, str);
            },
            .money => |m| {
                const str = try std.fmt.allocPrint(allocator, "${d:.2} {s}", .{ m.toDollars(), m.currency });
                return Text{ .data = str };
            },
            .time => |t| {
                const str = try std.fmt.allocPrint(allocator, "@{d}", .{t.value});
                return Text{ .data = str };
            },
            .record => {
                return Text.init(allocator, "[Record]");
            },
            .list => {
                return Text.init(allocator, "[List]");
            },
            .function => |f| {
                const str = try std.fmt.allocPrint(allocator, "[Function: {s}]", .{f.name});
                return Text{ .data = str };
            },
            .activator => |a| {
                const str = try std.fmt.allocPrint(allocator, "[Activator: {s}]", .{a.name});
                return Text{ .data = str };
            },
        }
    }

    pub fn isTruthy(self: MBLValue) bool {
        switch (self) {
            .text => |t| return t.data.len > 0 and !std.mem.eql(u8, t.data, "Nothing"),
            .number => |n| return n.value != 0.0,
            .boolean => |b| return b.value,
            .money => |m| return m.value != 0,
            .time => |t| return t.value != 0,
            .record, .list, .function, .activator => return true,
        }
    }

    pub fn equals(self: MBLValue, other: MBLValue) bool {
        switch (self) {
            .text => |t1| switch (other) {
                .text => |t2| return std.mem.eql(u8, t1.data, t2.data),
                else => return false,
            },
            .number => |n1| switch (other) {
                .number => |n2| return n1.value == n2.value,
                else => return false,
            },
            .boolean => |b1| switch (other) {
                .boolean => |b2| return b1.value == b2.value,
                else => return false,
            },
            .money => |m1| switch (other) {
                .money => |m2| return m1.value == m2.value and std.mem.eql(u8, m1.currency, m2.currency),
                else => return false,
            },
            .time => |t1| switch (other) {
                .time => |t2| return t1.value == t2.value,
                else => return false,
            },
            else => return false, // Records, lists, functions, activators need deep comparison
        }
    }
};

pub const Memory = struct {
    program: Record,
    activators: std.ArrayList(Activator),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Memory {
        return Memory{
            .program = Record.init(allocator),
            .activators = std.ArrayList(Activator).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Memory) void {
        self.program.deinit();
        for (self.activators.items) |*activator| {
            activator.deinit();
        }
        self.activators.deinit();
    }

    pub fn createText(self: *Memory, text: []const u8) !MBLValue {
        const text_obj = try Text.init(self.allocator, text);
        return MBLValue{ .text = text_obj };
    }

    pub fn createNumber(self: *Memory, value: f64) MBLValue {
        _ = self;
        return MBLValue{ .number = Number.init(value) };
    }

    pub fn createBoolean(self: *Memory, value: bool) MBLValue {
        _ = self;
        return MBLValue{ .boolean = Boolean.init(value) };
    }

    pub fn createMoney(self: *Memory, value: f64) !MBLValue {
        const money_obj = try Money.init(self.allocator, @as(i64, @intFromFloat(value * 100)), "USD", "penny", 1.0);
        return MBLValue{ .money = money_obj };
    }

    pub fn createTime(self: *Memory) MBLValue {
        _ = self;
        return MBLValue{ .time = Time.now() };
    }

    pub fn createRecord(self: *Memory) MBLValue {
        return MBLValue{ .record = Record.init(self.allocator) };
    }

    pub fn createList(self: *Memory) MBLValue {
        return MBLValue{ .list = List.init(self.allocator) };
    }

    pub fn getValue(self: *Memory, path: []const []const u8) !?MBLValue {
        var current: *Record = &self.program;

        for (path[0..path.len-1]) |segment| {
            if (current.get(segment)) |value| {
                switch (value) {
                    .record => |*record| current = @constCast(record),
                    else => return null, // Can't traverse non-record
                }
            } else {
                return null; // Path doesn't exist
            }
        }

        return current.get(path[path.len - 1]);
    }

    pub fn setValue(self: *Memory, path: []const []const u8, value: MBLValue) !void {
        var current: *Record = &self.program;

        // Navigate to the parent record
        for (path[0..path.len-1]) |segment| {
            if (current.get(segment)) |existing_value| {
                switch (existing_value) {
                    .record => |*record| current = @constCast(record),
                    else => return error.InvalidPath, // Can't traverse non-record
                }
            } else {
                // Create intermediate records as needed
                const new_record = Record.init(self.allocator);
                try current.set(segment, MBLValue{ .record = new_record });
                current = &@constCast(current.data.getPtr(segment).?).record;
            }
        }

        // Set the final value
        try current.set(path[path.len - 1], value);
    }
};

// ===== TESTS =====

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;

test "Text creation and manipulation" {
    const allocator = testing.allocator;

    // Test Text.init
    var text = try Text.init(allocator, "Hello World");
    defer text.deinit(allocator);

    try expectEqualStrings("Hello World", text.data);
    try expectEqual(@as(usize, 11), text.len());

    // Test Text.upper
    var upper_text = try text.upper(allocator);
    defer upper_text.deinit(allocator);
    try expectEqualStrings("HELLO WORLD", upper_text.data);

    // Test Text.lower
    var lower_text = try text.lower(allocator);
    defer lower_text.deinit(allocator);
    try expectEqualStrings("hello world", lower_text.data);

    // Test Text.split
    var split_text = try Text.init(allocator, "apple,banana,cherry");
    defer split_text.deinit(allocator);

    var split_list = try split_text.split(allocator, ",");
    defer split_list.deinit();

    try expectEqual(@as(usize, 3), split_list.len());

    const first_item = split_list.get(0).?;
    try expectEqualStrings("apple", first_item.text.data);

    // Test Text.replace
    var original = try Text.init(allocator, "Hello World");
    defer original.deinit(allocator);

    var replaced = try original.replace(allocator, "World", "Universe");
    defer replaced.deinit(allocator);
    try expectEqualStrings("Hello Universe", replaced.data);
}

test "Number operations" {
    const num1 = Number.init(42.5);
    const num2 = Number.init(-10.25);

    try expectEqual(@as(f64, 42.5), num1.value);
    try expectEqual(@as(f64, -10.25), num2.value);
}

test "Boolean operations" {
    const bool_true = Boolean.init(true);
    const bool_false = Boolean.init(false);

    try expect(bool_true.value);
    try expect(!bool_false.value);

    const true_as_num = bool_true.toNumber();
    const false_as_num = bool_false.toNumber();

    try expectEqual(@as(f64, 1.0), true_as_num.value);
    try expectEqual(@as(f64, 0.0), false_as_num.value);
}

test "Money operations" {
    const allocator = testing.allocator;

    var money1 = try Money.init(allocator, 125075, "USD", "penny", 1.0); // $1250.75 (pennies)
    defer money1.deinit();

    var money2 = try Money.init(allocator, 50000, "USD", "penny", 1.0);  // $500.00 (pennies)
    defer money2.deinit();

    try expectEqual(@as(i64, 125075), money1.value);
    try expectEqualStrings("USD", money1.currency);
    try expectEqual(@as(f64, 1250.75), money1.toDollars());

    const sum = money1.add(money2);
    try expectEqual(@as(i64, 175075), sum.value); // $1750.75 (pennies)

    const diff = money1.subtract(money2);
    try expectEqual(@as(i64, 75075), diff.value); // $750.75 (pennies)
}

test "Time operations" {
    const time1 = Time.init(1640995200); // 2022-01-01 00:00:00 UTC
    const duration = Time.init(3600); // 1 hour

    try expectEqual(@as(i64, 1640995200), time1.value);

    const later = time1.add(duration);
    try expectEqual(@as(i64, 1640998800), later.value); // 1 hour later

    const earlier = time1.subtract(duration);
    try expectEqual(@as(i64, 1640991600), earlier.value); // 1 hour earlier

    // Test current time
    const now = Time.now();
    try expect(now.value > 0);
}

test "Record operations" {
    const allocator = testing.allocator;

    var record = Record.init(allocator);
    defer record.deinit();

    // Test setting and getting values
    const text_value = MBLValue{ .text = try Text.init(allocator, "test") };
    const number_value = MBLValue{ .number = Number.init(42.0) };

    try record.set("name", text_value);
    try record.set("age", number_value);

    // Test retrieval
    const retrieved_name = record.get("name").?;
    const retrieved_age = record.get("age").?;

    try expectEqualStrings("test", retrieved_name.text.data);
    try expectEqual(@as(f64, 42.0), retrieved_age.number.value);

    // Test has method
    try expect(record.has("name"));
    try expect(record.has("age"));
    try expect(!record.has("nonexistent"));

    // Test non-existent key
    const missing = record.get("missing");
    try expect(missing == null);
}

test "Record inheritance" {
    const allocator = testing.allocator;

    var parent_record = Record.init(allocator);
    defer parent_record.deinit();

    var child_record = Record.init(allocator);
    defer child_record.deinit();
    child_record.super = &parent_record;

    // Set value in parent
    const parent_value = MBLValue{ .text = try Text.init(allocator, "parent") };
    try parent_record.set("inherited", parent_value);

    // Set value in child
    const child_value = MBLValue{ .text = try Text.init(allocator, "child") };
    try child_record.set("own", child_value);

    // Child should see both values
    try expect(child_record.has("inherited"));
    try expect(child_record.has("own"));

    const inherited = child_record.get("inherited").?;
    try expectEqualStrings("parent", inherited.text.data);
}

test "List operations" {
    const allocator = testing.allocator;

    var list = List.init(allocator);
    defer list.deinit();

    // Test appending values
    const value1 = MBLValue{ .number = Number.init(1.0) };
    const value2 = MBLValue{ .number = Number.init(2.0) };
    const value3 = MBLValue{ .number = Number.init(3.0) };

    try list.append(value1);
    try list.append(value2);
    try list.append(value3);

    try expectEqual(@as(usize, 3), list.len());

    // Test retrieval
    const first = list.get(0).?;
    const second = list.get(1).?;
    const third = list.get(2).?;

    try expectEqual(@as(f64, 1.0), first.number.value);
    try expectEqual(@as(f64, 2.0), second.number.value);
    try expectEqual(@as(f64, 3.0), third.number.value);

    // Test out of bounds
    const missing = list.get(10);
    try expect(missing == null);

    // Test setting at index
    const new_value = MBLValue{ .number = Number.init(99.0) };
    try list.set(1, new_value);

    const updated = list.get(1).?;
    try expectEqual(@as(f64, 99.0), updated.number.value);
}

test "List expansion" {
    const allocator = testing.allocator;

    var list = List.init(allocator);
    defer list.deinit();

    // Set value at index 5 when list is empty
    const value = MBLValue{ .number = Number.init(42.0) };
    try list.set(5, value);

    try expectEqual(@as(usize, 6), list.len());

    // Check that intermediate values are "Nothing"
    const intermediate = list.get(3).?;
    try expectEqualStrings("Nothing", intermediate.text.data);

    // Check that our value is at index 5
    const target = list.get(5).?;
    try expectEqual(@as(f64, 42.0), target.number.value);
}

test "Function creation and basic operations" {
    const allocator = testing.allocator;

    const params = [_][]const u8{ "x", "y" };
    const body = @as(*const anyopaque, @ptrCast(&params)); // Dummy body pointer

    var function = try Function.init(allocator, "add", params[0..], body);
    defer function.deinit();

    try expectEqualStrings("add", function.name);
    try expectEqual(@as(usize, 2), function.parameters.len);
    try expectEqualStrings("x", function.parameters[0]);
    try expectEqualStrings("y", function.parameters[1]);

    // Test function call placeholder
    const args = [_]MBLValue{
        MBLValue{ .number = Number.init(5.0) },
        MBLValue{ .number = Number.init(3.0) },
    };

    var result = try function.call(@constCast(&args));
    defer result.text.deinit(allocator);
    try expectEqualStrings("function_result", result.text.data);
}

test "Activator creation" {
    const allocator = testing.allocator;

    const condition = @as(*const anyopaque, @ptrCast(&allocator)); // Dummy condition
    const body = @as(*const anyopaque, @ptrCast(&allocator)); // Dummy body

    var activator = try Activator.init(allocator, "balance_check", condition, body);
    defer activator.deinit();

    try expectEqualStrings("balance_check", activator.name);

    // Test placeholder methods
    const should_execute = try activator.shouldExecute(undefined);
    try expect(!should_execute);
}

test "MBLValue toString conversion" {
    const allocator = testing.allocator;

    // Test text
    var text_val = MBLValue{ .text = try Text.init(allocator, "hello") };
    defer text_val.text.deinit(allocator);
    var text_str = try text_val.toString(allocator);
    defer text_str.deinit(allocator);
    try expectEqualStrings("hello", text_str.data);

    // Test number
    const num_val = MBLValue{ .number = Number.init(42.5) };
    var num_str = try num_val.toString(allocator);
    defer num_str.deinit(allocator);
    try expectEqualStrings("42.5", num_str.data);

    // Test boolean
    const bool_val = MBLValue{ .boolean = Boolean.init(true) };
    var bool_str = try bool_val.toString(allocator);
    defer bool_str.deinit(allocator);
    try expectEqualStrings("true", bool_str.data);

    // Test money
    var money_val = MBLValue{ .money = try Money.init(allocator, 125075, "USD", "penny", 1.0) };
    defer money_val.money.deinit();
    var money_str = try money_val.toString(allocator);
    defer money_str.deinit(allocator);
    // Should be something like "$1250.75 USD"
    try expect(std.mem.indexOf(u8, money_str.data, "$1250.75") != null);
    try expect(std.mem.indexOf(u8, money_str.data, "USD") != null);
}

test "MBLValue isTruthy" {
    const allocator = testing.allocator;

    // Test text truthy values
    const text_true = MBLValue{ .text = try Text.init(allocator, "hello") };
    const text_false = MBLValue{ .text = try Text.init(allocator, "") };
    const text_nothing = MBLValue{ .text = try Text.init(allocator, "Nothing") };

    try expect(text_true.isTruthy());
    try expect(!text_false.isTruthy());
    try expect(!text_nothing.isTruthy());

    @constCast(&text_true.text).deinit(allocator);
    @constCast(&text_false.text).deinit(allocator);
    @constCast(&text_nothing.text).deinit(allocator);

    // Test number truthy values
    const num_true = MBLValue{ .number = Number.init(42.0) };
    const num_false = MBLValue{ .number = Number.init(0.0) };

    try expect(num_true.isTruthy());
    try expect(!num_false.isTruthy());

    // Test boolean truthy values
    const bool_true = MBLValue{ .boolean = Boolean.init(true) };
    const bool_false = MBLValue{ .boolean = Boolean.init(false) };

    try expect(bool_true.isTruthy());
    try expect(!bool_false.isTruthy());

    // Test money truthy values
    var money_true = MBLValue{ .money = try Money.init(allocator, 100, "USD", "penny", 1.0) };
    defer money_true.money.deinit();
    var money_false = MBLValue{ .money = try Money.init(allocator, 0, "USD", "penny", 1.0) };
    defer money_false.money.deinit();

    try expect(money_true.isTruthy());
    try expect(!money_false.isTruthy());
}

test "MBLValue equals comparison" {
    const allocator = testing.allocator;

    // Test text equality
    const text1 = MBLValue{ .text = try Text.init(allocator, "hello") };
    const text2 = MBLValue{ .text = try Text.init(allocator, "hello") };
    const text3 = MBLValue{ .text = try Text.init(allocator, "world") };

    try expect(text1.equals(text2));
    try expect(!text1.equals(text3));

    @constCast(&text1.text).deinit(allocator);
    @constCast(&text2.text).deinit(allocator);
    @constCast(&text3.text).deinit(allocator);

    // Test number equality
    const num1 = MBLValue{ .number = Number.init(42.0) };
    const num2 = MBLValue{ .number = Number.init(42.0) };
    const num3 = MBLValue{ .number = Number.init(24.0) };

    try expect(num1.equals(num2));
    try expect(!num1.equals(num3));

    // Test boolean equality
    const bool1 = MBLValue{ .boolean = Boolean.init(true) };
    const bool2 = MBLValue{ .boolean = Boolean.init(true) };
    const bool3 = MBLValue{ .boolean = Boolean.init(false) };

    try expect(bool1.equals(bool2));
    try expect(!bool1.equals(bool3));

    // Test cross-type inequality
    var text_for_cross_test = MBLValue{ .text = try Text.init(allocator, "test") };
    defer text_for_cross_test.text.deinit(allocator);
    try expect(!text_for_cross_test.equals(num1));
    try expect(!num1.equals(bool1));
}

test "Memory system initialization" {
    const allocator = testing.allocator;

    var memory = Memory.init(allocator);
    defer memory.deinit();

    try expectEqual(@as(usize, 0), memory.activators.items.len);
}

test "Memory factory methods" {
    const allocator = testing.allocator;

    var memory = Memory.init(allocator);
    defer memory.deinit();

    // Test createText
    var text_val = try memory.createText("hello");
    defer text_val.deinit(allocator);
    try expectEqualStrings("hello", text_val.text.data);

    // Test createNumber
    const num_val = memory.createNumber(42.5);
    try expectEqual(@as(f64, 42.5), num_val.number.value);

    // Test createBoolean
    const bool_val = memory.createBoolean(true);
    try expect(bool_val.boolean.value);

    // Test createMoney
    var money_val = try memory.createMoney(1250.75);
    defer money_val.money.deinit();
    try expectEqual(@as(f64, 1250.75), money_val.money.toDollars());

    // Test createTime
    const time_val = memory.createTime();
    try expect(time_val.time.value > 0);

    // Test createRecord
    var record_val = memory.createRecord();
    defer record_val.record.deinit();
    try expect(record_val.record.data.count() == 0);

    // Test createList
    var list_val = memory.createList();
    defer list_val.list.deinit();
    try expectEqual(@as(usize, 0), list_val.list.len());
}

test "Memory path-based value access" {
    const allocator = testing.allocator;

    var memory = Memory.init(allocator);
    defer memory.deinit();

    // Test simple setValue and getValue
    const simple_path = [_][]const u8{"test_var"};
    const test_value = try memory.createText("test_data");

    try memory.setValue(&simple_path, test_value);

    const retrieved = try memory.getValue(&simple_path);
    try expect(retrieved != null);
    try expectEqualStrings("test_data", retrieved.?.text.data);

    // Test nested path creation
    const nested_path = [_][]const u8{ "user", "profile", "name" };
    const nested_value = try memory.createText("John Doe");

    try memory.setValue(&nested_path, nested_value);

    const nested_retrieved = try memory.getValue(&nested_path);
    try expect(nested_retrieved != null);
    try expectEqualStrings("John Doe", nested_retrieved.?.text.data);

    // Test intermediate record creation
    const user_path = [_][]const u8{"user"};
    const user_record = try memory.getValue(&user_path);
    try expect(user_record != null);
    try expect(user_record.?.record.data.count() > 0);

    // Test non-existent path
    const missing_path = [_][]const u8{ "nonexistent", "path" };
    const missing = try memory.getValue(&missing_path);
    try expect(missing == null);
}

test "Memory system comprehensive workflow" {
    const allocator = testing.allocator;

    var memory = Memory.init(allocator);
    defer memory.deinit();

    // Create a complex data structure
    const customer_path = [_][]const u8{ "customers", "12345" };
    var customer_record = memory.createRecord();

    // Add customer data
    try customer_record.record.set("name", try memory.createText("Alice Smith"));
    try customer_record.record.set("age", memory.createNumber(30));
    try customer_record.record.set("balance", try memory.createMoney(2500.50));
    try customer_record.record.set("active", memory.createBoolean(true));

    // Store in memory
    try memory.setValue(&customer_path, customer_record);

    // Retrieve and verify
    var retrieved_customer = try memory.getValue(&customer_path);
    try expect(retrieved_customer != null);

    const name = retrieved_customer.?.record.get("name").?;
    const age = retrieved_customer.?.record.get("age").?;
    const balance = retrieved_customer.?.record.get("balance").?;
    const active = retrieved_customer.?.record.get("active").?;

    try expectEqualStrings("Alice Smith", name.text.data);
    try expectEqual(@as(f64, 30.0), age.number.value);
    try expectEqual(@as(f64, 2500.50), balance.money.toDollars());
    try expect(active.boolean.value);

    // Test path traversal
    const name_path = [_][]const u8{ "customers", "12345", "name" };
    const direct_name = try memory.getValue(&name_path);
    try expect(direct_name != null);
    try expectEqualStrings("Alice Smith", direct_name.?.text.data);
}