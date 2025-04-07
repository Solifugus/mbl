const std = @import("std");
const memory = @import("memory/memory.zig");
const value_mod = @import("memory/value.zig");

const MemoryManager = memory.MemoryManager;
const TriggerManager = memory.TriggerManager;
const Value = value_mod.Value;
const ValueType = value_mod.ValueType;
const Environment = value_mod.Environment;
const Interpreter = value_mod.Interpreter;
const AstNode = value_mod.AstNode;
const EventType = value_mod.EventType;

const RuntimeError = error{
    InvalidValue,
    InvalidOperation,
    OutOfMemory,
    UnknownVariable,
};

// VariableWatcher tracks which variables are watched by which triggers
pub const VariableWatcher = struct {
    allocator: std.mem.Allocator,
    watchers: std.StringHashMap(std.ArrayList(*Value)),
    
    pub fn init(allocator: std.mem.Allocator) VariableWatcher {
        return .{
            .allocator = allocator,
            .watchers = std.StringHashMap(std.ArrayList(*Value)).init(allocator),
        };
    }
    
    pub fn deinit(self: *VariableWatcher) void {
        var it = self.watchers.valueIterator();
        while (it.next()) |watcher_list| {
            watcher_list.deinit();
        }
        self.watchers.deinit();
    }
    
    pub fn registerVariable(self: *VariableWatcher, variable_name: []const u8, trigger: *Value) !void {
        const key = try self.allocator.dupe(u8, variable_name);
        errdefer self.allocator.free(key);
        
        var entry = try self.watchers.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(*Value).init(self.allocator);
        } else {
            // If the key already exists, free our copy
            self.allocator.free(key);
        }
        
        try entry.value_ptr.*.append(trigger);
    }
    
    pub fn getWatchers(self: VariableWatcher, variable_name: []const u8) ?[]const *Value {
        if (self.watchers.get(variable_name)) |watcher_list| {
            return watcher_list.items;
        }
        return null;
    }
};

// ChangeTracker records which variables have changed during the current moment
pub const ChangeTracker = struct {
    allocator: std.mem.Allocator,
    changed_variables: std.StringHashMap(bool),
    
    pub fn init(allocator: std.mem.Allocator) ChangeTracker {
        return .{
            .allocator = allocator,
            .changed_variables = std.StringHashMap(bool).init(allocator),
        };
    }
    
    pub fn deinit(self: *ChangeTracker) void {
        // Free all keys
        var key_it = self.changed_variables.keyIterator();
        while (key_it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.changed_variables.deinit();
    }
    
    pub fn markChanged(self: *ChangeTracker, variable_name: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, variable_name);
        errdefer self.allocator.free(key_copy);
        
        var entry = try self.changed_variables.getOrPut(key_copy);
        if (entry.found_existing) {
            // Key already exists, clean up our copy
            self.allocator.free(key_copy);
        }
        
        entry.value_ptr.* = true;
    }
    
    pub fn isChanged(self: ChangeTracker, variable_name: []const u8) bool {
        return self.changed_variables.get(variable_name) orelse false;
    }
    
    pub fn resetAllChanges(self: *ChangeTracker) void {
        var it = self.changed_variables.valueIterator();
        while (it.next()) |value| {
            value.* = false;
        }
    }
    
    pub fn getChangedVariables(self: ChangeTracker) !std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).init(self.allocator);
        errdefer result.deinit();
        
        var it = self.changed_variables.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.*) {
                try result.append(entry.key_ptr.*);
            }
        }
        
        return result;
    }
};

