const std = @import("std");
const builtin = @import("builtin");

const tmd = @import("tmd");
//const tmd_parser = @import("tmd_parser.zig");
//const tmd_to_html = @import("tmd_to_html.zig");

const demo3 = @embedFile("demo3.tmd");
const Option = tmd.render.Option;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpaAllocator = gpa.allocator();

    const MaxInFileSize = 1 << 20;
    const MaxDocDataSize = 1 << 20;
    const MaxOutFileSize = 8 << 20;
    const FixedBufferSize = MaxInFileSize + MaxDocDataSize + MaxOutFileSize;
    const fixedBuffer = try gpaAllocator.alloc(u8, FixedBufferSize);
    defer gpaAllocator.free(fixedBuffer);
    var fba = std.heap.FixedBufferAllocator.init(fixedBuffer);
    const fbaAllocator = fba.allocator();

    const args = try std.process.argsAlloc(gpaAllocator);
    defer std.process.argsFree(gpaAllocator, args);

    std.debug.assert(args.len > 0);

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const cleanRequired = args.len == 2 and std.mem.eql(u8, args[1], "clean");

    if (args.len <= 1 or (!std.mem.eql(u8, args[1], "render") and !cleanRequired)) {
        try stdout.print(
            \\Usage:
            \\  tmd render [--full-html] TMD-files...
            \\  tmd clean
            \\
        , .{});
        return;
    }

    if (args.len == 2) {
        if (cleanRequired) {
            try std.fs.cwd().deleteTree("output");
        } else {
            try stderr.print("No tmd files specified.\n", .{});
        }
        return;
    }

    var optionsDone = false;
    var option = Option.none;

    std.fs.cwd().access("output", .{}) catch {
        try std.fs.cwd().makeDir("output");
    };

    for (args[2..]) |arg| {

        // ToDo: improve ...
        if (std.mem.startsWith(u8, arg, "--")) blk: {
            if (optionsDone) break :blk;

            if (std.mem.eql(u8, arg[2..], "full-html")) {
                option = Option.fullHtml;
            } else if (std.mem.eql(u8, arg[2..], "include-css")) {
                option = Option.includeCss;
            } else {
                try stderr.print("Got unexpected parameter : {s}.\n", .{arg});
                try std.fs.cwd().deleteTree("output");
                return;
            }

            continue;
        } else optionsDone = true;

        // load file

        defer fba.reset();

        const tmdFile = std.fs.cwd().openFile(arg, .{}) catch {
            try stdout.print("Could not open the following file: {s}\n", .{arg});
            try std.fs.cwd().deleteTree("output");
            return;
        };
        defer tmdFile.close();
        const stat = try tmdFile.stat();
        if (stat.kind != .file) try stderr.print("[{s}] is not a file.\n", .{arg});

        const tmdContent = try tmdFile.readToEndAlloc(fbaAllocator, MaxInFileSize);
        defer fbaAllocator.free(tmdContent);

        std.debug.assert(tmdContent.len == stat.size);

        // parse file

        var tmdDoc = try tmd.parser.parse_tmd_doc(tmdContent, fbaAllocator);
        defer tmd.parser.destroy_tmd_doc(&tmdDoc, fbaAllocator); // if fba, then this is actually not necessary.

        // render file

        const htmlExt = ".html";
        const tmdExt = ".tmd";
        var outputFilePath: [1024]u8 = undefined;
        var outputFilename: []u8 = undefined;
        if (std.ascii.endsWithIgnoreCase(arg, tmdExt)) {
            if (arg.len - tmdExt.len + htmlExt.len > outputFilePath.len)
                return error.InputFileNameTooLong;
            outputFilename = arg[0 .. arg.len - tmdExt.len];
        } else {
            if (arg.len + htmlExt.len > outputFilePath.len)
                return error.InputFileNameTooLong;
            outputFilename = arg;
        }
        std.mem.copyBackwards(u8, outputFilePath[0..], outputFilename);
        std.mem.copyBackwards(u8, outputFilePath[outputFilename.len..], htmlExt);
        outputFilename = outputFilePath[0 .. outputFilename.len + htmlExt.len];

        const renderBuffer = try fbaAllocator.alloc(u8, MaxOutFileSize);
        defer fbaAllocator.free(renderBuffer);
        var fbs = std.io.fixedBufferStream(renderBuffer);
        try tmd.render.tmd_to_html(tmdDoc, fbs.writer(), option, gpaAllocator);

        // write file
        const filePath = try std.mem.concat(fbaAllocator, u8, &[_][]const u8{ "output/", outputFilename });
        defer fbaAllocator.free(filePath);

        const htmlFile = try std.fs.cwd().createFile(filePath, .{});
        defer htmlFile.close();

        try htmlFile.writeAll(fbs.getWritten());

        try stdout.print(
            \\{s} ({} bytes)
            \\   -> {s} ({} bytes)
            \\
        , .{ arg, stat.size, outputFilename, fbs.getWritten().len });
    }
}
