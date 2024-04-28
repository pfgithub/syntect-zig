const std = @import("std");
const syntect = @import("syntect");

pub fn main() !void {
    std.log.info("rust code: {d}", .{syntect.add(9, 10)});
}
