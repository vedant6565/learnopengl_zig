const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zig_test",
        .root_module = exe_mod,
    });

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("wayland-client");
    exe.linkSystemLibrary("wayland-cursor");
    exe.linkSystemLibrary("wayland-egl");
    exe.linkSystemLibrary("xkbcommon"); // if keyboard input needed
    exe.linkSystemLibrary("glfw");

    const zglfw = b.dependency("zglfw", .{});
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));

    const zmath = b.dependency("zmath", .{});
    exe.root_module.addImport("zmath", zmath.module("root"));

    const zstbi = b.dependency("zstbi", .{});
    exe.root_module.addImport("zstbi", zstbi.module("root"));

    const zm = b.dependency("zm", .{});
    exe_mod.addImport("zm", zm.module("zm"));

    const zigimg_dependency = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zigimg", zigimg_dependency.module("zigimg"));

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.3",
        .profile = .core,
        .extensions = &.{ .ARB_clip_control, .NV_scissor_exclusive },
    });
    exe_mod.addImport("gl", gl_bindings);

    b.installArtifact(exe);

    b.installDirectory(.{ .source_dir = .{ .cwd_relative = "src/shaders/" }, .install_dir = .bin, .install_subdir = "shaders/" });
    b.installDirectory(.{ .source_dir = .{ .cwd_relative = "src/texture/" }, .install_dir = .bin, .install_subdir = "texture/" });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
