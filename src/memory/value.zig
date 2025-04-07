const std = @import("std");

pub const ValueType = enum {
    number,
    text,
    money,
    time,
    date,
    date_time,  // Combined date and time value
    percentage,
    ratio,
    boolean,
    unknown,
    nil,
    list,      // Dynamic array that can hold mixed values
    record,    // Key-value collection with inheritance support
    function,  // Function with parameters and code
    trigger,   // Event-based trigger with condition and actions
    constraint, // Immediate validation with optional healing
};

pub const List = struct {
    items: std.ArrayList(*Value),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) List {
        return .{
            .items = std.ArrayList(*Value).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *List) void {
        // We don't free the Value items here; that's the MemoryManager's job
        self.items.deinit();
    }
    
    pub fn length(self: List) usize {
        return self.items.items.len;
    }
    
    pub fn push(self: *List, item: *Value) !void {
        try self.items.append(item);
    }
    
    pub fn pop(self: *List) ?*Value {
        if (self.items.items.len == 0) return null;
        return self.items.pop();
    }
    
    pub fn get(self: List, index: usize) ?*Value {
        if (index >= self.items.items.len) return null;
        return self.items.items[index];
    }
    
    pub fn set(self: *List, index: usize, value: *Value) !void {
        if (index >= self.items.items.len) return error.IndexOutOfBounds;
        self.items.items[index] = value;
    }
    
    // Returns a new list with elements from start to start+length
    pub fn slice(self: List, start_idx: usize, slice_len: usize) !List {
        var result = List.init(self.allocator);
        errdefer result.deinit();
        
        const end = @min(start_idx + slice_len, self.items.items.len);
        if (start_idx >= self.items.items.len) return result;
        
        try result.items.appendSlice(self.items.items[start_idx..end]);
        return result;
    }
    
    // Removes elements from start to start+length, and optionally inserts new elements
    pub fn splice(self: *List, start_idx: usize, remove_len: usize, new_items: ?[]const *Value) !void {
        if (start_idx >= self.items.items.len) return error.IndexOutOfBounds;
        
        const end = @min(start_idx + remove_len, self.items.items.len);
        const remove_count = end - start_idx;
        
        // Remove items
        if (remove_count > 0) {
            // Shift remaining items to fill the gap
            const items_after = self.items.items.len - end;
            for (0..items_after) |i| {
                self.items.items[start_idx + i] = self.items.items[end + i];
            }
            
            // Truncate the list
            self.items.shrinkRetainingCapacity(self.items.items.len - remove_count);
        }
        
        // Insert new items if provided
        if (new_items) |items| {
            // First, make room for the new items
            try self.items.ensureUnusedCapacity(items.len);
            try self.items.resize(self.items.items.len + items.len);
            
            // Shift existing items to make room
            const items_to_shift = self.items.items.len - items.len - start_idx;
            for (0..items_to_shift) |i| {
                const index = items_to_shift - i - 1;
                self.items.items[start_idx + items.len + index] = self.items.items[start_idx + index];
            }
            
            // Insert the new items
            for (items, 0..) |item, i| {
                self.items.items[start_idx + i] = item;
            }
        }
    }
    
    pub fn format(
        self: List,
        comptime fmt_str: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt_str;
        _ = options;
        try writer.writeAll("[");
        
        for (self.items.items, 0..) |item, i| {
            if (i > 0) try writer.writeAll(", ");
            try std.fmt.format(writer, "{any}", .{item.*});
        }
        
        try writer.writeAll("]");
    }
};

pub const Record = struct {
    fields: std.StringHashMap(*Value),
    parent: ?*Value,  // For inheritance
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Record {
        return .{
            .fields = std.StringHashMap(*Value).init(allocator),
            .parent = null,
            .allocator = allocator,
        };
    }
    
    pub fn initWithParent(allocator: std.mem.Allocator, parent: *Value) !Record {
        if (parent.data != .record) return error.InvalidParent;
        
        return .{
            .fields = std.StringHashMap(*Value).init(allocator),
            .parent = parent,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Record) void {
        // We need to free all the keys which were allocated
        var key_it = self.fields.keyIterator();
        while (key_it.next()) |key| {
            self.allocator.free(key.*);
        }
        
        // Then deinit the HashMap itself
        self.fields.deinit();
    }
    
    pub fn set(self: *Record, key: []const u8, value: *Value) !void {
        // If it's a new field, we need to duplicate the key string since the hashmap doesn't take ownership
        const gop = try self.fields.getOrPut(key);
        if (!gop.found_existing) {
            const dupe_key = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(dupe_key);
            gop.key_ptr.* = dupe_key;
        }
        gop.value_ptr.* = value;
    }
    
    // Get a field, checking in parent records if needed
    pub fn get(self: Record, key: []const u8) ?*Value {
        // First check in this record
        if (self.fields.get(key)) |value| {
            return value;
        }
        
        // If not found and has parent, check parent
        if (self.parent) |parent| {
            if (parent.data == .record) {
                return parent.data.record.get(key);
            }
        }
        
        return null;
    }
    
    // Get only from this record's own fields (no parent lookup)
    pub fn getOwn(self: Record, key: []const u8) ?*Value {
        return self.fields.get(key);
    }
    
    // Remove a field
    pub fn remove(self: *Record, key: []const u8) bool {
        if (self.fields.getKey(key)) |owned_key| {
            if (self.fields.remove(key)) {
                // Free the duplicated key
                self.allocator.free(owned_key);
                return true;
            }
        }
        return false;
    }
    
    // Get all keys in this record (not including parent)
    pub fn keys(self: Record) !std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).init(self.allocator);
        errdefer result.deinit();
        
        var iter = self.fields.keyIterator();
        while (iter.next()) |key| {
            try result.append(key.*);
        }
        
        return result;
    }
    
    // Create a deep copy of this record
    pub fn copy(self: Record, allocator: std.mem.Allocator) !Record {
        var new_record = Record.init(allocator);
        errdefer new_record.deinit();
        
        // Copy parent reference if it exists
        if (self.parent) |parent| {
            new_record.parent = parent;
        }
        
        // Deep copy all fields
        var iter = self.fields.iterator();
        while (iter.next()) |entry| {
            // For now we're just copying the reference to the value
            // A true deep copy would require duplicating the values too
            try new_record.set(entry.key_ptr.*, entry.value_ptr.*);
        }
        
        return new_record;
    }
    
    pub fn format(
        self: Record,
        comptime fmt_str: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt_str;
        _ = options;
        
        try writer.writeAll("{ ");
        
        var iter = self.fields.iterator();
        var first = true;
        while (iter.next()) |entry| {
            if (!first) {
                try writer.writeAll(", ");
            }
            first = false;
            
            try writer.print("{s}: ", .{entry.key_ptr.*});
            try std.fmt.format(writer, "{any}", .{entry.value_ptr.*.*});
        }
        
        if (self.parent) |parent| {
            if (!first) {
                try writer.writeAll(", ");
            }
            try writer.writeAll("$parent: ");
            try std.fmt.format(writer, "{any}", .{parent.*});
        }
        
        try writer.writeAll(" }");
    }
};

