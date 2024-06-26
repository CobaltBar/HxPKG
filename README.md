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
- `haxelib run hxpkg add` - Adds a package to the `.hxpkg` file (Add multiple by seperating with commas)
- `haxelib run hxpkg remove` - Removes a package from the `.hxpkg` file
- `haxelib run hxpkg clear` - Removes all packages from the `.hxpkg` file
- `haxelib run hxpkg uninstall` - Removes all packages installed by the `.hxpkg` file
  - NOTE: Does not remove dependencies
- `haxelib run hxpkg help` - Shows help information

### Options

- `--quiet` - (Used with `install`) Silent Installation
- `--force` - (Used with `install`) Install packages even if a local haxelib repository (.haxelib) exists
- `--beautify` - (Used with `add`, `remove` and `clear`) Formats the `.hxpkg` file

### Credits

- Cobalt Bar (Main Developer)
