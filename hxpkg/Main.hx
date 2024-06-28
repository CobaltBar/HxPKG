package hxpkg;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

using StringTools;

typedef HxPKGFile = Array<PKGInfo>;

typedef PKGInfo =
{
	var name:String;
	var version:String;
	var link:String;
	var branch:String;
}

typedef InstallConfig =
{
	config:Int,
	info:PKGInfo
};

class Main
{
	static var quiet:Bool = false;

	static function main()
	{
		var args = Sys.args();
		args.pop();

		quiet = args.contains('--quiet');

		if (!quiet)
			Sys.println("\033[38;5;208m _   _       \033[38;5;33m ____  \033[38;5;33m _  __\033[38;5;33m ____ \n\033[38;5;208m| | | |\033[38;5;202m__  __\033[38;5;33m|  _ \\ \033[38;5;33m| |/ /\033[38;5;33m/ ___|\n\033[38;5;208m| |_| |\033[38;5;202m\\ \\/ /\033[38;5;33m| |_) |\033[38;5;33m| ' /\033[38;5;33m| |  _ \n\033[38;5;208m|  _  |\033[38;5;202m >  < \033[38;5;33m|  __/ \033[38;5;33m| . \\\033[38;5;33m| |_| |\n\033[38;5;208m|_| |_|\033[38;5;202m/_/\\_\\\033[38;5;33m|_|    \033[38;5;33m|_|\\_\\\033[38;5;33m\\____|\033[0;0m\n");

		switch (args[0])
		{
			case 'install':
				if (!FileSystem.exists('.hxpkg'))
				{
					Sys.println('.hxpkg does not exist, aborting install.');
					return;
				}

				var hxpkgFile:HxPKGFile = Json.parse(File.getContent('.hxpkg'));

				if (FileSystem.exists('.haxelib'))
					if (!args.contains('--force'))
					{
						Sys.println('Local haxelib repository (.haxelib) exists, aborting install.');
						return;
					}
					else
						Sys.println('Local haxelib repository (.haxelib) exists, continuing (--force)');
				else
					new Process('haxelib', ['newrepo']).exitCode();

				if (quiet)
					Sys.println('Installing packages ${[for (pkg in hxpkgFile) pkg.name].join(", ")}');

				var failedPackages:Array<String> = installPKGs([for (pkg in hxpkgFile) {config: pkg.link == null ? 0 : 1, info: pkg}]);
				if (failedPackages.length > 0)
					Sys.println('Failed to install ${[for (pkg in failedPackages) pkg].join(", ")}');
			case 'add':
				var hxpkgFile:HxPKGFile;
				if (!FileSystem.exists('.hxpkg'))
				{
					File.write('.hxpkg').close();
					hxpkgFile = [];
				}
				else
					hxpkgFile = Json.parse(File.getContent('.hxpkg'));

				args.shift();

				if (args.length < 1)
				{
					Sys.println('Not enough arguments. Run `hxpkg help`');
					return;
				}

				var map:Map<String, Int> = [for (i in 0...hxpkgFile.length) hxpkgFile[i].name => i];

				for (pkg in [for (arg in args.join(" ").split(",")) arg.trim().split(" ")])
				{
					if (map.exists(pkg[0]))
					{
						Sys.println('Package ${pkg[0]} already exists in the `.hxpkg` file. Continuing...');
						continue;
					}
					if (pkg[0] == '--beautify')
						continue;

					if (pkg.length == 3)
						hxpkgFile.push({
							name: pkg[0],
							version: null,
							link: pkg[1],
							branch: pkg[2]
						});
					else
					{
						var matches:Bool = new EReg("^(https?):\\/\\/[^\\s/$.?#].[^\\s]*$", "i").match(pkg[1] ?? '');
						hxpkgFile.push({
							name: pkg[0],
							version: matches ? pkg[1] : null,
							link: matches ? null : pkg[1],
							branch: null
						});
					}
				}

				File.saveContent('.hxpkg', Json.stringify(hxpkgFile, null, args.contains('--beautify') ? '\t' : null));
			case 'remove':
				var hxpkgFile:HxPKGFile;
				if (!FileSystem.exists('.hxpkg'))
				{
					File.write('.hxpkg').close();
					hxpkgFile = [];
				}
				else
					hxpkgFile = Json.parse(File.getContent('.hxpkg'));

				args.shift();

				if (args.length < 1)
				{
					Sys.println('Not enough arguments. Run `hxpkg help`');
					return;
				}

				var map:Map<String, Int> = [for (i in 0...hxpkgFile.length) hxpkgFile[i].name => i];

				for (pkg in args)
				{
					if (pkg == '--beautify')
						continue;
					if (map.exists(pkg))
						hxpkgFile.remove(hxpkgFile[map.get(pkg)]);
					else
						Sys.println('Package $pkg does not exist in the `.hxpkg` file');
				}

				File.saveContent('.hxpkg', Json.stringify(hxpkgFile, null, args.contains('--beautify') ? '\t' : null));
			case 'clear':
				File.saveContent('.hxpkg', Json.stringify('[]', null, args.contains('--beautify') ? '\t' : null));
			case 'uninstall':
				if (!FileSystem.exists('.haxelib'))
				{
					Sys.println('Local haxelib repository (.haxelib) does not exist, aborting uninstall.');
					return;
				}

				if (!FileSystem.exists('.hxpkg'))
				{
					Sys.println('.hxpkg does not exist, aborting install.');
					return;
				}

				var hxpkgFile:HxPKGFile = Json.parse(File.getContent('.hxpkg'));

				var failedPackages:Array<String> = uninstallPKGs([for (pkg in hxpkgFile) pkg.name]);
				if (failedPackages.length > 0)
					Sys.println('Failed to uninstall ${[for (pkg in failedPackages) pkg].join(", ")}');
			case 'help':
		}
	}

