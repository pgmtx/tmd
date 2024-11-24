const std = @import("std");
const mem = std.mem;

const tmd = @import("tmd.zig");
const render = @import("tmd_to_html-render.zig");

pub fn tmd_to_html(tmdDoc: tmd.Doc, writer: anytype, completeHTML: bool, allocator: mem.Allocator) !void {
    var r = render.TmdRender{
        .doc = tmdDoc,
        .allocator = allocator,
    };
    if (completeHTML) {
        try writeHead(writer);
        try r.render(writer, true);
        try writeFoot(writer);
        try createCssFile();
    } else {
        try r.render(writer, false);
    }
}

const cssStyle = @embedFile("example.css");

fn writeHead(w: anytype) !void {
    _ = try w.write(
        \\<html>
        \\<head>
        \\<meta charset="utf-8">
        \\<link rel="stylesheet" href="/style.css" />
        \\<title>pgmtx!</title>
        \\</head>
        \\<body>
        \\
    );
    //_ = try w.write(css_style);
    // _ = try w.write(
    //     \\</style>
    //     \\</head>
    //     \\<body>
    //     \\
    // );
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