pub const Money = struct {
    // Amount stored as integer with 4 digits below lowest denomination
    // e.g., $1.00 USD = 1_0000, $0.01 USD = 100, $0.0001 USD = 1
    amount: i128,
    currency: []const u8,
    currency_owned: bool = false,

    pub fn init(amount: i128, currency: []const u8) Money {
        return .{
            .amount = amount,
            .currency = currency,
            .currency_owned = false,
        };
    }
    
    // Create from dollars and cents
    pub fn initFromDecimal(dollars: i64, cents: i64, currency: []const u8) Money {
        const total = dollars * 10000 + cents * 100;
        return .{
            .amount = total,
            .currency = currency,
            .currency_owned = false,
        };
    }
    
    pub fn initOwned(allocator: std.mem.Allocator, amount: i128, currency: []const u8) !Money {
        const owned_currency = try allocator.dupe(u8, currency);
        return .{
            .amount = amount,
            .currency = owned_currency,
            .currency_owned = true,
        };
    }
    
    // Get the whole units (e.g., dollars)
    pub fn wholeUnits(self: Money) i64 {
        return @intCast(@divTrunc(self.amount, 10000));
    }
    
    // Get the fractional units (e.g., cents)
    pub fn fractionalUnits(self: Money) i64 {
        return @intCast(@divTrunc(@mod(self.amount, 10000), 100));
    }

    pub fn format(
        self: Money,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const whole = self.wholeUnits();
        const fractional = self.fractionalUnits();
        try writer.print("{d}.{d:0>2} {s}", .{ whole, fractional, self.currency });
    }
};

pub const Time = struct {
    hours: u8,
    minutes: u8,
    seconds: u8,
    milliseconds: u16,

    pub fn init(hours: u8, minutes: u8, seconds: u8, milliseconds: u16) Time {
        return .{
            .hours = hours,
            .minutes = minutes,
            .seconds = seconds,
            .milliseconds = milliseconds,
        };
    }
    
    // Parse a time from a string in the format HH:MM:SS or HH:MM:SS.mmm
    pub fn parse(str: []const u8) !Time {
        // Validate minimal input format (HH:MM:SS)
        if (str.len < 8 or str[2] != ':' or str[5] != ':') {
            return error.InvalidFormat;
        }
        
        // Parse hours
        const hours = std.fmt.parseInt(u8, str[0..2], 10) catch return error.InvalidFormat;
        if (hours > 23) return error.InvalidHours;
        
        // Parse minutes
        const minutes = std.fmt.parseInt(u8, str[3..5], 10) catch return error.InvalidFormat;
        if (minutes > 59) return error.InvalidMinutes;
        
        // Parse seconds
        const seconds = std.fmt.parseInt(u8, str[6..8], 10) catch return error.InvalidFormat;
        if (seconds > 59) return error.InvalidSeconds;
        
        // Parse milliseconds if present
        var milliseconds: u16 = 0;
        if (str.len > 9 and str[8] == '.') {
            if (str.len < 12) {
                // Need at least 3 digits for milliseconds
                return error.InvalidFormat;
            }
            
            milliseconds = std.fmt.parseInt(u16, str[9..12], 10) catch return error.InvalidFormat;
        }
        
        return Time.init(hours, minutes, seconds, milliseconds);
    }

    pub fn format(
        self: Time,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}", .{
            self.hours,
            self.minutes,
            self.seconds,
            self.milliseconds,
        });
    }
};

pub const DayOfWeek = enum(u3) {
    sunday = 0,
    monday = 1,
    tuesday = 2,
    wednesday = 3,
    thursday = 4,
    friday = 5,
    saturday = 6,
    
    pub fn fromString(s: []const u8) ?DayOfWeek {
        const lowercase = std.ascii.allocLowerString(std.heap.page_allocator, s) catch return null;
        defer std.heap.page_allocator.free(lowercase);
        
        const day = if (std.mem.eql(u8, lowercase, "sunday") or std.mem.eql(u8, lowercase, "sun")) 
            DayOfWeek.sunday
        else if (std.mem.eql(u8, lowercase, "monday") or std.mem.eql(u8, lowercase, "mon"))
            DayOfWeek.monday
        else if (std.mem.eql(u8, lowercase, "tuesday") or std.mem.eql(u8, lowercase, "tue"))
            DayOfWeek.tuesday
        else if (std.mem.eql(u8, lowercase, "wednesday") or std.mem.eql(u8, lowercase, "wed"))
            DayOfWeek.wednesday
        else if (std.mem.eql(u8, lowercase, "thursday") or std.mem.eql(u8, lowercase, "thu"))
            DayOfWeek.thursday
        else if (std.mem.eql(u8, lowercase, "friday") or std.mem.eql(u8, lowercase, "fri"))
            DayOfWeek.friday
        else if (std.mem.eql(u8, lowercase, "saturday") or std.mem.eql(u8, lowercase, "sat"))
            DayOfWeek.saturday
        else
            return null;
            
        return day;
    }
    
    pub fn toString(self: DayOfWeek) []const u8 {
        return switch (self) {
            .sunday => "Sunday",
            .monday => "Monday",
            .tuesday => "Tuesday",
            .wednesday => "Wednesday",
            .thursday => "Thursday",
            .friday => "Friday",
            .saturday => "Saturday",
        };
    }
};

pub const Date = struct {
    year: i32,
    month: u8,
    day: u8,

    pub fn init(year: i32, month: u8, day: u8) Date {
        return .{
            .year = year,
            .month = month,
            .day = day,
        };
    }
    
    // Parse a date from a string in the format YYYY-MM-DD
    pub fn parse(str: []const u8) !Date {
        // Validate input format
        if (str.len < 10 or str[4] != '-' or str[7] != '-') {
            return error.InvalidFormat;
        }
        
        // Parse year
        const year = std.fmt.parseInt(i32, str[0..4], 10) catch return error.InvalidFormat;
        
        // Parse month
        const month = std.fmt.parseInt(u8, str[5..7], 10) catch return error.InvalidFormat;
        if (month < 1 or month > 12) return error.InvalidMonth;
        
        // Parse day
        const day = std.fmt.parseInt(u8, str[8..10], 10) catch return error.InvalidFormat;
        const max_days = daysInMonth(year, month);
        if (day < 1 or day > max_days) return error.InvalidDay;
        
        return Date.init(year, month, day);
    }
    
    // Returns the day of the week for this date
    pub fn dayOfWeek(self: Date) DayOfWeek {
        // Use Zeller's Congruence algorithm to determine the day of the week
        var m = self.month;
        var y = self.year;
        
        // Adjust month and year for January and February
        if (m <= 2) {
            m += 12;
            y -= 1;
        }
        
        const K = @mod(y, 100); // Year of the century
        const J = @divTrunc(y, 100); // Century
        
        // Zeller's Congruence formula
        const h = @mod(self.day + @divTrunc((13 * (m + 1)), 5) + K + @divTrunc(K, 4) + @divTrunc(J, 4) - (2 * J), 7);
        
        // Convert h to DayOfWeek enum (0 = Saturday in Zeller's Congruence)
        return @enumFromInt(@mod(h + 6, 7));
    }
    
    // Get the next date after this one
    pub fn next(self: Date) Date {
        var new_date = self;
        new_date.day += 1;
        
        // Check if we need to roll over to next month
        if (new_date.day > daysInMonth(new_date.year, new_date.month)) {
            new_date.day = 1;
            new_date.month += 1;
            
            // Check if we need to roll over to next year
            if (new_date.month > 12) {
                new_date.month = 1;
                new_date.year += 1;
            }
        }
        
        return new_date;
    }
    
    // Get the previous date before this one
    pub fn previous(self: Date) Date {
        var new_date = self;
        
        if (new_date.day > 1) {
            new_date.day -= 1;
        } else {
            // Roll back to previous month
            if (new_date.month > 1) {
                new_date.month -= 1;
            } else {
                // Roll back to previous year
                new_date.month = 12;
                new_date.year -= 1;
            }
            
            // Set day to last day of the month
            new_date.day = daysInMonth(new_date.year, new_date.month);
        }
        
        return new_date;
    }
    
    // Finds the next occurrence of the specified day of the week after this date
    pub fn nextDayOfWeek(self: Date, day: DayOfWeek) Date {
        var date = self;
        // Make sure we start from tomorrow to avoid returning today if it's already the target day
        date = date.next();
        
        while (date.dayOfWeek() != day) {
            date = date.next();
        }
        
        return date;
    }
    
    // Finds the previous occurrence of the specified day of the week before this date
    pub fn previousDayOfWeek(self: Date, day: DayOfWeek) Date {
        var date = self;
        // Make sure we start from yesterday to avoid returning today if it's already the target day
        date = date.previous();
        
        while (date.dayOfWeek() != day) {
            date = date.previous();
        }
        
        return date;
    }
    
    // Add a specific number of days to this date
    pub fn addDays(self: Date, days: i32) Date {
        var result = self;
        
        if (days >= 0) {
            var i: i32 = 0;
            while (i < days) : (i += 1) {
                result = result.next();
            }
        } else {
            var i: i32 = 0;
            while (i > days) : (i -= 1) {
                result = result.previous();
            }
        }
        
        return result;
    }
    
    // Add a specific number of months to this date
    pub fn addMonths(self: Date, months: i32) Date {
        var year = self.year;
        var month = self.month;
        
        if (months >= 0) {
            month += @as(u8, @intCast(months % 12));
            if (month > 12) {
                month -= 12;
                year += 1;
            }
            year += @divTrunc(months, 12);
        } else {
            const abs_months = -months;
            month -= @as(u8, @intCast(abs_months % 12));
            if (month < 1) {
                month += 12;
                year -= 1;
            }
            year -= @divTrunc(abs_months, 12);
        }
        
        // Make sure day is valid for the new month
        const max_days = daysInMonth(year, month);
        const day = if (self.day > max_days) max_days else self.day;
        
        return Date.init(year, month, day);
    }
    
    // Add a specific number of years to this date
    pub fn addYears(self: Date, years: i32) Date {
        const year = self.year + years;
        
        // Make sure February 29 in a leap year is handled when the target year is not a leap year
        var day = self.day;
        if (self.month == 2 and self.day == 29 and !isLeapYear(year)) {
            day = 28;
        }
        
        return Date.init(year, self.month, day);
    }
    
    // Check if two dates are equal
    pub fn equals(self: Date, other: Date) bool {
        return self.year == other.year and self.month == other.month and self.day == other.day;
    }
    
    // Compare two dates
    pub fn compare(self: Date, other: Date) i8 {
        if (self.year < other.year) return -1;
        if (self.year > other.year) return 1;
        
        if (self.month < other.month) return -1;
        if (self.month > other.month) return 1;
        
        if (self.day < other.day) return -1;
        if (self.day > other.day) return 1;
        
        return 0;
    }

    pub fn format(
        self: Date,
        comptime fmt_str: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        
        if (fmt_str.len > 0 and fmt_str[0] == 'l') {
            // Long format with day of week
            const day_name = self.dayOfWeek().toString();
            try writer.print("{s}, {d:0>4}-{d:0>2}-{d:0>2}", .{
                day_name,
                self.year,
                self.month,
                self.day,
            });
        } else {
            // Standard ISO format
            try writer.print("{d:0>4}-{d:0>2}-{d:0>2}", .{
                self.year,
                self.month,
                self.day,
            });
        }
    }
};

