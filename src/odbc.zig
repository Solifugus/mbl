// odbc.zig - MBL Database Integration (v0.13.0)
// Business-friendly database operations with PostgreSQL support
const std = @import("std");
const memory = @import("memory.zig");
const interpreter = @import("interpreter.zig");

const MBLValue = memory.MBLValue;
const Record = memory.Record;
const List = memory.List;
const Text = memory.Text;
const NativeFunction = memory.NativeFunction;
const Interpreter = interpreter.Interpreter;

// Database types supported by MBL
const DatabaseType = enum {
    postgresql,
    // Future database support:
    // mysql,
    // sqlite,
    // sqlserver,
    // oracle,

    pub fn fromString(db_type: []const u8) ?DatabaseType {
        if (std.mem.eql(u8, db_type, "postgresql") or std.mem.eql(u8, db_type, "postgres")) {
            return .postgresql;
        }
        // Future implementations:
        // if (std.mem.eql(u8, db_type, "mysql")) return .mysql;
        // if (std.mem.eql(u8, db_type, "sqlite")) return .sqlite;
        return null;
    }
};

// Database connection configuration
const DatabaseConfig = struct {
    db_type: DatabaseType,
    host: []const u8,
    port: u16,
    database: []const u8,
    username: []const u8,
    password: []const u8,

    // Optional parameters
    charset: ?[]const u8 = null,
    timeout: ?u32 = null,
    pool_size: ?u32 = null,
    ssl_mode: ?[]const u8 = null,
    service_name: ?[]const u8 = null, // For Oracle
    encrypt: ?bool = null, // For SQL Server
    trust_server_certificate: ?bool = null, // For SQL Server
    app_name: ?[]const u8 = null, // For SQL Server
    connection_timeout: ?u32 = null,
    pool_min: ?u32 = null,
    pool_max: ?u32 = null,
};

// Database connection pool entry
const DatabaseConnection = struct {
    config: DatabaseConfig,
    handle: ?*anyopaque = null, // Database-specific connection handle
    is_connected: bool = false,
    last_used: i64 = 0,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, config: DatabaseConfig) DatabaseConnection {
        return DatabaseConnection{
            .config = config,
            .allocator = allocator,
            .last_used = std.time.timestamp(),
        };
    }

    fn connect(self: *DatabaseConnection) !void {
        switch (self.config.db_type) {
            .postgresql => try self.connectPostgreSQL(),
            // Future database implementations
        }
        self.is_connected = true;
        self.last_used = std.time.timestamp();
    }

    fn disconnect(self: *DatabaseConnection) void {
        if (self.handle) |handle| {
            switch (self.config.db_type) {
                .postgresql => self.disconnectPostgreSQL(handle),
                // Future database implementations
            }
            self.handle = null;
        }
        self.is_connected = false;
    }

    // PostgreSQL-specific connection logic
    fn connectPostgreSQL(self: *DatabaseConnection) !void {
        // TODO: Implement actual PostgreSQL connection using libpq
        // This is a placeholder for the PostgreSQL connection logic
        // We'll need to link with libpq and implement the actual connection
        std.log.info("Connecting to PostgreSQL: {s}@{s}:{d}/{s}", .{
            self.config.username,
            self.config.host,
            self.config.port,
            self.config.database,
        });

        // For now, create a mock connection handle
        // In real implementation, this would be a PGconn* from libpq
        self.handle = @ptrFromInt(0x12345678); // Mock handle
    }

    fn disconnectPostgreSQL(self: *DatabaseConnection, handle: *anyopaque) void {
        _ = self;
        _ = handle;
        // TODO: Implement actual PostgreSQL disconnection
        std.log.info("Disconnecting from PostgreSQL", .{});
    }
};

