# HxPKG

Installs packages locally from a `.hxpkg` file

Inspired by [hmm](https://github.com/andywhite37/hmm)

## Installation

- `haxelib --global install hxpkg` - Install HxPKG globally
- `haxelib run hxpkg install` - Install from `.hxpkg`

## Usage

- `haxelib run hxpkg [command] [options]`

### Commands

- `haxelib run hxpkg install` - Installs all packages from the `.hxpkg` file
- `haxelib run hxpkg add` - Adds a package to the .hxpkg file (Add multiple by seperating with commas)
  - `haxelib run hxpkg add [name] [version/git link] [branch name/git hash]`
- `haxelib run hxpkg remove` - Removes a package from the `.hxpkg` file
- `haxelib run hxpkg clear` - Removes all packages from the `.hxpkg` file
- `haxelib run hxpkg uninstall` - Removes all packages installed by the `.hxpkg` file
  - NOTE: Does not remove dependencies
- `haxelib run hxpkg list` - Lists all packages in the `.hxpkg` file
- `haxelib run hxpkg help` - Shows help information

### Options

- `--no-color`: Disables Color Printing
- `--quiet`: Silent Install/Uninstall

- `install`:
  - `--global`: Installs packages globally
  - `--quiet`: Silent Install
  - `--force`: Installs even if `.haxelib` exists
- `add`, `remove`:
  - `--beautify`: Formats the `.hxpkg` file
- `uninstall`:
  - `--remove-all`: Removes the local repo
  - `--quiet`: Silent Uninstall

### Credits

- Cobalt Bar (Main Developer)
