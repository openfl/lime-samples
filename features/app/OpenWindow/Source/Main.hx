package;


import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.Window;


class Main extends Application {
	
	
	public function new () {
		
		super ();
		
		
		
	}
	
	
	private function newWindow ():Void {
		
		var attributes = {
			
			title: "OpenWindow",
			width: 500,
			height: 400,
			
			context: {
				background: Math.round (Math.random () * 0xFFFFFF)
			}
			
		};
		
		var window = createWindow (attributes);
		
		if (window != null) {
			
			window.onMouseDown.add (onMouseDown);
			window.onRender.add (renderWindow.bind (window));
			
		}
		
	}
	
	
	public override function onMouseDown (x:Float, y:Float, button:Int):Void {
		
		#if desktop
		newWindow ();
		#end
		
	}
	
	
	public override function render (context:RenderContext):Void {
		
		renderWindow (window, context);
		
	}
	
	
	private function renderWindow (window:Window, context:RenderContext):Void {
		
		switch (context.type) {
			
			case CAIRO:
				
				var cairo = context.cairo;
				
				var r = ((context.attributes.background >> 16) & 0xFF) / 0xFF;
				var g = ((context.attributes.background >> 8) & 0xFF) / 0xFF;
				var b = (context.attributes.background & 0xFF) / 0xFF;
				
				cairo.setSourceRGB (r, g, b);
				cairo.paint ();
			
			case CANVAS:
				
				var ctx = context.canvas2D;
				
				ctx.fillStyle = "#" + StringTools.hex (context.attributes.background, 6);
				ctx.fillRect (0, 0, window.width, window.height);
			
			case FLASH:
				
				var sprite = context.flash;
				
				sprite.graphics.beginFill (context.attributes.background);
				sprite.graphics.drawRect (0, 0, window.width, window.height);
			
			case OPENGL, OPENGLES, WEBGL:
				
				var gl = context.webgl;
				
				var r = ((context.attributes.background >> 16) & 0xFF) / 0xFF;
				var g = ((context.attributes.background >> 8) & 0xFF) / 0xFF;
				var b = (context.attributes.background & 0xFF) / 0xFF;
				
				gl.clearColor (r, g, b, 1);
				gl.clear (gl.COLOR_BUFFER_BIT);
			
			default:
			
		}
		
	}
	
	
}