// ConstraintManager handles immediate validation and healing actions
pub const ConstraintManager = struct {
    allocator: std.mem.Allocator,
    constraints: std.ArrayList(*Value),
    interpreter: ?*Interpreter,
    
    pub fn init(allocator: std.mem.Allocator) ConstraintManager {
        return .{
            .allocator = allocator,
            .constraints = std.ArrayList(*Value).init(allocator),
            .interpreter = null,
        };
    }
    
    pub fn deinit(self: *ConstraintManager) void {
        self.constraints.deinit();
    }
    
    pub fn setInterpreter(self: *ConstraintManager, interpreter: *Interpreter) void {
        self.interpreter = interpreter;
    }
    
    pub fn registerConstraint(self: *ConstraintManager, constraint: *Value) !void {
        if (constraint.data != .constraint) {
            return RuntimeError.InvalidValue;
        }
        
        try self.constraints.append(constraint);
    }
    
    pub fn unregisterConstraint(self: *ConstraintManager, name: []const u8) bool {
        for (self.constraints.items, 0..) |constraint, i| {
            if (constraint.data == .constraint and std.mem.eql(u8, constraint.data.constraint.name, name)) {
                _ = self.constraints.orderedRemove(i);
                return true;
            }
        }
        
        return false;
    }
    
    // Check all constraints and return true if all pass
    pub fn validateAll(self: *ConstraintManager) !bool {
        if (self.interpreter == null) {
            return true; // No interpreter set, assume valid
        }
        
        for (self.constraints.items) |constraint| {
            if (!try self.validateConstraint(constraint)) {
                return false;
            }
        }
        
        return true;
    }
    
    // Check a specific variable against all constraints that might be affected
    pub fn validateVariable(self: *ConstraintManager, variable_name: []const u8, 
                           variable_watcher: *VariableWatcher) !bool {
        if (self.interpreter == null) {
            return true; // No interpreter set, assume valid
        }
        
        // Get all constraints that watch this variable
        const affected_constraints = try self.getConstraintsForVariable(variable_name, variable_watcher);
        defer affected_constraints.deinit();
        
        // Check each affected constraint
        for (affected_constraints.items) |constraint| {
            if (!try self.validateConstraint(constraint)) {
                return false;
            }
        }
        
        return true;
    }
    
    // Get all constraints that watch a specific variable
    fn getConstraintsForVariable(self: *ConstraintManager, variable_name: []const u8,
                               variable_watcher: *VariableWatcher) !std.ArrayList(*Value) {
        var result = std.ArrayList(*Value).init(self.allocator);
        errdefer result.deinit();
        
        // If we have watchers for this variable, check if any are constraints
        if (variable_watcher.getWatchers(variable_name)) |watchers| {
            for (watchers) |watcher_val| {
                if (watcher_val.data == .constraint) {
                    try result.append(watcher_val);
                }
            }
        }
        
        return result;
    }
    
    // Validate a single constraint
    fn validateConstraint(self: *ConstraintManager, constraint: *Value) !bool {
        if (constraint.data != .constraint or self.interpreter == null) {
            return true; // Not a constraint or no interpreter, assume valid
        }
        
        // Evaluate the condition
        const condition_result = try self.interpreter.?.evaluate(constraint.data.constraint.condition);
        
        // If condition is false (constraint violated), try healing action if available
        if (condition_result.data == .boolean and !condition_result.data.boolean) {
            if (constraint.data.constraint.healing_action) |healing_action| {
                // Execute healing action
                const healing_result = try self.interpreter.?.evaluate(healing_action);
                
                // The healing action should return a boolean indicating success
                if (healing_result.data == .boolean) {
                    return healing_result.data.boolean;
                }
                
                // If healing action doesn't return a boolean, assume it failed
                return false;
            } else {
                // No healing action, constraint is violated
                return false;
            }
        }
        
        // Condition is true, constraint is satisfied
        return true;
    }
};

