import hxp.*;


class Script extends hxp.Script {
	
	
	private var target:String;
	
	
	public function new () {
		
		super ();
		
		if (commandArgs.length > 0) {
			
			target = commandArgs[0];
			
		} else {
			
			Log.error ("Expected \"hxp (build|run|test) (target)\"");
			
		}
		
		if (command == "build" || command == "test") {
			
			build ();
			
		}
		
		if (command == "run" || command == "test") {
			
			run ();
			
		}
		
	}
	
	
	private function build () {
		
		var base = new HXML ({
			cp: [ "src" ],
			libs: [ "lime" ],
			main: "Main",
			debug: true
		});
		
		switch (target) {
			
			case "air":
				
				var air = base.clone ();
				air.swf = "bin/air/application.swf";
				air.swfVersion = "19";
				air.define ("air");
				air.build ();
			
			case "flash":
				
				var flash = base.clone ();
				flash.swf = "bin/flash/application.swf";
				flash.swfVersion = "19";
				flash.build ();
			
			case "hl":
				
				var hl = base.clone ();
				hl.hl = "bin/hl/application.hl";
				hl.build ();
			
			case "html5":
				
				var html5 = base.clone ();
				html5.js = "bin/html5/application.js";
				html5.build ();
			
			case "linux":
				
				var linux = base.clone ();
				linux.cpp = "bin/linux";
				linux.build ();
			
			case "mac", "macos":
				
				var macos = base.clone ();
				macos.cpp = "bin/macos";
				macos.build ();
			
			case "neko":
				
				var neko = base.clone ();
				neko.neko = "bin/neko/application.n";
				neko.build ();
			
			case "windows":
				
				var linux = base.clone ();
				linux.cpp = "bin/windows";
				linux.build ();
			
			default:
				
				Log.error ("Unknown target \"" + target + "\"");
			
		}
		
	}
	
	
	private function run ():Void {
		
		switch (target) {
			
			case "air":
				
				var airSDK = Sys.getEnv ("AIR_SDK");
				if (airSDK == null) airSDK = System.hostPlatform == WINDOWS ? "C:\\Development\\AIR" : "~/Development/AIR";
				
				System.runCommand ("bin/air", airSDK + "/bin/adl", [ "application.xml" ]);
			
			case "flash":
				
				System.openFile ("bin/flash", "application.swf");
			
			case "hl":
				
				var ndll = new NDLL ("lime");
				ndll.haxelib = new Haxelib ("lime");
				var libraryPath = switch (System.hostPlatform) {
					case WINDOWS: NDLL.getLibraryPath (ndll, "Windows");
					case MAC: NDLL.getLibraryPath (ndll, "Mac64");
					case LINUX: NDLL.getLibraryPath (ndll, "Linux");
					default: null;
				}
				
				if (libraryPath != null) {
					System.copyFile (libraryPath, "bin/hl/lime.hdll");
				}
				
				var hlPath = Sys.getEnv ("HLPATH");
				System.runCommand ("bin/hl", Path.combine (hlPath, "hl"), [ "application.hl" ]);
			
			case "html5":
				
				PlatformTools.launchWebServer ("bin/html5");
			
			case "linux":
				
				var ndll = new NDLL ("lime");
				ndll.haxelib = new Haxelib ("lime");
				var libraryPath = NDLL.getLibraryPath (ndll, "Linux64");
				
				if (libraryPath != null) {
					System.copyFile (libraryPath, "bin/linux/lime.ndll");
				}
				
				System.runCommand ("bin/linux", "./Main-debug", []);
			
			case "mac", "macos":
				
				var ndll = new NDLL ("lime");
				ndll.haxelib = new Haxelib ("lime");
				var libraryPath = NDLL.getLibraryPath (ndll, "Mac64");
				
				if (libraryPath != null) {
					System.copyFile (libraryPath, "bin/macos/lime.ndll");
				}
				
				System.runCommand ("bin/macos", "./Main-debug", []);
			
			case "neko":
				
				System.runCommand ("bin/neko", "neko", [ "application.n" ]);
			
			case "windows":
				
				var ndll = new NDLL ("lime");
				ndll.haxelib = new Haxelib ("lime");
				var libraryPath = NDLL.getLibraryPath (ndll, "Windows");
				
				if (libraryPath != null) {
					System.copyFile (libraryPath, "bin/windows/lime.ndll");
				}
				
				System.runCommand ("bin/windows", "Main-debug.exe", []);
			
			default:
				
				Log.error ("Unknown target \"" + target + "\"");
			
		}
		
	}
	
	
}