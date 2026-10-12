# Release validation

Before creating, moving, or publishing a release tag, run this check from the repository root:

```sh
sh IJSVGExample/Scripts/check-release.sh
```

The script uses a fresh temporary build directory to compile the Swift package in Release mode and run its package tests. A failed check blocks release publication. Run it with normal system access so the shader tests can use Metal when available.

Also build the Xcode project and run tests appropriate to the changes. A successful Xcode framework build does not replace the package check: Xcode header maps can hide missing Swift Package Manager header search paths.

Validate the final source and package configuration before tagging. Keep the framework version and release tag consistent.
