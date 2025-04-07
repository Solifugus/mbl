const std = @import("std");

pub fn main() void {
    // Simple format specifiers
    std.debug.print("Number: {d}\n", .{42});
    std.debug.print("String: {s}\n", .{"hello"});
    std.debug.print("Any: {any}\n", .{@as([]const u8, "test")});
}