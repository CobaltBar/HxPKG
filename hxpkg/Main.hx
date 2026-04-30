package;

import hxpkg.PKGFile.PKG;
import prismcli.CLI;
import sys.io.File;

using StringTools;

class Main
{
	// https://stackoverflow.com/questions/3809401/what-is-a-good-regular-expression-to-match-a-url
	static final urlMatch = new EReg('https?:\\/\\/(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b([-a-zA-Z0-9()@:%_\\+.~#?&//=]*)', "i");

	public static function main():Void
	{
		var cli = new CLI("HxPKG", "Local haxelib package manager", "1.7.0");
		cli.addDefaults();
		cli.addFlag("quiet", "Silent run", ["--quiet", "-q"]);
		cli.addFlag("force", "Bypass local haxelib repository warning", ["--force", "-f"]);

		cli.addCommand("install", "Install all packages from the package manifest", cmd_install)
			.addArgument("package", "Package to install or update", String, true)
			.addFlag("global", "Install packages globally", ["--global", "-g"])
			.addFlag("update", "Update installed packages to package manifest versions", ["--update", "-u"], String)
			.addFlag("profile", "Install specific profiles (Comma-separated)", ["--profile", "-p"], String); // PrismCLI needs better narg support

		cli.addCommand("add", "Add a package to the package manifest", cmd_add)
			.addArgument("name", "Haxelib package name")
			.addArgument("version", "Haxelib version or git link", String, true)
			.addFlag("branch", "Branch or git hash", ["--branch", "-b"], String)
			.addFlag("profile", "Package profile", ["--profile", "-p"], String);

		cli.addCommand("remove", "Remove a package from the package manifest", cmd_remove);
		cli.addCommand("clear", "Clear package manifest", (_, _, _) -> File.saveContent(".hxpkg", "[]"));

		cli.addCommand("uninstall", "Uninstalls all packages listed in the package manifest (does **not** include dependencies)", cmd_uninstall)
			.addArgument("package", "Package to update", String, true)
			.addFlag("remove_all", "Remove local repository", ["--remove-all"]);

		cli.addCommand("list", "List all packages in the package repository", cmd_list);
		cli.addCommand("lock", "Lock all versions in the package manifest", cmd_lock);
		cli.addCommand("compact", "Compact the package manifest", cmd_compact);
		cli.addCommand("setup", "Set up the HxPKG command alias - Run \"haxelib --global run hxpkg setup\"", cmd_setup);

		cli.setDefaultCommand(cli.addCommand("help", "Shows this help description", (cli, _, _) -> cli.print(cli.help())));

		cli.run();
	}

	static function cmd_install(cli, args, flags:Map<String, Any>):Void
	{
		Util.checkPKGFile(true);
		var pkgFile = Util.parsePKGFile();

		var global:Bool = flags["global"] ?? false;
		var update:Bool = flags["update"] ?? false;
		var quiet:Bool = flags["quiet"] ?? false;
		var force:Bool = flags["force"] ?? false;

		var profileFlag:String = flags["profile"];

		if (!global && !update)
		{
			if (Util.hasLocalHaxelib())
			{
				if (!force)
				{
					Sys.println("Local repository exists, aborting");
					Sys.exit(1);
				}
				else if (!quiet)
				{
					Sys.println("Local repository exists, continuing");
				}
			}
			else
			{
				Util.process("haxelib", ["--quiet", "newrepo"]);
			}
		}

		var pkgs = pkgFile["default"];
		for (profile in profileFlag.split(","))
		{
			pkgs = pkgs.concat(pkgFile[profile.trim().toLowerCase()]);
		}

		if (quiet)
		{
			Sys.print('Installing package${pkgs.length > 1 ? 's' : ''} ${[for (pkg in pkgs) pkg.name].join(', ')}... ');
		}

		var failedPackages = [];
		for (i => pkg in pkgs)
		{
			if (update && checkPackageUpdate(pkg, quiet, global))
			{
				continue;
			}

			if (!quiet)
			{
				Sys.print('Installing package ${pkg.name}... ');
			}

			var hxargs = ["--quiet", "--skip-dependencies", pkg.link != null ? "--always" : "--never"];

			if (global)
			{
				hxargs.push("--global");
			}
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
				if (pkg.dir != null)
					hxargs.push(pkg.dir);
				failMsg = 'Check the github repository.';
			}

			if (Util.process('haxelib', hxargs) != 0)
			{
				if (!quiet)
					Sys.println('failed. $failMsg');
				failedPackages.push(pkg.name);
			}
			else if (!quiet)
				Sys.println('done.');
		}

