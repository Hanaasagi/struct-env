const std = @import("std");
const struct_env = @import("struct-env");

const MyEnv = struct {
    job: []const u8,
    path: []const u8,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const env = try struct_env.fromPrefixedEnv(allocator, MyEnv, "GITHUB_");
    defer struct_env.free(allocator, env);

    std.debug.print("GITHUB_JOB is {s}\n", .{env.job});
    std.debug.print("GITHUB_PATH is {s}\n", .{env.path});
}