// Helper functions for date calculations

// Returns the number of days in a month, accounting for leap years
pub fn daysInMonth(year: i32, month: u8) u8 {
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (isLeapYear(year)) 29 else 28,
        else => unreachable,
    };
}

// Check if a year is a leap year
pub fn isLeapYear(year: i32) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}

// Source position tracking for error reporting and debugging
pub const SourcePosition = struct {
    file: ?[]const u8,  // Optional file name
    line: usize,        // Line number (1-based)
    column: usize,      // Column number (1-based)
    
    pub fn init(file: ?[]const u8, line: usize, column: usize) SourcePosition {
        return .{
            .file = file,
            .line = line,
            .column = column,
        };
    }
    
    pub fn unknown() SourcePosition {
        return .{
            .file = null,
            .line = 0,
            .column = 0,
        };
    }
};

// Operator types used in expressions
pub const OperatorType = enum {
    // Arithmetic
    add, subtract, multiply, divide, modulo, 
    // Comparison
    eq, neq, lt, lte, gt, gte,
    // Logical
    logical_and, logical_or, not,
    // Assignment
    assign,
    // Other
    member_access, index,
};

// Types of AST nodes
pub const AstNodeType = enum {
    // Literals
    number_literal,
    text_literal,
    boolean_literal,
    nil_literal,
    
    // Complex literals
    money_literal,
    date_literal,
    time_literal,
    datetime_literal,
    list_literal,
    record_literal,
    
    // Identifiers and operations
    identifier,
    binary_expression,
    unary_expression,
    member_access,
    index_expression,
    call_expression,
    
    // Statements
    block,
    expression_stmt,
    variable_declaration,
    if_stmt,
    for_stmt,
    while_stmt,
    return_stmt,
    
    // Definitions
    function_def,
    parameter_def,
};

// The main AST node structure
pub const AstNode = struct {
    node_type: AstNodeType,
    pos: SourcePosition,
    data: union(AstNodeType) {
        // Literals
        number_literal: f64,
        text_literal: []const u8,
        boolean_literal: bool,
        nil_literal: void,
        
        // Complex literals
        money_literal: Money,
        date_literal: Date,
        time_literal: Time,
        datetime_literal: DateTime,
        list_literal: []const *AstNode,
        record_literal: struct {
            keys: []const []const u8,
            values: []const *AstNode,
        },
        
        // Identifiers and operations
        identifier: []const u8,
        binary_expression: struct {
            left: *AstNode,
            operator: OperatorType,
            right: *AstNode,
        },
        unary_expression: struct {
            operator: OperatorType,
            operand: *AstNode,
        },
        member_access: struct {
            object: *AstNode,
            member: []const u8,
        },
        index_expression: struct {
            array: *AstNode,
            index: *AstNode,
        },
        call_expression: struct {
            callee: *AstNode,
            arguments: []const *AstNode,
        },
        
        // Statements
        block: []const *AstNode,
        expression_stmt: *AstNode,
        variable_declaration: struct {
            name: []const u8,
            initial_value: ?*AstNode,
        },
        if_stmt: struct {
            condition: *AstNode,
            then_branch: *AstNode,
            else_branch: ?*AstNode,
        },
        for_stmt: struct {
            init: ?*AstNode,
            condition: ?*AstNode,
            update: ?*AstNode,
            body: *AstNode,
        },
        while_stmt: struct {
            condition: *AstNode,
            body: *AstNode,
        },
        return_stmt: ?*AstNode,
        
        // Definitions
        function_def: struct {
            name: []const u8,
            parameters: []const *AstNode,
            body: *AstNode,
        },
        parameter_def: struct {
            name: []const u8,
            type_name: ?[]const u8,
        },
    },
    
    pub fn deinit(self: *AstNode, allocator: std.mem.Allocator) void {
        switch (self.node_type) {
            .text_literal => allocator.free(self.data.text_literal),
            .identifier => allocator.free(self.data.identifier),
            .list_literal => {
                for (self.data.list_literal) |node| {
                    node.deinit(allocator);
                    allocator.destroy(node);
                }
                allocator.free(self.data.list_literal);
            },
            .record_literal => {
                for (self.data.record_literal.keys) |key| {
                    allocator.free(key);
                }
                for (self.data.record_literal.values) |node| {
                    node.deinit(allocator);
                    allocator.destroy(node);
                }
                allocator.free(self.data.record_literal.keys);
                allocator.free(self.data.record_literal.values);
            },
            .binary_expression => {
                self.data.binary_expression.left.deinit(allocator);
                self.data.binary_expression.right.deinit(allocator);
                allocator.destroy(self.data.binary_expression.left);
                allocator.destroy(self.data.binary_expression.right);
            },
            .unary_expression => {
                self.data.unary_expression.operand.deinit(allocator);
                allocator.destroy(self.data.unary_expression.operand);
            },
            .member_access => {
                allocator.free(self.data.member_access.member);
                self.data.member_access.object.deinit(allocator);
                allocator.destroy(self.data.member_access.object);
            },
            .index_expression => {
                self.data.index_expression.array.deinit(allocator);
                self.data.index_expression.index.deinit(allocator);
                allocator.destroy(self.data.index_expression.array);
                allocator.destroy(self.data.index_expression.index);
            },
            .call_expression => {
                self.data.call_expression.callee.deinit(allocator);
                allocator.destroy(self.data.call_expression.callee);
                for (self.data.call_expression.arguments) |arg| {
                    arg.deinit(allocator);
                    allocator.destroy(arg);
                }
                allocator.free(self.data.call_expression.arguments);
            },
            .block => {
                for (self.data.block) |node| {
                    node.deinit(allocator);
                    allocator.destroy(node);
                }
                allocator.free(self.data.block);
            },
            .expression_stmt => {
                self.data.expression_stmt.deinit(allocator);
                allocator.destroy(self.data.expression_stmt);
            },
            .variable_declaration => {
                allocator.free(self.data.variable_declaration.name);
                if (self.data.variable_declaration.initial_value) |init| {
                    init.deinit(allocator);
                    allocator.destroy(init);
                }
            },
            .if_stmt => {
                self.data.if_stmt.condition.deinit(allocator);
                allocator.destroy(self.data.if_stmt.condition);
                self.data.if_stmt.then_branch.deinit(allocator);
                allocator.destroy(self.data.if_stmt.then_branch);
                if (self.data.if_stmt.else_branch) |else_branch| {
                    else_branch.deinit(allocator);
                    allocator.destroy(else_branch);
                }
            },
            .for_stmt => {
                if (self.data.for_stmt.init) |init| {
                    init.deinit(allocator);
                    allocator.destroy(init);
                }
                if (self.data.for_stmt.condition) |cond| {
                    cond.deinit(allocator);
                    allocator.destroy(cond);
                }
                if (self.data.for_stmt.update) |update| {
                    update.deinit(allocator);
                    allocator.destroy(update);
                }
                self.data.for_stmt.body.deinit(allocator);
                allocator.destroy(self.data.for_stmt.body);
            },
            .while_stmt => {
                self.data.while_stmt.condition.deinit(allocator);
                allocator.destroy(self.data.while_stmt.condition);
                self.data.while_stmt.body.deinit(allocator);
                allocator.destroy(self.data.while_stmt.body);
            },
            .return_stmt => {
                if (self.data.return_stmt) |ret_val| {
                    ret_val.deinit(allocator);
                    allocator.destroy(ret_val);
                }
            },
            .function_def => {
                allocator.free(self.data.function_def.name);
                for (self.data.function_def.parameters) |param| {
                    param.deinit(allocator);
                    allocator.destroy(param);
                }
                allocator.free(self.data.function_def.parameters);
                self.data.function_def.body.deinit(allocator);
                allocator.destroy(self.data.function_def.body);
            },
            .parameter_def => {
                allocator.free(self.data.parameter_def.name);
                if (self.data.parameter_def.type_name) |type_name| {
                    allocator.free(type_name);
                }
            },
            // The rest don't have allocations to free
            else => {},
        }
    }
};