		if (failedPackages.length > 0)
		{
			if (quiet)
				Sys.println('failed.');
			Sys.println('Failed to install ${[for (pkg in failedPackages) pkg].join(', ')}.');
		}
		else if (quiet)
			Sys.println('done.');
	}

	static function cmd_add(cli, args, flags):Void {}

	static function cmd_remove(cli, args, flags):Void {}

	static function cmd_uninstall(cli, args, flags):Void {}

	static function cmd_list(cli, args, flags):Void {}

	static function cmd_lock(cli, args, flags):Void {}

	static function cmd_compact(cli, args, flags):Void {}

	static function cmd_setup(cli, args, flags):Void {}

	// Helper functions
	static function checkPackageUpdate(pkg:PKG, quiet:Bool, global:Bool):Bool
	{
		if (!quiet)
		{
			Sys.print('Checking current version of ${pkg.name}... ');
		}

		var haxelibVersion:Null<String> = Util.getHaxelibVersion(pkg.name, global);
		if (haxelibVersion == null)
		{
			if (!quiet)
			{
				Sys.println("failed: Package not installed.");
			}
			return true;
		}

		var hash:Null<String> = null;
		var skippable = false;

		if (haxelibVersion == "git")
		{
			hash = Util.getGitHashForHaxelib(pkg.name, global);
			skippable = hash != null && hash == pkg.branch;
		}
		else
		{
			skippable = haxelibVersion == pkg.version;
		}

		if (skippable)
		{
			if (!quiet)
				Sys.println("done. Can be skipped.");
			return true;
		}

		if (!quiet)
		{
			Sys.println("done.");
		}

		return false;
	}
	/*
		class Main
		{

		public static var quiet:Bool = false;

		static function main()
		{
			var parsed = Util.parseArgs();

			if (!quiet)
				Sys.println("\033[38;5;208m _   _       \033[38;5;33m ____  \033[38;5;33m _  __\033[38;5;33m ____ \n\033[38;5;208m| | | |\033[38;5;202m__  __\033[38;5;33m|  _ \\ \033[38;5;33m| |/ /\033[38;5;33m/ ___|\n\033[38;5;208m| |_| |\033[38;5;202m\\ \\/ /\033[38;5;33m| |_) |\033[38;5;33m| ' /\033[38;5;33m| |  _ \n\033[38;5;208m|  _  |\033[38;5;202m >  < \033[38;5;33m|  __/ \033[38;5;33m| . \\\033[38;5;33m| |_| |\n\033[38;5;208m|_| |_|\033[38;5;202m/_/\\_\\\033[38;5;33m|_|    \033[38;5;33m|_|\\_\\\033[38;5;33m\\____|\033[0;0m\n");

			var args:Array<String> = parsed[0];
			var flags:Array<String> = parsed[1];
			if (args.length == 0)
			{
				Sys.println('Not enough arguments. Run "hxpkg help" for help');
				Sys.exit(1);
			}

			switch (cmd)
			{
				case 'install':
					install(args, flags.contains('--global'), flags.contains('--force'), flags.contains('--update'));
				case 'add':
					add(args);
				case 'remove':
					remove(args);
				case 'clear':
					clear();
				case 'uninstall':
					uninstall(args, flags.contains('--force'), flags.contains('--remove-all'));
				case 'list':
					list();
				case 'lock':
					lock(args);
				case 'upgrade':
					Util.savePKGFile(Util.parsePKGFile());
					Sys.println('.hxpkg updated');
				case 'compact':
					Util.savePKGFile(Util.parsePKGFile(), false);
					Sys.println('.hxpkg compacted');
				case 'setup':
					setupAlias();
				case 'help':
					help();
				default:
					Sys.println('$cmd is not a valid command. Run "hxpkg help" for help');
			}
		}

		static function add(args:Array<String>):Void
		{
			if (!Util.checkPKGFile())
				File.saveContent('.hxpkg', '[]');

			var pkgFile = Util.parsePKGFile();

			if (args.length == 0)
			{
				Sys.println('Not enough arguments. Run "hxpkg help" for help');
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
				if (args.length == 4)
					pkg.dir = args[3];
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
			Util.savePKGFile(pkgFile);
		}

		static function remove(args:Array<String>):Void
		{
			Util.checkPKGFile(true);
			var pkgFile = Util.parsePKGFile();

			if (args.length == 0)
			{
				Sys.println('Not enough arguments. Run "hxpkg help" for help');
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

			Util.savePKGFile(pkgFile);
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
						if (pkg.dir != null)
							pkgmsg += ' ${pkg.dir}';
					}

					msg += '$pkgmsg\n';
				}
				msgs.push(msg);
			}

			ArraySort.sort(msgs, (a, b) -> (a > b ? 1 : a < b ? -1 : 0));
			for (msg in msgs)
				Sys.println(msg);
		}

		static function lock(args:Array<String>):Void
		{
			Util.checkPKGFile(true);
			var pkgFile = Util.parsePKGFile();

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

			for (pkg in pkgFile[profile])
			{
				Sys.println('Locking ${pkg.name}');

				var haxelibVersion:Null<String> = Util.getHaxelibVersion(pkg.name);
				if (haxelibVersion != null)
				{
					if (haxelibVersion != 'git')
					{
						pkg.version = haxelibVersion;
					}
					else
					{
						var hash:Null<String> = Util.getGitHashForHaxelib(pkg.name);
						if (hash == null)
						{
							Sys.println('Failed to get git hash of ${pkg.name}');
							continue;
						}

						pkg.branch = hash;
					}
				}
				else
				{
					Sys.println('Package ${pkg.name} not installed - can\'t lock');
				}
			}

			Sys.println('Locked package versions');
			Util.savePKGFile(pkgFile);
		}

		/*
			Based on:
			https://github.com/openfl/hxp/blob/master/src/hxp/System.hx#L1505
			https://github.com/openfl/lime/blob/develop/tools/utils/PlatformSetup.hx#L812
		*\/
		static function setupAlias():Void
		{
			var sysName = Sys.systemName().toLowerCase();
			try
			{
				if (sysName.contains('window'))
				{
					var haxePath:String = Sys.getEnv('HAXEPATH').trim();
					if (haxePath == null || haxePath == '')
						haxePath = 'C:\\HaxeToolkit\\haxe';

					File.saveContent(Path.join([haxePath, 'hxpkg.bat']), '@echo off\nhaxelib --global run hxpkg %*');
				}
				else if (sysName.contains('linux') || sysName.contains('mac'))
				{
					Sys.command('${sysName.contains('mac') ? '' : 'sudo '}cp -f ${Path.join([Util.ogPath, 'hxpkg.sh'])} ${Path.join(["/usr/local/bin", 'hxpkg'])}');
					Sys.command('${sysName.contains('mac') ? '' : 'sudo '}chmod 775 ${Path.join(["/usr/local/bin", 'hxpkg'])}');
				}
				else
				{
					Sys.println('Installing the command line alias is not supported on this OS');
					Sys.exit(1);
				}

				// THANK YOU CYN
				Sys.println('Installed command-line alias "hxpkg" for "haxelib --global run hxpkg"');
			}
			catch (e)
			{
				Sys.println('Failed to install command-line alias');
				Sys.exit(1);
			}
		}
	 */
}
