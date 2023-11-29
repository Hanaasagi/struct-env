const std = @import("std");

pub fn str2bool(allocator: std.mem.Allocator, s: []const u8) !bool {
    const buf = try allocator.alloc(u8, s.len);
    defer allocator.free(buf);

    const truth = std.ascii.upperString(buf, s);

    return std.mem.eql(u8, truth, "TRUE");
}