// Runtime error codes
pub const RuntimeError = error{
    UndefinedVariable,
    TypeMismatch,
    InvalidOperator,
    DivisionByZero,
    InvalidArguments,
    InvalidPropertyAccess,
    InvalidAssignment,
    InvalidCall,
    ReturnValue,  // Special error used for handling return statements
    SystemError,
    Interrupted,
    OutOfMemory,
};

// Forward declare MemoryManager
// We only need the name here, the implementation is in memory.zig
pub const MemoryManager = opaque {}; 

// These declarations allow us to use MemoryManager methods in this file
pub extern fn allocateNumber(self: *MemoryManager, value: f64) anyerror!*Value;
pub extern fn allocateText(self: *MemoryManager, value: []const u8) anyerror!*Value;
pub extern fn allocateBoolean(self: *MemoryManager, value: bool) anyerror!*Value;
pub extern fn allocateNil(self: *MemoryManager) anyerror!*Value;

// Environment for variable bindings
pub const Environment = struct {
    parent: ?*Environment,
    variables: std.StringHashMap(*Value),
    memory_manager: *MemoryManager,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, memory_manager: *MemoryManager) Environment {
        return .{
            .parent = null,
            .variables = std.StringHashMap(*Value).init(allocator),
            .memory_manager = memory_manager,
            .allocator = allocator,
        };
    }
    
    pub fn initWithParent(allocator: std.mem.Allocator, parent: *Environment, memory_manager: *MemoryManager) Environment {
        return .{
            .parent = parent,
            .variables = std.StringHashMap(*Value).init(allocator),
            .memory_manager = memory_manager,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Environment) void {
        self.variables.deinit();
    }
    
    pub fn define(self: *Environment, name: []const u8, value: *Value) !void {
        try self.variables.put(name, value);
    }
    
    pub fn get(self: *Environment, name: []const u8) ?*Value {
        return self.variables.get(name) orelse if (self.parent) |parent| parent.get(name) else null;
    }
    
    pub fn set(self: *Environment, name: []const u8, value: *Value) !bool {
        if (self.variables.contains(name)) {
            try self.variables.put(name, value);
            return true;
        }
        
        if (self.parent) |parent| {
            return parent.set(name, value);
        }
        
        return false;
    }
};

