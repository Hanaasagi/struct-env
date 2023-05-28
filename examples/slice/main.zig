const std = @import("std");
const struct_env = @import("struct-env");

const MyEnv = struct {
    foo: []const []const u8,
    bar: []const []const u8 = &.{ "b", "a", "r" },
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const env = try struct_env.fromEnv(allocator, MyEnv);
    defer struct_env.free(allocator, env);

    std.debug.print("FOO is {any}\n", .{env.foo});
    std.debug.print("BAR is {any}\n", .{env.bar});
}
