const std = @import("std");
const zdf = @import("zdf");

const stdout = std.io.getStdOut().writer();

fn usage() !void {
    try stdout.writeAll("Usage: runc [-q] [-{d|f|i}m] [-k] \"source code\"\n");
}

fn help() !void {
    try usage();
    try stdout.writeAll("\n");
    try stdout.writeAll("Options:\n");
    try stdout.writeAll("  -q\t\t\t Quick mode: the source code is placed directly inside a builtin main funcion.\n");
    try stdout.writeAll("  -dm\t\t\t Math mode (double): evaluates the expression and prints the result.\n");
    try stdout.writeAll("  -fm\t\t\t Math mode (float)\n");
    try stdout.writeAll("  -im\t\t\t Math mode (int)\n");
    try stdout.writeAll("  -k\t\t\t Keep the generated source file. (the filename is \"runc_[somenumber].c\"\n");
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

const Mode = union(enum) {
    Normal: void,
    Quick: void,
    Math: enum {
        Float,
        Double,
        Int,
    },
};

const State = struct {
    srcFilename: []const u8 = undefined,
    outFilename: []const u8 = undefined,
    srcWritten: bool = false,
    outWritten: bool = false,
    mode: Mode = .Normal,
    keepSource: bool = false,
};

fn cleanFiles(s: *State) !void {
    if (s.srcWritten and !s.keepSource) {
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

    if (args.has("-h") or args.has("--help")) {
        try help();
        return;
    }

    var state = State{};

    var quick = args.has("-q");
    var mathFloat = args.has("-fm");
    var mathDouble = args.has("-dm");
    var mathInt = args.has("-im");
    state.keepSource = args.has("-k");

    if (quick) {
        state.mode = .Quick;
    } else if (mathDouble) {
        state.mode = .{ .Math = .Double };
    } else if (mathFloat) {
        state.mode = .{ .Math = .Float };
    } else if (mathInt) {
        state.mode = .{ .Math = .Int };
    } else {
        state.mode = .Normal;
    }

    var source = args.argv[args.argc - 1];

    if (source[0] == '-') {
        try usage();
        return;
    }

    state.srcFilename = try std.fmt.allocPrint(allocator, "./runc_{}.c", .{ts});
    state.outFilename = try std.fmt.allocPrint(allocator, "./runc_{}", .{ts});
    var sourceFile = try std.fs.cwd().createFile(state.srcFilename, .{});

    try sourceFile.writeAll(header);

    switch (state.mode) {
        .Normal => {
            try sourceFile.writeAll(source);
        },
        .Quick => {
            try sourceFile.writeAll(body_quick_pre);
            try sourceFile.writeAll(source);
            try sourceFile.writeAll(body_quick_after);
        },
        .Math => |mathMode| {
            try sourceFile.writeAll("#include<math.h>\nint main(){\n");
            var varString = switch (mathMode) {
                .Double => "double x = ",
                .Float => "float x = ",
                .Int => "int x = ",
            };
            var formatString = switch (mathMode) {
                .Double => "%f",
                .Float => "%f",
                .Int => "%d",
            };
            try sourceFile.writeAll(varString);
            try sourceFile.writeAll(source);
            try sourceFile.writeAll(";\n printf(\"");
            try sourceFile.writeAll(formatString);
            try sourceFile.writeAll("\\n\",x);\n return 0; \n }");
        },
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