// Database server registry
const DatabaseRegistry = struct {
    servers: std.HashMap([]const u8, DatabaseConnection, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) DatabaseRegistry {
        return DatabaseRegistry{
            .servers = std.HashMap([]const u8, DatabaseConnection, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .allocator = allocator,
        };
    }

    fn deinit(self: *DatabaseRegistry) void {
        // Disconnect all active connections
        var iterator = self.servers.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.disconnect();
        }
        self.servers.deinit();
    }

    fn registerServer(self: *DatabaseRegistry, name: []const u8, config: DatabaseConfig) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        const connection = DatabaseConnection.init(self.allocator, config);
        try self.servers.put(owned_name, connection);
    }

    fn getConnection(self: *DatabaseRegistry, server_name: []const u8) !*DatabaseConnection {
        if (self.servers.getPtr(server_name)) |connection| {
            if (!connection.is_connected) {
                try connection.connect();
            }
            connection.last_used = std.time.timestamp();
            return connection;
        }
        return error.ServerNotFound;
    }
};

// Global database registry
var db_registry: ?DatabaseRegistry = null;

// Initialize the database registry
fn ensureRegistry(allocator: std.mem.Allocator) !*DatabaseRegistry {
    if (db_registry == null) {
        db_registry = DatabaseRegistry.init(allocator);
    }
    return &db_registry.?;
}

// Parse database configuration from MBL Record
fn parseServerConfig(config_record: *Record) !DatabaseConfig {
    // Extract required fields
    const db_type_value = config_record.get("type") orelse return error.MissingDatabaseType;
    const db_type_text = switch (db_type_value) {
        .text => |text| text.data,
        else => return error.InvalidDatabaseType,
    };

    const db_type = DatabaseType.fromString(db_type_text) orelse return error.UnsupportedDatabaseType;

    const host_value = config_record.get("host") orelse return error.MissingHost;
    const host = switch (host_value) {
        .text => |text| text.data,
        else => return error.InvalidHost,
    };

    const port_value = config_record.get("port") orelse return error.MissingPort;
    const port: u16 = switch (port_value) {
        .number => |num| @intFromFloat(num.value),
        else => return error.InvalidPort,
    };

    const database_value = config_record.get("database") orelse return error.MissingDatabase;
    const database = switch (database_value) {
        .text => |text| text.data,
        else => return error.InvalidDatabase,
    };

    const username_value = config_record.get("username") orelse return error.MissingUsername;
    const username = switch (username_value) {
        .text => |text| text.data,
        else => return error.InvalidUsername,
    };

    const password_value = config_record.get("password") orelse return error.MissingPassword;
    const password = switch (password_value) {
        .text => |text| text.data,
        else => return error.InvalidPassword,
    };

    // Create base configuration
    var config = DatabaseConfig{
        .db_type = db_type,
        .host = host,
        .port = port,
        .database = database,
        .username = username,
        .password = password,
    };

    // Parse optional fields
    if (config_record.get("charset")) |charset_value| {
        if (charset_value == .text) {
            config.charset = charset_value.text.data;
        }
    }

    if (config_record.get("timeout")) |timeout_value| {
        if (timeout_value == .number) {
            config.timeout = @intFromFloat(timeout_value.number.value);
        }
    }

    if (config_record.get("pool_size")) |pool_size_value| {
        if (pool_size_value == .number) {
            config.pool_size = @intFromFloat(pool_size_value.number.value);
        }
    }

    // Add other optional fields as needed

    return config;
}

// Native function: program.odbc.run(server_name, sql_query, [parameters])
fn odbcRun(interpreter_ptr: *anyopaque, args: []MBLValue) !MBLValue {
    _ = interpreter_ptr; // Not used in this function
    const allocator = std.heap.page_allocator; // Use global allocator
    if (args.len < 2) {
        return error.InsufficientArguments;
    }

    // Extract server name
    const server_name = switch (args[0]) {
        .text => |text| text.data,
        else => return error.InvalidServerName,
    };

    // Extract SQL query
    const sql_query = switch (args[1]) {
        .text => |text| text.data,
        else => return error.InvalidSQLQuery,
    };

    // Extract optional parameters
    var parameters: ?MBLValue = null;
    if (args.len > 2) {
        parameters = args[2];
    }

    // Get database connection
    const registry = try ensureRegistry(allocator);
    const connection = registry.getConnection(server_name) catch |err| {
        std.log.err("Failed to get database connection for server '{s}': {}", .{ server_name, err });
        return MBLValue{ .record = Record.init(allocator) }; // Return empty record on error
    };

    // Execute the query
    return executeQuery(allocator, connection, sql_query, parameters);
}

