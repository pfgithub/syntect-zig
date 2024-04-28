supports cross-compiling to all targets in `supported_targets`

TODO: windows support (`lld-link: duplicate symbol: ___chkstk_ms`)

requires:

- rustup installed and in path

usage:

```
zig fetch --save ...
TODO
```

test building all targets: `bun build_all_targets.ts`

maybe there's a way it can automatically download rustup and use it from its own directory? but it doesn't do that right now. so rust has to be installed and in the path.