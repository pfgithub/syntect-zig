supports cross-compiling to all targets in `supported_targets`

TODO: windows support (`lld-link: duplicate symbol: ___chkstk_ms`)

requires:

- rustup must be installed and in path, along with `cargo` (added by rustup)

usage:

```
zig fetch --save=syntect https://github.com/pfgithub/syntect-zig/archive/COMMIT_HASH.tar.gz
```

```zig
// build.zig
const syntect = @import("syntect");

pub fn build(b: *std.build) void {
    const enable_syntect = b.option(bool, "enable_syntect", "Override enable syntect?") orelse syntect.targetSupported(b, target.result);

    const syntect_dep = b.dependency("syntect", .{.target = target, .optimize = optimize});

    const my_exe = b.addExecutable(…);
    if(enable_syntect) {
        demo_exe.root_module.addImport("syntect", syntect_dep.module("syntect"));
    }
}
```

---

development here:

test building all targets: `bun build_all_targets.ts`

maybe there's a way it can automatically download rustup and use it from its own directory? but it doesn't do that right now. so rust has to be installed and in the path.