// Interpreter for executing AST nodes
pub const Interpreter = struct {
    allocator: std.mem.Allocator,
    memory_manager: *MemoryManager,
    environment: *Environment,
    
    pub fn init(allocator: std.mem.Allocator, memory_manager: *MemoryManager, environment: *Environment) Interpreter {
        return .{
            .allocator = allocator,
            .memory_manager = memory_manager,
            .environment = environment,
        };
    }
    
    // Evaluate an AST node and return a value
    pub fn evaluate(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        // Simplified implementation for now
        _ = node;
        
        // Create a dummy value for testing
        // Use standard allocator since memory_manager is opaque
        var value = try self.environment.allocator.create(Value);
        value.* = .{
            .data = ValueType.nil,
            // Only include fields that exist in the struct
        };
        return value;
    }
    
    // Original implementation for reference
    fn _evaluate_original(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        return switch (node.node_type) {
            // TODO: These methods need wiring up but aren't being used yet
            .number_literal, .text_literal, .boolean_literal, .nil_literal => {
                @panic("Not implemented");
            },
            
            // Identifiers and expressions
            .identifier => self.evaluateIdentifier(node),
            .binary_expression => self.evaluateBinaryExpression(node),
            .unary_expression => self.evaluateUnaryExpression(node),
            .member_access => self.evaluateMemberAccess(node),
            .index_expression => self.evaluateIndexExpression(node),
            .call_expression => self.evaluateCallExpression(node),
            
            // Statements
            .block => self.evaluateBlock(node),
            .expression_stmt => self.evaluate(node.data.expression_stmt),
            .variable_declaration => self.evaluateVariableDeclaration(node),
            .if_stmt => self.evaluateIfStatement(node),
            .for_stmt => self.evaluateForStatement(node),
            .while_stmt => self.evaluateWhileStatement(node),
            .return_stmt => self.evaluateReturnStatement(node),
            
            // Other AST node types would be handled here
            else => RuntimeError.SystemError,
        };
    }
    
    // Evaluate an identifier node
    fn evaluateIdentifier(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        if (self.environment.get(node.data.identifier)) |value| {
            return value;
        }
        
        return RuntimeError.UndefinedVariable;
    }
    
    // Evaluate a binary expression
    fn evaluateBinaryExpression(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        const left = try self.evaluate(node.data.binary_expression.left);
        const right = try self.evaluate(node.data.binary_expression.right);
        
        return switch (node.data.binary_expression.operator) {
            .add => self.memory_manager.add(left, right) catch {
                return RuntimeError.InvalidOperator;
            },
            .subtract => self.memory_manager.subtract(left, right) catch {
                return RuntimeError.InvalidOperator;
            },
            .multiply => self.memory_manager.multiply(left, right) catch {
                return RuntimeError.InvalidOperator;
            },
            .divide => self.memory_manager.divide(left, right) catch {
                return RuntimeError.DivisionByZero;
            },
            .eq => blk: {
                const result = (self.memory_manager.compare(left, right) catch {
                    return RuntimeError.InvalidOperator;
                }) == 0;
                break :blk self.memory_manager.allocateBoolean(result);
            },
            .neq => blk: {
                const result = (self.memory_manager.compare(left, right) catch {
                    return RuntimeError.InvalidOperator;
                }) != 0;
                break :blk self.memory_manager.allocateBoolean(result);
            },
            .lt => blk: {
                const result = (self.memory_manager.compare(left, right) catch {
                    return RuntimeError.InvalidOperator;
                }) < 0;
                break :blk self.memory_manager.allocateBoolean(result);
            },
            .lte => blk: {
                const result = (self.memory_manager.compare(left, right) catch {
                    return RuntimeError.InvalidOperator;
                }) <= 0;
                break :blk self.memory_manager.allocateBoolean(result);
            },
            .gt => blk: {
                const result = (self.memory_manager.compare(left, right) catch {
                    return RuntimeError.InvalidOperator;
                }) > 0;
                break :blk self.memory_manager.allocateBoolean(result);
            },
            .gte => blk: {
                const result = (self.memory_manager.compare(left, right) catch {
                    return RuntimeError.InvalidOperator;
                }) >= 0;
                break :blk self.memory_manager.allocateBoolean(result);
            },
            .logical_and => blk: {
                if (left.data != .boolean or right.data != .boolean) {
                    return RuntimeError.TypeMismatch;
                }
                const result = left.data.boolean and right.data.boolean;
                break :blk self.memory_manager.allocateBoolean(result);
            },
            .logical_or => blk: {
                if (left.data != .boolean or right.data != .boolean) {
                    return RuntimeError.TypeMismatch;
                }
                const result = left.data.boolean or right.data.boolean;
                break :blk self.memory_manager.allocateBoolean(result);
            },
            .assign => self.evaluateAssignment(node.data.binary_expression.left, right),
            
            else => RuntimeError.InvalidOperator,
        };
    }
    
    // Evaluate a unary expression
    fn evaluateUnaryExpression(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        const operand = try self.evaluate(node.data.unary_expression.operand);
        
        return switch (node.data.unary_expression.operator) {
            .not => blk: {
                if (operand.data != .boolean) {
                    return RuntimeError.TypeMismatch;
                }
                break :blk self.memory_manager.allocateBoolean(!operand.data.boolean);
            },
            else => RuntimeError.InvalidOperator,
        };
    }
    
    // Evaluate a member access expression
    fn evaluateMemberAccess(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        const object = try self.evaluate(node.data.member_access.object);
        const member = node.data.member_access.member;
        
        return switch (object.data) {
            .record => blk: {
                if (self.memory_manager.recordGet(object, member) catch {
                    return RuntimeError.SystemError;
                }) |value| {
                    break :blk value;
                } else {
                    return RuntimeError.InvalidPropertyAccess;
                }
            },
            else => RuntimeError.InvalidPropertyAccess,
        };
    }
    
    // Evaluate an index expression
    fn evaluateIndexExpression(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        const array = try self.evaluate(node.data.index_expression.array);
        const index = try self.evaluate(node.data.index_expression.index);
        
        if (index.data != .number) {
            return RuntimeError.TypeMismatch;
        }
        
        const idx: usize = @intFromFloat(index.data.number);
        
        return switch (array.data) {
            .list => blk: {
                const item = self.memory_manager.listGet(array, idx) catch {
                    return RuntimeError.SystemError;
                } orelse {
                    return RuntimeError.InvalidPropertyAccess;
                };
                break :blk item;
            },
            .text => blk: {
                if (idx < 0 or idx >= array.data.text.len) {
                    return RuntimeError.InvalidPropertyAccess;
                }
                
                const char_str = [_]u8{array.data.text[idx]};
                break :blk self.memory_manager.allocateText(&char_str);
            },
            else => RuntimeError.TypeMismatch,
        };
    }
    
    // Evaluate a call expression
    fn evaluateCallExpression(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        const callee = try self.evaluate(node.data.call_expression.callee);
        
        var args = std.ArrayList(*Value).init(self.allocator);
        defer args.deinit();
        
        for (node.data.call_expression.arguments) |arg| {
            const arg_value = try self.evaluate(arg);
            try args.append(arg_value);
        }
        
        if (callee.data == .function) {
            return self.callFunction(callee, args.items);
        }
        
        return RuntimeError.InvalidCall;
    }
    
    // Call a function
    fn callFunction(self: *Interpreter, func: *Value, args: []const *Value) RuntimeError!*Value {
        if (func.data != .function) {
            return RuntimeError.InvalidCall;
        }
        
        if (args.len != func.data.function.parameters.len) {
            return RuntimeError.InvalidArguments;
        }
        
        // Create a new environment for the function execution
        var env = Environment.initWithParent(self.allocator, self.environment, self.memory_manager);
        defer env.deinit();
        
        // Bind arguments to parameters
        for (func.data.function.parameters, 0..) |param, i| {
            try env.define(param, args[i]);
        }
        
        // Store the current environment and set the function's environment
        const previous_env = self.environment;
        self.environment = &env;
        defer self.environment = previous_env;
        
        // Execute the function body
        const result = self.evaluate(func.data.function.body) catch |err| {
            // Catch return values
            if (err == RuntimeError.ReturnValue) {
                // The return_value would be set in evaluateReturnStatement
                // We would need a way to store and retrieve it
                // For now, we're just returning nil
                return self.memory_manager.allocateNil();
            }
            return err;
        };
        
        return result;
    }
    
    // Evaluate a block of statements
    fn evaluateBlock(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        var result = try self.memory_manager.allocateNil();
        
        for (node.data.block) |stmt| {
            result = try self.evaluate(stmt);
        }
        
        return result;
    }
    
    // Evaluate a variable declaration
    fn evaluateVariableDeclaration(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        var value = try self.memory_manager.allocateNil();
        
        if (node.data.variable_declaration.initial_value) |init_expr| {
            value = try self.evaluate(init_expr);
        }
        
        try self.environment.define(node.data.variable_declaration.name, value);
        return value;
    }
    
    // Evaluate an if statement
    fn evaluateIfStatement(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        const condition = try self.evaluate(node.data.if_stmt.condition);
        
        if (condition.data != .boolean) {
            return RuntimeError.TypeMismatch;
        }
        
        if (condition.data.boolean) {
            return self.evaluate(node.data.if_stmt.then_branch);
        } else if (node.data.if_stmt.else_branch) |else_branch| {
            return self.evaluate(else_branch);
        }
        
        return self.memory_manager.allocateNil();
    }
    
    // Evaluate a while statement
    fn evaluateWhileStatement(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        var result = try self.memory_manager.allocateNil();
        
        while (true) {
            const condition = try self.evaluate(node.data.while_stmt.condition);
            
            if (condition.data != .boolean) {
                return RuntimeError.TypeMismatch;
            }
            
            if (!condition.data.boolean) {
                break;
            }
            
            result = try self.evaluate(node.data.while_stmt.body);
        }
        
        return result;
    }
    
    // Evaluate a for statement
    fn evaluateForStatement(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        // Create a new environment for the loop scope
        var env = Environment.initWithParent(self.allocator, self.environment, self.memory_manager);
        defer env.deinit();
        
        // Store the current environment and set the loop's environment
        const previous_env = self.environment;
        self.environment = &env;
        defer self.environment = previous_env;
        
        // Initialize the loop variable if present
        if (node.data.for_stmt.init) |init_node| {
            _ = try self.evaluate(init_node);
        }
        
        var result = try self.memory_manager.allocateNil();
        
        while (true) {
            // Check the condition if present
            if (node.data.for_stmt.condition) |condition| {
                const cond_result = try self.evaluate(condition);
                
                if (cond_result.data != .boolean) {
                    return RuntimeError.TypeMismatch;
                }
                
                if (!cond_result.data.boolean) {
                    break;
                }
            }
            
            // Execute the loop body
            result = try self.evaluate(node.data.for_stmt.body);
            
            // Execute the update if present
            if (node.data.for_stmt.update) |update| {
                _ = try self.evaluate(update);
            }
        }
        
        return result;
    }
    
    // Evaluate a return statement
    fn evaluateReturnStatement(self: *Interpreter, node: *AstNode) RuntimeError!*Value {
        _ = if (node.data.return_stmt) |expr|
            try self.evaluate(expr)
        else
            try self.memory_manager.allocateNil();
        
        // In a real implementation, we'd store this value somewhere
        // and then throw the ReturnValue error to unwind the stack
        return RuntimeError.ReturnValue;
    }
    
    // Evaluate an assignment
    fn evaluateAssignment(self: *Interpreter, left: *AstNode, value: *Value) RuntimeError!*Value {
        return switch (left.node_type) {
            .identifier => blk: {
                const name = left.data.identifier;
                
                if (try self.environment.set(name, value)) {
                    break :blk value;
                }
                
                return RuntimeError.UndefinedVariable;
            },
            .member_access => blk: {
                const object = try self.evaluate(left.data.member_access.object);
                const member = left.data.member_access.member;
                
                if (object.data == .record) {
                    try self.memory_manager.recordSet(object, member, value);
                    break :blk value;
                }
                
                return RuntimeError.InvalidAssignment;
            },
            .index_expression => blk: {
                const array = try self.evaluate(left.data.index_expression.array);
                const index = try self.evaluate(left.data.index_expression.index);
                
                if (index.data != .number) {
                    return RuntimeError.TypeMismatch;
                }
                
                const idx = @as(usize, @intFromFloat(index.data.number));
                
                if (array.data == .list) {
                    try self.memory_manager.listSet(array, idx, value);
                    break :blk value;
                }
                
                return RuntimeError.InvalidAssignment;
            },
            else => RuntimeError.InvalidAssignment,
        };
    }
    
    // Execute a function
    pub fn executeFunction(self: *Interpreter, func: *Value, args: []const *Value) RuntimeError!*Value {
        return self.callFunction(func, args);
    }
    
    // Execute a trigger
    pub fn executeTrigger(self: *Interpreter, trigger: *Value, context: *Value) RuntimeError!void {
        if (trigger.data != .trigger) {
            return RuntimeError.InvalidCall;
        }
        
        // Bind the context to the environment
        try self.environment.define("context", context);
        
        // Evaluate the condition
        const condition = try self.evaluate(trigger.data.trigger.condition);
        
        if (condition.data != .boolean) {
            return RuntimeError.TypeMismatch;
        }
        
        // If the condition is true, execute the action
        if (condition.data.boolean) {
            _ = try self.evaluate(trigger.data.trigger.action);
        }
    }
};

