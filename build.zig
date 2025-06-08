const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const opt_runtime = b.option(bool, "runtime", "build nature runtime") orelse false;

    if (opt_runtime) {
        buildRuntime(b, target, optimize);
    }

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "nature",
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    exe.addIncludePath(.{ .cwd_relative = "./" });
    exe.addIncludePath(.{ .cwd_relative = "./include/" });
    exe.addIncludePath(.{ .cwd_relative = "./utils/" });

    exe.root_module.addCMacro("__LINUX", "1");
    exe.root_module.addCMacro("__AMD64", "1");
    // exe.root_module.addCMacro("_GNU_SOURCE", "");

    exe.addCSourceFiles(.{ .files = nature_main, .flags = &.{"-std=gnu11"} });
    exe.addCSourceFiles(.{ .files = nature_src, .flags = &.{} });
    exe.addCSourceFiles(.{ .files = nature_src_syntax, .flags = &.{} });
    exe.addCSourceFiles(.{ .files = nature_src_symbol, .flags = &.{} });
    exe.addCSourceFiles(.{ .files = nature_src_semantic, .flags = &.{} });
    exe.addCSourceFiles(.{ .files = nature_src_register, .flags = &.{} });
    exe.addCSourceFiles(.{ .files = nature_src_native, .flags = &.{} });
    exe.addCSourceFiles(.{ .files = nature_src_binary, .flags = &.{} });
    exe.addCSourceFiles(.{ .files = nature_src_lower, .flags = &.{} });
    exe.addCSourceFiles(.{ .files = nature_src_debug, .flags = &.{} });
    exe.addCSourceFiles(.{ .files = nature_src_build, .flags = &.{} });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    //install

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

pub fn buildRuntime(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const mod = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const lib = b.addStaticLibrary(.{
        .name = "nature",
        .root_module = mod,
    });

    // Include the source files for the runtime library.
    const aco = &.{"runtime/aco.c"};
    mod.addIncludePath(b.path("runtime/aco/"));
    mod.addCSourceFiles(.{ .files = aco, .flags = &.{"-std=c99"} });

    // Install the runtime library.
    b.installArtifact(lib);
}

const nature_main = &.{"main.c"};

const nature_src_binary = &.{
    "src/binary/elf/linker.c",
    "src/binary/elf/assembler.c",
    "src/binary/encoding/arm64/opcode.c",
    "src/binary/encoding/amd64/opcode.c",
    "src/binary/mach/mach.c",
};

const nature_src_build = &.{
    "src/build/build.c",
    "src/build/config.c",
};

const nature_src_debug = &.{
    "src/debug/debug.c",
    "src/debug/debug_asm.c",
    "src/debug/debug_lir.c",
};

const nature_src_lower = &.{
    "src/lower/amd64.c",
    "src/lower/amd64_abi.c",
    "src/lower/arm64.c",
    "src/lower/arm64_abi.c",
};

const nature_src_native = &.{
    "src/native/amd64.c",
    "src/native/arm64.c",
};

const nature_src_register = &.{
    "src/register/arch/amd64.c",
    "src/register/arch/arm64.c",
    "src/register/allocate.c",
    "src/register/interval.c",
    "src/register/linearscan.c",
    "src/register/register.c",
};

const nature_src_semantic = &.{
    "src/semantic/analyzer.c",
    "src/semantic/infer.c",
};

const nature_src_syntax = &.{
    "src/syntax/parser.c",
    "src/syntax/scanner.c",
};

const nature_src_symbol = &.{
    "src/symbol/symbol.c",
};

const nature_src = &.{
    "src/ast.c",
    "src/cfg.c",
    "src/error.c",
    "src/linear.c",
    "src/lir.c",
    "src/module.c",
    "src/package.c",
    "src/simd.c",
    "src/ssa.c",
};

const nature_utils = &.{
    "utils/autobuf.c",
    "utils/ct_list.c",
    "utils/custom_links.c",
    "utils/error.c",
    "utils/exec.c",
    "utils/helper.c",
    "utils/linked.c",
    "utils/log.c",
    "utils/mutex.c",
    "utils/picohttpparser.c",
    "utils/sc_map.c",
    "utils/slice.c",
    "utils/stack.c",
    "utils/table.c",
    "utils/toml.c",
    "utils/type.c",
    // "utils/ymal/api.c"
};

const includes: []const []const u8 = &.{
    "utils/",
    "cmd/",
    "include/mach/",
    "include/mach-o/",
    "include/uv/",
    "include/",

    "src/binary/arch/",
    "src/binary/elf/",
    "src/binary/encoding/",
    "src/binary/mach/",

    "src/build/",
    "src/build/build.h",

    "src/native",

    "src/debug/",

    "src/lower/",

    "src/register/arch/",
    "src/register/",

    "src/semantic/",

    "src/symbol/",

    "src/syntax/",

    "src/lir.h",
};
