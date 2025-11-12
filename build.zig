const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimise = b.standardOptimizeOption(.{});

    const mod = b.addModule("Lesser-Format", .{
        .root_source_file = b.path("src/fmt.zig"),
        .target = target,
        .optimize = optimise,
    });

    _ = mod;

    const modTest = b.createModule(.{
        .root_source_file = b.path("src/fmt.zig"),
        .target = target,
        .optimize = optimise,
        .link_libc = true,
    });

    const mod_tests = b.addTest(.{ .root_module = modTest });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
