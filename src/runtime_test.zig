const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime.zig");
const memory = @import("memory/memory.zig");
const value = @import("memory/value.zig");

const Runtime = runtime.Runtime;
const MemoryManager = memory.MemoryManager;
const Value = value.Value;
const AstNode = value.AstNode;
const SourcePosition = value.SourcePosition;
const EventType = value.EventType;
const OperatorType = value.OperatorType;

// Mock value for testing change detection
fn createCounter() !struct { mm: MemoryManager, counter: *Value } {
    var mm = MemoryManager.init(testing.allocator);
    var counter = try mm.allocateNumber(0);
    return .{ .mm = mm, .counter = counter };
}

test "VariableWatcher - basic operations" {
    var watcher = runtime.VariableWatcher.init(testing.allocator);
    defer watcher.deinit();
    
    var mm = MemoryManager.init(testing.allocator);
    defer mm.deinit();
    
    // Create a mock trigger
    const trigger = try mm.allocateTrigger(
        "test_trigger", 
        .data_changed, 
        mm.createAstNode(), // Dummy nodes
        mm.createAstNode()
    );
    
    // Register variable
    try watcher.registerVariable("x", trigger);
    
    // Verify watcher list
    const watchers = watcher.getWatchers("x").?;
    try testing.expectEqual(@as(usize, 1), watchers.len);
    try testing.expectEqual(trigger, watchers[0]);
    
    // Non-existent variable
    try testing.expectEqual(@as(?[]const *Value, null), watcher.getWatchers("y"));
    
    // Register another trigger for the same variable
    const trigger2 = try mm.allocateTrigger(
        "test_trigger2", 
        .data_changed, 
        mm.createAstNode(),
        mm.createAstNode()
    );
    
    try watcher.registerVariable("x", trigger2);
    
    // Verify updated watcher list
    const watchers_updated = watcher.getWatchers("x").?;
    try testing.expectEqual(@as(usize, 2), watchers_updated.len);
}

test "ChangeTracker - basic operations" {
    var tracker = runtime.ChangeTracker.init(testing.allocator);
    defer tracker.deinit();
    
    // Mark some variables as changed
    try tracker.markChanged("x");
    try tracker.markChanged("y");
    
    // Check if variables are marked as changed
    try testing.expect(tracker.isChanged("x"));
    try testing.expect(tracker.isChanged("y"));
    try testing.expect(!tracker.isChanged("z"));
    
    // Get list of changed variables
    var changed = try tracker.getChangedVariables();
    defer changed.deinit();
    
    try testing.expectEqual(@as(usize, 2), changed.items.len);
    
    // Reset changes
    tracker.resetAllChanges();
    
    // Verify reset worked
    try testing.expect(!tracker.isChanged("x"));
    try testing.expect(!tracker.isChanged("y"));
}

test "Runtime - variable extraction from expression" {
    // Create runtime
    var rt = try Runtime.init(testing.allocator);
    defer rt.deinit();
    
    // Create a binary expression: x > 10
    const x_node = try rt.memory_manager.createIdentifier("x", SourcePosition.unknown());
    const num_node = try rt.memory_manager.createNumberLiteral(10.0, SourcePosition.unknown());
    const expr = try rt.memory_manager.createBinaryExpression(
        x_node, 
        .gt, 
        num_node,
        SourcePosition.unknown()
    );
    
    // Extract variables
    var variables = try rt.extractVariablesFromExpression(expr);
    defer variables.deinit();
    
    // Verify
    try testing.expectEqual(@as(usize, 1), variables.items.len);
    try testing.expectEqualStrings("x", variables.items[0]);
    
    // Create a more complex expression: x + y.z > foo(a, b.c)
    const y_node = try rt.memory_manager.createIdentifier("y", SourcePosition.unknown());
    const y_z_node = try rt.memory_manager.createBinaryExpression(
        y_node,
        .member_access,
        try rt.memory_manager.createTextLiteral("z", SourcePosition.unknown()),
        SourcePosition.unknown()
    );
    const x_plus_y_z = try rt.memory_manager.createBinaryExpression(
        x_node,
        .add,
        y_z_node,
        SourcePosition.unknown()
    );
    
    const a_node = try rt.memory_manager.createIdentifier("a", SourcePosition.unknown());
    const b_node = try rt.memory_manager.createIdentifier("b", SourcePosition.unknown());
    const b_c_node = try rt.memory_manager.createBinaryExpression(
        b_node,
        .member_access,
        try rt.memory_manager.createTextLiteral("c", SourcePosition.unknown()),
        SourcePosition.unknown()
    );
    
    const args = [_]*AstNode{ a_node, b_c_node };
    const foo_node = try rt.memory_manager.createIdentifier("foo", SourcePosition.unknown());
    const call_node = rt.memory_manager.createAstNode();
    call_node.* = .{
        .node_type = .call_expression,
        .pos = SourcePosition.unknown(),
        .data = .{
            .call_expression = .{
                .callee = foo_node,
                .arguments = &args,
            },
        },
    };
    
    const complex_expr = try rt.memory_manager.createBinaryExpression(
        x_plus_y_z,
        .gt,
        call_node,
        SourcePosition.unknown()
    );
    
    // Extract variables from complex expression
    var complex_vars = try rt.extractVariablesFromExpression(complex_expr);
    defer complex_vars.deinit();
    
    // Verify (should find x, y.z, foo, a, b.c)
    try testing.expectEqual(@as(usize, 5), complex_vars.items.len);
    
    // We need to check if each expected variable is in the list
    // (order may vary since we're concatenating arrays)
    var found_x = false;
    var found_y_z = false;
    var found_foo = false;
    var found_a = false;
    var found_b_c = false;
    
    for (complex_vars.items) |v| {
        if (std.mem.eql(u8, v, "x")) found_x = true;
        if (std.mem.eql(u8, v, "y.z")) found_y_z = true;
        if (std.mem.eql(u8, v, "foo")) found_foo = true;
        if (std.mem.eql(u8, v, "a")) found_a = true;
        if (std.mem.eql(u8, v, "b.c")) found_b_c = true;
    }
    
    try testing.expect(found_x);
    try testing.expect(found_y_z);
    try testing.expect(found_foo);
    try testing.expect(found_a);
    try testing.expect(found_b_c);
}