const std = @import("std");
const syntect = @import("syntect");

pub fn main() !void {
    std.log.info("rust code: {d}", .{syntect.add(9, 10)});

    const syntax_set = syntect.SyntaxSet.allocate();
    defer syntax_set.deallocate();

    const ssb = syntect.SyntaxSetBuilder.create();
    defer ssb.deallocate();
    {
        // errdefer ssb.deinit(); //not implemented
        try ssb.add(@embedFile("sample.sublime-syntax"));
    }

    ssb.buildAndDeinit(syntax_set);
    // syntax_set.initDefaults();
    defer syntax_set.deinit();

    const parser = try syntect.ParseIter.create(syntax_set, "example");
    defer parser.destroy();
    const char = syntect.ParseChar.create();
    defer char.deallocate();
    var buf: [128]u8 = undefined;
    for (&[_][]const u8{ "red green\n", "green red\n" }) |line| {
        try parser.addLine(line);
        while (!parser.wantsNextLine()) {
            if (parser.next(char)) {
                defer char.deinit();

                const char_val = char.getChar();
                const len = char.getScopes(&buf);
                if (len > buf.len) return error.TooBig;
                std.log.info("char: '{c}', buf: '{s}'", .{ char_val, buf[0..len] });
            }
        }
    }
}
