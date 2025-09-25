const std = @import("std");
const lexer_mod = @import("lexer.zig");
const Lexer = lexer_mod.Lexer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "person = {\n    name: \"Alice\",\n    age: 30\n}";

    std.debug.print("Source ({d} chars): {s}\n", .{source.len, source});
    std.debug.print("Characters: ", .{});
    for (source) |char| {
        if (char == '\n') {
            std.debug.print("\\n", .{});
        } else if (char == '\t') {
            std.debug.print("\\t", .{});
        } else {
            std.debug.print("{c}", .{char});
        }
    }
    std.debug.print("\n", .{});

    var lexer = Lexer.init(allocator, source);

    const tokens = try lexer.scanTokens();
    defer tokens.deinit();

    for (tokens.items, 0..) |token, i| {
        std.debug.print("Token {}: type={s}, lexeme='{s}'\n", .{i, token.type.toString(), token.lexeme});
    }

    // Also test parsing
    const parser_mod = @import("parser.zig");
    var parser = parser_mod.Parser.init(allocator, tokens.items);
    const statements = parser.parse() catch |err| {
        std.debug.print("Parse error: {s}\n", .{@errorName(err)});
        return;
    };
    defer {
        for (statements) |*stmt| {
            stmt.deinit(allocator);
        }
        allocator.free(statements);
    }

    std.debug.print("Parsed {} statements\n", .{statements.len});
    for (statements, 0..) |stmt, i| {
        std.debug.print("Statement {}: type={s}\n", .{i, @tagName(stmt)});
    }
}