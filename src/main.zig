const std = @import("std");
const zdf = @import("zdf");

const stdout = std.io.getStdOut().writer();

fn usage() !void {
    try stdout.writeAll("Usage: runc \"[source code]\"");
}

const header =
    \\ #include <stdio.h>
    \\ #include <stdlib.h>
    \\ #include <string.h>
    \\ #include <stdint.h>
    \\ #include <stdbool.h>
    \\
;

const body_quick_pre =
    \\ int main() {
    \\
;

const body_quick_after =
    \\
    \\ return 0;
    \\ }
    \\
;

const State = struct {
    srcFilename: []const u8 = undefined,
    outFilename: []const u8 = undefined,
    srcWritten: bool = false,
    outWritten: bool = false,
};

fn cleanFiles(s: *State) !void {
    if (s.srcWritten) {
        try std.fs.cwd().deleteFile(s.srcFilename);
    }

    if (s.outWritten) {
        try std.fs.cwd().deleteFile(s.outFilename);
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const random = &std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())).random;
    var ts = random.int(u32);

    var args = try zdf.Args.init(allocator);

    if (args.argc < 2) {
        try usage();
        return;
    }

    var quick = args.has("-q");
    var source = args.argv[args.argc - 1];
    var state = State{};

    if (source[0] == '-') {
        try usage();
        return;
    }

    state.srcFilename = try std.fmt.allocPrint(allocator, "./runc_{}.c", .{ts});
    state.outFilename = try std.fmt.allocPrint(allocator, "./runc_{}", .{ts});
    var sourceFile = try std.fs.cwd().createFile(state.srcFilename, .{});

    try sourceFile.writeAll(header);

    if (quick) {
        try sourceFile.writeAll(body_quick_pre);
    }

    try sourceFile.writeAll(source);

    if (quick) {
        try sourceFile.writeAll(body_quick_after);
    }

    sourceFile.close();
    state.srcWritten = true;

    var c = std.ChildProcess.init(&[_][]const u8{ "clang", state.srcFilename, "-o", state.outFilename }, allocator) catch {
        try cleanFiles(&state);
        std.os.exit(1);
    };
    defer c.deinit();

    try c.spawn();
    var term = c.wait() catch {
        try cleanFiles(&state);
        std.os.exit(1);
    };

    if (term.Exited != 0) {
        try cleanFiles(&state);
        std.os.exit(1);
    }

    state.outWritten = true;

    var run = std.ChildProcess.init(&[_][]const u8{state.outFilename}, allocator) catch {
        try cleanFiles(&state);
        return;
    };
    defer run.deinit();

    run.stdout_behavior = .Pipe;
    try run.spawn();

    var runOutput = try run.stdout.?.readToEndAlloc(allocator, 1024 * 1024 * 1024);
    defer allocator.free(runOutput);

    _ = try run.wait();

    try stdout.writeAll(runOutput);
    try cleanFiles(&state);
}