	static function installPKGs(pkgs:Array<InstallConfig>):Array<String>
	{
		var failedPackages:Array<String> = [];
		for (pkg in pkgs)
		{
			// There might be a bug involving the add command that adds a blank package called ""
			if (pkg.info.name.trim() == "")
				continue;

			if (!quiet)
				Sys.print('Installing package ${pkg.info.name}... ');
			var args:Array<String> = [];
			var failMsg:String = '';
			switch (pkg.config)
			{
				case 0:
					args.push('install');
					args.push(pkg.info.name);
					if (pkg.info.version != null)
						args.push(pkg.info.version);
					failMsg = 'Check haxelib.';
				case 1:
					args.push('git');
					args.push(pkg.info.name);
					args.push(pkg.info.link);
					if (pkg.info.branch != null)
						args.push(pkg.info.branch);
					failMsg = 'Check the github repository.';
			}
			var proc = new Process('haxelib', args);
			proc.stdout.readAll(); // For some reason this fixes a freezing issue
			var exitCode = proc.exitCode();
			Sys.print(exitCode != 0 ? 'failed. $failMsg\n' : !quiet ? 'done.\n' : '');
			if (exitCode != 0)
				failedPackages.push(pkg.info.name);
		}
		return failedPackages;
	}

	static function uninstallPKGs(pkgs:Array<String>):Array<String>
	{
		var failedPackages:Array<String> = [];
		for (pkg in pkgs)
		{
			if (pkg.trim() == "")
				continue;
			if (!quiet)
				Sys.print('Uninstalling package ${pkg}... ');
			var proc = new Process('haxelib', ['remove', pkg]);
			proc.stdout.readAll();
			var exitCode = proc.exitCode();
			Sys.print(exitCode != 0 ? 'failed.\n' : !quiet ? 'done.\n' : '');
			if (exitCode != 0)
				failedPackages.push(pkg);
		}
		return failedPackages;
	}
}
