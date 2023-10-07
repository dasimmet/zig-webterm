# Zig Webterm

this project uses [zap]([https://](https://github.com/zigzap/zap)) to build a static webserver with its assets embedded.

for the impatient:

```
max@muster:~/zig-webterm$ zig build run
steps [54/56] zig build-exe zigtty Debug native... LLVM Emit Object... 
Open http://127.0.0.1:3000 in your browser
```

it holds a [src/build/CompressStep.zig](src/build/CompressStep.zig) to
bundle the responses from [assets/](assets/)
into a `std.ComptimeStringMap` zig source code file.
This file is added as a module to the server compilation.

```
const CompressStep = @import("CompressStep");
const assets_compressed = CompressStep.init(
    b,
    .{ .path = "src/assets" },
    "assets",
);
assets_compressed.compression = .Raw;
server.step.dependOn(&assets_compressed.step);

const assets = b.addModule("assets", .{
    .source_file = .{
        .generated = &assets_compressed.output_file,
    },
});
```

the result is a single static binary webserver serving
precompressed responses from memory ;-D.