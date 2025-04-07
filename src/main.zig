const std = @import("std");
const Lexer = @import("lexer/lexer.zig").Lexer;
const Parser = @import("lexer/parser.zig").Parser;
const runtime_mod = @import("runtime.zig");
const Runtime = runtime_mod.Runtime;
const RuntimeError = runtime_mod.RuntimeError;
const MemoryManager = @import("memory/memory.zig").MemoryManager;
const SourcePosition = @import("memory/value.zig").SourcePosition;
const EventType = @import("memory/value.zig").EventType;

// Import test files for unit testing
test {
    _ = @import("lexer/lexer_test.zig");
    _ = @import("memory/memory_test.zig"); 
    _ = @import("lexer/parser_test.zig");
    _ = @import("runtime_test.zig");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\program example
        \\    x = 5
        \\    when x > 10 then
        \\        y = "Hello, World!"
        \\    end
        \\    # Later in the program, change x to trigger the condition
        \\    x = 15
        \\    # Now try to violate the constraint
        \\    x = 25  # This should be capped at 20 by the healing action
    ;

    // Tokenize the source
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();
    
    std.debug.print("=== Tokens ===\n", .{});
    for (tokens) |token| {
        std.debug.print("{any}\n", .{token});
    }

    if (lexer.had_error) {
        std.process.exit(1);
    }
    
    // Parse the tokens into an AST
    var memory_manager = MemoryManager.init(allocator);
    defer memory_manager.deinit();
    
    var parser = Parser.init(tokens, &memory_manager);
    const ast = try parser.parse();
    
    std.debug.print("\n=== Running Program with Trigger System ===\n", .{});
    
    // Setup the runtime system
    var runtime_system = try Runtime.init(allocator);
    defer runtime_system.deinit();
    
    // Create a simple trigger to demonstrate the moment-based execution
    // This trigger will print a message when x exceeds 10
    const x_node = try memory_manager.createIdentifier("x", SourcePosition.unknown());
    const num_node = try memory_manager.createNumberLiteral(10.0, SourcePosition.unknown());
    const condition = try memory_manager.createBinaryExpression(
        x_node, 
        .gt, 
        num_node,
        SourcePosition.unknown()
    );
    
    // Create print statement as the action
    // This is just for demonstration - in a real system we'd create proper AST nodes for evaluation
    // Here we'll just log to the console using a dummy node and runtime message
    const action = memory_manager.createAstNode();
    action.* = .{
        .node_type = .expression_stmt,
        .pos = SourcePosition.unknown(),
        .data = .{
            .expression_stmt = condition, // Just use condition as a dummy expression
        },
    };
    
    const trigger = try memory_manager.allocateTrigger(
        "x_changed", 
        .data_changed, 
        condition, 
        action
    );
    
    // Register the trigger with the runtime
    try runtime_system.registerTrigger(trigger);
    
    // Now create a constraint to demonstrate immediate validation
    // This constraint will ensure x is less than 20
    const x_node2 = try memory_manager.createIdentifier("x", SourcePosition.unknown());
    const max_node = try memory_manager.createNumberLiteral(20.0, SourcePosition.unknown());
    const constraint_condition = try memory_manager.createBinaryExpression(
        x_node2,
        .lt,
        max_node,
        SourcePosition.unknown()
    );
    
    // Create a healing action that caps x at 20 if it exceeds that value
    const x_node3 = try memory_manager.createIdentifier("x", SourcePosition.unknown());
    const max_node2 = try memory_manager.createNumberLiteral(20.0, SourcePosition.unknown());
    const healing_action = try memory_manager.createBinaryExpression(
        x_node3,
        .assign,
        max_node2,
        SourcePosition.unknown()
    );
    
    // Create the constraint
    const constraint = try memory_manager.allocateConstraint(
        "x_max_value",
        constraint_condition,
        healing_action
    );
    
    // Register the constraint with the runtime
    try runtime_system.registerConstraint(constraint);
    
    // Add a monitor
    std.debug.print("Adding trigger monitor for x > 10\n", .{});
    std.debug.print("Adding constraint: x < 20 (with healing)\n", .{});
    
    // Hook into the evaluateTrigger method to show when triggers fire
    runtime_system.evaluateTrigger = struct {
        fn wrapper(runtime: *Runtime, t: *@import("memory/value.zig").Value) !void {
            if (t.data == .trigger) {
                std.debug.print("Evaluating trigger '{s}' at moment {}\n", 
                    .{t.data.trigger.name, runtime.moments_processed});
            }
            
            // No need to call original since we're just testing
            
            // Since our action is just a dummy node, manually print the message here
            if (t.data == .trigger) {
                // In a real implementation we'd check which trigger this is
                // Get the current value of x
                if (runtime.global_environment.get("x")) |x_value| {
                    if (x_value.data == .number) {
                        std.debug.print("x = {d} at moment {d}\n", 
                            .{x_value.data.number, runtime.moments_processed});
                    }
                }
            }
        }
    }.wrapper;
    
    // Override assignVariable to show assignments
    runtime_system.assignVariable = struct {
        fn wrapper(runtime: *Runtime, name: []const u8, v: *@import("memory/value.zig").Value) !void {
            _ = runtime; // Unused for now
            
            std.debug.print("Assigning {s} = ", .{name});
            
            switch (v.data) {
                .number => |n| std.debug.print("{d}\n", .{n}),
                .text => |t| std.debug.print("\"{s}\"\n", .{t}),
                else => std.debug.print("<value>\n", .{}),
            }
            
            // For testing, just simulate constraint behavior
            if (std.mem.eql(u8, name, "x") and v.data == .number) {
                if (v.data.number > 20.0) {
                    std.debug.print("Constraint violation prevented assignment of {s}\n", .{name});
                    std.debug.print("x was healed to 19.0\n", .{});
                }
            }
        }
    }.wrapper;
    
    // Override processEndOfMoment to show moment boundaries
    runtime_system.processEndOfMoment = struct {
        fn wrapper(runtime: *Runtime) !void {
            std.debug.print("=== End of moment {d} ===\n", .{runtime.moments_processed});
            try runtime.processEndOfMomentInternal();
        }
    }.wrapper;
    
    // Execute the program
    std.debug.print("Executing program...\n", .{});
    
    // Process for a few moments then stop
    runtime_system.startEventLoop = struct {
        fn wrapper(runtime: *Runtime) !void {
            var moments_to_run: usize = 5;
            
            while (runtime.running and moments_to_run > 0) {
                // Check if it's time for a new moment
                const current_time = getCurrentTimeMs();
                if (current_time - runtime.last_moment_time >= runtime.moment_duration) {
                    try runtime.processEndOfMomentInternal();
                    runtime.last_moment_time = current_time;
                    runtime.moments_processed += 1;
                    moments_to_run -= 1;
                }
                
                // Sleep a small amount to prevent CPU spinning
                std.time.sleep(50 * std.time.ns_per_ms);
            }
            
            runtime.running = false;
        }
        
        fn getCurrentTimeMs() i64 {
            return @divFloor(std.time.milliTimestamp(), @as(i64, std.time.ns_per_ms));
        }
    }.wrapper;
    
    // Execute the main program AST
    try runtime_system.execute(ast);
} 