# Zig Webterm


for now my demo repo for `https://gitlab.com/dasimmet/zbuild`.

### Self-Patching Zbuild

```
eval "$(zig build zbuild -- eval zig build --zig-lib-dir ../zig/lib zbuild --)"
zbuild zonupd ZBuild git+file://../zbuild
```