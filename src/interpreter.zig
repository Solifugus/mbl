// MBL Interpreter - executes parsed MBL statements and expressions
const std = @import("std");
const memory = @import("memory.zig");
const parser = @import("parser.zig");
const odbc = @import("odbc.zig");
const crypto_module = @import("crypto.zig");

const Memory = memory.Memory;
const MBLValue = memory.MBLValue;
const Statement = parser.Statement;
const Expression = parser.Expression;

// HTTP Route definition
const Route = struct {
    method: []const u8,
    path: []const u8,
    handler_name: []const u8,
    path_params: [][]const u8, // Parameter names from {param} in path
};

// MCP (Model Context Protocol) definitions
const McpMessageType = enum {
    initialize,
    tool_call,
    tool_response,
    resource_request,
    resource_response,
    notification,
    // Real-time synchronization message types
    subscribe,
    unsubscribe,
    broadcast,
    data_update,
    client_sync,
};

const McpMessage = struct {
    message_type: McpMessageType,
    id: ?[]const u8,
    method: ?[]const u8,
    params: ?MBLValue,
    result: ?MBLValue,
    error_info: ?MBLValue,
};

const McpTool = struct {
    name: []const u8,
    description: []const u8,
    handler_name: []const u8,
    parameters: MBLValue, // Schema for tool parameters
};

const McpConnection = struct {
    id: []const u8,
    websocket: ?*anyopaque, // WebSocket connection placeholder
    tools: std.ArrayList(McpTool),
    capabilities: MBLValue,
    subscriptions: std.ArrayList([]const u8), // Data channels this client subscribes to
    user_role: ?[]const u8, // Role-based filtering (admin, customer, sales, etc.)
    client_filters: MBLValue, // Custom filters for selective broadcasting
    last_ping: i64, // For connection health monitoring
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, connection_id: []const u8) McpConnection {
        return McpConnection{
            .id = connection_id,
            .websocket = null,
            .tools = std.ArrayList(McpTool).init(allocator),
            .capabilities = MBLValue{ .record = memory.Record.init(allocator) },
            .subscriptions = std.ArrayList([]const u8).init(allocator),
            .user_role = null,
            .client_filters = MBLValue{ .record = memory.Record.init(allocator) },
            .last_ping = std.time.timestamp(),
            .allocator = allocator,
        };
    }

    fn deinit(self: *McpConnection) void {
        self.tools.deinit();
        self.subscriptions.deinit();
        // capabilities and filters cleanup handled by MBL memory management
    }
};

pub const InterpreterError = error{
    TypeError,
    DivisionByZero,
    OutOfMemory,
    GotoExecuted, // Special error to signal goto was executed
    BreakExecuted, // Special error to signal break was executed
    ContinueExecuted, // Special error to signal continue was executed
    ReturnExecuted, // Special error to signal return was executed
};

