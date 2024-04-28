const std = @import("std");
const syntect = @import("syntect");

pub fn main() !void {
    std.log.info("rust code: {d}", .{syntect.add(9, 10)});

    const parser = try syntect.ParseIter.create("rs");
    defer parser.destroy();
    const char = syntect.ParseChar.create();
    defer char.destroy();
    for (&[_][]const u8{ "pub struct Wow { hi: u64 }\n", "fn blah() -> u64 {}\n" }) |line| {
        try parser.addLine(line);
        while (!parser.wantsNextLine()) {
            if (parser.next(char)) {
                defer char.deinit();
                char.print();
            }
        }
    }
}
