const std = @import("std");

pub const TokenType = enum {
    // Keywords
    program,
    trigger,
    on,
    when,
    constrain,
    consider,
    otherwise,
    end,
    if_,
    then,
    else_,
    while_,
    do_,
    for_,
    in_,
    function,
    return_,
    break_,
    continue_,
    true_,
    false_,
    unknown_,
    nil_,
    var_,
    const_,

    // Literals
    number,
    text,
    identifier,
    special_literal, // For @"..." literals like dates, money, etc.

    // Special types
    money,
    time,
    date,
    date_time,
    percentage,
    ratio,

    // Operators
    assign,
    plus,
    minus,
    multiply,
    divide,
    modulo,
    greater_than,
    less_than,
    equal_to,
    not_equal_to,
    greater_equal_to,
    less_equal_to,
    and_,
    or_,
    not_,

    // Delimiters
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    left_bracket,
    right_bracket,
    comma,
    dot,
    semicolon,
    colon,
    question_mark,

    // Special
    newline,
    eof,
    error_,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
    column: usize,
    literal: ?[]const u8,

    pub fn init(
        type_: TokenType,
        lexeme: []const u8,
        line: usize,
        column: usize,
        literal: ?[]const u8,
    ) Token {
        return .{
            .type = type_,
            .lexeme = lexeme,
            .line = line,
            .column = column,
            .literal = literal,
        };
    }

    pub fn format(
        self: Token,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            "Token({}, '{s}', line: {}, column: {})",
            .{ self.type, self.lexeme, self.line, self.column },
        );
    }
}; 