// Runtime is the main execution environment for MBL programs
pub const Runtime = struct {
    allocator: std.mem.Allocator,
    memory_manager: MemoryManager,
    global_environment: *Environment,
    interpreter: *Interpreter,
    
    // Trigger system
    variable_watcher: VariableWatcher,
    change_tracker: ChangeTracker,
    
    // Constraint system
    constraint_manager: ConstraintManager,
    
    // Moment timing
    last_moment_time: i64, // milliseconds
    moment_duration: i64, // milliseconds (default: 333 ms = 1/3 second)
    moments_processed: usize,
    
    // Function pointers for custom behaviors
    evaluateTrigger: ?*const fn (*Runtime, *Value) anyerror!void = null,
    assignVariable: ?*const fn (*Runtime, []const u8, *Value) anyerror!void = null,
    processEndOfMoment: ?*const fn (*Runtime) anyerror!void = null,
    startEventLoop: ?*const fn (*Runtime) anyerror!void = null,
    
    // Runtime state
    running: bool,
    
    pub fn init(allocator: std.mem.Allocator) !*Runtime {
        var runtime = try allocator.create(Runtime);
        errdefer allocator.destroy(runtime);
        
        // Initialize memory manager
        runtime.memory_manager = MemoryManager.init(allocator);
        
        // Initialize environments
        runtime.global_environment = try runtime.memory_manager.createEnvironment();
        
        // Initialize interpreter
        runtime.interpreter = try runtime.memory_manager.createInterpreter();
        
        // Initialize trigger system
        runtime.variable_watcher = VariableWatcher.init(allocator);
        runtime.change_tracker = ChangeTracker.init(allocator);
        
        // Initialize constraint system
        runtime.constraint_manager = ConstraintManager.init(allocator);
        runtime.constraint_manager.setInterpreter(runtime.interpreter);
        
        // Initialize timing
        runtime.last_moment_time = getCurrentTimeMs();
        runtime.moment_duration = 333; // 1/3 second in milliseconds
        runtime.moments_processed = 0;
        
        // Initialize state
        runtime.running = false;
        
        // Finish initialization
        runtime.allocator = allocator;
        
        return runtime;
    }
    
    pub fn deinit(self: *Runtime) void {
        // Clean up trigger tracking
        self.variable_watcher.deinit();
        self.change_tracker.deinit();
        
        // Clean up constraint system
        self.constraint_manager.deinit();
        
        // Memory manager cleans up interpreter and environments
        self.memory_manager.deinit();
        
        // Finally free the runtime itself
        self.allocator.destroy(self);
    }
    
    // Execute AST and start the runtime
    pub fn execute(self: *Runtime, ast: *AstNode) !void {
        // Set running flag
        self.running = true;
        
        // Execute the main program
        _ = try self.interpreter.evaluate(ast);
        
        // Start the event loop
        if (self.startEventLoop) |startFn| {
            try startFn(self);
        } else {
            try self.startEventLoopInternal();
        }
    }
    
    // Main event loop
    pub fn startEventLoopInternal(self: *Runtime) !void {
        while (self.running) {
            // Check if it's time for a new moment
            const current_time = getCurrentTimeMs();
            if (current_time - self.last_moment_time >= self.moment_duration) {
                // Call the hook if it exists, otherwise process normally
                if (self.processEndOfMoment) |processFn| {
                    try processFn(self);
                } else {
                    try self.processEndOfMomentInternal();
                }
                self.last_moment_time = current_time;
                self.moments_processed += 1;
            }
            
            // Sleep a small amount to prevent CPU spinning
            std.time.sleep(10 * std.time.ns_per_ms);
        }
    }
    
    // End-of-moment processing 
    pub fn processEndOfMomentInternal(self: *Runtime) !void {
        // Get all changed variables
        var changed_vars = try self.change_tracker.getChangedVariables();
        defer changed_vars.deinit();
        
        // Collect triggers to evaluate
        var triggers_to_evaluate = std.AutoHashMap(*Value, void).init(self.allocator);
        defer triggers_to_evaluate.deinit();
        
        // Find all triggers with changed variables
        for (changed_vars.items) |var_name| {
            if (self.variable_watcher.getWatchers(var_name)) |watchers| {
                for (watchers) |trigger| {
                    try triggers_to_evaluate.put(trigger, {});
                }
            }
        }
        
        // Evaluate each unique trigger once
        var trigger_it = triggers_to_evaluate.keyIterator();
        while (trigger_it.next()) |trigger| {
            if (self.evaluateTrigger) |evalFn| {
                try evalFn(self, trigger.*);
            }
        }
        
        // Reset all changed flags for the next moment
        self.change_tracker.resetAllChanges();
    }
    
    // Evaluate a single trigger
    pub fn evaluateTrigger(self: *Runtime, trigger: *Value) !void {
        if (trigger.data != .trigger) {
            return RuntimeError.InvalidValue;
        }
        
        // Create context for the trigger evaluation
        var context = try self.memory_manager.allocateRecord();
        try self.memory_manager.recordSet(context, "moment", try self.memory_manager.allocateNumber(
            @floatFromInt(self.moments_processed)
        ));
        
        // Evaluate the condition
        const condition_result = try self.interpreter.evaluate(trigger.data.trigger.condition);
        
        // Execute the action if condition is true
        if (condition_result.data == .boolean and condition_result.data.boolean) {
            _ = try self.interpreter.evaluate(trigger.data.trigger.action);
        }
    }
    
    // Register a trigger with variables it watches
    pub fn registerTrigger(self: *Runtime, trigger: *Value) !void {
        if (trigger.data != .trigger) {
            return RuntimeError.InvalidValue;
        }
        
        // Register with the trigger manager
        try self.memory_manager.registerTrigger(trigger);
        
        // Extract variables from the condition
        var variables = try self.extractVariablesFromExpression(trigger.data.trigger.condition);
        defer variables.deinit();
        
        // Register the trigger as watching these variables
        for (variables.items) |var_name| {
            try self.variable_watcher.registerVariable(var_name, trigger);
        }
    }
    
    // Register a constraint with variables it watches
    pub fn registerConstraint(self: *Runtime, constraint: *Value) !void {
        if (constraint.data != .constraint) {
            return RuntimeError.InvalidValue;
        }
        
        // Register with the constraint manager
        try self.constraint_manager.registerConstraint(constraint);
        
        // Extract variables from the condition
        var variables = try self.extractVariablesFromExpression(constraint.data.constraint.condition);
        defer variables.deinit();
        
        // Register the constraint as watching these variables
        for (variables.items) |var_name| {
            try self.variable_watcher.registerVariable(var_name, constraint);
        }
        
        // If healing action exists, extract variables from it too
        if (constraint.data.constraint.healing_action) |healing_action| {
            var healing_vars = try self.extractVariablesFromExpression(healing_action);
            defer healing_vars.deinit();
            
            // Register the constraint as watching these variables as well
            for (healing_vars.items) |var_name| {
                try self.variable_watcher.registerVariable(var_name, constraint);
            }
        }
        
        // Validate the constraint immediately
        if (!try self.constraint_manager.validateConstraint(constraint)) {
            return RuntimeError.InvalidValue; // Constraint is already violated
        }
    }
    
    // Extract variables from an expression
    pub fn extractVariablesFromExpression(self: *Runtime, node: *AstNode) !std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).init(self.allocator);
        errdefer result.deinit();
        
        switch (node.node_type) {
            .identifier => {
                try result.append(try self.allocator.dupe(u8, node.data.identifier));
            },
            .binary_expression => {
                var left_vars = try self.extractVariablesFromExpression(node.data.binary_expression.left);
                defer left_vars.deinit();
                
                var right_vars = try self.extractVariablesFromExpression(node.data.binary_expression.right);
                defer right_vars.deinit();
                
                try result.appendSlice(left_vars.items);
                try result.appendSlice(right_vars.items);
            },
            .unary_expression => {
                var operand_vars = try self.extractVariablesFromExpression(node.data.unary_expression.operand);
                defer operand_vars.deinit();
                
                try result.appendSlice(operand_vars.items);
            },
            .member_access => {
                // Add full path as a watched variable
                var base_vars = try self.extractVariablesFromExpression(node.data.member_access.object);
                defer base_vars.deinit();
                
                // If the base is a simple identifier, create the dot path
                if (base_vars.items.len == 1 and 
                    node.data.member_access.object.node_type == .identifier) {
                    const path = try std.fmt.allocPrint(
                        self.allocator,
                        "{s}.{s}",
                        .{node.data.member_access.object.data.identifier, node.data.member_access.member}
                    );
                    try result.append(path);
                } else {
                    // Otherwise, just add the base variables
                    try result.appendSlice(base_vars.items);
                }
            },
            .call_expression => {
                // Extract variables from callee and arguments
                var callee_vars = try self.extractVariablesFromExpression(node.data.call_expression.callee);
                defer callee_vars.deinit();
                
                try result.appendSlice(callee_vars.items);
                
                for (node.data.call_expression.arguments) |arg| {
                    var arg_vars = try self.extractVariablesFromExpression(arg);
                    defer arg_vars.deinit();
                    
                    try result.appendSlice(arg_vars.items);
                }
            },
            else => {}, // Other node types don't reference variables
        }
        
        return result;
    }
    
    // Mark a variable as changed during the current moment
    pub fn markVariableChanged(self: *Runtime, name: []const u8) !void {
        try self.change_tracker.markChanged(name);
    }
    
    // Handle variable assignment and change tracking
    pub fn assignVariable(self: *Runtime, name: []const u8, new_value: *Value) !void {
        // Get the current value (if any)
        const old_value = self.global_environment.get(name);
        
        // Determine if this is an actual change
        const is_real_change = if (old_value) |v| 
            self.memory_manager.compare(v, new_value) catch null != @as(?i32, 0)
        else 
            true;  // Variable didn't exist before
        
        // First, set the value temporarily
        try self.global_environment.define(name, new_value);
        
        // Check constraints if this is a real change
        if (is_real_change) {
            // Validate constraints that depend on this variable
            const validation_result = try self.constraint_manager.validateVariable(name, &self.variable_watcher);
            
            if (!validation_result) {
                // Constraint violation
                if (old_value) |v| {
                    // Roll back to previous value
                    try self.global_environment.define(name, v);
                    return RuntimeError.InvalidValue;
                } else {
                    // No previous value, remove the variable
                    _ = self.global_environment.get(name); // TODO: Proper variable removal
                    return RuntimeError.InvalidValue;
                }
            }
            
            // If we get here, constraints passed
            try self.markVariableChanged(name);
        }
    }
    
    // Terminate the runtime
    pub fn stop(self: *Runtime) void {
        self.running = false;
    }
};

// Utility function to get current time in milliseconds
fn getCurrentTimeMs() i64 {
    return @divFloor(std.time.milliTimestamp(), @as(i64, std.time.ns_per_ms));
}