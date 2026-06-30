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

## Updating A Port Version

After changing a port, run the local helper from the registry root:

```powershell
.\registry_add_version.bat mlog
```

The script prints each step, stages `ports/<name>`, calculates the `git-tree`,
updates `versions/baseline.json` and `versions/<first-letter>-/<name>.json`,
and shows the staged diff summary.
