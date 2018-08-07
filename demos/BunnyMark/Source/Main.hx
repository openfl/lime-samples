package;


import lime.app.Application;
import lime.graphics.Image;
import lime.graphics.RenderContext;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.utils.Assets;
import lime.utils.Log;
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
	
	
	public override function onKeyDown (key:KeyCode, modifier:KeyModifier):Void {
		
		if (key == KeyCode.SPACE) {
			
			trace ('${bunnies.length} bunnies @ ${fps.current} FPS');
			
		}
		
	}
	
	
	public override function onMouseDown (x:Float, y:Float, button:Int):Void {
		
		addingBunnies = true;
		
	}
	
	
	public override function onMouseUp (x:Float, y:Float, button:Int):Void {
		
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
		
		switch (window.context.type) {
			
			case OPENGL, OPENGLES, WEBGL:
				
				glRenderer = new GLRenderer (window.context.webgl, image, window.width, window.height);
			
			default:
				
				Log.warn ("Current render context not supported by this sample");
			
		}
		
		var count = #if bunnies Std.parseInt (haxe.macro.Compiler.getDefine ("bunnies")) #else 100 #end;
		
		for (i in 0...count) {
			
			addBunny ();
			
		}
		
	}
	
	
	public override function render (context:RenderContext):Void {
		
		if (!preloader.complete) return;
		
		if (glRenderer != null) glRenderer.render ();
		
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