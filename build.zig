const std = @import("std");

const supported_targets = @embedFile("supported_targets");
pub fn targetSupported(b: *std.Build, target: std.Target) bool {
    _ = b;
    // const target_printed = target.zigTriple(b.allocator) catch @panic("oom");
    var supported_targets_iter = std.mem.split(u8, supported_targets, "\n");
    while (supported_targets_iter.next()) |target_triple| {
        const trimmed = std.mem.trim(u8, target_triple, " \t\r");
        if (trimmed.len == 0) continue;
        const other_target_query = std.Target.Query.parse(.{
            .arch_os_abi = trimmed,
        }) catch @panic("bad other target");
        const other_target_resolved = std.zig.system.resolveTargetQuery(other_target_query) catch @panic("bad other target");
        // const other_target_printed = other_target_resolved.zigTriple(b.allocator) catch @panic("oom");

        // ignore versions
        if (target.os.tag == other_target_resolved.os.tag) {
            if (target.cpu.arch == other_target_resolved.cpu.arch) {
                if (target.abi == other_target_resolved.abi) {
                    return true;
                }
            }
        }
    }
    return false;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_profile: []const u8 = switch (optimize) {
        .Debug => "zig_debug",
        .ReleaseSmall => "release_small",
        .ReleaseFast => "release_fast",
        .ReleaseSafe => "release_safe",
    };
    var build_target = std.ArrayList(u8).init(b.allocator);
    build_target.appendSlice(@tagName(target.result.cpu.arch)) catch @panic("oom");
    build_target.appendSlice("-") catch @panic("oom");
    build_target.appendSlice(switch (target.result.os.tag) {
        .macos => "apple-darwin",
        .linux => "unknown-linux",
        .windows => "pc-windows",
        .wasi => "wasi",
        .freestanding => "unknown-unknown",
        else => @panic("not supported target for syntect"),
    }) catch @panic("oom");
    const ext = switch (target.result.os.tag) {
        .windows => switch (target.result.abi) {
            .msvc => "lib",
            else => "a",
        },
        else => "a",
    };
    if (target.result.abi != .none and !(target.result.cpu.arch == .wasm32 and target.result.abi == .musl)) {
        build_target.appendSlice("-") catch @panic("oom");
        build_target.appendSlice(@tagName(target.result.abi)) catch @panic("oom");
    }
    std.log.info("build target: {s}", .{build_target.items});
    // const add_toolchain_command = b.addSystemCommand(&.{
    //     "rustup", "toolchain", "install", "nightly",
    // });
    const add_target_command = b.addSystemCommand(&.{
        "rustup", "target", "add", build_target.items, // "--toolchain", "nightly",
    });
    // add_target_command.step.dependOn(&add_toolchain_command.step);
    // const add_component_command = b.addSystemCommand(&.{
    //     "rustup", "component", "add", "rust-src", // "--toolchain", "nightly",
    // });
    // add_component_command.step.dependOn(&add_target_command.step);
    const build_command = b.addSystemCommand(&.{
        // cargo +nightly
        "cargo", "zigbuild", "--profile", build_profile, "--target", build_target.items,
        // "-Z", "build-std",
        // "-Z", "build-std-features=panic_immediate_abort",
    });
    build_command.step.dependOn(&add_target_command.step);

    const object_file_generated: *std.Build.GeneratedFile = b.allocator.create(std.Build.GeneratedFile) catch @panic("oom");
    object_file_generated.* = .{
        .step = &build_command.step,
        .path = b.pathFromRoot(b.fmt("target/{s}/{s}/libsyntect_zig.{s}", .{ build_target.items, build_profile, ext })),
    };
    const object_file_path: std.Build.LazyPath = .{ .generated = .{ .file = object_file_generated } };

    // const fakeunwind = b.addObject(.{
    //     .name = "fakeunwind",
    //     .root_source_file = b.path("src/fakeunwind.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // fakeunwind.want_lto = false;

    const module = b.addModule("syntect", std.Build.Module.CreateOptions{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });
    module.link_libc = true;
    module.addObjectFile(object_file_path);
    // module.addObject(fakeunwind);
    // seems to be ok for cross compilation? it's provided by zig itself
    module.linkSystemLibrary("unwind", .{
        .needed = true,
        .weak = false,
        .use_pkg_config = .no,
        .preferred_link_mode = .static,
        .search_strategy = .no_fallback,
    });

    const demo_exe = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("example/demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo_exe.root_module.addImport("syntect", module);
    b.installArtifact(demo_exe);

    const run_cmd = b.addRunArtifact(demo_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the demo");
    run_step.dependOn(&run_cmd.step);
}
