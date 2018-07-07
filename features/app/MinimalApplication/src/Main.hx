package;


import lime.app.Application;
import lime.graphics.RenderContext;


class Main extends Application {
	
	
	public function new () {
		
		super ();
		
		#if native
		createWindow ({ width: 550, height: 400 });
		#elseif html5
		createWindow ({ width: 550, height: 400, element: js.Browser.document.getElementById ("content") });
		#end
		
	}
	
	
	public override function render (context:RenderContext):Void {
		
		switch (context.type) {
			
			case CAIRO:
				
				var cairo = context.cairo;
				
				cairo.setSourceRGB (0.75, 1, 0);
				cairo.paint ();
			
			case CANVAS:
				
				var ctx = context.canvas2D;
				
				ctx.fillStyle = "#BFFF00";
				ctx.fillRect (0, 0, window.width, window.height);
			
			case FLASH:
				
				var sprite = context.flash;
				
				sprite.graphics.beginFill (0xBFFF00);
				sprite.graphics.drawRect (0, 0, window.width, window.height);
			
			case OPENGL, OPENGLES, WEBGL:
				
				var gl = context.webgl;
				
				gl.clearColor (0.75, 1, 0, 1);
				gl.clear (gl.COLOR_BUFFER_BIT);
			
			default:
			
		}
		
	}
	
	
	public static function main () {
		
		var app = new Main ();
		return app.exec ();
		
	}
	
	
}