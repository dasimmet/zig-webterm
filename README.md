# Zig Zerve

this project uses [zap]([https://](https://github.com/zigzap/zap)) to build a static webserver with its assets embedded.
Mostly just for exploring custom `zig build` Steps.

for the impatient:

```
max@muster:~/zig-webterm$ zig build run
steps [54/56] zig build-exe zigtty Debug native... LLVM Emit Object... 
Open http://127.0.0.1:3000 in your browser
```

## Download Step

The module has a [src/build/Step/Download.zig](src/build/Step/Download.zig)
Build step to fetch a file using the `curl` system command.
Maybe later this will be replaced by standard library code.

The input `url` of `Download` accepts a LazyPath, but expects a URL to pass into curl.
The `output_file` is a GeneratedFile path to the downloaded file in zig's cache.

## JZon Step

the [src/build/Step/JZon.zig](src/build/Step/JZon.zig) step converts a `json` file from a LazyPath into a `.zig` file
with a `.zon`-like syntax, but assigned to a single identifier `data`:

```
pub const data = <converted json data here>
```

It can then be imported as a module in subsequent steps and processed at comptime.
The example fetches a
[list of mimetypes](https://github.com/patrickmccallum/mimetype-io/blob/master/src/mimeData.json)
using a Download step, then convert it to a `.zig` file.
The result is imported in the `Compress` step and in comptime
maps file extensions to the appropriate `Content-Type` header.

## Compress step

the repo holds a [src/build/Step/Compress.zig](src/build/Step/Compress.zig) to
bundle the responses from the generated [MyBuild](src/build/MyBuild.zig)
documentation into a `std.ComptimeStringMap` zig source code file.
While this intermediate representation is not too efficient for large binaries,
it allows comptime as well as runtime access to the compressed assets
directly by passing a string.
The `output_file` can be added as a module to other compilations:

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

const assets = b.addModule("assets", .{
    .source_file = .{
        .generated = &assets.output_file,
    },
});
```

Now, the assets can be imported and accessed with their relative path to
the base directory:

```
const assets = @import("assets");
const path = "index.html";
if (assets.map().get(path)) |res| {
    return Response.render(r, path, res);
}
```

as modern browsers support `Content-Encoding` and the zig standard library has
built-in `Deflate`-Support, the content can be served without even decompressing
once on the server.

the result is a single static binary webserver serving
precompressed responses from memory ;-D.

the default example embeds the static built documentation of the 
build Library and serves them.

## Perspective?

As of now, only the `Content-Type` detection is done in terms of preprocessing.
