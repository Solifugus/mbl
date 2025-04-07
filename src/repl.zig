const std = @import("std");
const Lexer = @import("lexer/lexer.zig").Lexer;
const Parser = @import("lexer/parser.zig").Parser;
const runtime_mod = @import("runtime.zig");
const Runtime = runtime_mod.Runtime;
const RuntimeError = runtime_mod.RuntimeError;
const MemoryManager = @import("memory/memory.zig").MemoryManager;
const SourcePosition = @import("memory/value.zig").SourcePosition;
const Value = @import("memory/value.zig").Value;
const AstNode = @import("memory/value.zig").AstNode;
const AstNodeType = @import("memory/value.zig").AstNodeType;
const EventType = @import("memory/value.zig").EventType;

pub const Repl = struct {
    allocator: std.mem.Allocator,
    runtime: *Runtime,
    memory_manager: MemoryManager,
    stdin: std.fs.File.Reader,
    stdout: std.fs.File.Writer,
    running: bool,
    history: std.ArrayList([]const u8),
    
    // For multi-line input support
    buffer: std.ArrayList(u8),
    indentation_level: usize,
    
    pub fn init(allocator: std.mem.Allocator) !*Repl {
        var repl = try allocator.create(Repl);
        errdefer allocator.destroy(repl);
        
        repl.* = .{
            .allocator = allocator,
            .memory_manager = MemoryManager.init(allocator),
            .stdin = std.io.getStdIn().reader(),
            .stdout = std.io.getStdOut().writer(),
            .running = false,
            .history = std.ArrayList([]const u8).init(allocator),
            .buffer = std.ArrayList(u8).init(allocator),
            .indentation_level = 0,
            .runtime = undefined, // Will be set below
        };
        
        // Initialize the runtime after the repl is set up
        repl.runtime = try Runtime.init(allocator);
        
        return repl;
    }
    
    pub fn deinit(self: *Repl) void {
        // Free all history entries
        for (self.history.items) |entry| {
            self.allocator.free(entry);
        }
        self.history.deinit();
        
        // Free input buffer
        self.buffer.deinit();
        
        // Clean up runtime
        self.runtime.deinit();
        
        // Clean up memory manager
        self.memory_manager.deinit();
        
        // Free the REPL itself
        self.allocator.destroy(self);
    }
    
    pub fn start(self: *Repl) !void {
        self.running = true;
        
        try self.welcome();
        
        while (self.running) {
            try self.prompt();
            try self.readCommand();
        }
    }
    
    fn welcome(self: *Repl) !void {
        try self.stdout.print(
            \\Modern Business Language (MBL) REPL
            \\Version 0.1.0
            \\Type 'help' for assistance, 'exit' to quit
            \\
            \\
        , .{});
    }
    
    fn prompt(self: *Repl) !void {
        if (self.indentation_level > 0) {
            var indent_buf: [100]u8 = undefined;
            var indent_len: usize = 0;
            
            // Copy the base indentation prefix
            const prefix = "... ";
            std.mem.copy(u8, indent_buf[0..], prefix);
            indent_len += prefix.len;
            
            // Add spaces based on indentation level
            const spaces_to_add = self.indentation_level * 4;
            for (0..spaces_to_add) |_| {
                if (indent_len < indent_buf.len) {
                    indent_buf[indent_len] = ' ';
                    indent_len += 1;
                }
            }
            
            try self.stdout.print("{s}", .{indent_buf[0..indent_len]});
        } else {
            try self.stdout.print("mbl> ", .{});
        }
    }
    
    fn readCommand(self: *Repl) !void {
        var line_buffer: [1024]u8 = undefined;
        const line = (try self.stdin.readUntilDelimiterOrEof(&line_buffer, '\n')) orelse {
            self.running = false;
            try self.stdout.print("\nExiting...\n", .{});
            return;
        };
        
        // Add the line to our input buffer
        try self.buffer.appendSlice(line);
        try self.buffer.append('\n');
        
        // Track indentation level for multi-line input
        self.updateIndentationLevel(line);
        
        // If we're still collecting a multi-line command, wait for more input
        if (self.indentation_level > 0) {
            return;
        }
        
        // Get the full command from the buffer
        const command = try self.allocator.dupe(u8, self.buffer.items);
        defer self.allocator.free(command);
        
        // Reset buffer for next command
        self.buffer.clearRetainingCapacity();
        
        // Process the command
        try self.processCommand(command);
    }
    
    fn updateIndentationLevel(self: *Repl, line: []const u8) void {
        // Trim the line
        var trimmed = std.mem.trim(u8, line, " \t\r\n");
        
        // Empty line doesn't change indentation
        if (trimmed.len == 0) {
            return;
        }
        
        // Check for block-ending keywords
        if (std.mem.eql(u8, trimmed, "end") or 
            std.mem.eql(u8, trimmed, "endif") or 
            std.mem.eql(u8, trimmed, "endwhile") or 
            std.mem.eql(u8, trimmed, "endfor")) {
            if (self.indentation_level > 0) {
                self.indentation_level -= 1;
            }
            return;
        }
        
        // Check for block-starting constructs
        if (std.mem.endsWith(u8, trimmed, ":") or 
            std.mem.endsWith(u8, trimmed, "then") or 
            std.mem.endsWith(u8, trimmed, "do")) {
            self.indentation_level += 1;
            return;
        }
    }
    
    fn processCommand(self: *Repl, command: []const u8) !void {
        // Save to history if not empty
        if (command.len > 0 and !std.mem.eql(u8, command, "\n")) {
            const history_entry = try self.allocator.dupe(u8, command);
            try self.history.append(history_entry);
        }
        
        // Handle built-in commands
        if (self.handleBuiltinCommand(command)) {
            return;
        }
        
        // Wrap the command in a program block if it's not already one
        var full_source: []const u8 = undefined;
        if (std.mem.indexOf(u8, command, "program") == null) {
            var program_buf = std.ArrayList(u8).init(self.allocator);
            defer program_buf.deinit();
            
            try program_buf.appendSlice("program repl_command\n");
            try program_buf.appendSlice(command);
            try program_buf.appendSlice("\nend");
            
            full_source = try program_buf.toOwnedSlice();
            defer self.allocator.free(full_source);
        } else {
            full_source = command;
        }
        
        // Execute the command
        try self.executeSource(full_source);
    }
    
    fn handleBuiltinCommand(self: *Repl, command: []const u8) bool {
        var trimmed = std.mem.trim(u8, command, " \t\r\n");
        
        if (std.mem.eql(u8, trimmed, "exit") or std.mem.eql(u8, trimmed, "quit")) {
            self.running = false;
            self.stdout.print("Exiting...\n", .{}) catch {};
            return true;
        }
        
        if (std.mem.eql(u8, trimmed, "help")) {
            self.showHelp() catch {};
            return true;
        }
        
        if (std.mem.eql(u8, trimmed, "clear")) {
            // Clear screen using ANSI escape sequence
            self.stdout.print("\x1B[2J\x1B[H", .{}) catch {};
            return true;
        }
        
        if (std.mem.eql(u8, trimmed, "history")) {
            self.showHistory() catch {};
            return true;
        }
        
        if (std.mem.startsWith(u8, trimmed, "!")) {
            self.executeHistory(trimmed[1..]) catch {};
            return true;
        }
        
        if (std.mem.eql(u8, trimmed, "reset")) {
            self.resetRuntime() catch {};
            return true;
        }
        
        if (std.mem.eql(u8, trimmed, "vars")) {
            self.showVariables() catch {};
            return true;
        }
        
        if (std.mem.eql(u8, trimmed, "triggers")) {
            self.showTriggers() catch {};
            return true;
        }
        
        if (std.mem.eql(u8, trimmed, "constraints")) {
            self.showConstraints() catch {};
            return true;
        }
        
        return false;
    }
    
    fn showHelp(self: *Repl) !void {
        try self.stdout.print(
            \\MBL REPL Commands:
            \\
            \\  exit, quit    - Exit the REPL
            \\  help          - Show this help message
            \\  clear         - Clear the screen
            \\  history       - Show command history
            \\  !<num>        - Execute command from history by number
            \\  reset         - Reset the runtime environment
            \\  vars          - Show all defined variables
            \\  triggers      - Show all defined triggers
            \\  constraints   - Show all defined constraints
            \\
            \\MBL Language Examples:
            \\
            \\  x = 5                       - Assign a value to a variable
            \\  y = x * 2                   - Expressions with variables
            \\  when x > 10:                - Define a trigger
            \\      y = "x is greater than 10"
            \\  end
            \\  constrain x < 20:           - Define a constraint
            \\      x = 20                  - With healing action
            \\  end
            \\
        , .{});
    }
    
    fn showHistory(self: *Repl) !void {
        if (self.history.items.len == 0) {
            try self.stdout.print("No history yet.\n", .{});
            return;
        }
        
        for (self.history.items, 0..) |entry, i| {
            try self.stdout.print("{d}: {s}", .{ i, entry });
            // Add newline if not already present
            if (entry.len == 0 or entry[entry.len - 1] != '\n') {
                try self.stdout.print("\n", .{});
            }
        }
    }
    
    fn executeHistory(self: *Repl, index_str: []const u8) !void {
        var trimmed = std.mem.trim(u8, index_str, " \t\r\n");
        
        if (trimmed.len == 0) {
            // Execute last command
            if (self.history.items.len == 0) {
                try self.stdout.print("No history to execute.\n", .{});
                return;
            }
            
            const last_command = self.history.items[self.history.items.len - 1];
            try self.stdout.print("Executing: {s}", .{last_command});
            try self.processCommand(last_command);
            return;
        }
        
        // Parse the index
        const index = std.fmt.parseInt(usize, trimmed, 10) catch {
            try self.stdout.print("Invalid history index: {s}\n", .{trimmed});
            return;
        };
        
        if (index >= self.history.items.len) {
            try self.stdout.print("History index out of range: {d}\n", .{index});
            return;
        }
        
        const command = self.history.items[index];
        try self.stdout.print("Executing: {s}", .{command});
        try self.processCommand(command);
    }
    
    fn resetRuntime(self: *Repl) !void {
        // Clean up old runtime
        self.runtime.deinit();
        
        // Create new runtime
        self.runtime = try Runtime.init(self.allocator);
        
        try self.stdout.print("Runtime environment reset.\n", .{});
    }
    
    fn showVariables(self: *Repl) !void {
        // TODO: Implement fetching variables from the runtime's global environment
        try self.stdout.print("Variables in global environment:\n", .{});
        
        const env = self.runtime.global_environment;
        var count: usize = 0;
        
        // Get all keys in the environment
        var iter = env.variables.iterator();
        while (iter.next()) |entry| {
            var key = entry.key_ptr.*;
            var value = entry.value_ptr.*;
            
            std.debug.print("  {s} = {any}\n", .{ key, value });
            count += 1;
        }
        
        if (count == 0) {
            try self.stdout.print("  No variables defined.\n", .{});
        }
    }
    
    fn showTriggers(self: *Repl) !void {
        // TODO: Implement showing trigger information
        try self.stdout.print("Defined triggers:\n", .{});
        try self.stdout.print("  Feature not yet implemented.\n", .{});
    }
    
    fn showConstraints(self: *Repl) !void {
        // TODO: Implement showing constraint information
        try self.stdout.print("Defined constraints:\n", .{});
        try self.stdout.print("  Feature not yet implemented.\n", .{});
    }
    
    fn executeSource(self: *Repl, source: []const u8) !void {
        // Set up tokenizer
        var lexer = Lexer.init(self.allocator, source);
        defer lexer.deinit();
        
        const tokens = lexer.scanTokens() catch |err| {
            try self.stdout.print("Lexer error: {any}\n", .{err});
            return;
        };
        
        if (lexer.had_error) {
            try self.stdout.print("Lexical analysis failed with errors.\n", .{});
            return;
        }
        
        // Set up parser
        var parser = Parser.init(tokens, &self.memory_manager);
        const ast = parser.parse() catch |err| {
            try self.stdout.print("Parser error: {any}\n", .{err});
            return;
        };
        
        if (parser.had_error) {
            try self.stdout.print("Parsing failed with errors.\n", .{});
            return;
        }
        
        // Execute the AST
        self.runtime.execute(ast) catch |err| {
            try self.stdout.print("Runtime error: {any}\n", .{err});
            return;
        };
        
        try self.stdout.print("Command executed successfully.\n", .{});
    }
};

// Main entry point for the REPL
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var repl = try Repl.init(allocator);
    defer repl.deinit();
    
    try repl.start();
}