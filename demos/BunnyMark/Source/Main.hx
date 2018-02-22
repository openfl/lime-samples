package;


import lime.app.Application;
import lime.graphics.Image;
import lime.Assets;
import lime.ui.KeyCode;
import render.GLRenderer;


class Main extends Application {
	
	
	private var addingBunnies:Bool;
	private var bunnies:Array<Bunny>;
	private var fps:FPS;
	private var glRenderer:GLRenderer;
	private var gravity:Float;
	private var minX:Int;
	private var minY:Int;
	private var maxX:Int;
	private var maxY:Int;
	
	
	public function new () {
		
		super ();
		
		bunnies = new Array ();
		fps = new FPS ();
		
	}
	
	
	private function addBunny ():Void {
		
		var bunny = new Bunny ();
		bunny.x = 0;
		bunny.y = 0;
		bunny.speedX = Math.random () * 5;
		bunny.speedY = (Math.random () * 5) - 2.5;
		bunnies.push (bunny);
		
	}
	
	
	public override function onKeyDown (_, key:KeyCode, _):Void {
		
		if (key == KeyCode.SPACE) {
			
			trace ('${bunnies.length} bunnies @ ${fps.current} FPS');
			
		}
		
	}
	
	
	public override function onMouseDown (_, _, _, _):Void {
		
		addingBunnies = true;
		
	}
	
	
	public override function onMouseUp (_, _, _, _):Void {
		
		addingBunnies = false;
		
		trace ('${bunnies.length} bunnies @ ${fps.current} FPS');
		
	}
	
	
	public override function onPreloadComplete ():Void {
		
		minX = 0;
		maxX = window.width;
		minY = 0;
		maxY = window.height;
		gravity = 0.5;
		
		var image = Assets.getImage ("assets/wabbit_alpha.png");
		
		switch (renderer.context) {
			
			case OPENGL (gl):
				
				glRenderer = new GLRenderer (gl, image, window.width, window.height);
			
			default:
				
				throw "Unsupported render context";
			
		}
		
		var count = #if bunnies Std.parseInt (haxe.macro.Compiler.getDefine ("bunnies")) #else 100 #end;
		
		for (i in 0...count) {
			
			addBunny ();
			
		}
		
	}
	
	
	public override function render (_):Void {
		
		if (!preloader.complete) return;
		
		glRenderer.render ();
		
	}
	
	
	public override function update (deltaTime:Int):Void {
		
		for (bunny in bunnies) {
			
			bunny.x += bunny.speedX;
			bunny.y += bunny.speedY;
			bunny.speedY += gravity;
			
			if (bunny.x > maxX) {
				
				bunny.speedX *= -1;
				bunny.x = maxX;
				
			} else if (bunny.x < minX) {
				
				bunny.speedX *= -1;
				bunny.x = minX;
				
			}
			
			if (bunny.y > maxY) {
				
				bunny.speedY *= -0.8;
				bunny.y = maxY;
				
				if (Math.random () > 0.5) {
					
					bunny.speedY -= 3 + Math.random () * 4;
					
				}
				
			} else if (bunny.y < minY) {
				
				bunny.speedY = 0;
				bunny.y = minY;
				
			}
			
		}
		
		if (addingBunnies) {
			
			for (i in 0...30) {
				
				addBunny ();
				
			}
			
		}
		
		fps.update (deltaTime);
		
		if (glRenderer != null) {
			
			glRenderer.updateBuffer (bunnies);
			
		}
		
	}
	
	
}