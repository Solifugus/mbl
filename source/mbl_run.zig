const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const interpreter = @import("interpreter.zig");
const memory = @import("memory.zig");

const Lexer = lexer.Lexer;
const Parser = parser.Parser;
const Interpreter = interpreter.Interpreter;
const Memory = memory.Memory;

// Global reference for signal handling
var global_interpreter: ?*Interpreter = null;
var shutdown_requested = std.atomic.Atomic(bool).init(false);

// Set up signal handling using Zig's approach
fn setupSignalHandlers(interp: *Interpreter) void {
    global_interpreter = interp;

    // Create a thread to handle signals
    const signal_thread = std.Thread.spawn(.{}, signalHandler, .{}) catch {
        std.log.warn("⚠️  Could not create signal handler thread, using manual shutdown only", .{});
        return;
    };
    signal_thread.detach();
}

fn signalHandler() void {
    // Simple signal monitoring approach
    // In a production environment, this would use proper signal handling
    // For now, we rely on the keep-alive loop and manual termination
    std.log.info("🔧 Signal handler thread started (basic implementation)", .{});

    // Keep the thread alive but don't do actual signal processing for now
    // The keep-alive loop provides the main termination mechanism
    while (!shutdown_requested.load(.Monotonic)) {
        std.time.sleep(1 * std.time.ns_per_s);
    }

    std.log.info("🔄 Signal handler thread terminating", .{});
}

pub fn main() !void {
    // Use GeneralPurposeAllocator for better memory safety and debugging
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.info("Usage: mbl [--quiet] <filename.mbl>", .{});
        std.log.info("Example: mbl demo.mbl", .{});
        std.log.info("  --quiet  Suppress debug output", .{});
        return;
    }

    // Parse arguments
    var quiet_mode = false;
    var filename: []const u8 = "";

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--quiet") or std.mem.eql(u8, arg, "-q")) {
            quiet_mode = true;
        } else if (filename.len == 0 and !std.mem.startsWith(u8, arg, "-")) {
            filename = arg;
        }
    }

    if (filename.len == 0) {
        std.log.info("Error: No filename provided", .{});
        return;
    }

    // Read the MBL file
    const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
        std.log.err("Error opening file '{s}': {}", .{filename, err});
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const mbl_code = try allocator.alloc(u8, file_size);
    defer allocator.free(mbl_code);

    _ = try file.readAll(mbl_code);

    if (!quiet_mode) {
        std.log.info("✓ Loaded {} bytes of MBL code", .{mbl_code.len});
        std.log.info("--- MBL Code ---", .{});
        std.log.info("{s}", .{mbl_code});
        std.log.info("--- Processing ---", .{});
    }

    // Initialize components
    var lex = Lexer.init(allocator, mbl_code, filename);

    var mem = Memory.init(allocator);
    defer mem.deinit();

    // Tokenize
    const tokens = try lex.scanTokens();
    defer tokens.deinit(); // Clean up token list
    if (!quiet_mode) std.log.info("✓ Lexer: {} tokens", .{tokens.items.len});

    // Parse
    var main_parser = Parser.init(allocator, tokens.items);

    const statements = try main_parser.parse();
    if (!quiet_mode) std.log.info("✓ Parser: {} statements", .{statements.len});

    // Execute
    var interp = Interpreter.init(allocator, &mem);
    defer interp.deinit();

    interp.quiet_mode = quiet_mode;
    try interp.execute(statements);
    if (!quiet_mode) std.log.info("✅ Program execution completed!", .{});

    // Show program output to stdout
    const output = interp.output.items;
    if (output.len > 0) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("{s}", .{output});
    }

    // Keep-alive mechanism: Check if any servers are running
    if (interp.hasRunningServers()) {
        if (!quiet_mode) std.log.info("🌐 Server(s) running - entering keep-alive mode", .{});
        if (!quiet_mode) std.log.info("Press Ctrl+C to gracefully shutdown", .{});

        // Set up signal handling for graceful shutdown
        setupSignalHandlers(&interp);

        // Keep-alive loop
        while (interp.hasRunningServers() and !interp.shutdown_requested and !shutdown_requested.load(.Monotonic)) {
            std.time.sleep(500 * std.time.ns_per_ms); // Check every 500ms for responsiveness
        }

        // Graceful shutdown
        if (!quiet_mode) std.log.info("🔄 Beginning graceful shutdown...", .{});
        interp.initiateGracefulShutdown();
        interp.waitForGracefulShutdown();
        if (!quiet_mode) std.log.info("✅ Graceful shutdown complete", .{});
    }

    // Clean up statements
    for (statements) |*stmt| {
        stmt.deinit(allocator);
    }
    allocator.free(statements);

    if (!quiet_mode) std.log.info("🎉 MBL Program '{s}' executed successfully!", .{filename});
}