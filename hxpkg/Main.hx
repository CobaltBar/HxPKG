package hxpkg;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

using StringTools;

typedef HxPKGFile = Array<PKG>;

typedef PKG =
{
	var name:String;
	@:optional var version:String;
	@:optional var link:String;
	@:optional var branch:String;
	@:optional var hash:String;
}

class Main
{
	static final validFlags:Map<String, Array<String>> = [
		'install' => ['--global', '--quiet', '--force'],
		'add' => ['--beautify'],
		'remove' => ['--beautify'],
		'uninstall' => ['--remove-all', '--quiet'],
	];

	static function main()
	{
		var oldArgs = Sys.args();
		Sys.setCwd(oldArgs.pop());

		if (!oldArgs.contains('--quiet'))
			if (oldArgs.contains('--no-color'))
				Sys.println(" _   _        ____   _  __ ____ \n| | | |__  __|  _ \\ | |/ // ___|\n| |_| |\\ \\/ /| |_) || ' /| |  _ \n|  _  | >  < |  __/ | . \\| |_| |\n|_| |_|/_/\\_\\|_|    |_|\\_\\\\____|\n");
			else
				Sys.println("\033[38;5;208m _   _       \033[38;5;33m ____  \033[38;5;33m _  __\033[38;5;33m ____ \n\033[38;5;208m| | | |\033[38;5;202m__  __\033[38;5;33m|  _ \\ \033[38;5;33m| |/ /\033[38;5;33m/ ___|\n\033[38;5;208m| |_| |\033[38;5;202m\\ \\/ /\033[38;5;33m| |_) |\033[38;5;33m| ' /\033[38;5;33m| |  _ \n\033[38;5;208m|  _  |\033[38;5;202m >  < \033[38;5;33m|  __/ \033[38;5;33m| . \\\033[38;5;33m| |_| |\n\033[38;5;208m|_| |_|\033[38;5;202m/_/\\_\\\033[38;5;33m|_|    \033[38;5;33m|_|\\_\\\033[38;5;33m\\____|\033[0;0m\n");

		var args:Array<String> = [];
		var flags:Array<String> = [];

		for (arg in oldArgs)
		{
			arg = arg.trim();

			if (arg.startsWith('--'))
			{
				arg = arg.toLowerCase();
				if (arg == '--no-color')
					continue;
				flags.push(arg);
			}
			else
				args.push(arg);
		}

		if (args.length == 0)
		{
			Sys.println('Not enough arguments. Run `haxelib run hxpkg help` for help');
			return;
		}

		var cmd = args.shift();
		if (validFlags.exists(cmd))
			for (flag in flags)
				if (!validFlags[cmd].contains(flag))
					Sys.println('WARN: Unsupported flag for $cmd: $flag');

		switch (cmd.toLowerCase())
		{
			case 'install':
				install(args, flags.contains('--global'), flags.contains('--quiet'), flags.contains('--force'));
			case 'add':
				add(args, flags.contains('--beautify'));
			case 'remove':
				remove(args, flags.contains('--beautify'));
			case 'clear':
				clear();
			case 'uninstall':
				uninstall(args, flags.contains('--remove-all'), flags.contains('--quiet'));
			case 'list':
				list();
			case 'help':
				Sys.println("Usage: haxelib run hxpkg [command] [options]

Commands:

haxelib run hxpkg install - Installs all packages from the .hxpkg file
haxelib run hxpkg add - Adds a package to the .hxpkg file (Add multiple by seperating with commas)
	haxelib run hxpkg add [name] [version/git link] [branch name/git hash]
haxelib run hxpkg remove - Removes a package from the .hxpkg file
haxelib run hxpkg clear - Removes all packages from the .hxpkg file
haxelib run hxpkg uninstall - Removes all packages installed by the .hxpkg file
	NOTE: Does not remove dependencies
haxelib run hxpkg list - Lists all packages in the .hxpkg file
haxelib run hxpkg help - Shows help information

Options:

--no-color: Disables Color Printing
--quiet: Silent Install/Uninstall

install:
	--global: Installs packages globally
	--quiet: Silent Install
	--force: Installs even if .haxelib exists
add, remove:
	--beautify: Formats the .hxpkg file
uninstall:
	--remove-all: Removes the local repo
	--quiet: Silent Uninstall");
			default:
				Sys.println('WARN: $cmd is not a valid command. Run `haxelib run hxpkg help` for help');
		}
	}

	static function install(args:Array<String>, global:Bool, quiet:Bool, force:Bool):Void
	{
		if (!HxPKG())
		{
			Sys.println('.hxpkg does not exist, aborting.');
			return;
		}

		var content = File.getContent('.hxpkg').trim();
		if (content == '')
			content = '[]';
		var hxpkgFile:HxPKGFile = Json.parse(content);

		if (!global)
			if (Haxelib())
				if (!force)
				{
					Sys.println('.haxelib exists, aborting. (Run with --force to continue anyway)');
					return;
				}
				else
				{
					if (!quiet)
						Sys.println('.haxelib exists, continuing (--force)');
				}
			else
			{
				var proc = new Process('haxelib', ['newrepo', '--quiet']);
				proc.stdout.readAll();
				proc.exitCode();
			}

		if (quiet)
			Sys.print('Installing package${if (hxpkgFile.length > 1) 's' else ''} ${[for (pkg in hxpkgFile) pkg.name].join(', ')}... ');

		var failedPackages:Array<String> = [];
		for (pkg in hxpkgFile)
		{
			if (!quiet)
				Sys.print('Installing package ${pkg.name}... ');

			var hxargs:Array<String> = [];
			var failMsg = '';
			if (pkg.link == null)
			{
				hxargs.push('install');
				hxargs.push(pkg.name);
				if (pkg.version != null)
					hxargs.push(pkg.version);
				failMsg = 'Check haxelib.';
			}
			else
			{
				hxargs.push('git');
				hxargs.push(pkg.name);
				hxargs.push(pkg.link);
				if (pkg.hash != null)
					hxargs.push(pkg.hash);
				else if (pkg.branch != null)
					hxargs.push(pkg.branch);
				failMsg = 'Check the github repository.';
			}

			if (global)
				hxargs.unshift('--global');

			var proc = new Process('haxelib', hxargs.concat(['--never', '--skip-dependencies', '--quiet']));
			proc.stdout.readAll(); // WHY DOES THIS FIX IT??

			if (proc.exitCode() != 0)
			{
				if (!quiet)
					Sys.println('failed. $failMsg');
				failedPackages.push(pkg.name);
			}
			else
			{
				if (!quiet)
					Sys.println('done.');
			}
		}

		if (failedPackages.length > 0)
		{
			if (quiet)
				Sys.println('failed.');
			Sys.println('Failed to install ${[for (pkg in failedPackages) pkg].join(', ')}.');
		}
		else
		{
			if (quiet)
				Sys.println('done.');
		}
	}

	static function add(args:Array<String>, beautify:Bool):Void
	{
		if (!HxPKG())
			File.saveContent('.hxpkg', '[]');

		var content = File.getContent('.hxpkg').trim();
		if (content == '')
			content = '[]';
		var hxpkgFile:HxPKGFile = Json.parse(content);

		var map:Map<String, PKG> = [for (pkg in hxpkgFile) pkg.name => pkg];

		// https://stackoverflow.com/questions/3809401/what-is-a-good-regular-expression-to-match-a-url
		final urlMatch = new EReg('https?:\\/\\/(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b([-a-zA-Z0-9()@:%_\\+.~#?&//=]*)', 'i');

		// Thank you ChatGPT
		final hashMatch = ~/\b[0-9a-f]{40}\b/;

		for (pkg in [for (arg in args.join(" ").split(",")) arg.trim().split(" ")])
		{
			if (map.exists(pkg[0]))
			{
				Sys.println('Package ${pkg[0]} already exists in the .hxpkg. Continuing...');
				continue;
			}

			if (pkg.length >= 3)
				if (hashMatch.match(pkg[2]))
					hxpkgFile.push({
						name: pkg[0],
						link: pkg[1],
						hash: pkg[2]
					});
				else
					hxpkgFile.push({
						name: pkg[0],
						link: pkg[1],
						branch: pkg[2]
					});
			else
			{
				if (pkg[1] == null)
					hxpkgFile.push({
						name: pkg[0]
					});
				else
				{
					if (urlMatch.match(pkg[1]))
						hxpkgFile.push({
							name: pkg[0],
							link: pkg[1]
						});
					else
						hxpkgFile.push({
							name: pkg[0],
							version: pkg[1]
						});
				}
			}
			Sys.println('Added package ${pkg[0]} to .hxpkg.');
		}

		if (beautify)
			File.saveContent('.hxpkg', Json.stringify(hxpkgFile, null, '\t'));
		else
			File.saveContent('.hxpkg', Json.stringify(hxpkgFile));
	}

	static function remove(args:Array<String>, beautify:Bool):Void
	{
		if (!HxPKG())
			File.saveContent('.hxpkg', '[]');

		var content = File.getContent('.hxpkg').trim();
		if (content == '')
			content = '[]';
		var hxpkgFile:HxPKGFile = Json.parse(content);

		var map:Map<String, PKG> = [for (pkg in hxpkgFile) pkg.name => pkg];

		for (pkg in args)
			if (map.exists(pkg))
			{
				Sys.println('Removed package ${pkg} from .hxpkg.');
				hxpkgFile.remove(map[pkg]);
			}
			else
				Sys.println('Package $pkg does not exist in the .hxpkg.');

		if (beautify)
			File.saveContent('.hxpkg', Json.stringify(hxpkgFile, null, '\t'));
		else
			File.saveContent('.hxpkg', Json.stringify(hxpkgFile));
	}

	static function clear():Void
	{
		File.saveContent('.hxpkg', '[]');
		Sys.println('Cleared all packages from the .hxpkg file.');
	}

	static function uninstall(args:Array<String>, removeAll:Bool, quiet:Bool):Void
	{
		if (!Haxelib())
		{
			Sys.println('.haxelib does not exist, aborting.');
			return;
		}

		if (!HxPKG())
		{
			Sys.println('.hxpkg does not exist, aborting.');
			return;
		}

		if (removeAll)
		{
			var proc = new Process('haxelib', ['deleterepo', '--quiet']);
			proc.stdout.readAll();
			proc.exitCode();
			Sys.println('Uninstalled all packages successfully.');
		}
		else
		{
			var content = File.getContent('.hxpkg').trim();
			if (content == '')
				content = '[]';
			var hxpkgFile:HxPKGFile = Json.parse(content);

			var failedPackages:Array<String> = [];
			for (pkg in hxpkgFile)
			{
				if (!quiet)
					Sys.print('Uninstalling package ${pkg.name}... ');
				var proc = new Process('haxelib', ['remove', pkg.name, '--never', '--quiet']);
				proc.stdout.readAll(); // WHY DOES THIS FIX IT??
				var exitCode = proc.exitCode();
				if (exitCode != 0)
				{
					if (!quiet)
						Sys.println('failed.');
					failedPackages.push(pkg.name);
				}
				else
				{
					if (!quiet)
						Sys.println('done.');
				}
			}

			if (failedPackages.length > 0)
				Sys.println('Failed to uninstall ${[for (pkg in failedPackages) pkg].join(", ")}.');
			else
				Sys.println('Uninstalled all packages successfully.');
		}
	}

	static function list():Void
	{
		if (!HxPKG())
		{
			Sys.println('.hxpkg does not exist, aborting.');
			return;
		}

		var content = File.getContent('.hxpkg').trim();
		if (content == '')
			content = '[]';
		var hxpkgFile:HxPKGFile = Json.parse(content);

		for (pkg in hxpkgFile)
		{
			var msg = pkg.name;
			if (pkg.version != null)
				msg += ' - ${pkg.version}';
			else
			{
				if (pkg.link != null)
					msg += ' - ${pkg.link}';
				if (pkg.hash != null)
					msg += ' - ${pkg.hash}';
				else if (pkg.branch != null)
					msg += ' - ${pkg.branch}';
			}
			Sys.println(msg);
		}
	}

	static inline function HxPKG():Bool
		return FileSystem.exists('.hxpkg');

	static inline function Haxelib():Bool
		return FileSystem.exists('.haxelib');
}
