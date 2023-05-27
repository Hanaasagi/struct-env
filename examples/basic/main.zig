const std = @import("std");
const struct_env = @import("struct-env");

const MyEnv = struct {
    home: []const u8,
    foo: ?[]const u8,
    bar: []const u8 = "bar",
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const env = try struct_env.fromEnv(allocator, MyEnv);
    defer struct_env.free(allocator, env);

    std.debug.print("HOME is {s}\n", .{env.home});
    std.debug.print("FOO  is {any}\n", .{env.foo == null});
    std.debug.print("BAR  is {s}\n", .{env.bar});
}
