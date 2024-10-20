package hxpkg;

import haxe.Http;
import haxe.Json;
import hxpkg.PKGFile;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

using StringTools;

@:publicFields
class Util
{
	static function checkPKGFile(abort:Bool = false):Bool
	{
		var exists = FileSystem.exists('.hxpkg');
		if (abort && !exists)
		{
			Sys.println('.hxpkg does not exist, aborting');
			Sys.exit(1);
		}
		return exists;
	}

	static function checkLocalHaxelib():Bool
		return FileSystem.exists('.haxelib');

	static function parsePKGFile():PKGFile
	{
		var pkgFile:Array<Dynamic> = null;

		try
		{
			pkgFile = Json.parse(File.getContent('.hxpkg'));
		}
		catch (e)
		{
			Sys.println('Invalid .hxpkg');
			Sys.exit(1);
		}

		var retPKG:PKGFile = [];

		if (pkgFile[0].profile == null) // Legacy Format
			retPKG.set('default', cast pkgFile);
		else
		{
			for (profile in (cast pkgFile : hxpkg.PKGFile.JSONPKGFile))
				retPKG.set(profile.profile, profile.pkgs);

			if (!retPKG.exists('default'))
			{
				Sys.println('Invalid .hxpkg');
				Sys.exit(1);
			}
		}

		return retPKG;
	}

	static function process(command:String, args:Array<String>):Int
	{
		var proc = new Process(command, args);
		proc.stdout.readAll();
		var code = proc.exitCode();
		proc.close();
		return code;
	}

	static function savePKGFile(pkgFile:PKGFile, beautify:Bool = true):Void
	{
		var json:JSONPKGFile = [];
		for (profile => pkgs in pkgFile)
			json.push({profile: profile, pkgs: pkgs});

		File.saveContent('.hxpkg', Json.stringify(json, null, beautify ? '\t' : null));
	}

	static function parseArgs():Array<Array<String>>
	{
		var args:Array<String> = [];
		var flags:Array<String> = [];

		var rawArgs = Sys.args();
		Sys.setCwd(rawArgs.pop());

		for (arg in rawArgs)
		{
			arg = arg.trim();

			if (arg.startsWith('--'))
			{
				arg = arg.toLowerCase();
				if (arg == '--quiet')
				{
					Main.quiet = true;
					continue;
				}
				flags.push(arg);
			}
			else
				args.push(arg);
		}

		return [args, flags];
	}

	static function getExceptions():Array<String>
	{
		var exceptions:Array<String> = [];
		var request = new Http('https://github.com/CobaltBar/HxPKG/blob/main/noskip');
		request.onError = (msg:String) -> {};
		request.onData = (data:String) -> exceptions = data.trim().split('\n');
		request.request();

		return exceptions;
	}
}
