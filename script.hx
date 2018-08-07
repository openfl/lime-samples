import hxp.*;
import sys.FileSystem;

class Script extends hxp.Script {
	
	public function new () {
		
		super ();
		
		var paths = [];
		getPaths ("demos", paths);
		getPaths ("features/app", paths);
		getPaths ("features/graphics", paths);
		getPaths ("features/input", paths);
		getPaths ("features/media", paths);
		getPaths ("features/text", paths);
		
		if (command == "list") {
			
			for (path in paths) {
				Log.println (path);
			}
			
		} else if (command == "test") {
			
			if (commandArgs.length > 0) {
				var sampleName = commandArgs.shift ();
				var match = false;
				for (path in paths) {
					if (path.split ("/").pop () == sampleName) {
						paths = [ path ];
						match = true;
						break;
					}
				}
				if (!match) {
					paths = [];
					if (sampleName == "features") {
						getPaths ("features/app", paths);
						getPaths ("features/graphics", paths);
						getPaths ("features/input", paths);
						getPaths ("features/media", paths);
						getPaths ("features/text", paths);
					} else {
						getPaths (sampleName, paths);
					}
				}
			}
			
			var targets;
			if (commandArgs.length > 0) {
				targets = commandArgs;
			} else {
				var hostPlatform = switch (System.hostPlatform) {
					case WINDOWS: "windows";
					case MAC: "mac";
					case LINUX: "linux";
					default: "";
				}
				if (System.hostPlatform != MAC) {
					targets = [ "neko", "neko -Dcairo", "flash", hostPlatform, "electron", "electron -Dcanvas", "electron -Ddom" ];
				} else {
					targets = [ "neko", "neko -Dcairo", /*"flash", hostPlatform,*/ "electron", "electron -Dcanvas", "electron -Ddom" ];
				}
			}
			
			for (path in paths) {
				var sampleName = Path.standardize (path).split ("/").pop ();
				for (target in targets) {
					Log.info (Log.accentColor + "Running Sample: " + sampleName + " [" + target + "]" + Log.resetColor);
					if (FileSystem.exists (Path.combine (path, "script.hx"))) {
						if (target == "electron") continue; // TODO
						var args = [ "test", Path.combine (path, "script.hx") ].concat (target.split (" "));
						for (flag in flags.keys ()) {
							args.push ("-" + flag);
						}
						for (define in defines.keys ()) {
							args.push ("-D");
							if (defines.get (define) != "") {
								args.push (define + "=" + defines.get (define));
							} else {
								args.push (define);
							}
						}
						System.runCommand ("", "hxp", args);
					} else {
						var args = [ "test", path, ].concat (target.split (" "));
						for (flag in flags.keys ()) {
							args.push ("-" + flag);
						}
						for (define in defines.keys ()) {
							args.push ("-D");
							if (defines.get (define) != "") {
								args.push (define + "=" + defines.get (define));
							} else {
								args.push (define);
							}
						}
						if (target == "flash") args.push ("-notrace");
						System.runCommand ("", "lime", args);
					}
				}
			}
			
		} else {
			
			Log.error ("Unknown command");
			
		}
		
	}
	
	private function getPaths (directory:String, paths:Array<String>):Void {
		
		directory = Path.combine (Sys.getCwd (), directory);
		for (path in FileSystem.readDirectory (directory)) {
			path = Path.combine (directory, path);
			if (FileSystem.isDirectory (path)) {
				paths.push (Path.standardize (path));
			}
		}
		
	}
	
}