# Zig Webterm

this project uses [zap]([https://](https://github.com/zigzap/zap)) to build a static webserver with its assets embedded.

for the impatient:

```
max@muster:~/zig-webterm$ zig build run
steps [54/56] zig build-exe zigtty Debug native... LLVM Emit Object... 
Open http://127.0.0.1:3000 in your browser
```

## Compress step

it holds a [src/build/CompressStep.zig](src/build/CompressStep.zig) to
bundle the responses from [assets/](assets/)
into a `std.ComptimeStringMap` zig source code file.
This file is added as a module to the server compilation.

```zig
const CompressStep = @import("CompressStep");
const assets = CompressStep.init(
    b,
    .{ .path = "src/assets" },
    "assets",
);
assets.method = .Deflate;
// the method enum will enable compression on the file entries.
// it will be shipped with the resulting zig file and can be switched on.
// TODO: provide a way to set compression method on a per-file basis.

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

## Download Step

The module also has a `Download` Build step to fetch a file using the `curl` system command.
Maybe later this will be replaced by standard library code.

The input `url` of `Download` accepts a LazyPath, but expects a URL to pass into curl.
The `output_file` is a GeneratedFile path to the downloaded file in zig's cache.

## JZon Step

the JZon step converts a `json` file from a LazyPath into a `.zig` file
with a `.zon`-like syntax, but assigned to a single identifier `data`:

```
pub const data = <converted json data here>
```

It can then be imported as a module in subsequent steps and processed at comptime.
The example fetches a
[list of mimetypes](https://github.com/patrickmccallum/mimetype-io/blob/master/src/mimeData.json)
using a Download step, then convert it to a `.zig` file.
The result is passed as a module to the server build step and in comptime
the server maps file extensions to the appropriate `Content-Type`
header.