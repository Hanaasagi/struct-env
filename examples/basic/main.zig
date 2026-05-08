const std = @import("std");
const struct_env = @import("struct-env");

const MyEnv = struct {
    home: []const u8,
    foo: ?[]const u8,
    bar: []const u8 = "bar",
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const env = try struct_env.fromEnv(allocator, MyEnv, init.environ_map);
    defer struct_env.free(allocator, env);

    std.debug.print("HOME is {s}\n", .{env.home});
    std.debug.print("FOO  is {any}\n", .{env.foo == null});
    std.debug.print("BAR  is {s}\n", .{env.bar});
}
