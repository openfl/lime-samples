package;


import hxp.*;
import sys.FileSystem;


class Script extends hxp.Script {
	
	
	private var samples:Array<String>;
	
	
	public function new () {
		
		super ();
		
		samples = [];
		findSamples ("demos", samples);
		findSamples ("features/app", samples);
		findSamples ("features/graphics", samples);
		findSamples ("features/input", samples);
		findSamples ("features/media", samples);
		findSamples ("features/text", samples);
		
		switch (command) {
			
			case "list":
				
				listSamples ();
			
			case "build", "run", "test", "update", "clean", "display":
				
				execSamples ();
			
			default:
				
				Log.error ("Unkown command \"" + command + "\"");
			
		}
		
	}
	
	
	private function execSamples ():Void {
		
		var paths = [];
		
		if (commandArgs.length > 0) {
			
			var sampleName = commandArgs.shift ();
			
			for (sample in samples) {
				if (sample.split ("/").pop () == sampleName) {
					paths.push (sample);
				}
			}
			
			if (paths.length == 0) {
				for (sample in samples) {
					if (StringTools.startsWith (sample, sampleName)) {
						paths.push (sample);
					}
				}
			}
			
			if (paths.length == 0) {
				Log.error ("Could not find sample name \"" + sampleName + "\"");
			}
			
		} else {
			
			paths = paths.concat (samples);
			
		}
		
		var targets = null;
		
		if (commandArgs.length > 0) {
			
			targets = commandArgs;
			
		} else {
			
			var hostPlatform = switch (System.hostPlatform) {
				case WINDOWS: "windows";
				case MAC: "mac";
				case LINUX: "linux";
				default: "";
			}
			
			targets = [];
			if (!flags.exists ("noneko")) targets.push ("neko");
			if (!flags.exists ("noneko") && !flags.exists ("nocairo")) targets.push ("neko -Dcairo");
			if (!flags.exists ("noelectron")) targets.push ("electron");
			if (!flags.exists ("noelectron") && !flags.exists ("nocanvas")) targets.push ("electron -Dcanvas");
			if (!flags.exists ("noelectron") && !flags.exists ("nodom")) targets.push ("electron -dom");
			if (!flags.exists ("nocpp")) targets.push (hostPlatform);
			if (!flags.exists ("noflash")) targets.push ("flash");
			
		}
		
		for (path in paths) {
			
			var sampleName = path.split ("/").pop ();
			
			for (target in targets) {
				
				Log.info (Log.accentColor + "Running Sample: " + sampleName + " [" + target + "]" + Log.resetColor);
				
				var script = "lime";
				var args = [ command ];
				
				if (FileSystem.exists (Path.combine (path, "script.hx"))) {
					
					script = "hxp";
					args.push (Path.combine (path, "script.hx"));
					
				} else {
					
					args.push (path);
					
				}
				
				args = args.concat (target.split (" "));
				
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
				
				if (target == "flash" && targets.length > 0) {
					args.push ("-notrace");
				}
				
				System.runCommand ("", script, args);
				
			}
			
		}
		
	}
	
	
	private function findSamples (path:String, list:Array<String>):Void {
		
		for (fileName in FileSystem.readDirectory (path)) {
			
			var filePath = Path.combine (path, fileName);
			
			if (FileSystem.isDirectory (filePath)) {
				
				list.push (Path.standardize (filePath));
				
			}
			
		}
		
	}
	
	
	private function listSamples ():Void {
		
		for (sample in samples) {
			
			var sampleName = sample.split ("/").pop ();
			Log.println (Log.accentColor + sampleName + Log.resetColor + " (" + sample + ")");
			
		}
		
	}
	
	
}