# Zig Webterm


for now my demo repo for `https://gitlab.com/dasimmet/zbuild`.

### Self-Patching Zbuild

```
ZBUILD="zig build --zig-lib-dir ../zig/lib zbuild --"
$ZBUILD zonupd ZBuild "$($ZBUILD zonurl ../zbuild)"
```