pub const DateTime = struct {
    date: Date,
    time: Time,
    
    pub fn init(year: i32, month: u8, day: u8, hours: u8, minutes: u8, seconds: u8, milliseconds: u16) DateTime {
        return .{
            .date = Date.init(year, month, day),
            .time = Time.init(hours, minutes, seconds, milliseconds),
        };
    }
    
    pub fn initFromDateAndTime(date: Date, time: Time) DateTime {
        return .{
            .date = date,
            .time = time,
        };
    }
    
    // Parse a datetime from a string in ISO 8601 format
    // Supported formats:
    // - YYYY-MM-DD HH:MM:SS
    // - YYYY-MM-DD HH:MM:SS.mmm
    // - YYYY-MM-DDT HH:MM:SS
    // - YYYY-MM-DDT HH:MM:SS.mmm
    pub fn parse(str: []const u8) !DateTime {
        // Find the separator between date and time (space or 'T')
        var separator_pos: usize = 0;
        for (str, 0..) |c, i| {
            if (c == ' ' or c == 'T') {
                separator_pos = i;
                break;
            }
        }
        
        // If no separator found or not enough characters for both date and time
        if (separator_pos == 0 or separator_pos + 1 >= str.len) {
            return error.InvalidFormat;
        }
        
        // Parse date part (first part of the string)
        const date = try Date.parse(str[0..separator_pos]);
        
        // Parse time part (everything after the separator)
        const time = try Time.parse(str[separator_pos+1..]);
        
        return DateTime.initFromDateAndTime(date, time);
    }
    
    // Add a time duration to this datetime
    pub fn addTime(self: DateTime, hours: i32, minutes: i32, seconds: i32, milliseconds: i32) DateTime {
        var new_datetime = self;
        
        // Add milliseconds
        var ms: i32 = @as(i32, @intCast(new_datetime.time.milliseconds)) + milliseconds;
        var extra_seconds: i32 = 0;
        
        if (ms >= 1000) {
            extra_seconds = @divTrunc(ms, 1000);
            ms = @mod(ms, 1000);
        } else if (ms < 0) {
            // Handle negative milliseconds by borrowing seconds
            extra_seconds = @divTrunc(ms - 999, 1000); // Subtracting 999 to account for integer division
            ms = @mod(ms + ((-extra_seconds) * 1000), 1000);
        }
        
        // Add seconds (including overflow from milliseconds)
        var sec: i32 = @as(i32, @intCast(new_datetime.time.seconds)) + seconds + extra_seconds;
        var extra_minutes: i32 = 0;
        
        if (sec >= 60) {
            extra_minutes = @divTrunc(sec, 60);
            sec = @mod(sec, 60);
        } else if (sec < 0) {
            extra_minutes = @divTrunc(sec - 59, 60);
            sec = @mod(sec + ((-extra_minutes) * 60), 60);
        }
        
        // Add minutes (including overflow from seconds)
        var min: i32 = @as(i32, @intCast(new_datetime.time.minutes)) + minutes + extra_minutes;
        var extra_hours: i32 = 0;
        
        if (min >= 60) {
            extra_hours = @divTrunc(min, 60);
            min = @mod(min, 60);
        } else if (min < 0) {
            extra_hours = @divTrunc(min - 59, 60);
            min = @mod(min + ((-extra_hours) * 60), 60);
        }
        
        // Add hours (including overflow from minutes)
        var hr: i32 = @as(i32, @intCast(new_datetime.time.hours)) + hours + extra_hours;
        var extra_days: i32 = 0;
        
        if (hr >= 24) {
            extra_days = @divTrunc(hr, 24);
            hr = @mod(hr, 24);
        } else if (hr < 0) {
            extra_days = @divTrunc(hr - 23, 24);
            hr = @mod(hr + ((-extra_days) * 24), 24);
        }
        
        // Update the time fields
        new_datetime.time.milliseconds = @intCast(@as(u31, @intCast(ms)));
        new_datetime.time.seconds = @intCast(@as(u31, @intCast(sec)));
        new_datetime.time.minutes = @intCast(@as(u31, @intCast(min)));
        new_datetime.time.hours = @intCast(@as(u31, @intCast(hr)));
        
        // If there's day overflow, handle it
        if (extra_days != 0) {
            new_datetime.date = new_datetime.date.addDays(extra_days);
        }
        
        return new_datetime;
    }
    
    // Add days to this datetime
    pub fn addDays(self: DateTime, days: i32) DateTime {
        return .{
            .date = self.date.addDays(days),
            .time = self.time,
        };
    }
    
    // Add months to this datetime
    pub fn addMonths(self: DateTime, months: i32) DateTime {
        return .{
            .date = self.date.addMonths(months),
            .time = self.time,
        };
    }
    
    // Add years to this datetime
    pub fn addYears(self: DateTime, years: i32) DateTime {
        return .{
            .date = self.date.addYears(years),
            .time = self.time,
        };
    }
    
    // Find the next occurrence of the specified day of week after this datetime
    pub fn nextDayOfWeek(self: DateTime, day: DayOfWeek) DateTime {
        return .{
            .date = self.date.nextDayOfWeek(day),
            .time = self.time,
        };
    }
    
    // Find the previous occurrence of the specified day of week before this datetime
    pub fn previousDayOfWeek(self: DateTime, day: DayOfWeek) DateTime {
        return .{
            .date = self.date.previousDayOfWeek(day),
            .time = self.time,
        };
    }
    
    // Check if two datetimes are equal
    pub fn equals(self: DateTime, other: DateTime) bool {
        return self.date.equals(other.date) and 
               self.time.hours == other.time.hours and
               self.time.minutes == other.time.minutes and
               self.time.seconds == other.time.seconds and
               self.time.milliseconds == other.time.milliseconds;
    }
    
    // Compare two datetimes
    pub fn compare(self: DateTime, other: DateTime) i8 {
        const date_comparison = self.date.compare(other.date);
        if (date_comparison != 0) {
            return date_comparison;
        }
        
        if (self.time.hours < other.time.hours) return -1;
        if (self.time.hours > other.time.hours) return 1;
        
        if (self.time.minutes < other.time.minutes) return -1;
        if (self.time.minutes > other.time.minutes) return 1;
        
        if (self.time.seconds < other.time.seconds) return -1;
        if (self.time.seconds > other.time.seconds) return 1;
        
        if (self.time.milliseconds < other.time.milliseconds) return -1;
        if (self.time.milliseconds > other.time.milliseconds) return 1;
        
        return 0;
    }
    
    pub fn format(
        self: DateTime,
        comptime fmt_str: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        
        // Format the date part
        if (fmt_str.len > 0 and fmt_str[0] == 'l') {
            // Long format with day of week
            const day_name = self.date.dayOfWeek().toString();
            try writer.print("{s}, {d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}", .{
                day_name,
                self.date.year,
                self.date.month,
                self.date.day,
                self.time.hours,
                self.time.minutes,
                self.time.seconds,
                self.time.milliseconds,
            });
        } else {
            // Standard ISO format
            try writer.print("{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}", .{
                self.date.year,
                self.date.month,
                self.date.day,
                self.time.hours,
                self.time.minutes,
                self.time.seconds,
                self.time.milliseconds,
            });
        }
    }
};

