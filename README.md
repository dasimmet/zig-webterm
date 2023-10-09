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

the default example embeds the static built documentation of the 
build steps and serves them.

# Download Step

The module also has a `Download` Build step to fetch a file using the system
`curl` command.

# JZon Step

the JZon step converts a `json` file from a LazyPath into a `.zig` file
with a `.zon`-like syntax.
It can then be imported as a module in subsequent steps.
the example fetches a
[list of mimetypes](https://github.com/patrickmccallum/mimetype-io/blob/master/src/mimeData.json)
and uses it to statically map file extensions to the appropriate `Content-Type`
header.