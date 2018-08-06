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
				targets = [ "neko", "flash", "linux", "electron" ];
			}
			
			for (path in paths) {
				var sampleName = Path.standardize (path).split ("/").pop ();
				for (target in targets) {
					Log.info (Log.accentColor + "Running Sample: " + sampleName + " [" + target + "]" + Log.resetColor);
					if (FileSystem.exists (Path.combine (path, "script.hx"))) {
						if (target == "electron") continue; // TODO
						var args = [ "test", Path.combine (path, "script.hx"), target ];
						for (flag in flags.keys ()) {
							args.push ("-" + flag);
						}
						System.runCommand ("", "hxp", args);
					} else {
						var args = [ "test", path, target ];
						for (flag in flags.keys ()) {
							args.push ("-" + flag);
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