pub const Percentage = struct {
    value: f64,

    pub fn init(value: f64) Percentage {
        return .{ .value = value };
    }

    pub fn format(
        self: Percentage,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d:.2}%", .{self.value});
    }
};

pub const Ratio = struct {
    numerator: f64,
    denominator: f64,

    pub fn init(numerator: f64, denominator: f64) Ratio {
        return .{
            .numerator = numerator,
            .denominator = denominator,
        };
    }

    pub fn format(
        self: Ratio,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d}/{d}", .{ self.numerator, self.denominator });
    }
};

// Function definition structure
pub const Function = struct {
    name: []const u8,
    parameters: []const []const u8,  // Parameter names
    body: *AstNode,                  // Function body AST
    closure: ?*Record,               // Optional environment/closure
    
    pub fn init(allocator: std.mem.Allocator, name: []const u8, params: []const []const u8, body: *AstNode) !Function {
        // Make owned copies of the name and parameters
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);
        
        var params_copy = try allocator.alloc([]const u8, params.len);
        errdefer allocator.free(params_copy);
        
        for (params, 0..) |param, i| {
            params_copy[i] = try allocator.dupe(u8, param);
            errdefer {
                for (params_copy[0..i]) |p| {
                    allocator.free(p);
                }
            }
        }
        
        return .{
            .name = name_copy,
            .parameters = params_copy,
            .body = body,
            .closure = null,
        };
    }
    
    pub fn deinit(self: *Function, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        
        for (self.parameters) |param| {
            allocator.free(param);
        }
        allocator.free(self.parameters);
        
        // The body and closure are managed separately
    }
};

// Event types for triggers
pub const EventType = enum {
    data_changed,    // Data in a record has been changed
    timer,           // Time-based event
    startup,         // System startup
    shutdown,        // System shutdown
    custom,          // Custom event type
};

// Constraint - similar to trigger but evaluated immediately
pub const Constraint = struct {
    name: []const u8,
    condition: *AstNode,  // Boolean expression to evaluate
    healing_action: ?*AstNode, // Optional action to attempt to fix violations
    
    pub fn init(allocator: std.mem.Allocator, name: []const u8, 
                condition: *AstNode, healing_action: ?*AstNode) !Constraint {
        const name_copy = try allocator.dupe(u8, name);
        
        return .{
            .name = name_copy,
            .condition = condition,
            .healing_action = healing_action,
        };
    }
    
    pub fn deinit(self: *Constraint, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        // The condition and healing_action ASTs are managed separately
    }
};

// Trigger definition structure
pub const Trigger = struct {
    name: []const u8,
    event_type: EventType,
    condition: *AstNode,  // Boolean expression to evaluate
    action: *AstNode,     // Code to execute if condition is true
    
    pub fn init(allocator: std.mem.Allocator, name: []const u8, event_type: EventType, 
                condition: *AstNode, action: *AstNode) !Trigger {
        const name_copy = try allocator.dupe(u8, name);
        
        return .{
            .name = name_copy,
            .event_type = event_type,
            .condition = condition,
            .action = action,
        };
    }
    
    pub fn deinit(self: *Trigger, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        // The condition and action ASTs are managed separately
    }
};

