const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .fast });

    const fzf_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    fzf_mod.addCSourceFile(.{
        .file = b.path("src/fzf.c"),
        .language = .c,
        .flags = &.{
            "-std=gnu99",
            "-Wall",
            "-fpic",
        },
    });

    const fzf_lib = b.addLibrary(.{
        .name = if (target.result.os.tag == .windows) "libfzf" else "fzf",
        .root_module = fzf_mod,
        .linkage = .dynamic,
        .use_llvm = true,
        .use_lld = true,
    });

    const install = b.addInstallArtifact(fzf_lib, .{
        .dest_dir = .{ .override = .{ .custom = "../build" } },
        .pdb_dir = .disabled,
        .implib_dir = .disabled,
    });
    b.default_step.dependOn(&install.step);

    // C test setup
    if (target.result.os.tag == .linux) {
        const examiner_upstream = try b.dependencyLazy("examiner", .{});
        const examiner_lib = examiner_lib_gen(b, examiner_upstream, target, optimize);

        const test_exe = b.addExecutable(.{
            .name = "test",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = .debug,
                .link_libc = true,
            }),
            .use_llvm = true,
        });
        test_exe.root_module.addCSourceFile(.{
            .file = b.path("test/test.c"),
            .language = .c,
            .flags = &.{
                "-std=gnu99",
                "-Wall",
                "-ggdb3",
            },
        });
        test_exe.root_module.addIncludePath(b.path("src"));
        test_exe.root_module.addIncludePath(examiner_upstream.path("src"));

        test_exe.root_module.linkLibrary(fzf_lib);
        test_exe.root_module.linkLibrary(examiner_lib);

        const test_step = b.step("test", "Run C tests");
        test_step.dependOn(&b.addRunArtifact(test_exe).step);
    }
}

fn examiner_lib_gen(
    b: *std.Build,
    dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Optimize,
) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "examiner",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });

    lib.root_module.addIncludePath(dep.path("src"));
    lib.root_module.addCSourceFile(.{
        .file = dep.path("src/examiner.c"),
        .language = .c,
        .flags = &.{
            "-std=gnu99",
            "-Wall",
        },
    });

    return lib;
}
