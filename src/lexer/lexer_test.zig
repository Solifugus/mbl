const std = @import("std");
const testing = std.testing;
const Lexer = @import("lexer.zig").Lexer;
const TokenType = @import("token.zig").TokenType;
const LexerError = @import("lexer.zig").LexerError;

test "empty input" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, "");
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();
    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(TokenType.eof, tokens[0].type);
}

test "whitespace" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, " \t\r\n");
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();
    try testing.expectEqual(@as(usize, 2), tokens.len);
    try testing.expectEqual(TokenType.newline, tokens[0].type);
    try testing.expectEqual(TokenType.eof, tokens[1].type);
}

test "keywords" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, "program when consider otherwise end");
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();
    try testing.expectEqual(@as(usize, 6), tokens.len);
    try testing.expectEqual(TokenType.program, tokens[0].type);
    try testing.expectEqual(TokenType.when, tokens[1].type);
    try testing.expectEqual(TokenType.consider, tokens[2].type);
    try testing.expectEqual(TokenType.otherwise, tokens[3].type);
    try testing.expectEqual(TokenType.end, tokens[4].type);
    try testing.expectEqual(TokenType.eof, tokens[5].type);
}

test "numbers" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, "123 45.67");
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();
    try testing.expectEqual(@as(usize, 3), tokens.len);
    try testing.expectEqual(TokenType.number, tokens[0].type);
    try testing.expectEqualStrings("123", tokens[0].lexeme);
    try testing.expectEqual(TokenType.number, tokens[1].type);
    try testing.expectEqualStrings("45.67", tokens[1].lexeme);
    try testing.expectEqual(TokenType.eof, tokens[2].type);
}

test "text" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, "\"Hello, World!\"");
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();
    try testing.expectEqual(@as(usize, 2), tokens.len);
    try testing.expectEqual(TokenType.text, tokens[0].type);
    if (tokens[0].literal) |literal| {
        try testing.expectEqualStrings("Hello, World!", literal);
    } else {
        try testing.expect(false);
    }
    try testing.expectEqual(TokenType.eof, tokens[1].type);
}

test "operators" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, "+ - * / % = == != < <= > >= && || !");
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();
    try testing.expectEqual(@as(usize, 16), tokens.len);
    try testing.expectEqual(TokenType.plus, tokens[0].type);
    try testing.expectEqual(TokenType.minus, tokens[1].type);
    try testing.expectEqual(TokenType.multiply, tokens[2].type);
    try testing.expectEqual(TokenType.divide, tokens[3].type);
    try testing.expectEqual(TokenType.modulo, tokens[4].type);
    try testing.expectEqual(TokenType.assign, tokens[5].type);
    try testing.expectEqual(TokenType.equal_to, tokens[6].type);
    try testing.expectEqual(TokenType.not_equal_to, tokens[7].type);
    try testing.expectEqual(TokenType.less_than, tokens[8].type);
    try testing.expectEqual(TokenType.less_equal_to, tokens[9].type);
    try testing.expectEqual(TokenType.greater_than, tokens[10].type);
    try testing.expectEqual(TokenType.greater_equal_to, tokens[11].type);
    try testing.expectEqual(TokenType.and_, tokens[12].type);
    try testing.expectEqual(TokenType.or_, tokens[13].type);
    try testing.expectEqual(TokenType.not_, tokens[14].type);
    try testing.expectEqual(TokenType.eof, tokens[15].type);
}

test "delimiters" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, "(){}[],.;:?");
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();
    try testing.expectEqual(@as(usize, 12), tokens.len);
    try testing.expectEqual(TokenType.left_paren, tokens[0].type);
    try testing.expectEqual(TokenType.right_paren, tokens[1].type);
    try testing.expectEqual(TokenType.left_brace, tokens[2].type);
    try testing.expectEqual(TokenType.right_brace, tokens[3].type);
    try testing.expectEqual(TokenType.left_bracket, tokens[4].type);
    try testing.expectEqual(TokenType.right_bracket, tokens[5].type);
    try testing.expectEqual(TokenType.comma, tokens[6].type);
    try testing.expectEqual(TokenType.dot, tokens[7].type);
    try testing.expectEqual(TokenType.semicolon, tokens[8].type);
    try testing.expectEqual(TokenType.colon, tokens[9].type);
    try testing.expectEqual(TokenType.question_mark, tokens[10].type);
    try testing.expectEqual(TokenType.eof, tokens[11].type);
}

test "line and column tracking" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, "x = 42\n  y = 123");
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();
    try testing.expectEqual(@as(usize, 8), tokens.len);
    try testing.expectEqual(@as(usize, 1), tokens[0].line); // x
    try testing.expectEqual(@as(usize, 1), tokens[0].column);
    try testing.expectEqual(@as(usize, 1), tokens[1].line); // =
    try testing.expectEqual(@as(usize, 3), tokens[1].column);
    try testing.expectEqual(@as(usize, 1), tokens[2].line); // 42
    try testing.expectEqual(@as(usize, 5), tokens[2].column);
    try testing.expectEqual(@as(usize, 1), tokens[3].line); // newline
    try testing.expectEqual(@as(usize, 7), tokens[3].column);
    try testing.expectEqual(@as(usize, 2), tokens[4].line); // y
    try testing.expectEqual(@as(usize, 3), tokens[4].column);
    try testing.expectEqual(@as(usize, 2), tokens[5].line); // =
    try testing.expectEqual(@as(usize, 5), tokens[5].column);
    try testing.expectEqual(@as(usize, 2), tokens[6].line); // 123
    try testing.expectEqual(@as(usize, 7), tokens[6].column);
    try testing.expectEqual(@as(usize, 2), tokens[7].line); // eof
    try testing.expectEqual(@as(usize, 10), tokens[7].column);
}

