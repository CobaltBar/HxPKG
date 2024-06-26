# hxpkg

Installs packages locally from a `.hxpkg` file

Inspired by [hmm](https://github.com/andywhite37/hmm)

## Installation

`haxelib --global install hxpkg && haxelib --global run hxpkg setup`

## Usage

- `hxpkg [command] [options]`

### Commands

- `hxpkg install` - Installs all packages
- `hxpkg add` - Adds a package (Add multiple by seperating with commas)
- `hxpkg remove` - Removes a package (Add multiple by seperating with commas)
- `hxpkg clear` - Removes all packages

### Options

- `--quiet' - Silent Installation
- `--verbose` - Verbose Installation
- `--force` - Install packages even if a local haxelib repository (.haxelib) exists

### Credits

- Cobalt Bar (Main Developer)
