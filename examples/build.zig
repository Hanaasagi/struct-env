const std = @import("std");

const pkg_name = "struct-env";
const pkg_path = "../src/lib.zig";

const examples = .{
    "basic",
    "slice",
    "prefix",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    inline for (examples) |e| {
        const example_path = e ++ "/main.zig";
        const exe_name = "example-" ++ e;
        const run_name = "run-" ++ e;
        const run_desc = "Run the " ++ e ++ " example";

        const exe = b.addExecutable(.{
            .name = exe_name,
            .root_source_file = b.path(example_path),
            .target = target,
            .optimize = optimize,
        });
        const mod = b.addModule("struct-env", .{
            .root_source_file = b.path("../src/lib.zig"),
        });
        exe.root_module.addImport("struct-env", mod);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());
        const run_step = b.step(run_name, run_desc);
        run_step.dependOn(&run_cmd.step);
    }
}