test "error handling" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, "\"unterminated string");
    defer lexer.deinit();

    _ = lexer.scanTokens() catch |err| {
        try testing.expectEqual(err, LexerError.UnterminatedString);
        try testing.expect(lexer.had_error);
        return;
    };
    try testing.expect(false);
}

test "complex example" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, 
        \\program example
        \\    when x > 10 then
        \\        y = "Hello, World!"
        \\    end
    );
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();
    try testing.expectEqual(@as(usize, 15), tokens.len);
    try testing.expectEqual(TokenType.program, tokens[0].type);
    try testing.expectEqual(TokenType.identifier, tokens[1].type);
    try testing.expectEqual(TokenType.newline, tokens[2].type);
    try testing.expectEqual(TokenType.when, tokens[3].type);
    try testing.expectEqual(TokenType.identifier, tokens[4].type);
    try testing.expectEqual(TokenType.greater_than, tokens[5].type);
    try testing.expectEqual(TokenType.number, tokens[6].type);
    try testing.expectEqual(TokenType.then, tokens[7].type);
    try testing.expectEqual(TokenType.newline, tokens[8].type);
    try testing.expectEqual(TokenType.identifier, tokens[9].type);
    try testing.expectEqual(TokenType.assign, tokens[10].type);
    try testing.expectEqual(TokenType.text, tokens[11].type);
    try testing.expectEqual(TokenType.newline, tokens[12].type);
    try testing.expectEqual(TokenType.end, tokens[13].type);
    try testing.expectEqual(TokenType.eof, tokens[14].type);
}

test "special literals" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, "var date = @\"2023-01-15\";\nvar money = @\"$123.45\";");
    defer lexer.deinit();
    
    const tokens = try lexer.scanTokens();
    
    try testing.expect(tokens.len > 0);
    try testing.expectEqual(TokenType.var_, tokens[0].type);
    try testing.expectEqual(TokenType.identifier, tokens[1].type);
    try testing.expectEqualStrings("date", tokens[1].lexeme);
    try testing.expectEqual(TokenType.assign, tokens[2].type);
    try testing.expectEqual(TokenType.special_literal, tokens[3].type);
    try testing.expectEqualStrings("2023-01-15", tokens[3].literal.?);
    try testing.expectEqual(TokenType.semicolon, tokens[4].type);
    try testing.expectEqual(TokenType.newline, tokens[5].type);
    try testing.expectEqual(TokenType.var_, tokens[6].type);
    try testing.expectEqual(TokenType.identifier, tokens[7].type);
    try testing.expectEqualStrings("money", tokens[7].lexeme);
    try testing.expectEqual(TokenType.assign, tokens[8].type);
    try testing.expectEqual(TokenType.special_literal, tokens[9].type);
    try testing.expectEqualStrings("$123.45", tokens[9].literal.?);
    try testing.expectEqual(TokenType.semicolon, tokens[10].type);
}

test "mbl keywords and types" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, "var x = true;\nDate myDate = @\"2023-01-15\";\nMoney balance = @\"$100.00\";");
    defer lexer.deinit();
    
    const tokens = try lexer.scanTokens();
    
    try testing.expect(tokens.len > 0);
    try testing.expectEqual(TokenType.var_, tokens[0].type);
    try testing.expectEqual(TokenType.identifier, tokens[1].type);
    try testing.expectEqual(TokenType.assign, tokens[2].type);
    try testing.expectEqual(TokenType.true_, tokens[3].type);
    try testing.expectEqual(TokenType.semicolon, tokens[4].type);
    try testing.expectEqual(TokenType.newline, tokens[5].type);
    try testing.expectEqual(TokenType.date, tokens[6].type);
}

test "mbl comments" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, "var x = 42; // This is a comment\nvar y = 100;");
    defer lexer.deinit();
    
    const tokens = try lexer.scanTokens();
    
    try testing.expect(tokens.len > 0);
    try testing.expectEqual(TokenType.var_, tokens[0].type);
    try testing.expectEqual(TokenType.identifier, tokens[1].type);
    try testing.expectEqual(TokenType.assign, tokens[2].type);
    try testing.expectEqual(TokenType.number, tokens[3].type);
    try testing.expectEqual(TokenType.semicolon, tokens[4].type);
    // The comment should be skipped
    try testing.expectEqual(TokenType.newline, tokens[5].type);
    try testing.expectEqual(TokenType.var_, tokens[6].type);
}

test "mbl trigger syntax" {
    const allocator = testing.allocator;
    var lexer = Lexer.init(allocator, 
        \\trigger balance_changed on data_changed
        \\  when context.key == "balance" then
        \\    log(context.value)
        \\  end
    );
    defer lexer.deinit();
    
    const tokens = try lexer.scanTokens();
    
    try testing.expect(tokens.len > 0);
    try testing.expectEqual(TokenType.trigger, tokens[0].type);
    try testing.expectEqual(TokenType.identifier, tokens[1].type);
    try testing.expectEqualStrings("balance_changed", tokens[1].lexeme);
    try testing.expectEqual(TokenType.on, tokens[2].type);
    try testing.expectEqual(TokenType.identifier, tokens[3].type);
    try testing.expectEqualStrings("data_changed", tokens[3].lexeme);
} 