// Execute SQL query with parameter substitution
fn executeQuery(allocator: std.mem.Allocator, connection: *DatabaseConnection, sql_query: []const u8, parameters: ?MBLValue) !MBLValue {
    // Process parameter substitution
    const processed_query = try processParameterSubstitution(allocator, sql_query, parameters);
    defer allocator.free(processed_query);

    std.log.info("Executing SQL: {s}", .{processed_query});

    // Execute based on database type
    switch (connection.config.db_type) {
        .postgresql => return executePostgreSQLQuery(allocator, connection, processed_query),
        // Future database implementations
    }
}

// Process parameter substitution in SQL query
fn processParameterSubstitution(allocator: std.mem.Allocator, sql_query: []const u8, parameters: ?MBLValue) ![]u8 {
    if (parameters == null) {
        return allocator.dupe(u8, sql_query);
    }

    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    var i: usize = 0;
    while (i < sql_query.len) {
        if (sql_query[i] == '{') {
            // Find the closing brace
            const start = i + 1;
            var end = start;
            while (end < sql_query.len and sql_query[end] != '}') {
                end += 1;
            }

            if (end < sql_query.len) {
                const param_name = sql_query[start..end];
                const param_value = getParameterValue(param_name, parameters.?);
                try result.appendSlice(param_value);
                i = end + 1;
            } else {
                try result.append(sql_query[i]);
                i += 1;
            }
        } else {
            try result.append(sql_query[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice();
}

// Get parameter value for substitution
fn getParameterValue(param_name: []const u8, parameters: MBLValue) []const u8 {
    switch (parameters) {
        .record => |record| {
            var mutable_record = record;
            if (mutable_record.get(param_name)) |value| {
                return formatValueForSQL(value);
            }
        },
        .list => |list| {
            // For list parameters, use numeric indices
            if (std.fmt.parseInt(usize, param_name, 10)) |index| {
                if (index < list.data.items.len) {
                    return formatValueForSQL(list.data.items[index]);
                }
            } else |_| {
                // Ignore parsing error, return empty string
            }
        },
        else => {},
    }

    return ""; // Return empty string if parameter not found
}

// Format MBL value for SQL insertion
fn formatValueForSQL(value: MBLValue) []const u8 {
    switch (value) {
        .text => |text| {
            // TODO: Implement proper SQL escaping
            return text.data;
        },
        .number => |num| {
            // TODO: Convert number to string
            _ = num;
            return "0"; // Placeholder
        },
        .boolean => |bool_val| {
            return if (bool_val.value) "true" else "false";
        },
        .money => |money| {
            // TODO: Convert money to string
            _ = money;
            return "0.00"; // Placeholder
        },
        else => return "NULL",
    }
}

// Execute PostgreSQL query (placeholder implementation)
fn executePostgreSQLQuery(allocator: std.mem.Allocator, connection: *DatabaseConnection, sql_query: []const u8) !MBLValue {
    _ = connection;

    std.log.info("PostgreSQL Query: {s}", .{sql_query});

    // TODO: Implement actual PostgreSQL query execution using libpq
    // This is a mock implementation that returns sample data

    // For now, return a mock result
    var result_list = List.init(allocator);

    // Create a sample record
    var sample_record = Record.init(allocator);
    try sample_record.set("id", MBLValue{ .number = memory.Number{ .value = 1.0 } });
    try sample_record.set("name", MBLValue{ .text = try Text.init(allocator, "Sample User") });
    try sample_record.set("active", MBLValue{ .boolean = memory.Boolean{ .value = true } });

    try result_list.append(MBLValue{ .record = sample_record });

    return MBLValue{ .list = result_list };
}

// Native function: program.odbc.server(server_name, config_record)
fn odbcServer(interpreter_ptr: *anyopaque, args: []MBLValue) !MBLValue {
    _ = interpreter_ptr; // Not used in this function
    const allocator = std.heap.page_allocator; // Use global allocator
    if (args.len < 2) {
        return error.InsufficientArguments;
    }

    // Extract server name
    const server_name = switch (args[0]) {
        .text => |text| text.data,
        else => return error.InvalidServerName,
    };

    // Extract configuration record
    const config_record = switch (args[1]) {
        .record => |record| record,
        else => return error.InvalidConfiguration,
    };

    // Parse and register the server
    var mutable_config_record = config_record;
    const config = parseServerConfig(&mutable_config_record) catch |err| {
        std.log.err("Failed to parse configuration for server '{s}': {}", .{ server_name, err });
        return MBLValue{ .boolean = memory.Boolean{ .value = false } }; // Return false on error
    };

    const registry = try ensureRegistry(allocator);
    registry.registerServer(server_name, config) catch |err| {
        std.log.err("Failed to register server '{s}': {}", .{ server_name, err });
        return MBLValue{ .boolean = memory.Boolean{ .value = false } }; // Return false on error
    };

    std.log.info("✅ Registered database server: {s} ({s})", .{ server_name, @tagName(config.db_type) });
    return MBLValue{ .boolean = memory.Boolean{ .value = true } }; // Return true on success
}

// Register ODBC native functions with the interpreter
pub fn registerOdbcFunctions(interp: *Interpreter) !void {
    const allocator = interp.allocator;

    // Create the program.odbc namespace
    var odbc_record = Record.init(allocator);

    // Register program.odbc.run function
    const run_function = NativeFunction{
        .name = "run",
        .zig_function = odbcRun,
        .parameter_count = null, // variadic: 2-3 args (server_name, sql_query, optional parameters)
        .allocator = allocator,
    };

    try odbc_record.set("run", MBLValue{ .native_function = run_function });

    // Create program.odbc.server function for configuration
    const server_function = NativeFunction{
        .name = "server",
        .zig_function = odbcServer,
        .parameter_count = 2, // server_name, config_record
        .allocator = allocator,
    };

    try odbc_record.set("server", MBLValue{ .native_function = server_function });

    // Set program.odbc
    try interp.memory.program.set("odbc", MBLValue{ .record = odbc_record });

    std.log.info("ODBC functions registered successfully", .{});
}

// Handle program.odbc.servers assignment
pub fn handleServersAssignment(allocator: std.mem.Allocator, servers_record: *Record) !void {
    const registry = try ensureRegistry(allocator);

    // Iterate through each server configuration
    var iterator = servers_record.fields.iterator();
    while (iterator.next()) |entry| {
        const server_name = entry.key_ptr.*;
        const server_config_value = entry.value_ptr.*;

        if (server_config_value == .record) {
            var mutable_record = server_config_value.record;
            const config = parseServerConfig(&mutable_record) catch |err| {
                std.log.err("Failed to parse configuration for server '{s}': {}", .{ server_name, err });
                continue;
            };

            registry.registerServer(server_name, config) catch |err| {
                std.log.err("Failed to register server '{s}': {}", .{ server_name, err });
                continue;
            };

            std.log.info("Registered database server: {s} ({s})", .{ server_name, @tagName(config.db_type) });
        }
    }
}

// Cleanup function to be called on program exit
pub fn cleanup() void {
    if (db_registry) |*registry| {
        registry.deinit();
        db_registry = null;
    }
}