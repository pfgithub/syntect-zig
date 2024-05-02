const std = @import("std");
const syntect = @import("syntect");

pub fn main() !void {
    std.log.info("Start!", .{});
    var timer = try std.time.Timer.start();

    const ssb = syntect.SyntaxSetBuilder.allocate();
    defer ssb.deallocate();
    ssb.init();
    {
        errdefer ssb.deinit();
        try ssb.add(@embedFile("sample.sublime-syntax"));
    }
    std.log.info("[{d}] SyntaxSetBuilder", .{timer.lap()});

    const syntax_set = syntect.SyntaxSet.allocate();
    defer syntax_set.deallocate();

    ssb.buildAndDeinit(syntax_set);
    defer syntax_set.deinit();
    std.log.info("[{d}] SyntaxSet", .{timer.lap()});

    const parse_state = syntect.ParseState.allocate();
    defer parse_state.deallocate();

    try parse_state.init(syntax_set, "example");
    defer parse_state.deinit();
    std.log.info("[{d}] ParseState", .{timer.lap()});

    const parser = syntect.ParseIter.allocate();
    defer parser.deallocate();

    try parser.init(syntax_set, parse_state);
    defer parser.deinit();
    std.log.info("[{d}] ParseIter", .{timer.lap()});

    const char = syntect.ParseChar.allocate();
    defer char.deallocate();
    std.log.info("[{d}] Char", .{timer.lap()});

    var buf: [128]u8 = undefined;
    for (&[_][]const u8{ "red green\n", "green red\n" }, 0..) |line, i| {
        timer.reset();
        try parser.addLine(line);
        std.log.info("[{d}] Line {d}", .{timer.lap(), i + 1});
        while (!parser.wantsNextLine()) {
            try parser.next(char);
            defer char.deinit();

            const char_val = char.getChar();
            const len = char.getScopes(&buf);
            if (len > buf.len) return error.TooBig;
            std.log.info("char: '{c}', buf: '{s}'", .{ char_val, buf[0..len] });
        }
    }
}