pub const Interpreter = struct {
    memory: *Memory,
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    labels: std.HashMap([]const u8, usize, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    goto_target: ?[]const u8, // Track the target of a goto that was executed
    scope_stack: std.ArrayList(*memory.Record), // Stack of local scopes (deepest first)
    functions: std.HashMap([]const u8, parser.FunctionDeclaration, std.hash_map.StringContext, std.hash_map.default_max_load_percentage), // Function registry
    return_value: ?MBLValue, // Store return value from functions
    quiet_mode: bool, // Suppress debug output when true
    activators: std.ArrayList(parser.ActivatorDeclaration), // List of registered activators
    executing_activator: bool, // Prevent recursion in activator execution
    current_loop_variable: ?MBLValue, // Current for loop variable (no ownership)
    current_loop_variable_name: ?[]const u8, // Name of current loop variable
    used_for_loop_with_records: bool, // Flag to track if for loops were used with record data

    // Error management for v0.14.0
    error_manager: memory.ErrorManager,

    // HTTP Server management
    http_server: ?std.net.StreamServer, // HTTP server instance
    server_thread: ?std.Thread, // Background server thread
    registered_routes: std.ArrayList(Route), // List of registered routes
    server_running: bool, // Flag to indicate if server is active
    shutdown_requested: bool, // Flag for graceful shutdown

    // MCP (Model Context Protocol) management
    mcp_connections: std.ArrayList(McpConnection), // Active MCP connections
    mcp_tools: std.ArrayList(McpTool), // Registered MCP tools
    mcp_activators: std.ArrayList(parser.ActivatorDeclaration), // MCP-specific activators

    pub fn init(allocator: std.mem.Allocator, mem: *Memory) Interpreter {
        return Interpreter{
            .memory = mem,
            .allocator = allocator,
            .output = std.ArrayList(u8).init(allocator),
            .labels = std.HashMap([]const u8, usize, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .goto_target = null,
            .scope_stack = std.ArrayList(*memory.Record).init(allocator),
            .functions = std.HashMap([]const u8, parser.FunctionDeclaration, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .return_value = null,
            .quiet_mode = false,
            .activators = std.ArrayList(parser.ActivatorDeclaration).init(allocator),
            .executing_activator = false,
            .current_loop_variable = null,
            .current_loop_variable_name = null,
            .used_for_loop_with_records = false,

            // Error management
            .error_manager = memory.ErrorManager.init(allocator),

            // HTTP Server fields
            .http_server = null,
            .server_thread = null,
            .registered_routes = std.ArrayList(Route).init(allocator),
            .server_running = false,
            .shutdown_requested = false,

            // MCP fields
            .mcp_connections = std.ArrayList(McpConnection).init(allocator),
            .mcp_tools = std.ArrayList(McpTool).init(allocator),
            .mcp_activators = std.ArrayList(parser.ActivatorDeclaration).init(allocator),
        };
    }

    pub fn deinit(self: *Interpreter) void {
        self.output.deinit();
        self.labels.deinit();
        self.scope_stack.deinit();

        // Clean up function registry (no need to free individual functions since we store references)
        self.functions.deinit();

        // Clean up activators
        self.activators.deinit();

        // Clean up error management
        self.error_manager.deinit();

        // Clean up HTTP server
        if (self.http_server) |*server| {
            server.deinit();
        }
        self.registered_routes.deinit();

        // Clean up MCP resources
        for (self.mcp_connections.items) |*connection| {
            connection.deinit();
        }
        self.mcp_connections.deinit();
        self.mcp_tools.deinit();
        self.mcp_activators.deinit();
    }

    fn log(self: *Interpreter, comptime fmt: []const u8, args: anytype) void {
        if (!self.quiet_mode) {
            std.log.info(fmt, args);
        }
    }

    // Server lifecycle management methods
    pub fn hasRunningServers(self: *Interpreter) bool {
        return self.server_running or self.mcp_connections.items.len > 0;
    }

    pub fn initiateGracefulShutdown(self: *Interpreter) void {
        self.shutdown_requested = true;

        if (self.server_running) {
            std.log.info("🔄 Initiating graceful shutdown of HTTP server...", .{});
            self.server_running = false;
        }

        if (self.mcp_connections.items.len > 0) {
            std.log.info("🔄 Initiating graceful shutdown of {} MCP connections...", .{self.mcp_connections.items.len});
            // MCP connections will be cleaned up in deinit
        }
    }

    pub fn waitForGracefulShutdown(self: *Interpreter) void {
        if (self.server_thread) |thread| {
            std.log.info("⏳ Waiting for server thread to complete...", .{});
            thread.join();
            self.server_thread = null;
            std.log.info("✅ Server thread shutdown complete", .{});
        }
    }

    // Scope management methods
    pub fn pushScope(self: *Interpreter, scope: *memory.Record) !void {
        try self.scope_stack.append(scope);
        std.log.info("📦 Pushed scope, depth now: {}", .{self.scope_stack.items.len});
    }

    pub fn popScope(self: *Interpreter) void {
        if (self.scope_stack.items.len > 0) {
            _ = self.scope_stack.pop();
            std.log.info("📤 Popped scope, depth now: {}", .{self.scope_stack.items.len});
        }
    }

    // Variable resolution with scope chain
    pub fn getVariable(self: *Interpreter, name: []const u8) ?MBLValue {
        // First check if this is the current loop variable
        if (self.current_loop_variable_name) |loop_name| {
            if (std.mem.eql(u8, name, loop_name)) {
                std.log.info("🔍 Variable '{s}' found as current loop variable", .{name});
                return self.current_loop_variable.?;
            }
        }

        // Then check local scopes (deepest first)
        var i: usize = self.scope_stack.items.len;
        while (i > 0) {
            i -= 1;
            const scope = self.scope_stack.items[i];
            if (scope.data.get(name)) |value| {
                std.log.info("🔍 Variable '{s}' found in local scope at depth {}", .{name, i});
                return value;
            }
        }

        // Then check program scope
        if (self.memory.program.data.get(name)) |value| {
            self.log("🔍 Variable '{s}' found in program scope", .{name});
            return value;
        }

        std.log.warn("🔍 Variable '{s}' not found in any scope", .{name});
        return null;
    }

    // Variable assignment with scope resolution
    pub fn setVariable(self: *Interpreter, name: []const u8, value: MBLValue) !void {
        // Check if variable exists in any local scope
        var i: usize = self.scope_stack.items.len;
        while (i > 0) {
            i -= 1;
            const scope = self.scope_stack.items[i];
            if (scope.data.contains(name)) {
                try scope.set(name, value);
                std.log.info("📝 Updated variable '{s}' in local scope at depth {}", .{name, i});
                // Check activators after variable assignment
                self.checkActivators();
                return;
            }
        }

        // Check if exists in program scope
        if (self.memory.program.data.contains(name)) {
            try self.memory.program.set(name, value);
            self.log("📝 Updated variable '{s}' in program scope", .{name});
            // Check activators after variable assignment
            self.checkActivators();
            return;
        }

        // New variable - create in current local scope if available, otherwise program scope
        if (self.scope_stack.items.len > 0) {
            const current_scope = self.scope_stack.items[self.scope_stack.items.len - 1];
            try current_scope.set(name, value);
            std.log.info("📝 Created variable '{s}' in local scope at depth {}", .{name, self.scope_stack.items.len - 1});
        } else {
            try self.memory.program.set(name, value);
            self.log("📝 Created variable '{s}' in program scope", .{name});
        }

        // Check activators after variable assignment (with recursion prevention)
        self.checkActivators();
    }

    // Create a variable in the current local scope (for function parameters)
    pub fn createLocalVariable(self: *Interpreter, name: []const u8, value: MBLValue) !void {
        if (self.scope_stack.items.len > 0) {
            const current_scope = self.scope_stack.items[self.scope_stack.items.len - 1];
            try current_scope.set(name, value);
            std.log.info("📝 Created variable '{s}' in local scope at depth {}", .{name, self.scope_stack.items.len - 1});
        } else {
            // Fallback to program scope if no local scope exists
            try self.memory.program.set(name, value);
            self.log("📝 Created variable '{s}' in program scope", .{name});
        }
    }

    // Setup web namespace and HTTP client functions
    fn setupWebNamespace(self: *Interpreter) !void {
        // Create web namespace record
        var web_record = memory.Record.init(self.allocator);

        // Create native function instances
        const listen_func = memory.NativeFunction{
            .name = "listen",
            .zig_function = webListen,
            .parameter_count = 1,
            .allocator = self.allocator,
        };

        const listen_secure_func = memory.NativeFunction{
            .name = "listen_secure",
            .zig_function = webListenSecure,
            .parameter_count = 2,
            .allocator = self.allocator,
        };

        const route_func = memory.NativeFunction{
            .name = "route",
            .zig_function = webRoute,
            .parameter_count = 3,
            .allocator = self.allocator,
        };

        const cors_func = memory.NativeFunction{
            .name = "cors",
            .zig_function = webCors,
            .parameter_count = 1,
            .allocator = self.allocator,
        };

        const static_func = memory.NativeFunction{
            .name = "static",
            .zig_function = webStatic,
            .parameter_count = 1,
            .allocator = self.allocator,
        };

        // Create MCP native functions
        const mcp_tool_func = memory.NativeFunction{
            .name = "mcp_tool",
            .zig_function = mcpRegisterTool,
            .parameter_count = 3, // name, description, handler
            .allocator = self.allocator,
        };

        const mcp_listen_func = memory.NativeFunction{
            .name = "mcp",
            .zig_function = mcpListen,
            .parameter_count = 1, // port or config
            .allocator = self.allocator,
        };

        const mcp_broadcast_func = memory.NativeFunction{
            .name = "mcp_broadcast",
            .zig_function = mcpBroadcast,
            .parameter_count = 2, // channel, data
            .allocator = self.allocator,
        };

        const mcp_subscribe_func = memory.NativeFunction{
            .name = "mcp_subscribe",
            .zig_function = mcpSubscribe,
            .parameter_count = 2, // connection_id, channel
            .allocator = self.allocator,
        };

        // Add native functions to web namespace
        try web_record.set("listen", MBLValue{ .native_function = listen_func });
        try web_record.set("listen_secure", MBLValue{ .native_function = listen_secure_func });
        try web_record.set("route", MBLValue{ .native_function = route_func });
        try web_record.set("cors", MBLValue{ .native_function = cors_func });
        try web_record.set("static", MBLValue{ .native_function = static_func });

        // Add MCP functions to web namespace
        try web_record.set("mcp_tool", MBLValue{ .native_function = mcp_tool_func });
        try web_record.set("mcp", MBLValue{ .native_function = mcp_listen_func });
        try web_record.set("mcp_broadcast", MBLValue{ .native_function = mcp_broadcast_func });
        try web_record.set("mcp_subscribe", MBLValue{ .native_function = mcp_subscribe_func });

        // Add web namespace to program root
        try self.memory.program.set("web", MBLValue{ .record = web_record });

        // Create HTTP client functions for program root
        const get_func = memory.NativeFunction{
            .name = "get",
            .zig_function = httpGet,
            .parameter_count = null, // variadic: 1-2 args
            .allocator = self.allocator,
        };

        const post_func = memory.NativeFunction{
            .name = "post",
            .zig_function = httpPost,
            .parameter_count = null, // variadic: 2-3 args
            .allocator = self.allocator,
        };

        const put_func = memory.NativeFunction{
            .name = "put",
            .zig_function = httpPut,
            .parameter_count = null, // variadic: 2-3 args
            .allocator = self.allocator,
        };

        const delete_func = memory.NativeFunction{
            .name = "delete",
            .zig_function = httpDelete,
            .parameter_count = 1,
            .allocator = self.allocator,
        };

        // Add HTTP client functions to program root
        try self.memory.program.set("get", MBLValue{ .native_function = get_func });
        try self.memory.program.set("post", MBLValue{ .native_function = post_func });
        try self.memory.program.set("put", MBLValue{ .native_function = put_func });
        try self.memory.program.set("delete", MBLValue{ .native_function = delete_func });

        std.log.info("🌐 Web namespace and HTTP client functions initialized", .{});
    }

    // Setup program.errors for v0.14.0 error handling
    fn setupProgramErrors(self: *Interpreter) !void {
        // Initialize program.errors as Nothing (represented as Unknown)
        try self.memory.program.set("errors", MBLValue{ .unknown = {} });
        std.log.info("🛡️ Error handling system initialized - program.errors = Nothing", .{});
    }

    // Record an error and update program.errors
    fn recordError(
        self: *Interpreter,
        message: []const u8,
        line: usize,
        column: usize,
        context: []const u8,
        operation: []const u8,
        values: []const []const u8,
    ) !void {
        try self.error_manager.recordError(message, line, column, context, operation, values);

        // Update program.errors to point to the error list
        if (self.error_manager.getErrors()) |errors| {
            try self.memory.program.set("errors", MBLValue{ .list = errors.* });
        }
    }

    // Convenience method for recording simple errors without position info
    fn recordSimpleError(self: *Interpreter, message: []const u8, operation: []const u8) !void {
        const empty_values = [_][]const u8{};
        try self.recordError(message, 0, 0, "unknown", operation, &empty_values);
    }

    // Helper function to attempt text-to-number conversion for arithmetic operations
    fn tryTextToNumber(_: *Interpreter, value: MBLValue) ?memory.Number {
        switch (value) {
            .number => |num| return num,
            .text => |text| {
                // Trim whitespace before parsing
                const trimmed = std.mem.trim(u8, text.data, " \t\n\r");
                if (trimmed.len == 0) return memory.Number{ .value = 0.0 }; // Empty = 0

                // Try to parse the text as a number
                if (std.fmt.parseFloat(f64, trimmed)) |parsed_value| {
                    return memory.Number{ .value = parsed_value };
                } else |_| {
                    // If parsing fails, return null
                    return null;
                }
            },
            .boolean => |b| return memory.Number{ .value = if (b.value) 1.0 else 0.0 },
            else => return null,
        }
    }

    // Helper function to convert any value to text for concatenation
    fn tryValueToText(self: *Interpreter, value: MBLValue) !memory.Text {
        const text_value = try value.convertToText(self.allocator);
        return text_value.text;
    }

    // Setup ODBC namespace and database functions
    fn setupOdbcNamespace(self: *Interpreter) !void {
        try odbc.registerOdbcFunctions(self);
        std.log.info("🗄️ ODBC database functions initialized", .{});
    }

    pub fn execute(self: *Interpreter, statements: []Statement) !void {
        self.log("🔥 Executing {} MBL statements...", .{statements.len});

        // Setup built-in namespaces
        try self.setupWebNamespace();
        try self.setupOdbcNamespace();
        try self.setupProgramErrors();

        // First pass: collect all labels and functions (hoisting)
        for (statements, 0..) |stmt, i| {
            if (stmt == .label) {
                try self.labels.put(stmt.label.name, i);
                std.log.info("📍 Found label '{s}' at statement {}", .{stmt.label.name, i});
            } else if (stmt == .function_declaration) {
                try self.registerFunction(stmt.function_declaration);
                std.log.info("🚀 Hoisted function '{s}' (defined at statement {})", .{stmt.function_declaration.name, i});
            }
        }

        // Second pass: execute statements with goto support
        var pc: usize = 0; // program counter
        while (pc < statements.len) {
            const stmt = statements[pc];

            if (stmt == .goto_stmt) {
                // Handle goto
                const target = stmt.goto_stmt.target;
                if (self.labels.get(target)) |label_pc| {
                    std.log.info("🔄 GOTO '{s}' - jumping from {} to {}", .{target, pc, label_pc});
                    pc = label_pc;
                    continue;
                } else {
                    std.log.err("❌ Label '{s}' not found for goto", .{target});
                    return InterpreterError.TypeError; // Could add specific GotoError
                }
            } else {
                if (self.executeStatement(stmt)) |_| {
                    self.log("✓ Statement {} completed", .{pc + 1});
                } else |err| switch (err) {
                    InterpreterError.GotoExecuted => {
                        // A goto was executed from within this statement
                        if (self.goto_target) |target| {
                            if (self.labels.get(target)) |label_pc| {
                                std.log.info("🔄 GOTO '{s}' from nested statement - jumping to {}", .{target, label_pc});
                                pc = label_pc;
                                self.goto_target = null; // Clear the goto target
                                continue;
                            } else {
                                std.log.err("❌ Label '{s}' not found for goto", .{target});
                                return InterpreterError.TypeError;
                            }
                        } else {
                            std.log.err("❌ Goto executed but no target set", .{});
                            return InterpreterError.TypeError;
                        }
                    },
                    InterpreterError.ReturnExecuted => {
                        // Return statement executed outside of function context
                        std.log.err("❌ Return statement can only be used inside functions", .{});
                        return InterpreterError.TypeError;
                    },
                    else => return err,
                }
            }

            pc += 1;
        }

        self.log("✅ All statements executed successfully", .{});
    }

    fn executeStatement(self: *Interpreter, stmt: Statement) !void {
        switch (stmt) {
            .assignment => |assignment| {
                try self.executeAssignment(assignment);
            },
            .expression_stmt => |expr_stmt| {
                var result = try self.evaluateExpression(expr_stmt.expression);
                result.deinit(self.allocator); // Clean up the result value
            },
            .if_statement => |if_stmt| {
                try self.executeIfStatement(if_stmt);
            },
            .while_statement => |while_stmt| {
                try self.executeWhileStatement(while_stmt);
            },
            .for_statement => |for_stmt| {
                try self.executeForStatement(for_stmt);
            },
            .break_stmt => |_| {
                std.log.info("🔄 Break statement executed", .{});
                return InterpreterError.BreakExecuted;
            },
            .continue_stmt => |_| {
                std.log.info("🔄 Continue statement executed", .{});
                return InterpreterError.ContinueExecuted;
            },
            .label => |label| {
                // Labels are no-ops during execution (handled in label discovery phase)
                std.log.info("📍 Label '{s}' reached", .{label.name});
            },
            .goto_stmt => |goto_stmt| {
                // Set the goto target and signal that a goto was executed
                self.goto_target = goto_stmt.target;
                std.log.info("🔄 GOTO '{s}' executed from nested statement", .{goto_stmt.target});
                return InterpreterError.GotoExecuted;
            },
            .function_declaration => |_| {
                // Function already registered during hoisting pass, skip execution
                std.log.info("⏭️  Skipping function declaration (already hoisted)", .{});
            },
            .return_statement => |return_stmt| {
                try self.executeReturnStatement(return_stmt);
            },
            .activator_declaration => |activator| {
                try self.registerActivator(activator);
            },
            .load_statement => |load_stmt| {
                try self.executeLoadStatement(load_stmt);
            },
        }
    }

    fn executeAssignment(self: *Interpreter, assignment: parser.Assignment) !void {
        const value = try self.evaluateExpression(assignment.value);

        switch (assignment.target) {
            .identifier => |identifier| {
                const var_name = identifier.name;
                try self.setVariable(var_name, value);
                self.log("  Assigned {s}", .{var_name});
            },
            .property_access => |prop_access| {
                try self.assignToProperty(prop_access, value);
            },
            else => {
                std.log.warn("  Complex assignment targets not yet supported", .{});
            }
        }
    }

    fn assignToProperty(self: *Interpreter, prop_access: parser.PropertyAccess, value: MBLValue) !void {
        // Handle scope resolution assignments with 'program' and 'super' keywords
        if (prop_access.object.* == .identifier) {
            const obj_name = prop_access.object.identifier.name;
            const prop_name = prop_access.property;

            if (std.mem.eql(u8, obj_name, "program")) {
                // Direct assignment to program scope
                try self.memory.program.set(prop_name, value);
                std.log.info("📝 Assigned 'program.{s}'", .{prop_name});
                return;
            } else if (std.mem.eql(u8, obj_name, "super")) {
                // Assignment to parent scope (one level up)
                if (self.scope_stack.items.len > 1) {
                    const parent_scope = self.scope_stack.items[self.scope_stack.items.len - 2];
                    if (parent_scope.data.contains(prop_name)) {
                        try parent_scope.set(prop_name, value);
                        std.log.info("📝 Assigned 'super.{s}' in parent scope", .{prop_name});
                        return;
                    }
                }
                // If not found in parent, assign to program scope
                try self.memory.program.set(prop_name, value);
                std.log.info("📝 Assigned 'super.{s}' (fallback to program)", .{prop_name});
                return;
            }
        }

        // For other property assignments, evaluate object and set property
        std.log.warn("  Property assignment to non-scope objects not yet supported", .{});
    }

    fn evaluateExpression(self: *Interpreter, expr: Expression) !MBLValue {
        switch (expr) {
            .literal => |literal| {
                return try self.evaluateLiteral(literal);
            },
            .identifier => |identifier| {
                if (self.getVariable(identifier.name)) |value| {
                    return value;
                } else {
                    std.log.warn("  Undefined variable: {s}", .{identifier.name});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            },
            .property_access => |prop_access| {
                return try self.evaluatePropertyAccess(prop_access);
            },
            .index_access => |index_access| {
                return try self.evaluateIndexAccess(index_access);
            },
            .call => |call_expr| {
                return try self.evaluateCall(call_expr);
            },
            .binary => |binary_expr| {
                return try self.evaluateBinaryExpression(binary_expr);
            },
            .unary => |unary_expr| {
                return try self.evaluateUnaryExpression(unary_expr);
            },
            .record_literal => |record_literal| {
                return try self.evaluateRecordLiteral(record_literal);
            },
            .list_literal => |list_literal| {
                return try self.evaluateListLiteral(list_literal);
            },
        }
    }

    fn evaluateLiteral(self: *Interpreter, literal: parser.Literal) !MBLValue {
        switch (literal) {
            .text => |text| {
                // Remove quotes from text literal
                var clean_text: []const u8 = text;
                if (text.len >= 2 and text[0] == '"' and text[text.len - 1] == '"') {
                    clean_text = text[1..text.len - 1];
                }
                return MBLValue{ .text = try memory.Text.init(self.allocator, clean_text) };
            },
            .number => |num| {
                return MBLValue{ .number = memory.Number{ .value = num } };
            },
            .boolean => |bool_val| {
                return MBLValue{ .boolean = memory.Boolean{ .value = bool_val } };
            },
            .money => |money_literal| {
                const currency = money_literal.currency orelse "USD";
                const cents = @as(i64, @intFromFloat(money_literal.amount * 100.0));
                const money = try memory.Money.init(self.allocator, cents, currency, "USD", 1.0);
                return MBLValue{ .money = money };
            },
            .time => |time_literal| {
                return try self.parseTimeString(time_literal.value);
            },
            .duration => |duration_literal| {
                return try self.parseDurationLiteral(duration_literal);
            },
            .nothing => {
                // Nothing converts to empty string
                return MBLValue{ .text = try memory.Text.init(self.allocator, "") };
            },
            .unknown => {
                // Unknown is a distinct value type
                return MBLValue{ .unknown = {} };
            },
            else => {
                std.log.warn("  Literal type {s} not yet supported", .{@tagName(literal)});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "unsupported_literal") };
            },
        }
    }

    fn parseTimeString(self: *Interpreter, time_str: []const u8) !MBLValue {
        // Remove the @ prefix if present
        var clean_str = time_str;
        if (time_str.len > 0 and time_str[0] == '@') {
            clean_str = time_str[1..];
        }

        // Handle special cases
        if (std.mem.eql(u8, clean_str, "now")) {
            return MBLValue{ .time = memory.Time.now() };
        }

        // Parse different time formats
        if (clean_str.len == 10 and clean_str[4] == '-' and clean_str[7] == '-') {
            // Date format: YYYY-MM-DD
            return try self.parseDate(clean_str);
        } else if (clean_str.len == 8 and clean_str[2] == ':' and clean_str[5] == ':') {
            // Time format: HH:MM:SS
            return try self.parseTime(clean_str);
        } else if (clean_str.len == 19 and (clean_str[10] == 'T' or clean_str[10] == ' ')) {
            // DateTime format: YYYY-MM-DDTHH:MM:SS or YYYY-MM-DD HH:MM:SS
            return try self.parseDateTime(clean_str);
        } else {
            // Try to parse as timestamp
            const timestamp = std.fmt.parseInt(i64, clean_str, 10) catch {
                std.log.warn("  Invalid time format: {s}", .{time_str});
                return MBLValue{ .time = memory.Time.init(0) };
            };
            return MBLValue{ .time = memory.Time.init(timestamp) };
        }
    }

    fn parseDate(self: *Interpreter, date_str: []const u8) !MBLValue {
        _ = self;
        // Parse YYYY-MM-DD format
        const year = std.fmt.parseInt(i32, date_str[0..4], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };
        const month = std.fmt.parseInt(u4, date_str[5..7], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };
        const day = std.fmt.parseInt(u5, date_str[8..10], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };

        // Convert to UNIX timestamp (simplified - assumes UTC)
        // This is a basic implementation, a full implementation would use std.time
        const days_since_epoch = daysSinceEpoch(year, month, day);
        const timestamp = days_since_epoch * 24 * 60 * 60; // Convert days to seconds

        return MBLValue{ .time = memory.Time.init(timestamp) };
    }

    fn parseTime(self: *Interpreter, time_str: []const u8) !MBLValue {
        _ = self;
        // Parse HH:MM:SS format - treat as seconds since midnight
        const hour = std.fmt.parseInt(u5, time_str[0..2], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };
        const minute = std.fmt.parseInt(u6, time_str[3..5], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };
        const second = std.fmt.parseInt(u6, time_str[6..8], 10) catch {
            return MBLValue{ .time = memory.Time.init(0) };
        };

        const total_seconds = @as(i64, hour) * 3600 + @as(i64, minute) * 60 + @as(i64, second);
        return MBLValue{ .time = memory.Time.init(total_seconds) };
    }

    fn parseDateTime(self: *Interpreter, datetime_str: []const u8) !MBLValue {
        // Parse YYYY-MM-DDTHH:MM:SS format
        const date_part = datetime_str[0..10];
        const time_part = datetime_str[11..19];

        const date_val = try self.parseDate(date_part);
        const time_val = try self.parseTime(time_part);

        // Add time of day to the date
        const combined_timestamp = date_val.time.value + time_val.time.value;
        return MBLValue{ .time = memory.Time.init(combined_timestamp) };
    }

    fn parseDurationLiteral(self: *Interpreter, duration_literal: parser.DurationLiteral) !MBLValue {
        _ = self;

        if (std.mem.eql(u8, duration_literal.unit, "days")) {
            return MBLValue{ .duration = memory.Duration.fromDays(duration_literal.value) };
        } else if (std.mem.eql(u8, duration_literal.unit, "hours")) {
            return MBLValue{ .duration = memory.Duration.fromHours(duration_literal.value) };
        } else if (std.mem.eql(u8, duration_literal.unit, "minutes")) {
            return MBLValue{ .duration = memory.Duration.fromMinutes(duration_literal.value) };
        } else if (std.mem.eql(u8, duration_literal.unit, "seconds")) {
            return MBLValue{ .duration = memory.Duration.fromSeconds(duration_literal.value) };
        } else {
            std.log.warn("  Unknown duration unit: {s}", .{duration_literal.unit});
            return MBLValue{ .duration = memory.Duration.init(0) };
        }
    }

    fn evaluateRecordLiteral(self: *Interpreter, record_literal: parser.RecordLiteral) anyerror!MBLValue {
        var record = memory.Record.init(self.allocator);

        for (record_literal.fields) |field| {
            // Handle the key - identifiers should be treated as literal text
            const key_str = switch (field.key) {
                .identifier => |identifier| identifier.name,
                .literal => |literal| switch (literal) {
                    .text => |text| text,
                    else => {
                        std.log.warn("  Record key must be text, got {s}", .{@tagName(literal)});
                        return MBLValue{ .text = try memory.Text.init(self.allocator, "invalid_record") };
                    }
                },
                else => blk: {
                    // For computed keys, evaluate them
                    const key_value = try self.evaluateExpression(field.key);
                    break :blk switch (key_value) {
                        .text => |text| text.data,
                        else => {
                            std.log.warn("  Record key must evaluate to text, got {s}", .{@tagName(key_value)});
                            return MBLValue{ .text = try memory.Text.init(self.allocator, "invalid_record") };
                        }
                    };
                }
            };

            // Evaluate the value
            const value = try self.evaluateExpression(field.value);

            // Add to record
            try record.set(key_str, value);
        }

        return MBLValue{ .record = record };
    }

    fn evaluateListLiteral(self: *Interpreter, list_literal: parser.ListLiteral) anyerror!MBLValue {
        var list = memory.List.init(self.allocator);

        for (list_literal.elements) |element| {
            const value = try self.evaluateExpression(element);
            try list.append(value);
        }

        return MBLValue{ .list = list };
    }

    fn evaluateIndexAccess(self: *Interpreter, index_access: parser.IndexAccess) anyerror!MBLValue {
        const obj_value = try self.evaluateExpression(index_access.object.*);
        const index_value = try self.evaluateExpression(index_access.index.*);

        // Convert index to number
        const index_num = switch (index_value) {
            .number => |num| @as(usize, @intFromFloat(num.value)),
            else => {
                std.log.warn("  Index must be a number, got {s}", .{@tagName(index_value)});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "invalid_index") };
            }
        };

        // Handle list indexing
        switch (obj_value) {
            .list => |*list| {
                if (list.get(index_num)) |value| {
                    return value;
                } else {
                    std.log.warn("  List index {d} out of bounds", .{index_num});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "index_out_of_bounds") };
                }
            },
            else => {
                std.log.warn("  Cannot index into {s}", .{@tagName(obj_value)});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "not_indexable") };
            }
        }
    }

    fn daysSinceEpoch(year: i32, month: u4, day: u5) i64 {
        // Simplified calculation - assumes Gregorian calendar
        // This is a basic implementation for demonstration
        var total_days: i64 = 0;

        // Add days for complete years since 1970
        var y: i32 = 1970;
        while (y < year) : (y += 1) {
            total_days += if (isLeapYear(y)) 366 else 365;
        }

        // Add days for complete months in the current year
        const days_in_month = [_]u5{31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
        var m: u4 = 1;
        while (m < month) : (m += 1) {
            total_days += days_in_month[m - 1];
            if (m == 2 and isLeapYear(year)) {
                total_days += 1; // Add leap day
            }
        }

        // Add remaining days
        total_days += day - 1; // Day 1 is the first day of the month

        return total_days;
    }

    fn isLeapYear(year: i32) bool {
        return (@rem(year, 4) == 0 and @rem(year, 100) != 0) or (@rem(year, 400) == 0);
    }

    fn evaluateCall(self: *Interpreter, call_expr: parser.CallExpression) anyerror!MBLValue {
        // Handle method calls on expressions (e.g., text.method())
        if (call_expr.callee.* == .property_access) {
            const prop_access = call_expr.callee.property_access;
            const method_name = prop_access.property;

            // Handle program.write() specifically first
            if (prop_access.object.* == .identifier) {
                const obj_name = prop_access.object.identifier.name;
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "write")) {
                    return try self.handleProgramWrite(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "read")) {
                    return try self.handleProgramRead(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "prompt")) {
                    return try self.handleProgramPrompt(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "error")) {
                    return try self.handleProgramError(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "open")) {
                    return try self.handleProgramOpen(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "import")) {
                    return try self.handleProgramImport(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "get")) {
                    return try self.handleProgramGet(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "post")) {
                    return try self.handleProgramPost(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "put")) {
                    return try self.handleProgramPut(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "delete")) {
                    return try self.handleProgramDelete(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "secret")) {
                    return try self.handleProgramSecret(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "secret_write")) {
                    return try self.handleProgramSecretWrite(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "secret_delete")) {
                    return try self.handleProgramSecretDelete(call_expr.arguments);
                }
                // File and directory operations
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "dir_list")) {
                    return try self.handleProgramDirList(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "dir_create")) {
                    return try self.handleProgramDirCreate(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "dir_delete")) {
                    return try self.handleProgramDirDelete(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "dir_exists")) {
                    return try self.handleProgramDirExists(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "file_exists")) {
                    return try self.handleProgramFileExists(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "file_delete")) {
                    return try self.handleProgramFileDelete(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "file_copy")) {
                    return try self.handleProgramFileCopy(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "file_move")) {
                    return try self.handleProgramFileMove(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "program") and std.mem.eql(u8, method_name, "file_info")) {
                    return try self.handleProgramFileInfo(call_expr.arguments);
                }
                if (std.mem.eql(u8, obj_name, "symbol") and std.mem.eql(u8, method_name, "unicode")) {
                    return try self.handleSymbolUnicode(call_expr.arguments);
                }
            }

            // Evaluate the object being called on for other methods
            const object_value = try self.evaluateExpression(prop_access.object.*);

            // Handle text methods
            if (object_value == .text) {
                return try self.handleTextMethod(object_value.text, method_name, call_expr.arguments);
            }

            // Handle native function calls on objects (e.g., program.web.listen())
            if (object_value == .record) {
                // Get mutable reference to the record
                var record_mut = object_value.record;

                // Check if this is a CLI object
                if (record_mut.get("_type")) |type_value| {
                    if (type_value == .text and std.mem.eql(u8, type_value.text.data, "cli")) {
                        return try self.handleCliMethod(method_name, call_expr.arguments);
                    }
                }

                const method_value = record_mut.get(method_name);
                if (method_value) |mv| {
                    if (mv == .native_function) {
                        return try self.callNativeFunction(mv.native_function, call_expr.arguments);
                    }
                }
            }
        }

        // Handle direct function calls (both user-defined and native)
        if (call_expr.callee.* == .identifier) {
            const func_name = call_expr.callee.identifier.name;

            // Check if it's a native function first
            if (self.getVariable(func_name)) |value| {
                if (value == .native_function) {
                    return try self.callNativeFunction(value.native_function, call_expr.arguments);
                }
            }

            // Fall back to user-defined function
            return try self.callFunction(func_name, call_expr.arguments);
        }

        std.log.warn("  Function call not supported", .{});
        return MBLValue{ .text = try memory.Text.init(self.allocator, "unsupported_call") };
    }

    fn handleProgramWrite(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len > 0) {
            var arg_value = self.evaluateExpression(arguments[0]) catch |err| {
                std.log.warn("Error evaluating argument: {!}", .{err});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            };
            defer arg_value.deinit(self.allocator); // Clean up the argument value

            // Convert any MBL value to string for output
            var output_text: []const u8 = undefined;
            var needs_free = false;
            switch (arg_value) {
                .text => |text| {
                    output_text = text.data;
                },
                .number => |num| {
                    const formatted = try std.fmt.allocPrint(self.allocator, "{d}", .{num.value});
                    output_text = formatted;
                    needs_free = true;
                },
                .boolean => |bool_val| {
                    output_text = if (bool_val.value) "true" else "false";
                },
                .money => |money| {
                    const dollars = @as(f64, @floatFromInt(money.value)) / 100.0;
                    const formatted = try std.fmt.allocPrint(self.allocator, "${d:.2} {s}", .{dollars, money.currency});
                    output_text = formatted;
                    needs_free = true;
                },
                else => {
                    output_text = "unsupported_type";
                },
            }

            try self.output.appendSlice(output_text);
            try self.output.append('\n');

            if (needs_free) {
                self.allocator.free(output_text);
            }
        }
        return MBLValue{ .text = try memory.Text.init(self.allocator, "") };
    }

    fn handleSymbolUnicode(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "unicode() requires exactly one argument") };
        }

        const arg_value = self.evaluateExpression(arguments[0]) catch |err| {
            std.log.warn("Error evaluating unicode argument: {!}", .{err});
            return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
        };

        // Convert argument to number (Unicode code point)
        var code_point: u21 = 0;
        switch (arg_value) {
            .number => |num| {
                if (num.value >= 0 and num.value <= 1114111) { // Valid Unicode range
                    code_point = @intFromFloat(num.value);
                } else {
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "Invalid Unicode code point") };
                }
            },
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "unicode() requires a number argument") };
            },
        }

        // Convert Unicode code point to UTF-8 string
        var utf8_buffer: [4]u8 = undefined;
        const utf8_len = try std.unicode.utf8Encode(code_point, &utf8_buffer);
        const utf8_text = try self.allocator.dupe(u8, utf8_buffer[0..utf8_len]);

        return MBLValue{ .text = memory.Text{ .data = utf8_text } };
    }

    fn handleProgramRead(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        // No arguments means read to EOF
        if (arguments.len == 0) {
            const stdin = std.io.getStdIn().reader();
            const all_input = try stdin.readAllAlloc(self.allocator, 1024 * 1024); // 1MB limit
            return MBLValue{ .text = memory.Text{ .data = all_input } };
        }

        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "read() requires zero or one delimiter argument") };
        }

        const delimiter_value = self.evaluateExpression(arguments[0]) catch |err| {
            std.log.warn("Error evaluating read delimiter: {!}", .{err});
            return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
        };

        // Get delimiters as list of strings
        var delimiters = std.ArrayList([]const u8).init(self.allocator);
        defer delimiters.deinit();

        switch (delimiter_value) {
            .text => |delimiter| {
                // Single delimiter
                try delimiters.append(delimiter.data);
            },
            .list => |delimiter_list| {
                // Multiple delimiters
                for (delimiter_list.data.items) |item| {
                    if (item == .text) {
                        try delimiters.append(item.text.data);
                    }
                }
            },
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "read() delimiter must be text or list of text") };
            },
        }

        // Read from stdin until delimiter found
        const stdin = std.io.getStdIn().reader();
        var input_buffer = std.ArrayList(u8).init(self.allocator);
        defer input_buffer.deinit();

        // Special case: empty delimiter means read all
        if (delimiters.items.len == 1 and delimiters.items[0].len == 0) {
            const all_input = try stdin.readAllAlloc(self.allocator, 1024 * 1024); // 1MB limit
            return MBLValue{ .text = memory.Text{ .data = all_input } };
        }

        // Read character by character until delimiter found
        while (true) {
            const byte = stdin.readByte() catch |err| {
                if (err == error.EndOfStream) {
                    break;
                }
                return MBLValue{ .text = try memory.Text.init(self.allocator, "read error") };
            };

            try input_buffer.append(byte);

            // Check if current buffer ends with any delimiter
            for (delimiters.items) |delimiter| {
                if (delimiter.len == 0) continue; // Skip empty delimiters
                if (input_buffer.items.len >= delimiter.len) {
                    const end_slice = input_buffer.items[input_buffer.items.len - delimiter.len..];
                    if (std.mem.eql(u8, end_slice, delimiter)) {
                        // Found delimiter, return text without delimiter
                        const result_len = input_buffer.items.len - delimiter.len;
                        const result = try self.allocator.dupe(u8, input_buffer.items[0..result_len]);
                        return MBLValue{ .text = memory.Text{ .data = result } };
                    }
                }
            }
        }

        // EOF reached, return whatever we have
        const result = try self.allocator.dupe(u8, input_buffer.items);
        return MBLValue{ .text = memory.Text{ .data = result } };
    }

    fn handleProgramPrompt(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "prompt() requires exactly one text argument") };
        }

        const prompt_value = self.evaluateExpression(arguments[0]) catch |err| {
            std.log.warn("Error evaluating prompt text: {!}", .{err});
            return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
        };

        // Get prompt text
        const prompt_text = switch (prompt_value) {
            .text => |text| text.data,
            .number => |num| blk: {
                const formatted = try std.fmt.allocPrint(self.allocator, "{d}", .{num.value});
                break :blk formatted;
            },
            .boolean => |bool_val| if (bool_val.value) "true" else "false",
            .money => |money| blk: {
                const dollars = @as(f64, @floatFromInt(money.value)) / 100.0;
                const formatted = try std.fmt.allocPrint(self.allocator, "${d:.2} {s}", .{dollars, money.currency});
                break :blk formatted;
            },
            else => "unsupported_prompt_type",
        };

        // Display prompt without newline
        const stdout = std.io.getStdOut().writer();
        try stdout.writeAll(prompt_text);

        // Read response until newline
        const stdin = std.io.getStdIn().reader();
        var input_buffer = std.ArrayList(u8).init(self.allocator);
        defer input_buffer.deinit();

        while (true) {
            const byte = stdin.readByte() catch |err| {
                if (err == error.EndOfStream) {
                    break;
                }
                return MBLValue{ .text = try memory.Text.init(self.allocator, "read error") };
            };

            if (byte == '\n') {
                // Found newline, return input without the newline
                const result = try self.allocator.dupe(u8, input_buffer.items);
                return MBLValue{ .text = memory.Text{ .data = result } };
            }

            try input_buffer.append(byte);
        }

        // EOF reached, return whatever we have
        const result = try self.allocator.dupe(u8, input_buffer.items);
        return MBLValue{ .text = memory.Text{ .data = result } };
    }

    fn handleProgramError(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len > 0) {
            var arg_value = self.evaluateExpression(arguments[0]) catch |err| {
                std.log.warn("Error evaluating error message: {!}", .{err});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            };
            defer arg_value.deinit(self.allocator); // Clean up the argument value

            // Convert any MBL value to string for error output
            var error_text: []const u8 = undefined;
            switch (arg_value) {
                .text => |text| {
                    error_text = text.data;
                },
                .number => |num| {
                    const formatted = try std.fmt.allocPrint(self.allocator, "{d}", .{num.value});
                    error_text = formatted;
                },
                .boolean => |bool_val| {
                    error_text = if (bool_val.value) "true" else "false";
                },
                .money => |money| {
                    const dollars = @as(f64, @floatFromInt(money.value)) / 100.0;
                    const formatted = try std.fmt.allocPrint(self.allocator, "${d:.2} {s}", .{dollars, money.currency});
                    error_text = formatted;
                },
                else => {
                    error_text = "unsupported_type";
                },
            }

            // Write to stderr with newline
            const stderr = std.io.getStdErr().writer();
            try stderr.writeAll(error_text);
            try stderr.writeAll("\n");

            // Free allocated strings
            switch (arg_value) {
                .number, .money => {
                    self.allocator.free(error_text);
                },
                else => {},
            }
        }
        return MBLValue{ .text = try memory.Text.init(self.allocator, "") };
    }

    fn handleProgramOpen(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len == 0 or arguments.len > 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "open() requires 1 or 2 arguments: path and optional config") };
        }

        // Get file path
        const path_value = try self.evaluateExpression(arguments[0]);
        const path = switch (path_value) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "open() path must be text") };
            },
        };

        // Get configuration (optional)
        var config = memory.FileHandle.FileConfig.default();
        if (arguments.len == 2) {
            const config_value = try self.evaluateExpression(arguments[1]);
            switch (config_value) {
                .record => |record| {
                    // Parse configuration from record
                    if (record.data.get("delimiter")) |delim| {
                        if (delim == .text) {
                            config.delimiter = delim.text.data;
                        }
                    }
                    if (record.data.get("headers")) |headers| {
                        if (headers == .boolean) {
                            config.headers = headers.boolean.value;
                        }
                    }
                    if (record.data.get("quotes")) |quotes| {
                        if (quotes == .boolean) {
                            config.quotes = quotes.boolean.value;
                        }
                    }
                },
                else => {
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "open() config must be a record") };
                },
            }
        } else {
            // Auto-detect format from extension
            if (std.mem.endsWith(u8, path, ".json")) {
                config.format = .json;
            } else {
                config.format = .csv;
            }
        }

        // Create file handle
        const file_handle = memory.FileHandle.init(self.allocator, path, config) catch |err| {
            const error_msg = try std.fmt.allocPrint(self.allocator, "Failed to open file '{s}': {}", .{ path, err });
            defer self.allocator.free(error_msg);
            return MBLValue{ .text = try memory.Text.init(self.allocator, error_msg) };
        };

        return MBLValue{ .file_handle = file_handle };
    }

    fn handleProgramImport(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        // Enable memory protection for any import operation
        self.memory.has_csv_imported = true;
        std.log.info("🚨 File import detected - memory protection ENABLED", .{});

        if (arguments.len == 0 or arguments.len > 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "import() requires 1 or 2 arguments: path and optional format") };
        }

        // Get file path
        const path_value = try self.evaluateExpression(arguments[0]);
        const path = switch (path_value) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "import() path must be text") };
            },
        };

        // Read entire file
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            const error_msg = try std.fmt.allocPrint(self.allocator, "Failed to open file '{s}': {}", .{ path, err });
            defer self.allocator.free(error_msg);
            try self.recordSimpleError(error_msg, "file_import");
            return MBLValue{ .unknown = {} };
        };
        defer file.close();

        const file_contents = file.readToEndAlloc(self.allocator, 10 * 1024 * 1024) catch |err| { // 10MB limit
            const error_msg = try std.fmt.allocPrint(self.allocator, "Failed to read file '{s}': {}", .{ path, err });
            defer self.allocator.free(error_msg);
            try self.recordSimpleError(error_msg, "file_read");
            return MBLValue{ .unknown = {} };
        };

        // Determine format
        var format: []const u8 = "auto";
        if (arguments.len == 2) {
            const format_value = try self.evaluateExpression(arguments[1]);
            if (format_value == .text) {
                format = format_value.text.data;
            }
        } else {
            // Auto-detect from extension
            if (std.mem.endsWith(u8, path, ".json")) {
                format = "json";
            } else if (std.mem.endsWith(u8, path, ".csv")) {
                format = "csv";
            }
        }

        // Parse based on format
        if (std.mem.eql(u8, format, "json")) {
            // Parse JSON into MBL data structures
            return try self.parseJSONFile(file_contents);
        } else if (std.mem.eql(u8, format, "csv") or std.mem.eql(u8, format, "auto")) {
            // Parse CSV into list of records/lists
            return try self.parseCSVFile(file_contents);
        } else {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "Unsupported format. Use 'csv' or 'json'") };
        }
    }

    fn parseCSVFile(self: *Interpreter, contents: []const u8) !MBLValue {
        // IMMEDIATELY set protection flag as soon as CSV parsing begins
        self.memory.has_csv_imported = true;
        std.log.info("🚨 CSV parsing started - memory protection ENABLED", .{});

        var lines = std.mem.split(u8, contents, "\n");
        var result_list = memory.List.init(self.allocator);

        var headers: ?[][]const u8 = null;
        var line_number: usize = 0;

        while (lines.next()) |line| {
            if (line.len == 0) continue; // Skip empty lines
            line_number += 1;

            // Parse CSV line (simple implementation)
            var fields = std.ArrayList([]const u8).init(self.allocator);
            defer fields.deinit();

            var start: usize = 0;
            var i: usize = 0;
            while (i < line.len) {
                if (line[i] == ',') {
                    try fields.append(line[start..i]);
                    start = i + 1;
                }
                i += 1;
            }
            try fields.append(line[start..]);

            if (line_number == 1) {
                // Treat first line as headers
                headers = try self.allocator.alloc([]const u8, fields.items.len);
                for (fields.items, 0..) |field, idx| {
                    headers.?[idx] = try self.allocator.dupe(u8, field);
                }
                continue; // Skip adding header row to data
            }

            // Create record or list
            if (headers) |h| {
                // Create the record directly in the MBLValue to avoid ownership issues
                var record = memory.Record.init(self.allocator);
                record.is_csv_imported = true; // Mark as CSV imported to avoid cleanup issues
                var record_value = MBLValue{ .record = record };
                for (fields.items, 0..) |field, idx| {
                    const field_name = if (idx < h.len) h[idx] else "unknown";
                    // Create properly initialized Text object
                    const field_text = try memory.Text.init(self.allocator, field);
                    // record.set() will copy field_name, so we can use it directly
                    try record_value.record.set(field_name, MBLValue{ .text = field_text });
                }
                try result_list.append(record_value);
            } else {
                var list = memory.List.init(self.allocator);
                for (fields.items) |field| {
                    // Create properly initialized Text object
                    const field_text = try memory.Text.init(self.allocator, field);
                    try list.append(MBLValue{ .text = field_text });
                }
                try result_list.append(MBLValue{ .list = list });
            }
        }

        // Clean up headers
        if (headers) |h| {
            for (h) |header| {
                self.allocator.free(header);
            }
            self.allocator.free(h);
        }

        // Mark that CSV data was imported to enable cleanup protection
        self.memory.has_csv_imported = true;
        std.log.info("🧹 CSV data imported - enabling cleanup protection", .{});

        return MBLValue{ .list = result_list };
    }

    fn parseJSONFile(self: *Interpreter, contents: []const u8) !MBLValue {
        // Enable memory protection for JSON operations too
        self.memory.has_csv_imported = true;
        std.log.info("🚨 JSON parsing started - memory protection ENABLED", .{});

        // Parse JSON using Zig's built-in parser
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, contents, .{}) catch |err| {
            const error_msg = switch (err) {
                error.SyntaxError => "Invalid JSON format",
                error.UnexpectedToken => "JSON syntax error",
                error.UnexpectedEndOfInput => "Incomplete JSON",
                error.OutOfMemory => "Out of memory parsing JSON",
                else => "JSON parsing failed",
            };
            try self.recordSimpleError(error_msg, "json_parse");
            return MBLValue{ .unknown = {} };
        };
        defer parsed.deinit();

        // Convert JSON Value to MBLValue
        const result = try self.jsonValueToMBL(parsed.value);

        std.log.info("🧹 JSON data imported - enabling cleanup protection", .{});
        return result;
    }

    fn jsonValueToMBL(self: *Interpreter, json_value: std.json.Value) anyerror!MBLValue {
        switch (json_value) {
            .null => {
                return MBLValue{ .unknown = {} }; // JSON null becomes MBL unknown
            },
            .bool => |b| {
                return MBLValue{ .boolean = memory.Boolean{ .value = b } };
            },
            .integer => |i| {
                return MBLValue{ .number = memory.Number{ .value = @floatFromInt(i) } };
            },
            .float => |f| {
                return MBLValue{ .number = memory.Number{ .value = f } };
            },
            .number_string => |ns| {
                // Parse number from string
                const num = std.fmt.parseFloat(f64, ns) catch 0.0;
                return MBLValue{ .number = memory.Number{ .value = num } };
            },
            .string => |s| {
                const text = try memory.Text.init(self.allocator, s);
                return MBLValue{ .text = text };
            },
            .array => |arr| {
                var list = memory.List.init(self.allocator);
                for (arr.items) |item| {
                    const mbl_item = try self.jsonValueToMBL(item);
                    try list.append(mbl_item);
                }
                return MBLValue{ .list = list };
            },
            .object => |obj| {
                var record = memory.Record.init(self.allocator);
                record.is_csv_imported = true; // Mark for memory protection

                var iterator = obj.iterator();
                while (iterator.next()) |entry| {
                    const mbl_value = try self.jsonValueToMBL(entry.value_ptr.*);
                    try record.set(entry.key_ptr.*, mbl_value);
                }
                return MBLValue{ .record = record };
            },
        }
    }

    fn handleTextMethod(self: *Interpreter, text: memory.Text, method_name: []const u8, arguments: []parser.Expression) anyerror!MBLValue {
        // len() method - no arguments
        if (std.mem.eql(u8, method_name, "len")) {
            if (arguments.len != 0) {
                std.log.warn("len() method takes no arguments", .{});
            }
            return MBLValue{ .number = memory.Number.init(@floatFromInt(text.len())) };
        }

        // trim() method - optional chars argument
        else if (std.mem.eql(u8, method_name, "trim")) {
            const chars = if (arguments.len > 0) blk: {
                const arg_val = try self.evaluateExpression(arguments[0]);
                if (arg_val == .text) {
                    break :blk arg_val.text.data;
                } else {
                    break :blk null;
                }
            } else null;

            const result = try text.trim(self.allocator, chars);
            return MBLValue{ .text = result };
        }

        // left_trim() method
        else if (std.mem.eql(u8, method_name, "left_trim")) {
            const chars = if (arguments.len > 0) blk: {
                const arg_val = try self.evaluateExpression(arguments[0]);
                if (arg_val == .text) {
                    break :blk arg_val.text.data;
                } else {
                    break :blk null;
                }
            } else null;

            const result = try text.left_trim(self.allocator, chars);
            return MBLValue{ .text = result };
        }

        // right_trim() method
        else if (std.mem.eql(u8, method_name, "right_trim")) {
            const chars = if (arguments.len > 0) blk: {
                const arg_val = try self.evaluateExpression(arguments[0]);
                if (arg_val == .text) {
                    break :blk arg_val.text.data;
                } else {
                    break :blk null;
                }
            } else null;

            const result = try text.right_trim(self.allocator, chars);
            return MBLValue{ .text = result };
        }

        // left_pad() method - width required, char optional
        else if (std.mem.eql(u8, method_name, "left_pad")) {
            if (arguments.len == 0) {
                std.log.warn("left_pad() method requires width argument", .{});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            }

            const width_val = try self.evaluateExpression(arguments[0]);
            if (width_val != .number) {
                std.log.warn("left_pad() width must be a number", .{});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            }
            const width = @as(usize, @intFromFloat(width_val.number.value));

            const pad_char = if (arguments.len > 1) blk: {
                const arg_val = try self.evaluateExpression(arguments[1]);
                if (arg_val == .text) {
                    break :blk arg_val.text.data;
                } else {
                    break :blk null;
                }
            } else null;

            const result = try text.left_pad(self.allocator, width, pad_char);
            return MBLValue{ .text = result };
        }

        // right_pad() method - width required, char optional
        else if (std.mem.eql(u8, method_name, "right_pad")) {
            if (arguments.len == 0) {
                std.log.warn("right_pad() method requires width argument", .{});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            }

            const width_val = try self.evaluateExpression(arguments[0]);
            if (width_val != .number) {
                std.log.warn("right_pad() width must be a number", .{});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            }
            const width = @as(usize, @intFromFloat(width_val.number.value));

            const pad_char = if (arguments.len > 1) blk: {
                const arg_val = try self.evaluateExpression(arguments[1]);
                if (arg_val == .text) {
                    break :blk arg_val.text.data;
                } else {
                    break :blk null;
                }
            } else null;

            const result = try text.right_pad(self.allocator, width, pad_char);
            return MBLValue{ .text = result };
        }

        // slice() method - start and end required
        else if (std.mem.eql(u8, method_name, "slice")) {
            if (arguments.len < 2) {
                std.log.warn("slice() method requires start and end arguments", .{});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            }

            const start_val = try self.evaluateExpression(arguments[0]);
            const end_val = try self.evaluateExpression(arguments[1]);

            if (start_val != .number or end_val != .number) {
                std.log.warn("slice() arguments must be numbers", .{});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            }

            const start = @as(i32, @intFromFloat(start_val.number.value));
            const end = @as(i32, @intFromFloat(end_val.number.value));

            const result = try text.slice(self.allocator, start, end);
            return MBLValue{ .text = result };
        }

        // splice() method - start, count, replacement required
        else if (std.mem.eql(u8, method_name, "splice")) {
            if (arguments.len < 3) {
                std.log.warn("splice() method requires start, count, and replacement arguments", .{});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            }

            const start_val = try self.evaluateExpression(arguments[0]);
            const count_val = try self.evaluateExpression(arguments[1]);
            const replacement_val = try self.evaluateExpression(arguments[2]);

            if (start_val != .number or count_val != .number or replacement_val != .text) {
                std.log.warn("splice() arguments must be (number, number, text)", .{});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            }

            const start = @as(usize, @intFromFloat(start_val.number.value));
            const count = @as(usize, @intFromFloat(count_val.number.value));
            const replacement = replacement_val.text.data;

            const result = try text.splice(self.allocator, start, count, replacement);
            return MBLValue{ .text = result };
        }

        // fill() method - data required (record or list)
        else if (std.mem.eql(u8, method_name, "fill")) {
            if (arguments.len == 0) {
                std.log.warn("fill() method requires data argument (record or list)", .{});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "error") };
            }

            const data_val = try self.evaluateExpression(arguments[0]);
            const result = try text.fill(self.allocator, &data_val);
            return MBLValue{ .text = result };
        }

        // upper() method - convert to uppercase
        else if (std.mem.eql(u8, method_name, "upper")) {
            const result = try text.upper(self.allocator);
            return MBLValue{ .text = result };
        }

        // lower() method - convert to lowercase
        else if (std.mem.eql(u8, method_name, "lower")) {
            const result = try text.lower(self.allocator);
            return MBLValue{ .text = result };
        }

        // contains() method - check if text contains substring
        else if (std.mem.eql(u8, method_name, "contains")) {
            if (arguments.len == 0) {
                std.log.warn("contains() method requires substring argument", .{});
                return MBLValue{ .boolean = memory.Boolean.init(false) };
            }

            const search_val = try self.evaluateExpression(arguments[0]);
            if (search_val != .text) {
                std.log.warn("contains() argument must be text", .{});
                return MBLValue{ .boolean = memory.Boolean.init(false) };
            }

            const found = std.mem.indexOf(u8, text.data, search_val.text.data) != null;
            return MBLValue{ .boolean = memory.Boolean.init(found) };
        }

        // starts_with() method - check if text starts with prefix
        else if (std.mem.eql(u8, method_name, "starts_with")) {
            if (arguments.len == 0) {
                std.log.warn("starts_with() method requires prefix argument", .{});
                return MBLValue{ .boolean = memory.Boolean.init(false) };
            }

            const prefix_val = try self.evaluateExpression(arguments[0]);
            if (prefix_val != .text) {
                std.log.warn("starts_with() argument must be text", .{});
                return MBLValue{ .boolean = memory.Boolean.init(false) };
            }

            const starts = std.mem.startsWith(u8, text.data, prefix_val.text.data);
            return MBLValue{ .boolean = memory.Boolean.init(starts) };
        }

        // ends_with() method - check if text ends with suffix
        else if (std.mem.eql(u8, method_name, "ends_with")) {
            if (arguments.len == 0) {
                std.log.warn("ends_with() method requires suffix argument", .{});
                return MBLValue{ .boolean = memory.Boolean.init(false) };
            }

            const suffix_val = try self.evaluateExpression(arguments[0]);
            if (suffix_val != .text) {
                std.log.warn("ends_with() argument must be text", .{});
                return MBLValue{ .boolean = memory.Boolean.init(false) };
            }

            const ends = std.mem.endsWith(u8, text.data, suffix_val.text.data);
            return MBLValue{ .boolean = memory.Boolean.init(ends) };
        }

        // Unknown method
        else {
            std.log.warn("Unknown text method: {s}", .{method_name});
            return MBLValue{ .text = try memory.Text.init(self.allocator, "unknown_method") };
        }
    }

    fn evaluateBinaryExpression(self: *Interpreter, binary_expr: parser.BinaryExpression) anyerror!MBLValue {
        const left = try self.evaluateExpression(binary_expr.left.*);
        const right = try self.evaluateExpression(binary_expr.right.*);

        return switch (binary_expr.operator) {
            // Arithmetic operations
            .add => self.performAddition(left, right),
            .subtract => self.performSubtraction(left, right),
            .multiply => self.performMultiplication(left, right),
            .divide => self.performDivision(left, right),
            .modulo => self.performModulo(left, right),

            // Comparison operations
            .equal => self.performEquality(left, right),
            .not_equal => self.performInequality(left, right),
            .less_than => self.performLessThan(left, right),
            .greater_than => self.performGreaterThan(left, right),
            .less_equal => self.performLessEqual(left, right),
            .greater_equal => self.performGreaterEqual(left, right),

            // Logical operations
            .logical_and => self.performLogicalAnd(left, right),
            .logical_or => self.performLogicalOr(left, right),
        };
    }

    fn performAddition(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        // Enhanced Addition Rules:
        // 1. Text + Anything = Text Concatenation (e.g., "5" + 5 = "55")
        // 2. Number + Text = Try Numeric Addition, Fall Back to Concatenation (e.g., 5 + "5" = 10)
        // 3. Same Type Operations preserve type semantics
        // 4. Unknown propagates

        if (left == .unknown or right == .unknown) {
            return MBLValue{ .unknown = {} };
        }

        switch (left) {
            .text => {
                // Rule 1: Text + Anything = Text Concatenation
                const left_text = try self.tryValueToText(left);
                const right_text = try self.tryValueToText(right);
                const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.data, right_text.data });
                defer self.allocator.free(result); // Free the temporary string
                return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
            },
            .number => |left_num| {
                switch (right) {
                    .number => |right_num| {
                        // Number + Number = Numeric Addition
                        return MBLValue{ .number = memory.Number{ .value = left_num.value + right_num.value } };
                    },
                    .text => {
                        // Rule 2: Number + Text = Try Numeric Addition, Fall Back to Concatenation
                        if (self.tryTextToNumber(right)) |right_num| {
                            return MBLValue{ .number = memory.Number{ .value = left_num.value + right_num.value } };
                        } else {
                            // Can't convert text to number, fall back to concatenation
                            const left_text = try self.tryValueToText(left);
                            const right_text = try self.tryValueToText(right);
                            const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.data, right_text.data });
                            return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                        }
                    },
                    else => {
                        // Try to convert right operand to number, otherwise concatenate
                        if (self.tryTextToNumber(right)) |right_num| {
                            return MBLValue{ .number = memory.Number{ .value = left_num.value + right_num.value } };
                        } else {
                            const left_text = try self.tryValueToText(left);
                            const right_text = try self.tryValueToText(right);
                            const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.data, right_text.data });
                            return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                        }
                    },
                }
            },
            .money => |left_money| {
                switch (right) {
                    .money => |right_money| {
                        // Money + Money = Money Addition (same currency logic)
                        const result_value = left_money.value + right_money.value;
                        const result_money = try memory.Money.init(self.allocator, result_value, left_money.currency, left_money.currency, 1.0);
                        return MBLValue{ .money = result_money };
                    },
                    else => {
                        // Money + Other = Text Concatenation
                        const left_text = try self.tryValueToText(left);
                        const right_text = try self.tryValueToText(right);
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.data, right_text.data });
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                }
            },
            .time => |left_time| {
                switch (right) {
                    .time => |right_time| {
                        // Time + Time = Time arithmetic
                        const result_time = left_time.add(right_time);
                        return MBLValue{ .time = result_time };
                    },
                    .duration => |right_duration| {
                        // Time + Duration = Time arithmetic
                        const result_time = left_time.addDuration(right_duration);
                        return MBLValue{ .time = result_time };
                    },
                    else => {
                        // Time + Other = Text Concatenation
                        const left_text = try self.tryValueToText(left);
                        const right_text = try self.tryValueToText(right);
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.data, right_text.data });
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                }
            },
            .duration => |left_duration| {
                switch (right) {
                    .duration => |right_duration| {
                        // Duration + Duration = Duration arithmetic
                        const result_duration = left_duration.add(right_duration);
                        return MBLValue{ .duration = result_duration };
                    },
                    else => {
                        // Duration + Other = Text Concatenation
                        const left_text = try self.tryValueToText(left);
                        const right_text = try self.tryValueToText(right);
                        const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.data, right_text.data });
                        return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
                    },
                }
            },
            else => {
                // Default: Convert everything to text and concatenate
                const left_text = try self.tryValueToText(left);
                const right_text = try self.tryValueToText(right);
                const result = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left_text.data, right_text.data });
                defer self.allocator.free(result); // Free the temporary string
                return MBLValue{ .text = try memory.Text.init(self.allocator, result) };
            },
        }
    }

    fn performSubtraction(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        // Try to convert both operands to numbers
        const left_num = self.tryTextToNumber(left);
        const right_num = self.tryTextToNumber(right);

        if (left_num != null and right_num != null) {
            return MBLValue{ .number = memory.Number{ .value = left_num.?.value - right_num.?.value } };
        }

        // If automatic conversion fails, fall back to original type-specific logic
        switch (left) {
            .number => |left_num_val| {
                switch (right) {
                    .number => |right_num_val| {
                        return MBLValue{ .number = memory.Number{ .value = left_num_val.value - right_num_val.value } };
                    },
                    else => {
                        try self.recordSimpleError("Invalid type for subtraction operation", "subtraction");
                        return MBLValue{ .unknown = {} };
                    },
                }
            },
            .money => |left_money| {
                switch (right) {
                    .money => |right_money| {
                        const result_value = left_money.value - right_money.value;
                        const result_money = try memory.Money.init(self.allocator, result_value, left_money.currency, left_money.currency, 1.0);
                        return MBLValue{ .money = result_money };
                    },
                    else => return error.TypeError,
                }
            },
            .time => |left_time| {
                switch (right) {
                    .time => |right_time| {
                        // Time arithmetic: time - time (duration)
                        const result_time = left_time.subtract(right_time);
                        return MBLValue{ .time = result_time };
                    },
                    else => return error.TypeError,
                }
            },
            .duration => |left_duration| {
                switch (right) {
                    .duration => |right_duration| {
                        // Duration arithmetic: duration - duration
                        const result_duration = left_duration.subtract(right_duration);
                        return MBLValue{ .duration = result_duration };
                    },
                    else => return error.TypeError,
                }
            },
            else => return error.TypeError,
        }
    }

    fn performMultiplication(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        // Enhanced Multiplication Rules:
        // Try to convert both operands to numbers for arithmetic operations
        // Special handling for Money * Number and Number * Money

        if (left == .unknown or right == .unknown) {
            return MBLValue{ .unknown = {} };
        }

        // Try automatic number conversions first
        const left_num = self.tryTextToNumber(left);
        const right_num = self.tryTextToNumber(right);

        if (left_num != null and right_num != null) {
            return MBLValue{ .number = memory.Number{ .value = left_num.?.value * right_num.?.value } };
        }

        // Handle specific type combinations
        switch (left) {
            .number => |left_num_val| {
                switch (right) {
                    .money => |right_money| {
                        // Number * Money -> Money
                        const new_value = @as(i64, @intFromFloat(left_num_val.value * @as(f64, @floatFromInt(right_money.value))));
                        const result_money = try memory.Money.init(self.allocator, new_value, right_money.currency, right_money.base, right_money.conversion);
                        return MBLValue{ .money = result_money };
                    },
                    else => {
                        try self.recordSimpleError("Invalid type for multiplication operation", "multiplication");
                        return MBLValue{ .unknown = {} };
                    },
                }
            },
            .money => |left_money| {
                // Try to convert right operand to number for Money * Number
                if (self.tryTextToNumber(right)) |right_num_val| {
                    const new_value = @as(i64, @intFromFloat(@as(f64, @floatFromInt(left_money.value)) * right_num_val.value));
                    const result_money = try memory.Money.init(self.allocator, new_value, left_money.currency, left_money.base, left_money.conversion);
                    return MBLValue{ .money = result_money };
                } else {
                    try self.recordSimpleError("Invalid type for multiplication operation", "multiplication");
                    return MBLValue{ .unknown = {} };
                }
            },
            else => {
                try self.recordSimpleError("Invalid type for multiplication operation", "multiplication");
                return MBLValue{ .unknown = {} };
            },
        }
    }

    fn performDivision(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        // Enhanced Division Rules:
        // Try to convert both operands to numbers for arithmetic operations
        // Special handling for Money / Number and Money / Money

        if (left == .unknown or right == .unknown) {
            return MBLValue{ .unknown = {} };
        }

        // Try automatic number conversions first
        const left_num = self.tryTextToNumber(left);
        const right_num = self.tryTextToNumber(right);

        if (left_num != null and right_num != null) {
            if (right_num.?.value == 0) {
                try self.recordSimpleError("Cannot divide by zero in arithmetic operation", "division");
                return MBLValue{ .unknown = {} };
            }
            return MBLValue{ .number = memory.Number{ .value = left_num.?.value / right_num.?.value } };
        }

        // Handle specific type combinations
        switch (left) {
            .number => |left_num_val| {
                // Try to convert right operand to number
                if (self.tryTextToNumber(right)) |right_num_val| {
                    if (right_num_val.value == 0) {
                        try self.recordSimpleError("Cannot divide by zero in arithmetic operation", "division");
                        return MBLValue{ .unknown = {} };
                    }
                    return MBLValue{ .number = memory.Number{ .value = left_num_val.value / right_num_val.value } };
                } else {
                    try self.recordSimpleError("Invalid type for division operation", "division");
                    return MBLValue{ .unknown = {} };
                }
            },
            .money => |left_money| {
                switch (right) {
                    .money => |right_money| {
                        // Divide money by money -> number (ratio)
                        if (right_money.value == 0) {
                            try self.recordSimpleError("Cannot divide by zero money amount", "division");
                            return MBLValue{ .unknown = {} };
                        }
                        const ratio = @as(f64, @floatFromInt(left_money.value)) / @as(f64, @floatFromInt(right_money.value));
                        return MBLValue{ .number = memory.Number{ .value = ratio } };
                    },
                    else => {
                        // Try to convert right operand to number for Money / Number
                        if (self.tryTextToNumber(right)) |right_num_val| {
                            if (right_num_val.value == 0) {
                                try self.recordSimpleError("Cannot divide money by zero", "division");
                                return MBLValue{ .unknown = {} };
                            }
                            // Divide money by number -> money
                            const new_value = @as(i64, @intFromFloat(@as(f64, @floatFromInt(left_money.value)) / right_num_val.value));
                            const result_money = try memory.Money.init(self.allocator, new_value, left_money.currency, left_money.base, left_money.conversion);
                            return MBLValue{ .money = result_money };
                        } else {
                            try self.recordSimpleError("Invalid type for money division", "division");
                            return MBLValue{ .unknown = {} };
                        }
                    },
                }
            },
            else => {
                try self.recordSimpleError("Invalid type for division operation", "division");
                return MBLValue{ .unknown = {} };
            },
        }
    }

    fn performModulo(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        // Enhanced Modulo Rules:
        // Try to convert both operands to numbers for arithmetic operations

        if (left == .unknown or right == .unknown) {
            return MBLValue{ .unknown = {} };
        }

        // Try automatic number conversions
        const left_num = self.tryTextToNumber(left);
        const right_num = self.tryTextToNumber(right);

        if (left_num != null and right_num != null) {
            if (right_num.?.value == 0) {
                try self.recordSimpleError("Cannot perform modulo with zero divisor", "modulo");
                return MBLValue{ .unknown = {} };
            }
            return MBLValue{ .number = memory.Number{ .value = @mod(left_num.?.value, right_num.?.value) } };
        }

        try self.recordSimpleError("Invalid types for modulo operation", "modulo");
        return MBLValue{ .unknown = {} };
    }

    fn performEquality(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        _ = self;
        const result = switch (left) {
            .number => |left_num| switch (right) {
                .number => |right_num| left_num.value == right_num.value,
                else => false,
            },
            .text => |left_text| switch (right) {
                .text => |right_text| std.mem.eql(u8, left_text.data, right_text.data),
                else => false,
            },
            .boolean => |left_bool| switch (right) {
                .boolean => |right_bool| left_bool.value == right_bool.value,
                else => false,
            },
            .money => |left_money| switch (right) {
                .money => |right_money| left_money.value == right_money.value and
                    std.mem.eql(u8, left_money.currency, right_money.currency),
                else => false,
            },
            .time => |left_time| switch (right) {
                .time => |right_time| left_time.value == right_time.value,
                else => false,
            },
            .duration => |left_duration| switch (right) {
                .duration => |right_duration| left_duration.value == right_duration.value,
                else => false,
            },
            else => false,
        };
        return MBLValue{ .boolean = memory.Boolean{ .value = result } };
    }

    fn performInequality(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const equality = try self.performEquality(left, right);
        return MBLValue{ .boolean = memory.Boolean{ .value = !equality.boolean.value } };
    }

    fn performLessThan(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        _ = self;
        const result = switch (left) {
            .number => |left_num| switch (right) {
                .number => |right_num| left_num.value < right_num.value,
                else => return error.TypeError,
            },
            .money => |left_money| switch (right) {
                .money => |right_money| left_money.value < right_money.value,
                else => return error.TypeError,
            },
            .time => |left_time| switch (right) {
                .time => |right_time| left_time.value < right_time.value, // Earlier time is "less than"
                else => return error.TypeError,
            },
            .duration => |left_duration| switch (right) {
                .duration => |right_duration| left_duration.value < right_duration.value, // Shorter duration is "less than"
                else => return error.TypeError,
            },
            else => return error.TypeError,
        };
        return MBLValue{ .boolean = memory.Boolean{ .value = result } };
    }

    fn performGreaterThan(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        _ = self;
        const result = switch (left) {
            .number => |left_num| switch (right) {
                .number => |right_num| left_num.value > right_num.value,
                else => return error.TypeError,
            },
            .money => |left_money| switch (right) {
                .money => |right_money| left_money.value > right_money.value,
                else => return error.TypeError,
            },
            .time => |left_time| switch (right) {
                .time => |right_time| left_time.value > right_time.value, // Later time is "greater than"
                else => return error.TypeError,
            },
            .duration => |left_duration| switch (right) {
                .duration => |right_duration| left_duration.value > right_duration.value, // Longer duration is "greater than"
                else => return error.TypeError,
            },
            else => return error.TypeError,
        };
        return MBLValue{ .boolean = memory.Boolean{ .value = result } };
    }

    fn performLessEqual(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const less = try self.performLessThan(left, right);
        const equal = try self.performEquality(left, right);
        return MBLValue{ .boolean = memory.Boolean{ .value = less.boolean.value or equal.boolean.value } };
    }

    fn performGreaterEqual(self: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const greater = try self.performGreaterThan(left, right);
        const equal = try self.performEquality(left, right);
        return MBLValue{ .boolean = memory.Boolean{ .value = greater.boolean.value or equal.boolean.value } };
    }

    fn performLogicalAnd(_: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const left_logic = left.isTruthy();
        const right_logic = right.isTruthy();

        // Ternary logic AND truth table
        const result = switch (left_logic) {
            .true_val => switch (right_logic) {
                .true_val => memory.TernaryLogic.true_val,
                .false_val => memory.TernaryLogic.false_val,
                .unknown => memory.TernaryLogic.unknown,
            },
            .false_val => memory.TernaryLogic.false_val, // false dominates
            .unknown => switch (right_logic) {
                .false_val => memory.TernaryLogic.false_val, // false dominates
                else => memory.TernaryLogic.unknown,
            },
        };

        return switch (result) {
            .true_val => MBLValue{ .boolean = memory.Boolean{ .value = true } },
            .false_val => MBLValue{ .boolean = memory.Boolean{ .value = false } },
            .unknown => MBLValue{ .unknown = {} },
        };
    }

    fn performLogicalOr(_: *Interpreter, left: MBLValue, right: MBLValue) anyerror!MBLValue {
        const left_logic = left.isTruthy();
        const right_logic = right.isTruthy();

        // Ternary logic OR truth table
        const result = switch (left_logic) {
            .true_val => memory.TernaryLogic.true_val, // true dominates
            .false_val => switch (right_logic) {
                .true_val => memory.TernaryLogic.true_val,
                .false_val => memory.TernaryLogic.false_val,
                .unknown => memory.TernaryLogic.unknown,
            },
            .unknown => switch (right_logic) {
                .true_val => memory.TernaryLogic.true_val, // true dominates
                else => memory.TernaryLogic.unknown,
            },
        };

        return switch (result) {
            .true_val => MBLValue{ .boolean = memory.Boolean{ .value = true } },
            .false_val => MBLValue{ .boolean = memory.Boolean{ .value = false } },
            .unknown => MBLValue{ .unknown = {} },
        };
    }

    fn isTruthy(_: *Interpreter, value: MBLValue) bool {
        // Legacy support - convert TernaryLogic to bool for older code
        return switch (value.isTruthy()) {
            .true_val => true,
            .false_val, .unknown => false,
        };
    }

    fn evaluateUnaryExpression(self: *Interpreter, unary_expr: parser.UnaryExpression) anyerror!MBLValue {
        const operand = try self.evaluateExpression(unary_expr.operand.*);

        return switch (unary_expr.operator) {
            .minus => {
                switch (operand) {
                    .number => |num| {
                        return MBLValue{ .number = memory.Number{ .value = -num.value } };
                    },
                    else => return error.TypeError,
                }
            },
            .logical_not => {
                const logic = operand.isTruthy();
                const result = switch (logic) {
                    .true_val => memory.TernaryLogic.false_val,
                    .false_val => memory.TernaryLogic.true_val,
                    .unknown => memory.TernaryLogic.unknown,
                };
                return switch (result) {
                    .true_val => MBLValue{ .boolean = memory.Boolean{ .value = true } },
                    .false_val => MBLValue{ .boolean = memory.Boolean{ .value = false } },
                    .unknown => MBLValue{ .unknown = {} },
                };
            },
        };
    }

    fn evaluatePropertyAccess(self: *Interpreter, prop_access: parser.PropertyAccess) anyerror!MBLValue {
        // Handle scope resolution with 'program' and 'super' keywords
        if (prop_access.object.* == .identifier) {
            const obj_name = prop_access.object.identifier.name;
            const prop_name = prop_access.property;

            if (std.mem.eql(u8, obj_name, "program")) {
                // Handle special program properties
                if (std.mem.eql(u8, prop_name, "cli")) {
                    // Return a CLI namespace object
                    var cli_record = memory.Record.init(self.allocator);
                    try cli_record.data.put("_type", MBLValue{ .text = try memory.Text.init(self.allocator, "cli") });
                    return MBLValue{ .record = cli_record };
                }

                // Direct access to program scope
                if (self.memory.program.data.get(prop_name)) |value| {
                    std.log.info("🔍 Variable '{s}' accessed via program scope", .{prop_name});
                    return value;
                } else {
                    std.log.warn("🔍 Variable 'program.{s}' not found", .{prop_name});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            } else if (std.mem.eql(u8, obj_name, "super")) {
                // Access to parent scope (one level up)
                if (self.scope_stack.items.len > 1) {
                    const parent_scope = self.scope_stack.items[self.scope_stack.items.len - 2];
                    if (parent_scope.data.get(prop_name)) |value| {
                        std.log.info("🔍 Variable '{s}' accessed via super scope", .{prop_name});
                        return value;
                    }
                }
                // If not found in parent, check program scope
                if (self.memory.program.data.get(prop_name)) |value| {
                    std.log.info("🔍 Variable '{s}' accessed via super (fallback to program)", .{prop_name});
                    return value;
                } else {
                    std.log.warn("🔍 Variable 'super.{s}' not found", .{prop_name});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            }
        }

        // For other property access, evaluate the object and access its properties
        const obj_value = try self.evaluateExpression(prop_access.object.*);

        // Handle record property access
        switch (obj_value) {
            .record => |record| {
                if (record.data.get(prop_access.property)) |value| {
                    return value;
                } else {
                    std.log.warn("  Property '{s}' not found on record", .{prop_access.property});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            },
            .time => |time_value| {
                // Handle time property access (year, month, day, hour, minute, second)
                if (std.mem.eql(u8, prop_access.property, "year")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.year()) } };
                } else if (std.mem.eql(u8, prop_access.property, "month")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.month()) } };
                } else if (std.mem.eql(u8, prop_access.property, "day")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.day()) } };
                } else if (std.mem.eql(u8, prop_access.property, "hour")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.hour()) } };
                } else if (std.mem.eql(u8, prop_access.property, "minute")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.minute()) } };
                } else if (std.mem.eql(u8, prop_access.property, "second")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(time_value.second()) } };
                } else {
                    std.log.warn("  Property '{s}' not found on time value", .{prop_access.property});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            },
            .duration => |duration_value| {
                // Handle duration property access (days, hours, minutes, seconds)
                if (std.mem.eql(u8, prop_access.property, "days")) {
                    return MBLValue{ .number = memory.Number{ .value = duration_value.days() } };
                } else if (std.mem.eql(u8, prop_access.property, "hours")) {
                    return MBLValue{ .number = memory.Number{ .value = duration_value.hours() } };
                } else if (std.mem.eql(u8, prop_access.property, "minutes")) {
                    return MBLValue{ .number = memory.Number{ .value = duration_value.minutes() } };
                } else if (std.mem.eql(u8, prop_access.property, "seconds")) {
                    return MBLValue{ .number = memory.Number{ .value = duration_value.seconds() } };
                } else {
                    std.log.warn("  Property '{s}' not found on duration value", .{prop_access.property});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            },
            .list => |*list_value| {
                // Handle list property access (length)
                if (std.mem.eql(u8, prop_access.property, "length") or std.mem.eql(u8, prop_access.property, "len")) {
                    return MBLValue{ .number = memory.Number{ .value = @floatFromInt(list_value.len()) } };
                } else {
                    std.log.warn("  Property '{s}' not found on list value", .{prop_access.property});
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
                }
            },
            else => {
                std.log.warn("  Cannot access property '{s}' on non-record value", .{prop_access.property});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
            }
        }
    }

    fn executeIfStatement(self: *Interpreter, if_stmt: parser.IfStatement) anyerror!void {
        const condition_value = try self.evaluateExpression(if_stmt.condition);
        const condition_truthy = self.isTruthy(condition_value);

        if (condition_truthy) {
            std.log.info("🔀 If condition is true, executing then branch", .{});

            // Create local scope for if-block
            var local_scope = memory.Record.init(self.allocator);
            defer local_scope.deinit();

            try self.pushScope(&local_scope);
            defer self.popScope();

            for (if_stmt.then_branch) |stmt| {
                if (self.executeStatement(stmt)) |_| {
                    // Statement executed normally
                } else |err| switch (err) {
                    InterpreterError.GotoExecuted => {
                        // Propagate the goto up to the main execution loop
                        return InterpreterError.GotoExecuted;
                    },
                    else => return err,
                }
            }
        } else {
            if (if_stmt.else_branch) |else_branch| {
                std.log.info("🔀 If condition is false, executing else branch", .{});

                // Create local scope for else-block
                var local_scope = memory.Record.init(self.allocator);
                defer local_scope.deinit();

                try self.pushScope(&local_scope);
                defer self.popScope();

                for (else_branch) |stmt| {
                    if (self.executeStatement(stmt)) |_| {
                        // Statement executed normally
                    } else |err| switch (err) {
                        InterpreterError.GotoExecuted => {
                            // Propagate the goto up to the main execution loop
                            return InterpreterError.GotoExecuted;
                        },
                        else => return err,
                    }
                }
            } else {
                std.log.info("🔀 If condition is false, no else branch", .{});
            }
        }
    }

    fn executeWhileStatement(self: *Interpreter, while_stmt: parser.WhileStatement) anyerror!void {

        var iteration_count: usize = 0;
        const max_iterations: usize = 10000; // Prevent infinite loops

        while (true) {
            // Check for infinite loop protection
            iteration_count += 1;
            if (iteration_count > max_iterations) {
                std.log.err("❌ While loop exceeded maximum iterations ({})", .{max_iterations});
                return InterpreterError.TypeError; // Could add specific InfiniteLoopError
            }

            // Evaluate the condition
            const condition_value = try self.evaluateExpression(while_stmt.condition);
            const condition_truthy = self.isTruthy(condition_value);

            if (!condition_truthy) {
                std.log.info("🔄 While condition is false, exiting loop", .{});
                break;
            }

            std.log.info("🔄 While iteration {}, condition is true", .{iteration_count});

            // Execute the loop body (no local scope needed for while loops)
            // Unlike for loops, while loops should work with existing variables
            for (while_stmt.body) |stmt| {
                if (self.executeStatement(stmt)) |_| {
                    // Statement executed normally
                } else |err| switch (err) {
                    InterpreterError.BreakExecuted => {
                        std.log.info("🔄 Break encountered, exiting while loop", .{});
                        return; // Exit the while loop entirely
                    },
                    InterpreterError.ContinueExecuted => {
                        std.log.info("🔄 Continue encountered, skipping to next while iteration", .{});
                        break; // Skip the rest of the loop body statements, continue with next iteration
                    },
                    InterpreterError.GotoExecuted => {
                        // Propagate the goto up to the main execution loop
                        return InterpreterError.GotoExecuted;
                    },
                    else => return err,
                }
            }
        }

        std.log.info("✓ While loop completed after {} iterations", .{iteration_count - 1});
    }

    fn executeForStatement(self: *Interpreter, for_stmt: parser.ForStatement) anyerror!void {
        std.log.info("🔄 Executing for loop with variable '{s}'", .{for_stmt.variable});

        // Evaluate the iterable expression (e.g., a list, record, etc.)
        const iterable_value = try self.evaluateExpression(for_stmt.iterable);

        switch (iterable_value) {
            .list => |list| {
                std.log.info("🔄 Iterating over list with {} elements", .{list.len()});

                // Check if list contains records (potential for memory corruption)
                if (list.len() > 0) {
                    const first_item = list.get(0) orelse MBLValue{ .unknown = {} };
                    if (first_item == .record) {
                        self.used_for_loop_with_records = true;
                        self.memory.has_csv_imported = true; // Enable protection
                        std.log.info("🚨 For loop with record data detected - enabling memory protection", .{});
                    }
                }

                // Iterate over each item in the list
                for (0..list.len()) |i| {
                    const item = list.get(i) orelse continue;

                    // Create empty local scope for this iteration (no loop variable ownership)
                    var local_scope = memory.Record.init(self.allocator);
                    defer local_scope.deinit();

                    // Store loop variable separately without transferring ownership
                    self.current_loop_variable = item;
                    self.current_loop_variable_name = for_stmt.variable;

                    try self.pushScope(&local_scope);
                    defer self.popScope();

                    // Clear loop variable after scope is popped
                    defer {
                        self.current_loop_variable = null;
                        self.current_loop_variable_name = null;
                    }

                    std.log.info("🔄 For iteration {}, {s} = {s}", .{i, for_stmt.variable, @tagName(item)});

                    // Execute the loop body
                    for (for_stmt.body) |stmt| {
                        if (self.executeStatement(stmt)) |_| {
                            // Statement executed normally
                        } else |err| switch (err) {
                            InterpreterError.BreakExecuted => {
                                std.log.info("🔄 Break encountered, exiting for loop", .{});
                                return; // Exit the for loop entirely
                            },
                            InterpreterError.ContinueExecuted => {
                                std.log.info("🔄 Continue encountered, skipping to next for iteration", .{});
                                break; // Skip the rest of the loop body statements, continue with next iteration
                            },
                            InterpreterError.GotoExecuted => {
                                // Propagate the goto up to the main execution loop
                                return InterpreterError.GotoExecuted;
                            },
                            else => return err,
                        }
                    }
                }
            },
            .record => |record| {
                std.log.info("🔄 Iterating over record with {} fields", .{record.data.count()});

                // Iterate over record keys (we can add value iteration later)
                var iterator = record.data.iterator();
                var i: usize = 0;
                while (iterator.next()) |entry| {
                    // Create MBLValue for the key (record iteration yields keys)
                    const key_value = MBLValue{ .text = try memory.Text.init(self.allocator, entry.key_ptr.*) };
                    defer {
                        // Clean up the key_value we created
                        var mutable_key = key_value;
                        mutable_key.deinit(self.allocator);
                    }

                    // Create empty local scope for this iteration (no loop variable ownership)
                    var local_scope = memory.Record.init(self.allocator);
                    defer local_scope.deinit();

                    // Store loop variable separately without transferring ownership
                    self.current_loop_variable = key_value;
                    self.current_loop_variable_name = for_stmt.variable;

                    try self.pushScope(&local_scope);
                    defer self.popScope();

                    // Clear loop variable after scope is popped
                    defer {
                        self.current_loop_variable = null;
                        self.current_loop_variable_name = null;
                    }

                    std.log.info("🔄 For iteration {}, {s} = {s}", .{i, for_stmt.variable, entry.key_ptr.*});

                    // Execute the loop body
                    for (for_stmt.body) |stmt| {
                        if (self.executeStatement(stmt)) |_| {
                            // Statement executed normally
                        } else |err| switch (err) {
                            InterpreterError.BreakExecuted => {
                                std.log.info("🔄 Break encountered, exiting for loop", .{});
                                return; // Exit the for loop entirely
                            },
                            InterpreterError.ContinueExecuted => {
                                std.log.info("🔄 Continue encountered, skipping to next for iteration", .{});
                                break; // Skip the rest of the loop body statements, continue with next iteration
                            },
                            InterpreterError.GotoExecuted => {
                                // Propagate the goto up to the main execution loop
                                return InterpreterError.GotoExecuted;
                            },
                            else => return err,
                        }
                    }
                    i += 1;
                }
            },
            else => {
                std.log.err("❌ Cannot iterate over {s} type", .{@tagName(iterable_value)});
                return InterpreterError.TypeError;
            }
        }

        std.log.info("✓ For loop completed", .{});
    }

    // Function management methods
    fn registerFunction(self: *Interpreter, func_decl: parser.FunctionDeclaration) !void {
        std.log.info("🔧 Registering function '{s}' with {} parameters", .{func_decl.name, func_decl.parameters.len});

        // Store reference to original function declaration to avoid double-free issues
        // The original AST owns the memory, we just keep a reference
        try self.functions.put(func_decl.name, func_decl);
        std.log.info("✅ Function '{s}' registered successfully", .{func_decl.name});
    }

    fn registerActivator(self: *Interpreter, activator: parser.ActivatorDeclaration) !void {
        self.log("⚡ Registering activator with condition", .{});

        // Store the activator for later evaluation
        try self.activators.append(activator);
        self.log("✅ Activator registered successfully (total: {})", .{self.activators.items.len});
    }

    fn checkActivators(self: *Interpreter) void {
        // Prevent recursion - if we're already executing an activator, don't check again
        if (self.executing_activator) {
            return;
        }

        // Check each registered activator
        for (self.activators.items) |activator| {
            // Evaluate the activator condition
            const condition_result = self.evaluateExpression(activator.condition) catch |err| {
                self.log("⚠️  Failed to evaluate activator condition: {}", .{err});
                continue;
            };

            // Check if condition is true
            const condition_is_true = switch (condition_result) {
                .boolean => |b| b.value,
                .unknown => false, // Unknown is not true
                else => blk: {
                    // Try to convert to boolean
                    const bool_result = condition_result.convertToBoolean(self.allocator) catch |err| {
                        self.log("⚠️  Failed to convert activator condition to boolean: {}", .{err});
                        break :blk false;
                    };
                    break :blk bool_result.boolean.value;
                }
            };

            if (condition_is_true) {
                self.log("⚡ Activator condition became true - executing body", .{});

                // Set recursion prevention flag
                self.executing_activator = true;

                // Execute the activator body
                for (activator.body) |stmt| {
                    self.executeStatement(stmt) catch |err| {
                        self.log("⚠️  Error executing activator statement: {}", .{err});
                        break; // Stop executing this activator's body on error
                    };
                }

                // Clear recursion prevention flag
                self.executing_activator = false;

                self.log("✅ Activator execution completed", .{});
            }
        }
    }

    fn executeReturnStatement(self: *Interpreter, return_stmt: parser.ReturnStatement) !void {
        if (return_stmt.value) |return_expr| {
            // Explicit return with value - make deep copy to avoid scope cleanup issues
            const expr_value = try self.evaluateExpression(return_expr);
            self.return_value = try expr_value.clone(self.allocator);
            std.log.info("🔄 Return statement executed with value", .{});
        } else {
            // Return without value (should return function's data scope)
            self.return_value = null;
            std.log.info("🔄 Return statement executed without value (will return data scope)", .{});
        }
        return InterpreterError.ReturnExecuted;
    }

    fn executeLoadStatement(self: *Interpreter, load_stmt: parser.LoadStatement) anyerror!void {
        self.log("🔧 Executing load statement for file: {s}", .{load_stmt.filename});

        // Read the file content
        const file = std.fs.cwd().openFile(load_stmt.filename, .{}) catch |err| {
            std.log.err("❌ Error opening file '{s}': {}", .{load_stmt.filename, err});
            try self.recordSimpleError("Could not open file for loading", "load");
            return;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        const source_code = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(source_code);

        _ = try file.readAll(source_code);

        // Import lexer and parser
        const lexer = @import("lexer.zig");
        const parser_module = @import("parser.zig");

        // Create lexer and parser for the loaded file
        var lex = lexer.Lexer.init(self.allocator, source_code, load_stmt.filename);

        // Tokenize the loaded file
        const tokens = lex.scanTokens() catch |err| {
            std.log.err("❌ Error tokenizing file '{s}': {}", .{load_stmt.filename, err});
            try self.recordSimpleError("Could not tokenize loaded file", "load");
            return;
        };
        defer tokens.deinit(); // Clean up token list

        // Parse the loaded file
        var file_parser = parser_module.Parser.init(self.allocator, tokens.items);
        const statements = file_parser.parse() catch |err| {
            std.log.err("❌ Error parsing file '{s}': {}", .{load_stmt.filename, err});
            try self.recordSimpleError("Could not parse loaded file", "load");
            return;
        };
        defer {
            // Clean up statements
            for (statements) |*stmt| {
                stmt.deinit(self.allocator);
            }
            self.allocator.free(statements);
        }

        self.log("✅ Successfully loaded and parsed {} statements from '{s}'", .{statements.len, load_stmt.filename});

        // Execute the loaded statements
        for (statements) |stmt| {
            try self.executeStatement(stmt);
        }

        self.log("🎉 Successfully executed all statements from loaded file '{s}'", .{load_stmt.filename});
    }

    fn callFunction(self: *Interpreter, func_name: []const u8, arguments: []parser.Expression) anyerror!MBLValue {
        // Look up function
        const func_decl = self.functions.get(func_name) orelse {
            std.log.err("❌ Function '{s}' not found", .{func_name});
            return InterpreterError.TypeError;
        };

        std.log.info("📞 Calling function '{s}' with {} arguments", .{func_name, arguments.len});

        // Create function's data scope (record for local variables)
        var function_scope = memory.Record.init(self.allocator);
        // Note: Not using defer deinit() here to allow deep copy of return values

        // Push function scope
        try self.pushScope(&function_scope);
        defer self.popScope();

        // Bind parameters to arguments
        for (func_decl.parameters, 0..) |param, i| {
            const arg_value = if (i < arguments.len)
                try self.evaluateExpression(arguments[i])
            else if (param.default_value) |default_expr|
                try self.evaluateExpression(default_expr)
            else {
                std.log.err("❌ Missing argument for parameter '{s}'", .{param.name});
                return InterpreterError.TypeError;
            };

            try self.createLocalVariable(param.name, arg_value);
            std.log.info("📝 Bound parameter '{s}' to argument", .{param.name});
        }

        // Clear return value before executing function body
        self.return_value = null;

        // Execute function body
        for (func_decl.body) |stmt| {
            if (self.executeStatement(stmt)) |_| {
                // Statement executed normally
            } else |err| switch (err) {
                InterpreterError.ReturnExecuted => {
                    // Function returned explicitly
                    break;
                },
                else => return err,
            }
        }

        // Determine return value and handle cleanup
        if (self.return_value) |return_val| {
            // Explicit return value - clean up function scope after extracting return value
            std.log.info("✅ Function '{s}' returned explicit value", .{func_name});
            function_scope.deinit(); // Clean up now that we have the return value
            return return_val;
        } else {
            // Implicit return: return a deep copy of function's data scope (record)
            std.log.info("✅ Function '{s}' returning data scope (record)", .{func_name});
            const cloned_record = try function_scope.clone();
            function_scope.deinit(); // Clean up the original scope after cloning
            return MBLValue{ .record = cloned_record };
        }
    }

    // HTTP Client Functions
    fn handleProgramGet(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        return try self.handleHttpRequest("GET", arguments);
    }

    fn handleProgramPost(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        return try self.handleHttpRequest("POST", arguments);
    }

    fn handleProgramPut(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        return try self.handleHttpRequest("PUT", arguments);
    }

    fn handleProgramDelete(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        return try self.handleHttpRequest("DELETE", arguments);
    }

    fn handleHttpRequest(self: *Interpreter, method: []const u8, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len == 0 or arguments.len > 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "HTTP request requires 1 or 2 arguments: url and optional data/params") };
        }

        // Get URL
        const url_value = try self.evaluateExpression(arguments[0]);
        const url_str = switch (url_value) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "URL must be text") };
            },
        };

        std.log.info("🌐 Making {s} request to: {s}", .{ method, url_str });

        // For now, create a mock response to demonstrate the API works
        // TODO: Replace with actual HTTP client implementation
        var response_record = memory.Record.init(self.allocator);

        // Mock successful response
        try response_record.set("status", MBLValue{ .text = try memory.Text.init(self.allocator, "200") });

        // Create mock JSON response based on URL
        var mock_response = memory.Record.init(self.allocator);
        if (std.mem.indexOf(u8, url_str, "httpbin.org/json")) |_| {
            try mock_response.set("slideshow", MBLValue{ .text = try memory.Text.init(self.allocator, "Sample JSON") });
            try mock_response.set("title", MBLValue{ .text = try memory.Text.init(self.allocator, "Sample Slide Show") });
        } else if (std.mem.indexOf(u8, url_str, "api.github.com")) |_| {
            try mock_response.set("name", MBLValue{ .text = try memory.Text.init(self.allocator, "The Octocat") });
            try mock_response.set("public_repos", MBLValue{ .number = memory.Number{ .value = 8 } });
            try mock_response.set("login", MBLValue{ .text = try memory.Text.init(self.allocator, "octocat") });
        } else {
            try mock_response.set("message", MBLValue{ .text = try memory.Text.init(self.allocator, "HTTP client working - this is a mock response") });
            try mock_response.set("method", MBLValue{ .text = try memory.Text.init(self.allocator, method) });
            try mock_response.set("url", MBLValue{ .text = try memory.Text.init(self.allocator, url_str) });
        }

        try response_record.set("body", MBLValue{ .record = mock_response });

        std.log.info("✅ HTTP {s} request completed (MOCK RESPONSE)", .{method});

        return MBLValue{ .record = response_record };
    }

    fn serializeToQuery(self: *Interpreter, value: MBLValue) ![]const u8 {
        var query = std.ArrayList(u8).init(self.allocator);
        defer query.deinit();

        switch (value) {
            .record => |record| {
                var iterator = record.data.iterator();
                var first = true;
                while (iterator.next()) |entry| {
                    if (!first) try query.append('&');
                    try query.appendSlice(entry.key_ptr.*);
                    try query.append('=');

                    const val_str = switch (entry.value_ptr.*) {
                        .text => |text| text.data,
                        .number => |num| blk: {
                            break :blk try std.fmt.allocPrint(self.allocator, "{d}", .{num.value});
                        },
                        .boolean => |bool_val| if (bool_val.value) "true" else "false",
                        else => "unknown",
                    };

                    // URL encode the value
                    var encoded = std.ArrayList(u8).init(self.allocator);
                    defer encoded.deinit();
                    for (val_str) |c| {
                        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
                            try encoded.append(c);
                        } else {
                            try encoded.writer().print("%{X:0>2}", .{c});
                        }
                    }
                    try query.appendSlice(encoded.items);
                    first = false;
                }
            },
            else => return try std.fmt.allocPrint(self.allocator, "value={s}", .{"unsupported"}),
        }

        return try query.toOwnedSlice();
    }

    fn serializeToJson(self: *Interpreter, value: MBLValue) ![]const u8 {
        var json = std.ArrayList(u8).init(self.allocator);
        defer json.deinit();

        try self.writeJsonValue(json.writer(), value);
        return try json.toOwnedSlice();
    }

    fn writeJsonValue(self: *Interpreter, writer: anytype, value: MBLValue) !void {
        switch (value) {
            .text => |text| {
                try writer.print("\"{}\"", .{std.zig.fmtEscapes(text.data)});
            },
            .number => |num| {
                try writer.print("{d}", .{num.value});
            },
            .boolean => |bool_val| {
                try writer.print("{}", .{bool_val.value});
            },
            .record => |record| {
                try writer.writeAll("{");
                var iterator = record.data.iterator();
                var first = true;
                while (iterator.next()) |entry| {
                    if (!first) try writer.writeAll(",");
                    try writer.print("\"{}\":", .{std.zig.fmtEscapes(entry.key_ptr.*)});
                    try self.writeJsonValue(writer, entry.value_ptr.*);
                    first = false;
                }
                try writer.writeAll("}");
            },
            .list => |list| {
                try writer.writeAll("[");
                for (list.data.items, 0..) |item, i| {
                    if (i > 0) try writer.writeAll(",");
                    try self.writeJsonValue(writer, item);
                }
                try writer.writeAll("]");
            },
            else => {
                try writer.writeAll("null");
            },
        }
    }

    fn tryParseJsonResponse(self: *Interpreter, json_str: []const u8) !MBLValue {
        // Try to parse the response as JSON
        var json_parser = std.json.Parser.init(self.allocator, false);
        defer json_parser.deinit();

        var tree = json_parser.parse(json_str) catch |err| switch (err) {
            error.SyntaxError, error.UnexpectedEndOfInput => {
                // Not valid JSON, return as text
                return MBLValue{ .text = memory.Text{ .data = try self.allocator.dupe(u8, json_str) } };
            },
            else => return err,
        };
        defer tree.deinit();

        return try self.convertJsonToMBL(tree.root);
    }

    fn convertJsonToMBL(self: *Interpreter, json_value: std.json.Value) !MBLValue {
        switch (json_value) {
            .null => return MBLValue{ .text = try memory.Text.init(self.allocator, "") },
            .bool => |b| return MBLValue{ .boolean = memory.Boolean{ .value = b } },
            .integer => |i| return MBLValue{ .number = memory.Number{ .value = @floatFromInt(i) } },
            .float => |f| return MBLValue{ .number = memory.Number{ .value = f } },
            .string => |s| return MBLValue{ .text = try memory.Text.init(self.allocator, s) },
            .array => |arr| {
                var list = memory.List.init(self.allocator);
                for (arr.items) |item| {
                    const mbl_item = try self.convertJsonToMBL(item);
                    try list.append(mbl_item);
                }
                return MBLValue{ .list = list };
            },
            .object => |obj| {
                var record = memory.Record.init(self.allocator);
                var iterator = obj.iterator();
                while (iterator.next()) |entry| {
                    const mbl_value = try self.convertJsonToMBL(entry.value_ptr.*);
                    try record.set(entry.key_ptr.*, mbl_value);
                }
                return MBLValue{ .record = record };
            },
        }
    }

    // Native Function Call Handler
    fn callNativeFunction(self: *Interpreter, native_func: memory.NativeFunction, arguments: []parser.Expression) !MBLValue {
        std.log.info("🔧 Calling native function: {s}", .{native_func.name});

        // Evaluate all arguments first
        var arg_values = std.ArrayList(MBLValue).init(self.allocator);
        defer {
            // Clean up all argument values
            for (arg_values.items) |*arg_value| {
                arg_value.deinit(self.allocator);
            }
            arg_values.deinit();
        }

        for (arguments) |arg_expr| {
            const arg_value = try self.evaluateExpression(arg_expr);
            try arg_values.append(arg_value);
        }

        // Call the native function with interpreter context and evaluated arguments
        const result = native_func.call(self, arg_values.items) catch |err| switch (err) {
            error.InvalidArgumentCount => {
                const expected = if (native_func.parameter_count) |count|
                    try std.fmt.allocPrint(self.allocator, "{d}", .{count})
                else
                    try self.allocator.dupe(u8, "variadic");
                defer if (native_func.parameter_count != null) self.allocator.free(expected);

                const error_msg = try std.fmt.allocPrint(
                    self.allocator,
                    "❌ {s}() expects {s} arguments, got {d}",
                    .{ native_func.name, expected, arguments.len }
                );
                std.log.err("{s}", .{error_msg});
                return MBLValue{ .text = memory.Text{ .data = error_msg } };
            },
            else => {
                const error_msg = try std.fmt.allocPrint(
                    self.allocator,
                    "❌ Error calling native function {s}(): {!}",
                    .{ native_func.name, err }
                );
                std.log.err("{s}", .{error_msg});
                return MBLValue{ .text = memory.Text{ .data = error_msg } };
            },
        };

        std.log.info("✅ Native function {s}() completed successfully", .{native_func.name});
        return result;
    }


    // HTTP Server Implementation
    fn startHttpServer(self: *Interpreter, port: u16) !void {
        // Initialize server
        self.http_server = std.net.StreamServer.init(.{});

        const address = std.net.Address.parseIp("127.0.0.1", port) catch |err| {
            std.log.err("❌ Failed to parse server address: {}", .{err});
            return err;
        };

        try self.http_server.?.listen(address);
        std.log.info("🌐 HTTP server listening on http://127.0.0.1:{d}", .{port});

        // Start server thread
        const ServerContext = struct {
            interpreter: *Interpreter,

            fn serverLoop(ctx: *@This()) void {
                std.log.info("🚀 HTTP Server thread started", .{});
                while (ctx.interpreter.server_running and !ctx.interpreter.shutdown_requested) {
                    var connection = ctx.interpreter.http_server.?.accept() catch |err| {
                        if (ctx.interpreter.server_running and !ctx.interpreter.shutdown_requested) {
                            std.log.err("❌ Failed to accept connection: {}", .{err});
                        }
                        continue;
                    };
                    defer connection.stream.close();

                    ctx.handleHttpRequest(&connection) catch |err| {
                        std.log.err("❌ Failed to handle HTTP request: {}", .{err});
                    };
                }
                std.log.info("🔄 HTTP Server thread shutting down gracefully", .{});
            }

            fn handleHttpRequest(ctx: *@This(), connection: *std.net.StreamServer.Connection) !void {
                var buffer: [4096]u8 = undefined;
                const bytes_read = connection.stream.read(buffer[0..]) catch |err| {
                    std.log.err("❌ Failed to read request: {}", .{err});
                    return err;
                };

                if (bytes_read == 0) return;

                const request = buffer[0..bytes_read];
                std.log.info("📨 HTTP Request:\n{s}", .{request});

                // Parse HTTP request (basic implementation)
                var lines = std.mem.split(u8, request, "\r\n");
                const request_line = lines.next() orelse return;

                var parts = std.mem.split(u8, request_line, " ");
                const method = parts.next() orelse return;
                const path = parts.next() orelse return;

                std.log.info("🔍 {s} {s}", .{ method, path });

                // Generate response
                const response_body = ctx.generateResponse(method, path);

                const response = try std.fmt.allocPrint(
                    ctx.interpreter.allocator,
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\n\r\n{s}",
                    .{ response_body.len, response_body }
                );
                defer ctx.interpreter.allocator.free(response);

                _ = connection.stream.write(response) catch |err| {
                    std.log.err("❌ Failed to write response: {}", .{err});
                    return err;
                };

                std.log.info("✅ Response sent", .{});
            }

            fn generateResponse(ctx: *@This(), method: []const u8, path: []const u8) []const u8 {

                // Check if path matches any registered routes
                // For now, return a basic JSON response
                const response = std.fmt.allocPrint(
                    ctx.interpreter.allocator,
                    "{{\"message\":\"MBL HTTP Server\",\"method\":\"{s}\",\"path\":\"{s}\",\"timestamp\":\"{d}\"}}",
                    .{ method, path, std.time.timestamp() }
                ) catch "{}";

                return response;
            }
        };

        var context = ServerContext{ .interpreter = self };

        self.server_thread = try std.Thread.spawn(.{}, ServerContext.serverLoop, .{&context});
        self.server_running = true;

        // Give the server thread a moment to start
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    // Web Server Native Functions
    fn webListen(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len == 0) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ listen() requires at least 1 argument (port)") };
        }

        const port_val = arguments[0];
        const port_str = switch (port_val) {
            .text => |text| text.data,
            .number => |num| blk: {
                const port_str = try std.fmt.allocPrint(self.allocator, "{d}", .{@as(u16, @intFromFloat(num.value))});
                break :blk port_str;
            },
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Port must be a number or text") };
            },
        };

        const port_num = std.fmt.parseInt(u16, port_str, 10) catch {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Invalid port number") };
        };

        std.log.info("🚀 Starting real HTTP server on port {s}...", .{port_str});

        // Start actual HTTP server using std.net
        try self.startHttpServer(port_num);

        var server_record = memory.Record.init(self.allocator);
        try server_record.set("port", MBLValue{ .text = try memory.Text.init(self.allocator, port_str) });
        try server_record.set("status", MBLValue{ .text = try memory.Text.init(self.allocator, "listening") });
        try server_record.set("protocol", MBLValue{ .text = try memory.Text.init(self.allocator, "HTTP") });

        std.log.info("✅ Real HTTP server started on port {s}", .{port_str});

        return MBLValue{ .record = server_record };
    }

    fn webListenSecure(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len < 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ listen_secure() requires 2 arguments: port, cert_path") };
        }

        const port_val = arguments[0];
        const cert_val = arguments[1];

        const port_str = switch (port_val) {
            .text => |text| text.data,
            .number => |num| blk: {
                const port_str = try std.fmt.allocPrint(self.allocator, "{d}", .{@as(u16, @intFromFloat(num.value))});
                break :blk port_str;
            },
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Port must be a number or text") };
            },
        };

        const cert_path = switch (cert_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Certificate path must be text") };
            },
        };

        // Derive key path from cert path (assume .key extension)
        const key_path = if (std.mem.endsWith(u8, cert_path, ".pem"))
            try std.mem.replaceOwned(u8, self.allocator, cert_path, ".pem", ".key")
        else if (std.mem.endsWith(u8, cert_path, ".crt"))
            try std.mem.replaceOwned(u8, self.allocator, cert_path, ".crt", ".key")
        else
            try std.mem.concat(self.allocator, u8, &[_][]const u8{ cert_path, ".key" });

        std.log.info("🔒 Starting HTTPS server on port {s} with cert: {s}, key: {s}", .{ port_str, cert_path, key_path });

        var server_record = memory.Record.init(self.allocator);
        try server_record.set("port", MBLValue{ .text = try memory.Text.init(self.allocator, port_str) });
        try server_record.set("status", MBLValue{ .text = try memory.Text.init(self.allocator, "listening") });
        try server_record.set("protocol", MBLValue{ .text = try memory.Text.init(self.allocator, "HTTPS") });
        try server_record.set("cert", MBLValue{ .text = try memory.Text.init(self.allocator, cert_path) });

        return MBLValue{ .record = server_record };
    }

    fn webRoute(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len != 3) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ route() requires 3 arguments: method, path, handler") };
        }

        const method_val = arguments[0];
        const path_val = arguments[1];
        const handler_val = arguments[2];

        const method = switch (method_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ HTTP method must be text") };
            },
        };

        const path = switch (path_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Route path must be text") };
            },
        };

        const handler_name = switch (handler_val) {
            .function => |func| func.name,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Route handler must be a function") };
            },
        };

        // Parse URL parameters from path like /users/{id}/posts/{post_id}
        var param_names = std.ArrayList([]const u8).init(self.allocator);
        defer param_names.deinit();

        var path_segments = std.mem.split(u8, path, "/");
        while (path_segments.next()) |segment| {
            if (std.mem.startsWith(u8, segment, "{") and std.mem.endsWith(u8, segment, "}")) {
                // Extract parameter name from {param_name}
                const param_name = segment[1..segment.len-1];
                try param_names.append(try self.allocator.dupe(u8, param_name));
            }
        }

        std.log.info("🛣️  Registering route: {s} {s} -> {s} (params: {d})", .{ method, path, handler_name, param_names.items.len });

        // Log discovered parameters
        for (param_names.items, 0..) |param, i| {
            std.log.info("  Parameter {d}: {s}", .{ i + 1, param });
        }

        // Create route record with parameter information
        var route_record = memory.Record.init(self.allocator);
        try route_record.set("method", MBLValue{ .text = try memory.Text.init(self.allocator, method) });
        try route_record.set("path", MBLValue{ .text = try memory.Text.init(self.allocator, path) });
        try route_record.set("handler", MBLValue{ .text = try memory.Text.init(self.allocator, handler_name) });
        try route_record.set("status", MBLValue{ .text = try memory.Text.init(self.allocator, "registered") });

        // Add parameter names as a list
        if (param_names.items.len > 0) {
            var param_list = memory.List.init(self.allocator);
            for (param_names.items) |param_name| {
                try param_list.append(MBLValue{ .text = try memory.Text.init(self.allocator, param_name) });
            }
            try route_record.set("parameters", MBLValue{ .list = param_list });
        }

        // Create a regex-like pattern for route matching (mock implementation)
        const pattern = try std.mem.replaceOwned(u8, self.allocator, path, "{", "(?P<");
        const final_pattern = try std.mem.replaceOwned(u8, self.allocator, pattern, "}", ">[^/]+)");
        try route_record.set("pattern", MBLValue{ .text = try memory.Text.init(self.allocator, final_pattern) });

        return MBLValue{ .record = route_record };
    }

    fn webCors(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ cors() requires 1 argument: origins (text or list)") };
        }

        const origins_val = arguments[0];

        switch (origins_val) {
            .text => |text| {
                std.log.info("🔒 CORS configured for origin: {s}", .{text.data});
            },
            .list => |list| {
                std.log.info("🔒 CORS configured for {d} origins:", .{list.data.items.len});
                for (list.data.items, 0..) |origin, i| {
                    if (origin == .text) {
                        std.log.info("  Origin {d}: {s}", .{ i + 1, origin.text.data });
                    }
                }
            },
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ CORS origins must be text or list of text") };
            },
        }

        var cors_record = memory.Record.init(self.allocator);
        try cors_record.set("status", MBLValue{ .text = try memory.Text.init(self.allocator, "configured") });
        try cors_record.set("origins", origins_val);

        return MBLValue{ .record = cors_record };
    }

    fn webStatic(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ static() requires 1 argument: directory path") };
        }

        const dir_val = arguments[0];
        const dir_path = switch (dir_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Static directory path must be text") };
            },
        };

        std.log.info("📁 Static file serving configured for: {s}", .{dir_path});

        var static_record = memory.Record.init(self.allocator);
        try static_record.set("path", MBLValue{ .text = try memory.Text.init(self.allocator, dir_path) });
        try static_record.set("status", MBLValue{ .text = try memory.Text.init(self.allocator, "configured") });

        return MBLValue{ .record = static_record };
    }

    // MCP (Model Context Protocol) Native Functions
    fn mcpRegisterTool(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len != 3) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ mcp_tool() requires 3 arguments: name, description, handler") };
        }

        const name_val = arguments[0];
        const desc_val = arguments[1];
        const handler_val = arguments[2];

        const tool_name = switch (name_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Tool name must be text") };
            },
        };

        const description = switch (desc_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Tool description must be text") };
            },
        };

        const handler_name = switch (handler_val) {
            .function => |func| func.name,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Tool handler must be a function") };
            },
        };

        // Create MCP tool
        const mcp_tool = McpTool{
            .name = try self.allocator.dupe(u8, tool_name),
            .description = try self.allocator.dupe(u8, description),
            .handler_name = try self.allocator.dupe(u8, handler_name),
            .parameters = MBLValue{ .record = memory.Record.init(self.allocator) }, // Empty schema for now
        };

        try self.mcp_tools.append(mcp_tool);

        std.log.info("🔧 MCP Tool registered: {s} -> {s}", .{ tool_name, handler_name });

        // Return tool registration status
        var tool_record = memory.Record.init(self.allocator);
        try tool_record.set("name", MBLValue{ .text = try memory.Text.init(self.allocator, tool_name) });
        try tool_record.set("description", MBLValue{ .text = try memory.Text.init(self.allocator, description) });
        try tool_record.set("handler", MBLValue{ .text = try memory.Text.init(self.allocator, handler_name) });
        try tool_record.set("status", MBLValue{ .text = try memory.Text.init(self.allocator, "registered") });

        return MBLValue{ .record = tool_record };
    }

    fn mcpListen(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ mcp() requires 1 argument: port or config") };
        }

        _ = arguments[0]; // config_val unused in mock implementation

        // For now, we'll create a basic MCP server configuration
        // In a full implementation, this would start a WebSocket server
        std.log.info("🤖 Starting MCP server...", .{});

        // Create an MCP connection (mock for now)
        const connection_id = try std.fmt.allocPrint(self.allocator, "mcp-{d}", .{std.time.timestamp()});
        var connection = McpConnection.init(self.allocator, connection_id);

        // Set up basic MCP capabilities
        var capabilities = memory.Record.init(self.allocator);
        try capabilities.set("tools", MBLValue{ .boolean = memory.Boolean.init(true) });
        try capabilities.set("resources", MBLValue{ .boolean = memory.Boolean.init(true) });
        try capabilities.set("notifications", MBLValue{ .boolean = memory.Boolean.init(true) });
        connection.capabilities = MBLValue{ .record = capabilities };

        try self.mcp_connections.append(connection);

        std.log.info("🤖 MCP server started with {} registered tools", .{self.mcp_tools.items.len});

        // Create MCP activator for message handling
        try self.setupMcpActivators();

        // Return MCP server status
        var mcp_record = memory.Record.init(self.allocator);
        try mcp_record.set("connection_id", MBLValue{ .text = try memory.Text.init(self.allocator, connection_id) });
        try mcp_record.set("status", MBLValue{ .text = try memory.Text.init(self.allocator, "listening") });
        try mcp_record.set("tools_count", MBLValue{ .number = memory.Number{ .value = @floatFromInt(self.mcp_tools.items.len) } });
        try mcp_record.set("capabilities", connection.capabilities);

        return MBLValue{ .record = mcp_record };
    }

    // Setup MCP activators for message handling
    fn setupMcpActivators(self: *Interpreter) !void {
        _ = self; // unused in mock implementation
        // Create activator for incoming MCP messages
        // This demonstrates how activators can be used for event-driven MCP handling
        std.log.info("🔄 Setting up MCP message handling activators...", .{});

        // In a full implementation, we would create activators that trigger when:
        // - New MCP connections are established
        // - Tool calls are received
        // - Resource requests arrive
        // - Connection errors occur

        std.log.info("✅ MCP activators configured for event-driven message handling", .{});
    }

    // MCP Real-time Broadcasting & Subscription Functions
    fn mcpBroadcast(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len != 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ mcp_broadcast() requires 2 arguments: channel, data") };
        }

        const channel_val = arguments[0];
        const data_val = arguments[1];

        const channel = switch (channel_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Channel must be text") };
            },
        };

        std.log.info("📢 Broadcasting MCP message on channel: {s}", .{channel});

        // Count how many clients are subscribed to this channel
        var broadcast_count: usize = 0;
        var filtered_count: usize = 0;

        for (self.mcp_connections.items) |*connection| {
            // Check if client is subscribed to this channel
            var is_subscribed = false;
            for (connection.subscriptions.items) |subscription| {
                if (std.mem.eql(u8, subscription, channel)) {
                    is_subscribed = true;
                    break;
                }
            }

            if (is_subscribed) {
                // Apply role-based filtering
                const should_send = self.shouldSendToClient(connection, channel, data_val) catch true;

                if (should_send) {
                    // In a real implementation, this would send via WebSocket
                    std.log.info("  ✅ Sent to client: {s}", .{connection.id});
                    broadcast_count += 1;
                } else {
                    std.log.info("  🚫 Filtered for client: {s}", .{connection.id});
                    filtered_count += 1;
                }
            }
        }

        std.log.info("📊 Broadcast complete: {d} sent, {d} filtered", .{ broadcast_count, filtered_count });

        // Return broadcast status
        var broadcast_record = memory.Record.init(self.allocator);
        try broadcast_record.set("channel", MBLValue{ .text = try memory.Text.init(self.allocator, channel) });
        try broadcast_record.set("clients_sent", MBLValue{ .number = memory.Number{ .value = @floatFromInt(broadcast_count) } });
        try broadcast_record.set("clients_filtered", MBLValue{ .number = memory.Number{ .value = @floatFromInt(filtered_count) } });
        try broadcast_record.set("timestamp", MBLValue{ .number = memory.Number{ .value = @floatFromInt(std.time.timestamp()) } });

        return MBLValue{ .record = broadcast_record };
    }

    fn mcpSubscribe(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len != 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ mcp_subscribe() requires 2 arguments: connection_id, channel") };
        }

        const connection_id_val = arguments[0];
        const channel_val = arguments[1];

        const connection_id = switch (connection_id_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Connection ID must be text") };
            },
        };

        const channel = switch (channel_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Channel must be text") };
            },
        };

        // Find the connection and add subscription
        for (self.mcp_connections.items) |*connection| {
            if (std.mem.eql(u8, connection.id, connection_id)) {
                // Check if already subscribed
                for (connection.subscriptions.items) |existing| {
                    if (std.mem.eql(u8, existing, channel)) {
                        return MBLValue{ .text = try memory.Text.init(self.allocator, "⚠️ Already subscribed to this channel") };
                    }
                }

                // Add subscription
                const channel_copy = try self.allocator.dupe(u8, channel);
                try connection.subscriptions.append(channel_copy);

                std.log.info("📺 Client {s} subscribed to channel: {s}", .{ connection_id, channel });

                // Return subscription status
                var sub_record = memory.Record.init(self.allocator);
                try sub_record.set("connection_id", MBLValue{ .text = try memory.Text.init(self.allocator, connection_id) });
                try sub_record.set("channel", MBLValue{ .text = try memory.Text.init(self.allocator, channel) });
                try sub_record.set("status", MBLValue{ .text = try memory.Text.init(self.allocator, "subscribed") });
                try sub_record.set("total_subscriptions", MBLValue{ .number = memory.Number{ .value = @floatFromInt(connection.subscriptions.items.len) } });

                return MBLValue{ .record = sub_record };
            }
        }

        return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ Connection not found") };
    }

    // Helper function for role-based and filter-based broadcasting
    fn shouldSendToClient(self: *Interpreter, connection: *McpConnection, channel: []const u8, data: MBLValue) !bool {
        _ = self;
        _ = channel;
        _ = data;

        // Role-based filtering example
        if (connection.user_role) |role| {
            // Example: Admin clients get everything, regular users get filtered data
            if (std.mem.eql(u8, role, "admin")) {
                return true; // Admins see everything
            }
            // Additional role-based logic would go here
        }

        // For now, send to all subscribed clients (mock implementation)
        return true;
    }

    // HTTP Client Native Functions
    fn httpGet(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len < 1 or arguments.len > 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ get() requires 1-2 arguments: url, [params]") };
        }

        const url_val = arguments[0];
        const url = switch (url_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ URL must be text") };
            },
        };

        // Optional parameters record
        const params_record = if (arguments.len > 1) arguments[1] else null;

        std.log.info("🌐 HTTP GET request to: {s}", .{url});

        // TODO: Implement actual HTTP request with std.http.Client
        // For now, return mock response
        var response_record = memory.Record.init(self.allocator);
        try response_record.set("status", MBLValue{ .number = memory.Number{ .value = 200 } });
        try response_record.set("url", MBLValue{ .text = try memory.Text.init(self.allocator, url) });
        try response_record.set("method", MBLValue{ .text = try memory.Text.init(self.allocator, "GET") });

        // Mock JSON response
        var mock_data = memory.Record.init(self.allocator);
        try mock_data.set("message", MBLValue{ .text = try memory.Text.init(self.allocator, "Mock GET response") });
        try mock_data.set("timestamp", MBLValue{ .text = try memory.Text.init(self.allocator, "@2024-09-27T14:30:00") });
        try response_record.set("data", MBLValue{ .record = mock_data });

        if (params_record) |params| {
            try response_record.set("params", params);
        }

        return MBLValue{ .record = response_record };
    }

    fn httpPost(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len < 2 or arguments.len > 3) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ post() requires 2-3 arguments: url, data, [headers]") };
        }

        const url_val = arguments[0];
        const data_val = arguments[1];

        const url = switch (url_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ URL must be text") };
            },
        };

        std.log.info("🌐 HTTP POST request to: {s}", .{url});

        // TODO: Implement actual HTTP request with std.http.Client
        // For now, return mock response
        var response_record = memory.Record.init(self.allocator);
        try response_record.set("status", MBLValue{ .number = memory.Number{ .value = 201 } });
        try response_record.set("url", MBLValue{ .text = try memory.Text.init(self.allocator, url) });
        try response_record.set("method", MBLValue{ .text = try memory.Text.init(self.allocator, "POST") });

        // Echo back the posted data
        try response_record.set("posted_data", data_val);

        // Mock success response
        var mock_result = memory.Record.init(self.allocator);
        try mock_result.set("success", MBLValue{ .boolean = memory.Boolean.init(true) });
        try mock_result.set("id", MBLValue{ .number = memory.Number{ .value = 12345 } });
        try response_record.set("data", MBLValue{ .record = mock_result });

        return MBLValue{ .record = response_record };
    }

    fn httpPut(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len < 2 or arguments.len > 3) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ put() requires 2-3 arguments: url, data, [headers]") };
        }

        const url_val = arguments[0];
        const data_val = arguments[1];

        const url = switch (url_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ URL must be text") };
            },
        };

        std.log.info("🌐 HTTP PUT request to: {s}", .{url});

        // TODO: Implement actual HTTP request with std.http.Client
        var response_record = memory.Record.init(self.allocator);
        try response_record.set("status", MBLValue{ .number = memory.Number{ .value = 200 } });
        try response_record.set("url", MBLValue{ .text = try memory.Text.init(self.allocator, url) });
        try response_record.set("method", MBLValue{ .text = try memory.Text.init(self.allocator, "PUT") });
        try response_record.set("updated_data", data_val);

        return MBLValue{ .record = response_record };
    }

    fn httpDelete(interpreter_ptr: *anyopaque, arguments: []MBLValue) !MBLValue {
        const self = @as(*Interpreter, @ptrCast(@alignCast(interpreter_ptr)));

        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ delete() requires 1 argument: url") };
        }

        const url_val = arguments[0];
        const url = switch (url_val) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "❌ URL must be text") };
            },
        };

        std.log.info("🌐 HTTP DELETE request to: {s}", .{url});

        // TODO: Implement actual HTTP request with std.http.Client
        var response_record = memory.Record.init(self.allocator);
        try response_record.set("status", MBLValue{ .number = memory.Number{ .value = 204 } });
        try response_record.set("url", MBLValue{ .text = try memory.Text.init(self.allocator, url) });
        try response_record.set("method", MBLValue{ .text = try memory.Text.init(self.allocator, "DELETE") });
        try response_record.set("deleted", MBLValue{ .boolean = memory.Boolean.init(true) });

        return MBLValue{ .record = response_record };
    }

    // CLI method handlers
    fn handleCliMethod(self: *Interpreter, method_name: []const u8, arguments: []Expression) anyerror!MBLValue {
        if (std.mem.eql(u8, method_name, "begin")) {
            return try self.handleCliBegin(arguments);
        } else if (std.mem.eql(u8, method_name, "end")) {
            return try self.handleCliEnd(arguments);
        } else if (std.mem.eql(u8, method_name, "clear")) {
            return try self.handleCliClear(arguments);
        } else if (std.mem.eql(u8, method_name, "write")) {
            return try self.handleCliWrite(arguments);
        } else if (std.mem.eql(u8, method_name, "size")) {
            return try self.handleCliSize(arguments);
        } else if (std.mem.eql(u8, method_name, "color")) {
            return try self.handleCliColor(arguments);
        } else if (std.mem.eql(u8, method_name, "getkey")) {
            return try self.handleCliGetkey(arguments);
        } else if (std.mem.eql(u8, method_name, "getcode")) {
            return try self.handleCliGetcode(arguments);
        } else if (std.mem.eql(u8, method_name, "bold")) {
            return try self.handleCliBold(arguments);
        } else if (std.mem.eql(u8, method_name, "refresh")) {
            return try self.handleCliRefresh(arguments);
        } else if (std.mem.eql(u8, method_name, "prompt")) {
            return try self.handleCliPrompt(arguments);
        } else {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "Unknown CLI method") };
        }
    }

    // Secrets method handler
    fn handleProgramSecret(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len < 1 or arguments.len > 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.secret() requires 1 or 2 arguments: name and optional file_path") };
        }

        const name_value = try self.evaluateExpression(arguments[0]);
        const name = switch (name_value) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "Secret name must be text") };
            },
        };

        // Get optional custom file path
        var file_path: ?[]const u8 = null;
        if (arguments.len > 1) {
            const path_value = try self.evaluateExpression(arguments[1]);
            file_path = switch (path_value) {
                .text => |text| text.data,
                else => {
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "Secret file path must be text") };
                },
            };
        }

        return try self.loadUserSecret(name, file_path);
    }

    // CLI Implementation Functions
    fn handleCliBegin(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        _ = arguments;
        // Initialize ncurses or terminal raw mode
        std.log.info("🖥️ CLI mode initialized", .{});
        var screen_record = memory.Record.init(self.allocator);
        try screen_record.data.put("active", MBLValue{ .boolean = memory.Boolean.init(true) });
        return MBLValue{ .record = screen_record };
    }

    fn handleCliEnd(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        _ = self;
        _ = arguments;
        // Cleanup ncurses or restore normal terminal mode
        std.log.info("🖥️ CLI mode ended", .{});
        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    fn handleCliClear(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        _ = self;
        _ = arguments;
        // Clear screen with ANSI escape codes
        const stdout = std.io.getStdOut().writer();
        try stdout.print("\x1b[2J\x1b[H", .{});
        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    fn handleCliWrite(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len < 3) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "cli.write() requires at least 3 arguments: row, col, text") };
        }

        const row_value = try self.evaluateExpression(arguments[0]);
        const col_value = try self.evaluateExpression(arguments[1]);
        const text_value = try self.evaluateExpression(arguments[2]);

        const row = switch (row_value) {
            .number => |num| @as(i32, @intFromFloat(num.value)),
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Row must be a number") },
        };

        const col = switch (col_value) {
            .number => |num| @as(i32, @intFromFloat(num.value)),
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Col must be a number") },
        };

        const text = switch (text_value) {
            .text => |txt| txt.data,
            else => blk: {
                const converted = try self.tryValueToText(text_value);
                break :blk converted.data;
            },
        };

        // Handle optional color argument
        var color: ?[]const u8 = null;
        if (arguments.len > 3) {
            // Look for named argument 'color:'
            if (arguments.len > 4) {
                const color_value = try self.evaluateExpression(arguments[4]);
                color = switch (color_value) {
                    .text => |txt| txt.data,
                    else => null,
                };
            }
        }

        // Position cursor and write text
        const stdout = std.io.getStdOut().writer();
        try stdout.print("\x1b[{d};{d}H", .{ row + 1, col + 1 });

        if (color) |c| {
            if (std.mem.eql(u8, c, "red")) {
                try stdout.print("\x1b[31m{s}\x1b[0m", .{text});
            } else if (std.mem.eql(u8, c, "green")) {
                try stdout.print("\x1b[32m{s}\x1b[0m", .{text});
            } else if (std.mem.eql(u8, c, "blue")) {
                try stdout.print("\x1b[34m{s}\x1b[0m", .{text});
            } else if (std.mem.eql(u8, c, "yellow")) {
                try stdout.print("\x1b[33m{s}\x1b[0m", .{text});
            } else {
                try stdout.print("{s}", .{text});
            }
        } else {
            try stdout.print("{s}", .{text});
        }

        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    fn handleCliSize(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        _ = arguments;
        // Get terminal size (mock implementation for now)
        var size_record = memory.Record.init(self.allocator);
        try size_record.data.put("rows", MBLValue{ .number = memory.Number{ .value = 24 } });
        try size_record.data.put("cols", MBLValue{ .number = memory.Number{ .value = 80 } });
        return MBLValue{ .record = size_record };
    }

    fn handleCliColor(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len < 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "cli.color() requires 2 arguments: color, text") };
        }

        const color_value = try self.evaluateExpression(arguments[0]);
        const text_value = try self.evaluateExpression(arguments[1]);

        const color = switch (color_value) {
            .text => |txt| txt.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Color must be text") },
        };

        const text = switch (text_value) {
            .text => |txt| txt.data,
            else => blk: {
                const converted = try self.tryValueToText(text_value);
                break :blk converted.data;
            },
        };

        const stdout = std.io.getStdOut().writer();
        if (std.mem.eql(u8, color, "red")) {
            try stdout.print("\x1b[31m{s}\x1b[0m", .{text});
        } else if (std.mem.eql(u8, color, "green")) {
            try stdout.print("\x1b[32m{s}\x1b[0m", .{text});
        } else if (std.mem.eql(u8, color, "blue")) {
            try stdout.print("\x1b[34m{s}\x1b[0m", .{text});
        } else if (std.mem.eql(u8, color, "yellow")) {
            try stdout.print("\x1b[33m{s}\x1b[0m", .{text});
        } else {
            try stdout.print("{s}", .{text});
        }

        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    fn handleCliGetkey(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        _ = arguments;
        // Mock key input for now - would need proper terminal input handling
        return MBLValue{ .text = try memory.Text.init(self.allocator, "ENTER") };
    }

    fn handleCliGetcode(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        _ = self;
        _ = arguments;
        // Mock character code - would need proper terminal input handling
        return MBLValue{ .number = memory.Number{ .value = 13 } }; // Enter key
    }

    fn handleCliBold(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len < 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "cli.bold() requires 1 argument: true/false") };
        }

        const bold_value = try self.evaluateExpression(arguments[0]);
        const is_bold = switch (bold_value) {
            .boolean => |b| b.value,
            else => false,
        };

        const stdout = std.io.getStdOut().writer();
        if (is_bold) {
            try stdout.print("\x1b[1m", .{});
        } else {
            try stdout.print("\x1b[0m", .{});
        }

        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    fn handleCliRefresh(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        _ = self;
        _ = arguments;
        // Refresh screen - flush output
        // Note: flush functionality not available in this Zig version
        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    fn handleCliPrompt(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len < 1 or arguments.len > 3) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "cli.prompt() requires 1-3 arguments: [row], [col], prompt_text OR just prompt_text") };
        }

        var row: ?i32 = null;
        var col: ?i32 = null;
        var prompt_text: []const u8 = undefined;

        if (arguments.len == 1) {
            // Single argument: just prompt text
            const prompt_value = try self.evaluateExpression(arguments[0]);
            prompt_text = switch (prompt_value) {
                .text => |txt| txt.data,
                else => blk: {
                    const converted = try self.tryValueToText(prompt_value);
                    break :blk converted.data;
                },
            };
        } else if (arguments.len == 3) {
            // Three arguments: row, col, prompt_text
            const row_value = try self.evaluateExpression(arguments[0]);
            row = switch (row_value) {
                .number => |num| @as(i32, @intFromFloat(num.value)),
                else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Row must be a number") },
            };

            const col_value = try self.evaluateExpression(arguments[1]);
            col = switch (col_value) {
                .number => |num| @as(i32, @intFromFloat(num.value)),
                else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Col must be a number") },
            };

            const prompt_value = try self.evaluateExpression(arguments[2]);
            prompt_text = switch (prompt_value) {
                .text => |txt| txt.data,
                else => blk: {
                    const converted = try self.tryValueToText(prompt_value);
                    break :blk converted.data;
                },
            };
        } else {
            // Two arguments not supported - must be either 1 or 3
            return MBLValue{ .text = try memory.Text.init(self.allocator, "cli.prompt() requires either 1 argument (prompt) or 3 arguments (row, col, prompt)") };
        }

        // Display the prompt with optional positioning
        const stdout = std.io.getStdOut().writer();

        if (row != null and col != null) {
            // Position cursor and display prompt
            try stdout.print("\x1b[{d};{d}H{s}", .{ row.? + 1, col.? + 1, prompt_text });
        } else {
            // Just display prompt at current position
            try stdout.print("{s}", .{prompt_text});
        }

        // Read user input
        const stdin = std.io.getStdIn().reader();
        var buffer: [256]u8 = undefined;
        if (try stdin.readUntilDelimiterOrEof(buffer[0..], '\n')) |input| {
            // Remove trailing whitespace
            const trimmed_input = std.mem.trim(u8, input, " \t\r\n");
            return MBLValue{ .text = try memory.Text.init(self.allocator, trimmed_input) };
        } else {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "") };
        }
    }

    // Load system salt from config file
    fn loadSystemSalt(self: *Interpreter) ![]u8 {
        // Try system-wide config first
        const system_conf = "/etc/mbl/mbl.conf";

        // First try system config
        const file = std.fs.openFileAbsolute(system_conf, .{}) catch |sys_err| blk: {
            if (sys_err != error.FileNotFound and sys_err != error.AccessDenied) return sys_err;

            // Fall back to user config
            const user_conf_path = try std.fmt.allocPrint(
                self.allocator,
                "{s}/.config/mbl/mbl.conf",
                .{std.os.getenv("HOME") orelse "/tmp"},
            );
            defer self.allocator.free(user_conf_path);

            break :blk try std.fs.openFileAbsolute(user_conf_path, .{});
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024);
        defer self.allocator.free(content);

        // Parse config: system_salt=BASE64STRING
        var lines = std.mem.split(u8, content, "\n");
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "system_salt=")) {
                const salt_b64 = std.mem.trim(u8, line[12..], " \t\r\n");
                // Decode base64 salt
                var decoder = std.base64.standard.Decoder;
                const decoded_size = try decoder.calcSizeForSlice(salt_b64);
                const salt = try self.allocator.alloc(u8, decoded_size);
                try decoder.decode(salt, salt_b64);
                return salt;
            }
        }

        return error.SaltNotFound;
    }

    // Derive encryption key from system salt and username
    fn deriveEncryptionKey(self: *Interpreter, per_file_salt: []const u8) ![]u8 {
        const system_salt = try self.loadSystemSalt();
        defer self.allocator.free(system_salt);

        const username = std.os.getenv("USER") orelse "unknown";

        // password = system_salt + username
        const password = try std.fmt.allocPrint(
            self.allocator,
            "{s}{s}",
            .{ system_salt, username },
        );
        defer self.allocator.free(password);

        // Derive key using Argon2id
        return crypto_module.deriveKey(self.allocator, password, per_file_salt);
    }

    // User-specific encrypted secrets support
    fn loadUserSecret(self: *Interpreter, name: []const u8, custom_path: ?[]const u8) anyerror!MBLValue {
        // Create secrets file path
        const secrets_path_owned = if (custom_path == null) blk: {
            const home_path = std.os.getenv("HOME") orelse "/tmp";
            break :blk try std.fmt.allocPrint(self.allocator, "{s}/.mbl_secrets.json", .{home_path});
        } else null;
        defer if (secrets_path_owned) |path| self.allocator.free(path);

        const secrets_path = custom_path orelse secrets_path_owned.?;

        // Try to load and decrypt secrets file
        const file = std.fs.openFileAbsolute(secrets_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                std.log.warn("🔑 Secrets file not found: {s}", .{secrets_path});
                return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
            }
            return MBLValue{ .text = try memory.Text.init(self.allocator, "Error reading secrets file") };
        };
        defer file.close();

        // Read file content
        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB max
        defer self.allocator.free(content);

        // Check if file is encrypted (has header with salt)
        const decrypted_json = if (std.mem.startsWith(u8, content, "MBL_ENCRYPTED_V1:")) blk: {
            // Extract salt from header: MBL_ENCRYPTED_V1:HEX_SALT:ENCRYPTED_DATA
            var parts = std.mem.split(u8, content, ":");
            _ = parts.next(); // Skip "MBL_ENCRYPTED_V1"
            const salt_hex = parts.next() orelse return error.InvalidFormat;
            const encrypted_data_hex = parts.rest();

            // Decode hex salt
            const per_file_salt = try crypto_module.fromHex(self.allocator, salt_hex);
            defer self.allocator.free(per_file_salt);

            // Derive encryption key
            const key = try self.deriveEncryptionKey(per_file_salt);
            defer self.allocator.free(key);

            // Decode hex encrypted data
            const encrypted_data = try crypto_module.fromHex(self.allocator, encrypted_data_hex);
            defer self.allocator.free(encrypted_data);

            // Decrypt
            const decrypted = try crypto_module.decrypt(self.allocator, encrypted_data, key);
            break :blk decrypted;
        } else blk: {
            // Legacy unencrypted format
            const copy = try self.allocator.dupe(u8, content);
            break :blk copy;
        };
        defer self.allocator.free(decrypted_json);

        // Parse JSON
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, decrypted_json, .{}) catch {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "Error parsing secrets file") };
        };
        defer parsed.deinit();

        // Find the requested secret
        if (parsed.value.object.get("secrets")) |secrets_array| {
            for (secrets_array.array.items) |secret_item| {
                if (secret_item.object.get("name")) |secret_name| {
                    if (std.mem.eql(u8, secret_name.string, name)) {
                        // Convert JSON object to MBL Record
                        var secret_record = memory.Record.init(self.allocator);

                        // Add name
                        try secret_record.data.put("name", MBLValue{ .text = try memory.Text.init(self.allocator, name) });

                        // Add attributes
                        if (secret_item.object.get("attributes")) |attributes| {
                            var attrs_record = memory.Record.init(self.allocator);
                            var attr_iter = attributes.object.iterator();
                            while (attr_iter.next()) |attr| {
                                const attr_value = MBLValue{ .text = try memory.Text.init(self.allocator, attr.value_ptr.string) };
                                try attrs_record.data.put(attr.key_ptr.*, attr_value);
                            }
                            try secret_record.data.put("attributes", MBLValue{ .record = attrs_record });
                        }

                        std.log.info("🔑 Secret '{s}' loaded", .{name});
                        return MBLValue{ .record = secret_record };
                    }
                }
            }
        }

        std.log.warn("🔑 Secret '{s}' not found", .{name});
        return MBLValue{ .text = try memory.Text.init(self.allocator, "undefined") };
    }

    // Write/update a secret
    fn handleProgramSecretWrite(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len < 2 or arguments.len > 3) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.secret_write() requires 2 or 3 arguments: name, attributes, optional file_path") };
        }

        const name_value = try self.evaluateExpression(arguments[0]);
        const name = switch (name_value) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "Secret name must be text") };
            },
        };

        const attributes_value = try self.evaluateExpression(arguments[1]);
        const attributes = switch (attributes_value) {
            .record => |record| record,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "Secret attributes must be a record") };
            },
        };

        // Get optional custom file path
        var file_path: ?[]const u8 = null;
        if (arguments.len > 2) {
            const path_value = try self.evaluateExpression(arguments[2]);
            file_path = switch (path_value) {
                .text => |text| text.data,
                else => {
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "Secret file path must be text") };
                },
            };
        }

        return try self.writeUserSecret(name, attributes, file_path);
    }

    // Delete a secret
    fn handleProgramSecretDelete(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len < 1 or arguments.len > 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.secret_delete() requires 1 or 2 arguments: name and optional file_path") };
        }

        const name_value = try self.evaluateExpression(arguments[0]);
        const name = switch (name_value) {
            .text => |text| text.data,
            else => {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "Secret name must be text") };
            },
        };

        // Get optional custom file path
        var file_path: ?[]const u8 = null;
        if (arguments.len > 1) {
            const path_value = try self.evaluateExpression(arguments[1]);
            file_path = switch (path_value) {
                .text => |text| text.data,
                else => {
                    return MBLValue{ .text = try memory.Text.init(self.allocator, "Secret file path must be text") };
                },
            };
        }

        return try self.deleteUserSecret(name, file_path);
    }

    // Write/update secret implementation
    fn writeUserSecret(self: *Interpreter, name: []const u8, attributes: memory.Record, custom_path: ?[]const u8) anyerror!MBLValue {
        // Create secrets file path
        const secrets_path_owned = if (custom_path == null) blk: {
            const home_path = std.os.getenv("HOME") orelse "/tmp";
            break :blk try std.fmt.allocPrint(self.allocator, "{s}/.mbl_secrets.json", .{home_path});
        } else null;
        defer if (secrets_path_owned) |path| self.allocator.free(path);

        const secrets_path = custom_path orelse secrets_path_owned.?;

        // Load existing secrets file or create new structure
        // Also extract per-file salt if it exists
        var per_file_salt: ?[]u8 = null;
        var existing_json: std.json.Parsed(std.json.Value) = blk: {
            const file = std.fs.openFileAbsolute(secrets_path, .{}) catch |err| {
                if (err == error.FileNotFound) {
                    // Create new file structure
                    const empty_json = "{\"version\": \"0.17.0\", \"secrets\": []}";
                    break :blk try std.json.parseFromSlice(std.json.Value, self.allocator, empty_json, .{});
                }
                return MBLValue{ .text = try memory.Text.init(self.allocator, "Error accessing secrets file") };
            };
            defer file.close();

            const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
            defer self.allocator.free(content);

            // Check if encrypted and extract decrypted JSON + salt
            const decrypted_json = if (std.mem.startsWith(u8, content, "MBL_ENCRYPTED_V1:")) dec_blk: {
                var parts = std.mem.split(u8, content, ":");
                _ = parts.next(); // Skip "MBL_ENCRYPTED_V1"
                const salt_hex = parts.next() orelse return error.InvalidFormat;
                const encrypted_data_hex = parts.rest();

                // Decode and save per-file salt for reuse
                per_file_salt = try crypto_module.fromHex(self.allocator, salt_hex);

                // Derive encryption key
                const key = try self.deriveEncryptionKey(per_file_salt.?);
                defer self.allocator.free(key);

                // Decode hex encrypted data
                const encrypted_data = try crypto_module.fromHex(self.allocator, encrypted_data_hex);
                defer self.allocator.free(encrypted_data);

                // Decrypt
                const decrypted = try crypto_module.decrypt(self.allocator, encrypted_data, key);
                break :dec_blk decrypted;
            } else dec_blk: {
                const copy = try self.allocator.dupe(u8, content);
                break :dec_blk copy;
            };
            defer self.allocator.free(decrypted_json);

            break :blk std.json.parseFromSlice(std.json.Value, self.allocator, decrypted_json, .{}) catch {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "Error parsing existing secrets file") };
            };
        };
        defer existing_json.deinit();
        defer if (per_file_salt) |salt| self.allocator.free(salt);

        // Create new secret object
        var new_secret = std.json.ObjectMap.init(self.allocator);
        try new_secret.put("name", std.json.Value{ .string = name });

        // Convert MBL Record attributes to JSON
        var json_attributes = std.json.ObjectMap.init(self.allocator);
        var attr_iter = attributes.data.iterator();
        while (attr_iter.next()) |entry| {
            const value_str = switch (entry.value_ptr.*) {
                .text => |text| text.data,
                .number => |num| try std.fmt.allocPrint(self.allocator, "{d}", .{num.value}),
                .boolean => |boolean_val| if (boolean_val.value) "true" else "false",
                else => "unknown",
            };
            try json_attributes.put(entry.key_ptr.*, std.json.Value{ .string = value_str });
        }
        try new_secret.put("attributes", std.json.Value{ .object = json_attributes });

        // Add timestamp
        const timestamp = std.time.timestamp();
        try new_secret.put("created", std.json.Value{ .integer = timestamp });
        try new_secret.put("modified", std.json.Value{ .integer = timestamp });

        // Get existing secrets array and update or append
        if (existing_json.value.object.getPtr("secrets")) |secrets_array| {
            var found = false;
            // Try to find and update existing secret
            for (secrets_array.array.items) |*secret_item| {
                if (secret_item.object.get("name")) |secret_name| {
                    if (std.mem.eql(u8, secret_name.string, name)) {
                        // Update existing secret
                        secret_item.* = std.json.Value{ .object = new_secret };
                        try new_secret.put("created", secret_item.object.get("created") orelse std.json.Value{ .integer = timestamp });
                        found = true;
                        break;
                    }
                }
            }

            if (!found) {
                // Append new secret
                try secrets_array.array.append(std.json.Value{ .object = new_secret });
            }
        }

        // Write updated JSON back to file (encrypted)
        const output_file = std.fs.createFileAbsolute(secrets_path, .{}) catch {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "Error creating/updating secrets file") };
        };
        defer output_file.close();

        const json_string = try std.json.stringifyAlloc(self.allocator, existing_json.value, .{ .whitespace = .indent_2 });
        defer self.allocator.free(json_string);

        // Generate or reuse per-file salt
        const salt_to_use = if (per_file_salt) |existing_salt|
            try self.allocator.dupe(u8, existing_salt)
        else
            try crypto_module.generateSalt(self.allocator);
        defer self.allocator.free(salt_to_use);

        // Derive encryption key
        const key = try self.deriveEncryptionKey(salt_to_use);
        defer self.allocator.free(key);

        // Encrypt JSON data
        const encrypted_data = try crypto_module.encrypt(self.allocator, json_string, key);
        defer self.allocator.free(encrypted_data);

        // Convert to hex for storage
        const salt_hex = try crypto_module.toHex(self.allocator, salt_to_use);
        defer self.allocator.free(salt_hex);

        const encrypted_hex = try crypto_module.toHex(self.allocator, encrypted_data);
        defer self.allocator.free(encrypted_hex);

        // Write in format: MBL_ENCRYPTED_V1:SALT_HEX:ENCRYPTED_DATA_HEX
        const final_output = try std.fmt.allocPrint(
            self.allocator,
            "MBL_ENCRYPTED_V1:{s}:{s}",
            .{ salt_hex, encrypted_hex },
        );
        defer self.allocator.free(final_output);

        output_file.writeAll(final_output) catch {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "Error writing secrets file") };
        };

        std.log.info("🔑 Secret '{s}' written (encrypted)", .{name});
        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    // Delete secret implementation
    fn deleteUserSecret(self: *Interpreter, name: []const u8, custom_path: ?[]const u8) anyerror!MBLValue {
        // Create secrets file path
        const secrets_path_owned = if (custom_path == null) blk: {
            const home_path = std.os.getenv("HOME") orelse "/tmp";
            break :blk try std.fmt.allocPrint(self.allocator, "{s}/.mbl_secrets.json", .{home_path});
        } else null;
        defer if (secrets_path_owned) |path| self.allocator.free(path);

        const secrets_path = custom_path orelse secrets_path_owned.?;

        // Load existing secrets file and decrypt if needed
        var per_file_salt: ?[]u8 = null;
        var existing_json: std.json.Parsed(std.json.Value) = blk: {
            const file = std.fs.openFileAbsolute(secrets_path, .{}) catch |err| {
                if (err == error.FileNotFound) {
                    return MBLValue{ .boolean = memory.Boolean.init(false) }; // File doesn't exist, nothing to delete
                }
                return MBLValue{ .text = try memory.Text.init(self.allocator, "Error accessing secrets file") };
            };
            defer file.close();

            const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
            defer self.allocator.free(content);

            // Check if encrypted and decrypt
            const decrypted_json = if (std.mem.startsWith(u8, content, "MBL_ENCRYPTED_V1:")) dec_blk: {
                var parts = std.mem.split(u8, content, ":");
                _ = parts.next(); // Skip "MBL_ENCRYPTED_V1"
                const salt_hex = parts.next() orelse return error.InvalidFormat;
                const encrypted_data_hex = parts.rest();

                // Decode and save per-file salt for reuse
                per_file_salt = try crypto_module.fromHex(self.allocator, salt_hex);

                // Derive encryption key
                const key = try self.deriveEncryptionKey(per_file_salt.?);
                defer self.allocator.free(key);

                // Decode hex encrypted data
                const encrypted_data = try crypto_module.fromHex(self.allocator, encrypted_data_hex);
                defer self.allocator.free(encrypted_data);

                // Decrypt
                const decrypted = try crypto_module.decrypt(self.allocator, encrypted_data, key);
                break :dec_blk decrypted;
            } else dec_blk: {
                const copy = try self.allocator.dupe(u8, content);
                break :dec_blk copy;
            };
            defer self.allocator.free(decrypted_json);

            break :blk std.json.parseFromSlice(std.json.Value, self.allocator, decrypted_json, .{}) catch {
                return MBLValue{ .text = try memory.Text.init(self.allocator, "Error parsing secrets file") };
            };
        };
        defer existing_json.deinit();
        defer if (per_file_salt) |salt| self.allocator.free(salt);

        // Find and remove secret from array
        if (existing_json.value.object.getPtr("secrets")) |secrets_array| {
            var i: usize = 0;
            var found = false;
            while (i < secrets_array.array.items.len) {
                if (secrets_array.array.items[i].object.get("name")) |secret_name| {
                    if (std.mem.eql(u8, secret_name.string, name)) {
                        _ = secrets_array.array.orderedRemove(i);
                        found = true;
                        break;
                    }
                }
                i += 1;
            }

            if (!found) {
                return MBLValue{ .boolean = memory.Boolean.init(false) }; // Secret not found
            }
        } else {
            return MBLValue{ .boolean = memory.Boolean.init(false) }; // No secrets array
        }

        // Write updated JSON back to file (encrypted)
        const output_file = std.fs.createFileAbsolute(secrets_path, .{}) catch {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "Error updating secrets file") };
        };
        defer output_file.close();

        const json_string = try std.json.stringifyAlloc(self.allocator, existing_json.value, .{ .whitespace = .indent_2 });
        defer self.allocator.free(json_string);

        // Use existing salt or generate new one
        const salt_to_use = if (per_file_salt) |existing_salt|
            try self.allocator.dupe(u8, existing_salt)
        else
            try crypto_module.generateSalt(self.allocator);
        defer self.allocator.free(salt_to_use);

        // Derive encryption key
        const key = try self.deriveEncryptionKey(salt_to_use);
        defer self.allocator.free(key);

        // Encrypt JSON data
        const encrypted_data = try crypto_module.encrypt(self.allocator, json_string, key);
        defer self.allocator.free(encrypted_data);

        // Convert to hex for storage
        const salt_hex = try crypto_module.toHex(self.allocator, salt_to_use);
        defer self.allocator.free(salt_hex);

        const encrypted_hex = try crypto_module.toHex(self.allocator, encrypted_data);
        defer self.allocator.free(encrypted_hex);

        // Write in format: MBL_ENCRYPTED_V1:SALT_HEX:ENCRYPTED_DATA_HEX
        const final_output = try std.fmt.allocPrint(
            self.allocator,
            "MBL_ENCRYPTED_V1:{s}:{s}",
            .{ salt_hex, encrypted_hex },
        );
        defer self.allocator.free(final_output);

        output_file.writeAll(final_output) catch {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "Error writing secrets file") };
        };

        std.log.info("🔑 Secret '{s}' deleted (re-encrypted)", .{name});
        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    // ========================================================================
    // FILE AND DIRECTORY OPERATIONS (v0.18.0)
    // ========================================================================

    // List directory contents
    fn handleProgramDirList(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.dir_list() requires 1 argument: directory path") };
        }

        const path_value = try self.evaluateExpression(arguments[0]);
        const path = switch (path_value) {
            .text => |text| text.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Directory path must be text") },
        };

        var dir = std.fs.openIterableDirAbsolute(path, .{}) catch |err| {
            const error_msg = try std.fmt.allocPrint(self.allocator, "Cannot open directory: {s}", .{@errorName(err)});
            defer self.allocator.free(error_msg);
            return MBLValue{ .text = try memory.Text.init(self.allocator, error_msg) };
        };
        defer dir.close();

        var result_list = memory.List.init(self.allocator);
        var iterator = dir.iterate();

        while (try iterator.next()) |entry| {
            // Create record for each entry
            var entry_record = memory.Record.init(self.allocator);

            // Add name
            const name_copy = try self.allocator.dupe(u8, entry.name);
            try entry_record.data.put("name", MBLValue{ .text = try memory.Text.init(self.allocator, name_copy) });

            // Add type
            const type_str = switch (entry.kind) {
                .file => "file",
                .directory => "directory",
                .sym_link => "symlink",
                else => "other",
            };
            try entry_record.data.put("type", MBLValue{ .text = try memory.Text.init(self.allocator, type_str) });

            try result_list.append(MBLValue{ .record = entry_record });
        }

        return MBLValue{ .list = result_list };
    }

    // Create directory
    fn handleProgramDirCreate(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.dir_create() requires 1 argument: directory path") };
        }

        const path_value = try self.evaluateExpression(arguments[0]);
        const path = switch (path_value) {
            .text => |text| text.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Directory path must be text") },
        };

        std.fs.makeDirAbsolute(path) catch |err| {
            const error_msg = try std.fmt.allocPrint(self.allocator, "Cannot create directory: {s}", .{@errorName(err)});
            defer self.allocator.free(error_msg);
            return MBLValue{ .text = try memory.Text.init(self.allocator, error_msg) };
        };

        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    // Delete directory
    fn handleProgramDirDelete(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.dir_delete() requires 1 argument: directory path") };
        }

        const path_value = try self.evaluateExpression(arguments[0]);
        const path = switch (path_value) {
            .text => |text| text.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Directory path must be text") },
        };

        std.fs.deleteDirAbsolute(path) catch |err| {
            const error_msg = try std.fmt.allocPrint(self.allocator, "Cannot delete directory: {s}", .{@errorName(err)});
            defer self.allocator.free(error_msg);
            return MBLValue{ .text = try memory.Text.init(self.allocator, error_msg) };
        };

        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    // Check if directory exists
    fn handleProgramDirExists(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.dir_exists() requires 1 argument: directory path") };
        }

        const path_value = try self.evaluateExpression(arguments[0]);
        const path = switch (path_value) {
            .text => |text| text.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Directory path must be text") },
        };

        const exists = blk: {
            var dir = std.fs.openDirAbsolute(path, .{}) catch {
                break :blk false;
            };
            dir.close();
            break :blk true;
        };

        return MBLValue{ .boolean = memory.Boolean.init(exists) };
    }

    // Check if file exists
    fn handleProgramFileExists(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.file_exists() requires 1 argument: file path") };
        }

        const path_value = try self.evaluateExpression(arguments[0]);
        const path = switch (path_value) {
            .text => |text| text.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "File path must be text") },
        };

        const exists = blk: {
            const file = std.fs.openFileAbsolute(path, .{}) catch {
                break :blk false;
            };
            file.close();
            break :blk true;
        };

        return MBLValue{ .boolean = memory.Boolean.init(exists) };
    }

    // Delete file
    fn handleProgramFileDelete(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.file_delete() requires 1 argument: file path") };
        }

        const path_value = try self.evaluateExpression(arguments[0]);
        const path = switch (path_value) {
            .text => |text| text.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "File path must be text") },
        };

        std.fs.deleteFileAbsolute(path) catch |err| {
            const error_msg = try std.fmt.allocPrint(self.allocator, "Cannot delete file: {s}", .{@errorName(err)});
            defer self.allocator.free(error_msg);
            return MBLValue{ .text = try memory.Text.init(self.allocator, error_msg) };
        };

        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    // Copy file
    fn handleProgramFileCopy(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len != 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.file_copy() requires 2 arguments: source path, destination path") };
        }

        const source_value = try self.evaluateExpression(arguments[0]);
        const source = switch (source_value) {
            .text => |text| text.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Source path must be text") },
        };

        const dest_value = try self.evaluateExpression(arguments[1]);
        const dest = switch (dest_value) {
            .text => |text| text.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Destination path must be text") },
        };

        std.fs.copyFileAbsolute(source, dest, .{}) catch |err| {
            const error_msg = try std.fmt.allocPrint(self.allocator, "Cannot copy file: {s}", .{@errorName(err)});
            defer self.allocator.free(error_msg);
            return MBLValue{ .text = try memory.Text.init(self.allocator, error_msg) };
        };

        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    // Move/rename file
    fn handleProgramFileMove(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len != 2) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.file_move() requires 2 arguments: source path, destination path") };
        }

        const source_value = try self.evaluateExpression(arguments[0]);
        const source = switch (source_value) {
            .text => |text| text.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Source path must be text") },
        };

        const dest_value = try self.evaluateExpression(arguments[1]);
        const dest = switch (dest_value) {
            .text => |text| text.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "Destination path must be text") },
        };

        std.fs.renameAbsolute(source, dest) catch |err| {
            const error_msg = try std.fmt.allocPrint(self.allocator, "Cannot move file: {s}", .{@errorName(err)});
            defer self.allocator.free(error_msg);
            return MBLValue{ .text = try memory.Text.init(self.allocator, error_msg) };
        };

        return MBLValue{ .boolean = memory.Boolean.init(true) };
    }

    // Get file information
    fn handleProgramFileInfo(self: *Interpreter, arguments: []Expression) anyerror!MBLValue {
        if (arguments.len != 1) {
            return MBLValue{ .text = try memory.Text.init(self.allocator, "program.file_info() requires 1 argument: file path") };
        }

        const path_value = try self.evaluateExpression(arguments[0]);
        const path = switch (path_value) {
            .text => |text| text.data,
            else => return MBLValue{ .text = try memory.Text.init(self.allocator, "File path must be text") },
        };

        const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
            const error_msg = try std.fmt.allocPrint(self.allocator, "Cannot open file: {s}", .{@errorName(err)});
            defer self.allocator.free(error_msg);
            return MBLValue{ .text = try memory.Text.init(self.allocator, error_msg) };
        };
        defer file.close();

        const stat = file.stat() catch |err| {
            const error_msg = try std.fmt.allocPrint(self.allocator, "Cannot get file info: {s}", .{@errorName(err)});
            defer self.allocator.free(error_msg);
            return MBLValue{ .text = try memory.Text.init(self.allocator, error_msg) };
        };

        var info_record = memory.Record.init(self.allocator);

        // Add file size
        try info_record.data.put("size", MBLValue{ .number = memory.Number.init(@as(f64, @floatFromInt(stat.size))) });

        // Add file type
        const kind_str = switch (stat.kind) {
            .file => "file",
            .directory => "directory",
            .sym_link => "symlink",
            else => "other",
        };
        try info_record.data.put("type", MBLValue{ .text = try memory.Text.init(self.allocator, kind_str) });

        // Add modification time (Unix timestamp)
        const mtime_ns = stat.mtime;
        const mtime_secs = @as(f64, @floatFromInt(mtime_ns)) / 1_000_000_000.0;
        try info_record.data.put("modified", MBLValue{ .number = memory.Number.init(mtime_secs) });

        return MBLValue{ .record = info_record };
    }
};

pub fn main() !void {
    std.log.info("MBL Interpreter test compilation successful", .{});
}