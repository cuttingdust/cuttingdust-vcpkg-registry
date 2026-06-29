# Cuttingdust vcpkg Registry

This repository is a custom vcpkg git registry for Cuttingdust C++ libraries.

## Packages

- `mlog` 0.1.0

## Consumer Usage

Add `vcpkg-configuration.json` next to your project's `vcpkg.json`:

```json
{
	"default-registry": {
		"kind": "git",
		"repository": "https://github.com/microsoft/vcpkg",
		"baseline": "<builtin-baseline>"
	},
	"registries": [
		{
			"kind": "git",
			"repository": "https://github.com/cuttingdust/cuttingdust-vcpkg-registry.git",
			"baseline": "<registry-commit-sha>",
			"packages": [ "mlog" ]
		}
	]
}
```

Then declare the dependency in `vcpkg.json`:

```json
{
	"dependencies": [ "mlog" ]
}
```

Use the installed CMake package:

```cmake
find_package(MLog CONFIG REQUIRED)
target_link_libraries(my_app PRIVATE MLog::MLog)
```
