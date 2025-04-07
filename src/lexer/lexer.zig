const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

pub const LexerError = error{
    UnterminatedString,
    InvalidNumber,
    InvalidToken,
    UnexpectedCharacter,
};

const keywords = std.ComptimeStringMap(TokenType, .{
    .{ "program", .program },
    .{ "trigger", .trigger },
    .{ "on", .on },
    .{ "when", .when },
    .{ "constrain", .constrain },
    .{ "consider", .consider },
    .{ "otherwise", .otherwise },
    .{ "end", .end },
    .{ "if", .if_ },
    .{ "then", .then },
    .{ "else", .else_ },
    .{ "while", .while_ },
    .{ "do", .do_ },
    .{ "for", .for_ },
    .{ "in", .in_ },
    .{ "function", .function },
    .{ "return", .return_ },
    .{ "break", .break_ },
    .{ "continue", .continue_ },
    .{ "true", .true_ },
    .{ "false", .false_ },
    .{ "unknown", .unknown_ },
    .{ "nil", .nil_ },
    .{ "var", .var_ },
    .{ "const", .const_ },
    
    // Type keywords
    .{ "Money", .money },
    .{ "Time", .time },
    .{ "Date", .date },
    .{ "DateTime", .date_time },
    .{ "Percentage", .percentage },
    .{ "Ratio", .ratio },
});

pub const Lexer = struct {
    source: []const u8,
    tokens: std.ArrayList(Token),
    start: usize,
    current: usize,
    line: usize,
    column: usize,
    had_error: bool,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        return .{
            .source = source,
            .tokens = std.ArrayList(Token).init(allocator),
            .start = 0,
            .current = 0,
            .line = 1,
            .column = 1,
            .had_error = false,
        };
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }

    pub fn scanTokens(self: *Lexer) ![]const Token {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }

        try self.tokens.append(Token.init(
            .eof,
            "",
            self.line,
            self.column,
            null,
        ));

        return self.tokens.items;
    }

    fn scanToken(self: *Lexer) !void {
        const c = self.advance();
        switch (c) {
            ' ' => {},
            '\r' => {},
            '\t' => {},
            '\n' => {
                try self.addToken(.newline, null);
                self.line += 1;
                self.column = 1;
            },
            '(' => try self.addToken(.left_paren, null),
            ')' => try self.addToken(.right_paren, null),
            '{' => try self.addToken(.left_brace, null),
            '}' => try self.addToken(.right_brace, null),
            '[' => try self.addToken(.left_bracket, null),
            ']' => try self.addToken(.right_bracket, null),
            ',' => try self.addToken(.comma, null),
            '.' => try self.addToken(.dot, null),
            '-' => try self.addToken(.minus, null),
            '+' => try self.addToken(.plus, null),
            ';' => try self.addToken(.semicolon, null),
            '*' => try self.addToken(.multiply, null),
            '/' => {
                if (self.match('/')) {
                    // A comment goes until the end of the line
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        _ = self.advance();
                    }
                } else {
                    try self.addToken(.divide, null);
                }
            },
            '?' => try self.addToken(.question_mark, null),
            ':' => try self.addToken(.colon, null),
            '%' => try self.addToken(.modulo, null),
            '=' => {
                if (self.match('=')) {
                    try self.addToken(.equal_to, null);
                } else {
                    try self.addToken(.assign, null);
                }
            },
            '!' => {
                if (self.match('=')) {
                    try self.addToken(.not_equal_to, null);
                } else {
                    try self.addToken(.not_, null);
                }
            },
            '<' => {
                if (self.match('=')) {
                    try self.addToken(.less_equal_to, null);
                } else {
                    try self.addToken(.less_than, null);
                }
            },
            '>' => {
                if (self.match('=')) {
                    try self.addToken(.greater_equal_to, null);
                } else {
                    try self.addToken(.greater_than, null);
                }
            },
            '&' => {
                if (self.match('&')) {
                    try self.addToken(.and_, null);
                } else {
                    self.had_error = true;
                    std.debug.print("[line {d}] Error: Expected '&' after '&'\n", .{self.line});
                    return LexerError.InvalidToken;
                }
            },
            '|' => {
                if (self.match('|')) {
                    try self.addToken(.or_, null);
                } else {
                    self.had_error = true;
                    std.debug.print("[line {d}] Error: Expected '|' after '|'\n", .{self.line});
                    return LexerError.InvalidToken;
                }
            },
            '@' => try self.specialLiteral(),
            '"' => try self.string(),
            else => {
                if (isDigit(c)) {
                    try self.number();
                } else if (isAlpha(c)) {
                    try self.identifier();
                } else {
                    self.had_error = true;
                    std.debug.print("[line {d}] Error: Unexpected character\n", .{self.line});
                    return LexerError.UnexpectedCharacter;
                }
            },
        }
    }
    
    fn specialLiteral(self: *Lexer) !void {
        // Special literals are in the form @"content"
        if (self.peek() != '"') {
            self.had_error = true;
            std.debug.print("[line {d}] Error: Expected '\"' after '@'\n", .{self.line});
            return LexerError.InvalidToken;
        }
        
        // Advance past the opening quote
        _ = self.advance();
        
        // Read until the closing quote
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') {
                self.line += 1;
                self.column = 1;
            }
            _ = self.advance();
        }
        
        if (self.isAtEnd()) {
            self.had_error = true;
            std.debug.print("[line {d}] Error: Unterminated special literal\n", .{self.line});
            return LexerError.UnterminatedString;
        }
        
        // Consume the closing quote
        _ = self.advance();
        
        // Get the content inside the quotes
        const value = self.source[self.start + 2 .. self.current - 1];
        try self.addToken(.special_literal, value);
    }

    fn string(self: *Lexer) !void {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') {
                self.line += 1;
                self.column = 1;
            }
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            self.had_error = true;
            std.debug.print("[line {d}] Error: Unterminated string\n", .{self.line});
            return LexerError.UnterminatedString;
        }

        _ = self.advance(); // The closing "

        const value = self.source[self.start + 1 .. self.current - 1];
        try self.addToken(.text, value);
    }

    fn number(self: *Lexer) !void {
        while (isDigit(self.peek())) _ = self.advance();

        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance(); // consume the '.'

            while (isDigit(self.peek())) _ = self.advance();
        }

        const value = self.source[self.start..self.current];
        try self.addToken(.number, value);
    }

    fn identifier(self: *Lexer) !void {
        while (isAlphaNumeric(self.peek())) _ = self.advance();

        const text = self.source[self.start..self.current];
        const token_type = keywords.get(text) orelse .identifier;
        try self.addToken(token_type, null);
    }

    fn match(self: *Lexer, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;

        self.current += 1;
        self.column += 1;
        return true;
    }

    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *Lexer) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            c == '_';
    }

    fn isAlphaNumeric(c: u8) bool {
        return isAlpha(c) or isDigit(c);
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.current];
        self.current += 1;
        self.column += 1;
        return c;
    }

    fn addToken(self: *Lexer, type_: TokenType, literal: ?[]const u8) !void {
        const text = self.source[self.start..self.current];
        try self.tokens.append(Token.init(
            type_,
            text,
            self.line,
            self.column - text.len,
            literal,
        ));
    }
}; 