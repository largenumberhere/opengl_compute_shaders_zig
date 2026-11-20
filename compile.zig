const std = @import("std");
const Process = std.process;

const DebugAllocator = std.heap.DebugAllocator;
const Allocator = std.mem.Allocator;

// Run a command and block until it is done.
// Discard the return code
fn run(args: []const []const u8, alloc: Allocator, workingDirectory: []const u8) !void {
    var child = Process.Child.init(args, alloc);
    child.cwd = workingDirectory;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    const err = try Process.Child.spawnAndWait(&child);
    if (err != .Exited) {
        std.debug.print("failed running command:\n", .{});
        for (args, 0..) |arg, i| {
            const last = i == args.len - 1;
            if (last) {
                std.debug.print("{s}\t\n", .{arg});
            } else {
                std.debug.print("{s}\t\\\n", .{arg});
            }
        }
    }
}

const script_output = "./compile";
const script_source = "./compile.zig";
const no_rebuild_flag = "--no-rebuild";
fn rebuild(alloc: Allocator) !void {
    // std.debug.print("Rebuilding\n", .{});

    try run(&.{ "rm", script_output }, alloc, ".");
    try run(&.{ "./zig", "build-exe", script_source }, alloc, ".");
    try run(&.{ script_output, no_rebuild_flag }, alloc, ".");
}

fn todo() noreturn {
    unreachable;
}

fn shouldRebuild(argsIter: *Process.ArgIterator) bool {
    // discard program name
    _ = argsIter.next();

    const arg1 = argsIter.next();
    if (arg1 == null) {
        return true;
    } else if (std.mem.eql(u8, no_rebuild_flag, arg1.?)) {
        return false;
    } else {
        todo();
    }
}

pub fn main() !void {
    var debug_allocator = DebugAllocator(.{}).init;
    const alloc = debug_allocator.allocator();
    defer _ = debug_allocator.deinit();

    var argsIter = std.process.args();
    if (shouldRebuild(&argsIter)) {
        try rebuild(alloc);
        return;
    }

    try run(&.{ "rm", "-rd", "build/" }, alloc, ".");
    try run(&.{ "mkdir", "build/" }, alloc, ".");

    const args = .{
        "./zig",
        "build-exe",
        "-I",
        "src/opengl/include",
        "src/opengl/glad.c",
        "src/main.zig",
        "-lc",
        "-lglfw",
        "-lGL",
        "-femit-bin=build/main",
    };
    try run(&args, alloc, ".");

    std.debug.print("Finished Compiling. Running...\n", .{});

    try run(&.{"./build/main"}, alloc, ".");
}
