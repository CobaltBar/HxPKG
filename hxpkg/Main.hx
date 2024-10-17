package hxpkg;

import haxe.ds.ArraySort;
import haxe.io.Path;
import hxpkg.PKGFile;
import sys.io.File;
import sys.io.Process;

using StringTools;

class Main
{
	static final validFlags:Map<String, Array<String>> = [
		'install' => ['--global', '--force'],
		'add' => ['--beautify'],
		'remove' => ['--beautify'],
		'uninstall' => ['--remove-all'],
	];

	// https://stackoverflow.com/questions/3809401/what-is-a-good-regular-expression-to-match-a-url
	static final urlMatch = new EReg('https?:\\/\\/(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b([-a-zA-Z0-9()@:%_\\+.~#?&//=]*)', 'i');

	public static var quiet:Bool = false;

	static function main()
	{
		var parsed = Util.parseArgs();

		if (!quiet)
			Sys.println("\033[38;5;208m _   _       \033[38;5;33m ____  \033[38;5;33m _  __\033[38;5;33m ____ \n\033[38;5;208m| | | |\033[38;5;202m__  __\033[38;5;33m|  _ \\ \033[38;5;33m| |/ /\033[38;5;33m/ ___|\n\033[38;5;208m| |_| |\033[38;5;202m\\ \\/ /\033[38;5;33m| |_) |\033[38;5;33m| ' /\033[38;5;33m| |  _ \n\033[38;5;208m|  _  |\033[38;5;202m >  < \033[38;5;33m|  __/ \033[38;5;33m| . \\\033[38;5;33m| |_| |\n\033[38;5;208m|_| |_|\033[38;5;202m/_/\\_\\\033[38;5;33m|_|    \033[38;5;33m|_|\\_\\\033[38;5;33m\\____|\033[0;0m\n");

		var args:Array<String> = parsed[0];
		var flags:Array<String> = parsed[1];

		var cmd = args.shift().toLowerCase();
		if (validFlags.exists(cmd))
			for (flag in flags)
				if (!validFlags[cmd].contains(flag))
					Sys.println('Unsupported flag for $cmd command: $flag');

		switch (cmd)
		{
			case 'install':
				install(args, flags.contains('--global'), flags.contains('--force'));
			case 'add':
				add(args, flags.contains('--beautify'));
			case 'remove':
				remove(args, flags.contains('--beautify'));
			case 'clear':
				clear();
			case 'uninstall':
				uninstall(args, flags.contains('--force'), flags.contains('--remove-all'));
			case 'list':
				list();
			case 'update':
				Util.savePKGFile(Util.parsePKGFile(), flags.contains('--beautify'));
				Sys.println('.hxpkg updated');
			case 'help':
				help();
			default:
				Sys.println('$cmd is not a valid command. Run "haxelib run hxpkg help" for help');
		}
	}

	static function install(args:Array<String>, global:Bool, force:Bool):Void
	{
		Util.checkPKGFile(true);
		var pkgFile = Util.parsePKGFile();

		if (!global)
			if (Util.checkLocalHaxelib())
			{
				if (!force)
				{
					Sys.println('.haxelib exists, aborting (Run with --force to continue anyway)');
					Sys.exit(1);
				}
				else if (!quiet)
					Sys.println('.haxelib exists, continuing (--force)');
			}
			else
				Util.process('haxelib', ['--quiet', 'newrepo']);

		var pkgs = pkgFile["default"];

		for (arg in args)
			if (pkgFile.exists(arg.trim()))
				pkgs.concat(pkgFile[arg.trim()]);

		if (quiet)
			Sys.print('Installing package${pkgs.length > 1 ? 's' : ''} ${[for (pkg in pkgs) pkg.name].join(', ')}... \033[s');

		var failedPackages:Array<String> = [];

		for (i => pkg in pkgs)
		{
			if (!quiet)
				Sys.print('Installing package ${pkg.name}... \033[K\033[s');

			Sys.println('\033[u\n[' + ''.rpad('=', Std.int((i + 1) / pkgs.length * 40)).rpad('-', 40) + ']');

			var hxargs = ['--never', '--skip-dependencies', '--quiet'];
			if (global)
				hxargs.push('--global');
			var failMsg:String = null;

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
				if (pkg.branch != null)
					hxargs.push(pkg.branch);
				failMsg = 'Check the github repository.';
			}

			if (Util.process('haxelib', hxargs) != 0)
			{
				if (!quiet)
					Sys.println('\033[ufailed. $failMsg');
				failedPackages.push(pkg.name);
			}
			else if (!quiet)
				Sys.println('\033[udone.');
		}

