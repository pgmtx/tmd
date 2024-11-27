const std = @import("std");
const mem = std.mem;

const tmd = @import("tmd.zig");
const render = @import("tmd_to_html-render.zig");

pub const Option = enum { none, fullHtml, includeCss };

pub fn tmd_to_html(tmdDoc: tmd.Doc, writer: anytype, option: Option, allocator: mem.Allocator) !void {
    var r = render.TmdRender{
        .doc = tmdDoc,
        .allocator = allocator,
    };

    switch (option) {
        Option.fullHtml => {
            try writeHeadFull(writer);
            try r.render(writer, true);
        },
        Option.includeCss => {
            try writeHead(writer);
            try r.render(writer, true);
            try writeFoot(writer);
            try createCssFile();
        },
        else => try r.render(writer, false),
    }
}

const cssStyle = @embedFile("example.css");
const htmlBeforeTitle =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\<meta charset="utf-8">
    \\<meta name="viewport" content="width=device-width, initial-scale=1.0">
    \\
;

const htmlAfterTitle =
    \\<title>pgmtx!</title>
    \\</head>
    \\<body>
    \\
;

fn writeHeadFull(w: anytype) !void {
    _ = try w.write(htmlBeforeTitle);
    _ = try w.write("<style>");
    _ = try w.write(cssStyle);
    _ = try w.write("</style>");
    _ = try w.write(htmlAfterTitle);
}

fn writeHead(w: anytype) !void {
    _ = try w.write(htmlBeforeTitle);
    _ = try w.write(
        \\<link rel="stylesheet" href="/style.css">
    );
    _ = try w.write(htmlAfterTitle);
}

fn writeFoot(w: anytype) !void {
    _ = try w.write(
        \\
        \\</body>
        \\</html>
    );
}

fn createCssFile() !void {
    const cssFilePath = "output/" ++ "style.css";

    const cssFile = try std.fs.cwd().createFile(cssFilePath, .{});
    defer cssFile.close();

    try cssFile.writeAll(cssStyle);
}
