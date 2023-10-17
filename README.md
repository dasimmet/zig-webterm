# Zig Webterm


for now my demo repo for `https://gitlab.com/dasimmet/zbuild`.

### Self-Patching Zbuild

```
zig build --zig-lib-dir ../zig/lib zbuild -- zonupd ZBuild "$(cd ../zbuild; zig build zbuild -- zonurl zbuild)"
```