		if (failedPackages.length > 0)
		{
			if (quiet)
				Sys.println('\033[ufailed.');
			Sys.println('Failed to install ${[for (pkg in failedPackages) pkg].join(', ')}.');
		}
		else if (quiet)
			Sys.println('\033[udone.');

		// git HXCPP auto setup
		if ([
			for (pkg in pkgs)
				if (pkg.name == 'hxcpp' && pkg.link != null && !failedPackages.contains('hxcpp')) pkg
		].length > 0)
		{
			Sys.print('\033[KSetting up hxcpp... ');
			var curCwd = Sys.getCwd();
			var pathProc = new Process('haxelib', ['libpath', 'hxcpp']);
			pathProc.exitCode();
			var path = pathProc.stdout.readAll().toString().trim();
			pathProc.close();
			Sys.setCwd(Path.join([path, 'tools', 'run']));
			Util.process('haxe', ['compile.hxml']);
			Sys.setCwd(Path.join([path, 'tools', 'hxcpp']));
			Util.process('haxe', ['compile.hxml']);
			Sys.setCwd(curCwd);
			Sys.println('done.');
		}
	}

	static function add(args:Array<String>, beautify:Bool):Void
	{
		if (!Util.checkPKGFile())
			File.saveContent('.hxpkg', '[]');

		var pkgFile = Util.parsePKGFile();

		if (args.length == 0)
		{
			Sys.println('Not enough arguments. Run "haxelib run hxpkg help" for help');
			Sys.exit(1);
		}

		var profile:String = 'default';

		if (args.indexOf('profile') != -1)
		{
			if (args.indexOf('profile') + 1 >= args.length)
			{
				Sys.println('No profile specified, aborting');
				Sys.exit(1);
			}

			profile = args[args.indexOf('profile') + 1].trim();
			if (pkgFile[profile] == null)
				pkgFile.set(profile, []);
			args = args.splice(0, args.indexOf('profile'));
		}

		var packages = pkgFile[profile];
		if (profile != 'default')
			packages.concat(pkgFile['default']);

		final pkgMap = [for (pkg in packages) pkg.name => pkg];

		if (pkgMap.exists(args[0]))
		{
			Sys.println('Package ${args[0]} already exists in the .hxpkg, aborting');
			Sys.exit(1);
		}

		var pkg:PKG = {name: args[0]}

		if (args.length >= 3)
		{
			pkg.link = args[1];
			pkg.branch = args[2];
		}
		else if (args[1] != null)
		{
			if (urlMatch.match(args[1]))
				pkg.link = args[1];
			else
				pkg.version = args[1];
		}

		pkgFile[profile].push(pkg);
		Sys.println('Added package ${args[0]}${profile != null ? ' (profile $profile)' : ''} to .hxpkg');
		Util.savePKGFile(pkgFile, beautify);
	}

	static function remove(args:Array<String>, beautify:Bool):Void
	{
		Util.checkPKGFile(true);
		var pkgFile = Util.parsePKGFile();

		if (args.length == 0)
		{
			Sys.println('Not enough arguments. Run "haxelib run hxpkg help" for help');
			Sys.exit(1);
		}

		var profile:String = 'default';

		if (args.indexOf('profile') != -1)
		{
			if (args.indexOf('profile') + 1 >= args.length)
			{
				Sys.println('No profile specified, aborting');
				Sys.exit(1);
			}

			profile = args[args.indexOf('profile') + 1].trim();
			if (pkgFile[profile] == null)
				pkgFile.set(profile, []);
			args = args.splice(0, args.indexOf('profile'));
		}

		var packages = pkgFile[profile];
		if (profile != 'default')
			packages.concat(pkgFile['default']);

		final pkgMap = [for (pkg in packages) pkg.name => pkg];

		for (arg in args)
		{
			if (!pkgMap.exists(arg))
			{
				Sys.println('Package $arg doesn\'t exist in the .hxpkg, continuing');
				continue;
			}

			pkgFile[profile].remove(pkgMap[arg]);
			Sys.println('Removed package ${arg}${profile != 'default' ? ' (profile $profile)' : ''} from .hxpkg');
		}

		if (pkgFile[profile].length == 0)
			pkgFile.remove(profile);

		Util.savePKGFile(pkgFile, beautify);
	}

	static function clear():Void
	{
		File.saveContent('.hxpkg', '[]');
	}

	static function uninstall(args:Array<String>, force:Bool, removeAll:Bool):Void
	{
		if (!Util.checkLocalHaxelib())
			if (!force)
			{
				Sys.println('.haxelib exists, aborting (Run with --force to continue anyway)');
				Sys.exit(1);
			}
			else if (!quiet)
				Sys.println('.haxelib exists, continuing (--force)');

		Util.checkPKGFile(true);
		var pkgFile = Util.parsePKGFile();

		if (removeAll)
		{
			Util.process('haxelib', ['--quiet', 'deleterepo']);
			Sys.println('Uninstalled all packages successfully');
		}
		else
		{
			var profile:String = 'default';

			if (args.length > 0)
				profile = args[0].trim();

			var packages = pkgFile[profile];
			if (profile != 'default')
				packages.concat(pkgFile['default']);
			var failedPackages:Array<String> = [];
			for (pkg in packages)
			{
				if (!quiet)
					Sys.print('Uninstalling package ${pkg.name}... ');
				if (Util.process('haxelib', ['--never', '--quiet', 'remove', pkg.name]) != 0)
				{
					if (!quiet)
						Sys.println('failed.');
					failedPackages.push(pkg.name);
				}
				else if (!quiet)
					Sys.println('done. ');
			}

			if (failedPackages.length > 0)
				Sys.println('Failed to uninstall ${[for (pkg in failedPackages) pkg].join(", ")}.');
			else
				Sys.println('Uninstalled all packages successfully.');
		}
	}

	static function list():Void
	{
		Util.checkPKGFile(true);
		var pkgFile = Util.parsePKGFile();

		var allpkgs = [];
		for (pkgs in pkgFile)
			allpkgs = allpkgs.concat(pkgs);

		if (allpkgs.length == 0)
		{
			Sys.println('No packages to list, aborting');
			Sys.exit(1);
		}

		var msgs:Array<String> = [];

		for (profile => packages in pkgFile)
		{
			var msg = '$profile:\n';

			for (pkg in packages)
			{
				var pkgmsg = pkg.name;

				if (pkg.version != null)
					pkgmsg += ' ${pkg.version}';
				else if (pkg.link != null)
				{
					pkgmsg += ' ${pkg.link}';
					if (pkg.branch != null)
						pkgmsg += ' ${pkg.branch}';
				}

				msg += '$pkgmsg\n';
			}
			msgs.push(msg);
		}

		ArraySort.sort(msgs, (a, b) -> (a > b ? 1 : a < b ? -1 : 0));
		for (msg in msgs)
			Sys.println(msg);
	}

	static function help():Void
	{
		Sys.println("Usage: haxelib run hxpkg [command] [flags]

Commands:

haxelib run hxpkg install - Installs all packages from the .hxpkg file
haxelib run hxpkg add - Adds a package to the .hxpkg file
	haxelib run hxpkg add [name] [version/git link] [branch/hash] profile [profile]
    NOTE: Only name is required
haxelib run hxpkg remove - Removes a package from the .hxpkg file
haxelib run hxpkg clear - Removes all packages from the .hxpkg file
haxelib run hxpkg uninstall - Removes all packages installed by the .hxpkg file
	NOTE: Does not remove dependencies
haxelib run hxpkg list - Lists all packages in the .hxpkg file
haxelib run hxpkg update - Updates the .hxpkg file to the new format
	NOTE: Also happens when attempting to add a package profile in the old format
haxelib run hxpkg help - Shows help information

Flags:
--quiet: Silent Install/Uninstall
--force: Installs/Uninstalls even if .haxelib exists

install:
	--global: Installs packages globally
add, remove, update:
	--beautify: Formats the .hxpkg file
- uninstall:
	--remove-all: Removes the local repo");
	}
}
