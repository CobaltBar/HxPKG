package hxpkg;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

using StringTools;

typedef HxPKGFile = Array<
	{
		var name:String;
		var version:String;
		var link:String;
		var branch:String;
	}>

class Main
{
	static var verbose:Bool = false;
	static var quiet:Bool = false;

	static function main()
	{
		var args = Sys.args();
		args.pop();

		quiet = args.contains('--quiet');
		verbose = args.contains('--verbose');
		quiet = !verbose;
		verbose = !quiet;

		if (verbose || !quiet)
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
				{
					if (!args.contains('--force'))
					{
						Sys.println('Local haxelib repository (.haxelib) exists, aborting install.');
						return;
					}
					else
						Sys.println('Local haxelib repository (.haxelib) exists, continuing (--force)');
				}
				else
					new Process('haxelib', ['newrepo']);

				var failedPackages:Array<String> = [];

				if (quiet)
					Sys.println('Installing packages ${[for (pkg in hxpkgFile) pkg.name].join(", ")}');

				for (pkg in hxpkgFile)
				{
					if (verbose || !quiet)
						Sys.print('Installing package ${pkg.name}... ');
					if (pkg.link == null)
					{
						var arg = ['install', pkg.name, '--never'];
						if (pkg.version != null)
							arg.insert(2, pkg.version);
						if (!installPackage(arg, 'Check haxelib.'))
							failedPackages.push(pkg.name);
					}
					else
					{
						if (pkg.branch != null)
						{
							if (!installPackage(['git', pkg.name, pkg.link, pkg.branch, '--never'], 'Check the github repository.'))
								failedPackages.push(pkg.name);
						}
						else
						{
							if (!installPackage(['git', pkg.name, pkg.link, '--never'], 'Check the github repository.'))
								failedPackages.push(pkg.name);
						}
					}
				}

				Sys.println('Installed all packages successfully${failedPackages.length == 0 ? '.' : ' except ' + [for (pkg in failedPackages) pkg].join(", ")}');

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
				var urlRegex:EReg = new EReg("^(https?):\\/\\/[^\\s/$.?#].[^\\s]*$", "i");
				// theres probably a better way to do this
				for (pkg in [for (arg in args.join(" ").split(",")) arg.trim().split(" ")])
					if (pkg.length == 3)
						hxpkgFile.push({
							name: pkg[0],
							version: null,
							link: pkg[1],
							branch: pkg[2]
						});
					else
					{
						if (urlRegex.match(pkg[1] ?? ''))
							hxpkgFile.push({
								name: pkg[0],
								version: null,
								link: pkg[1],
								branch: null
							});
						else
							hxpkgFile.push({
								name: pkg[0],
								version: pkg[1],
								link: null,
								branch: null
							});
					}
				File.saveContent('.hxpkg', Json.stringify(hxpkgFile));
			case 'remove':

			case 'clear':
		}
	}

	static function installPackage(arg:Array<String>, failMsg:String):Bool
	{
		var proc = new Process('haxelib', arg);
		proc.stdout.readAll(); // For some reason this fixes a freezing issue
		Sys.print(proc.exitCode() != 0 ? 'failed. $failMsg\n' : (verbose || !quiet) ? 'done.\n' : '');
		return proc.exitCode() == 0;
	}
}