pub const Value = struct {
    data: union(ValueType) {
        number: f64,
        text: []const u8,
        money: Money,
        time: Time,
        date: Date,
        date_time: DateTime,
        percentage: Percentage,
        ratio: Ratio,
        boolean: bool,
        unknown: void,
        nil: void,
        list: List,
        record: Record,
        function: Function,
        trigger: Trigger,
        constraint: Constraint,
    },
    // Track if we own the memory (especially for strings)
    owns_memory: bool = false,
    
    // Try to parse a special literal prefixed with @ (like @"2024-03-15" for dates)
    pub fn tryParseSpecialLiteral(allocator: std.mem.Allocator, str: []const u8) !?Value {
        if (str.len < 3 or str[0] != '@' or str[1] != '"' or str[str.len - 1] != '"') {
            return null; // Not a valid @ literal format
        }
        
        // Extract the content inside the quotes
        const content = str[2..str.len-1];
        
        // Try to parse as date (YYYY-MM-DD)
        if (content.len == 10 and content[4] == '-' and content[7] == '-') {
            if (Date.parse(content)) |date| {
                return Value.initDate(date.year, date.month, date.day);
            } else |_| {}
        }
        
        // Try to parse as time (HH:MM:SS or HH:MM:SS.mmm)
        if ((content.len == 8 or (content.len == 12 and content[8] == '.')) and 
             content[2] == ':' and content[5] == ':') {
            if (Time.parse(content)) |time| {
                return Value.initTime(time.hours, time.minutes, time.seconds, time.milliseconds);
            } else |_| {}
        }
        
        // Try to parse as datetime (YYYY-MM-DD HH:MM:SS or YYYY-MM-DDT HH:MM:SS)
        if (content.len >= 19) {
            if (DateTime.parse(content)) |dt| {
                return Value.initDateTimeFromParts(dt.date, dt.time);
            } else |_| {}
        }
        
        // Try to parse as money ($123.45)
        if (content.len >= 2 and content[0] == '$') {
            var i: usize = 1;
            var dollars: i64 = 0;
            var cents: i64 = 0;
            var negative = false;
            
            if (content[1] == '-') {
                negative = true;
                i += 1;
            }
            
            // Parse dollars
            var decimal_found = false;
            while (i < content.len) : (i += 1) {
                const c = content[i];
                if (c == '.') {
                    decimal_found = true;
                    i += 1;
                    break;
                } else if (c >= '0' and c <= '9') {
                    dollars = dollars * 10 + @as(i64, @intCast(c - '0'));
                } else {
                    return null; // Invalid character in money literal
                }
            }
            
            // Parse cents if decimal point was found
            if (decimal_found and i < content.len) {
                var cent_position: usize = 0;
                while (i < content.len and cent_position < 2) : ({ i += 1; cent_position += 1; }) {
                    const c = content[i];
                    if (c >= '0' and c <= '9') {
                        cents = cents * 10 + @as(i64, @intCast(c - '0'));
                    } else {
                        return null; // Invalid character in money literal
                    }
                }
                
                // Adjust cents if only one digit provided
                if (cent_position == 1) {
                    cents *= 10;
                }
            }
            
            if (negative) {
                dollars = -dollars;
                cents = -cents;
            }
            
            const money = try Money.initOwned(allocator, dollars * 10000 + cents * 100, "USD");
            return Value{
                .data = .{ .money = money },
                .owns_memory = true,
            };
        }
        
        return null; // Not a recognized special literal
    }
    
    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        if (self.owns_memory) {
            switch (self.data) {
                .text => |t| allocator.free(t),
                .money => |m| if (@hasField(@TypeOf(m), "currency_owned") and m.currency_owned) {
                    allocator.free(m.currency);
                },
                .list => |*l| l.deinit(),
                .record => |*r| r.deinit(),
                .function => |*f| f.deinit(allocator),
                .trigger => |*t| t.deinit(allocator),
                .constraint => |*c| c.deinit(allocator),
                else => {}, // Other types don't own memory
            }
            self.owns_memory = false;
        }
    }

    pub fn initNumber(value: f64) Value {
        return .{ 
            .data = .{ .number = value },
            .owns_memory = false,
        };
    }
    
    pub fn initText(value: []const u8) Value {
        return .{ 
            .data = .{ .text = value },
            .owns_memory = false, 
        };
    }
    
    pub fn initOwnedText(allocator: std.mem.Allocator, value: []const u8) !Value {
        const owned_text = try allocator.dupe(u8, value);
        return .{ 
            .data = .{ .text = owned_text },
            .owns_memory = true,
        };
    }

    pub fn initMoney(amount: i128, currency: []const u8) Value {
        return .{ 
            .data = .{ .money = Money.init(amount, currency) },
            .owns_memory = false,
        };
    }
    
    pub fn initOwnedMoney(allocator: std.mem.Allocator, amount: i128, currency: []const u8) !Value {
        const money = try Money.initOwned(allocator, amount, currency);
        return .{ 
            .data = .{ .money = money },
            .owns_memory = true,
        };
    }
    
    // Helper methods for working with decimal values
    pub fn initMoneyFromDecimal(dollars: i64, cents: i64, currency: []const u8) Value {
        return .{
            .data = .{ .money = Money.initFromDecimal(dollars, cents, currency) },
            .owns_memory = false,
        };
    }
    
    pub fn initOwnedMoneyFromDecimal(allocator: std.mem.Allocator, dollars: i64, cents: i64, currency: []const u8) !Value {
        const amount = dollars * 10000 + cents * 100;
        return initOwnedMoney(allocator, amount, currency);
    }

    pub fn initTime(hours: u8, minutes: u8, seconds: u8, milliseconds: u16) Value {
        return .{ 
            .data = .{ .time = Time.init(hours, minutes, seconds, milliseconds) },
            .owns_memory = false,
        };
    }

    pub fn initDate(year: i32, month: u8, day: u8) Value {
        return .{ 
            .data = .{ .date = Date.init(year, month, day) },
            .owns_memory = false,
        };
    }
    
    pub fn initDateTime(year: i32, month: u8, day: u8, hours: u8, minutes: u8, seconds: u8, milliseconds: u16) Value {
        return .{
            .data = .{ .date_time = DateTime.init(year, month, day, hours, minutes, seconds, milliseconds) },
            .owns_memory = false,
        };
    }
    
    pub fn initDateTimeFromParts(date: Date, time: Time) Value {
        return .{
            .data = .{ .date_time = DateTime.initFromDateAndTime(date, time) },
            .owns_memory = false,
        };
    }

    pub fn initPercentage(value: f64) Value {
        return .{ 
            .data = .{ .percentage = Percentage.init(value) },
            .owns_memory = false,
        };
    }

    pub fn initRatio(numerator: f64, denominator: f64) Value {
        return .{ 
            .data = .{ .ratio = Ratio.init(numerator, denominator) },
            .owns_memory = false,
        };
    }

    pub fn initBoolean(value: bool) Value {
        return .{ 
            .data = .{ .boolean = value },
            .owns_memory = false,
        };
    }

    pub fn initUnknown() Value {
        return .{ 
            .data = .{ .unknown = {} },
            .owns_memory = false,
        };
    }

    pub fn initNil() Value {
        return .{ 
            .data = .{ .nil = {} },
            .owns_memory = false,
        };
    }
    
    pub fn initList(allocator: std.mem.Allocator) Value {
        return .{
            .data = .{ .list = List.init(allocator) },
            .owns_memory = true,
        };
    }
    
    pub fn initRecord(allocator: std.mem.Allocator) Value {
        return .{
            .data = .{ .record = Record.init(allocator) },
            .owns_memory = true,
        };
    }
    
    pub fn initRecordWithParent(allocator: std.mem.Allocator, parent: *Value) !Value {
        const record = try Record.initWithParent(allocator, parent);
        return .{
            .data = .{ .record = record },
            .owns_memory = true,
        };
    }
    
    pub fn initFunction(allocator: std.mem.Allocator, name: []const u8, 
                       params: []const []const u8, body: *AstNode) !Value {
        const function = try Function.init(allocator, name, params, body);
        return .{
            .data = .{ .function = function },
            .owns_memory = true,
        };
    }
    
    pub fn initTrigger(allocator: std.mem.Allocator, name: []const u8, 
                      event_type: EventType, condition: *AstNode, 
                      action: *AstNode) !Value {
        const trigger = try Trigger.init(allocator, name, event_type, condition, action);
        return .{
            .data = .{ .trigger = trigger },
            .owns_memory = true,
        };
    }
    
    pub fn initConstraint(allocator: std.mem.Allocator, name: []const u8,
                         condition: *AstNode, healing_action: ?*AstNode) !Value {
        const constraint = try Constraint.init(allocator, name, condition, healing_action);
        return .{
            .data = .{ .constraint = constraint },
            .owns_memory = true,
        };
    }

    pub fn format(
        self: Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        switch (self.data) {
            .number => |n| try writer.print("{d}", .{n}),
            .text => |t| try writer.print("\"{s}\"", .{t}),
            .money => |m| try m.format("", options, writer),
            .time => |t| try t.format("", options, writer),
            .date => |d| try d.format("", options, writer),
            .date_time => |dt| try dt.format("", options, writer),
            .percentage => |p| try p.format("", options, writer),
            .ratio => |r| try r.format("", options, writer),
            .boolean => |b| try writer.print("{s}", .{if (b) "true" else "false"}),
            .unknown => try writer.print("unknown", .{}),
            .nil => try writer.print("nil", .{}),
            .list => |l| try l.format("", options, writer),
            .record => |r| try r.format("", options, writer),
            .function => |f| try writer.print("function {s}({d} params)", .{f.name, f.parameters.len}),
            .trigger => |t| try writer.print("trigger {s} on {s}", .{t.name, @tagName(t.event_type)}),
            .constraint => |c| try writer.print("constraint {s}", .{c.name}),
        }
    }
}; 