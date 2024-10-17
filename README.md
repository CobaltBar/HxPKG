# HxPKG

Installs packages locally from a `.hxpkg` file

Inspired by [hmm](https://github.com/andywhite37/hmm)

## Installation

- `haxelib --global install hxpkg` - Install HxPKG globally
- `haxelib --global run hxpkg install` - Install from `.hxpkg`

## Usage

- `haxelib run hxpkg [command] [flags]`

### Commands

- `haxelib run hxpkg install` - Installs all packages from the `.hxpkg` file
- `haxelib run hxpkg add` - Adds a package to the .hxpkg file
  - `haxelib run hxpkg add [name] [version/git link] [branch/hash] profile [profile]`
    - NOTE: Only `name` is required
- `haxelib run hxpkg remove` - Removes a package from the `.hxpkg` file
- `haxelib run hxpkg clear` - Removes all packages from the `.hxpkg` file
- `haxelib run hxpkg uninstall` - Removes all packages installed by the `.hxpkg` file
  - NOTE: Does not remove dependencies
- `haxelib run hxpkg list` - Lists all packages in the `.hxpkg` file
- `haxelib run hxpkg update` - Updates the .hxpkg file to the new format
	- NOTE: Also happens when attempting to add a package profile in the old format
- `haxelib run hxpkg help` - Shows help information

### Flags

- `--quiet`: Silent Install/Uninstall
- `--force`: Installs/Uninstalls even if `.haxelib` exists

- `install`:
  - `--global`: Installs packages globally
- `add`, `remove`, `update`:
  - `--beautify`: Formats the `.hxpkg` file
- `uninstall`:
  - `--remove-all`: Removes the local repo

### Credits

- Cobalt Bar (Main Developer)
