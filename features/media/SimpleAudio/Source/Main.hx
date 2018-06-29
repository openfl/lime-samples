package;


import lime.app.Application;
import lime.graphics.RenderContext;
import lime.media.AudioSource;
import lime.utils.Assets;


class Main extends Application {
	
	
	private var ambience:AudioSource;
	private var sound:AudioSource;
	
	
	public function new () {
		
		super ();
		
	}
	
	
	public override function onMouseDown (x:Float, y:Float, button:Int):Void {
		
		if (sound != null) {
			
			sound.play ();
			
		}
		
	}
	
	
	public override function onPreloadComplete ():Void {
		
		#if !flash
		ambience = new AudioSource (Assets.getAudioBuffer ("assets/ambience.ogg"));
		ambience.play ();
		#end
		
		sound = new AudioSource (Assets.getAudioBuffer ("assets/sound.wav"));
		
	}
	
	
	public override function render (context:RenderContext):Void {
		
		switch (context.type) {
			
			case CAIRO:
				
				var cairo = context.cairo;
				
				cairo.setSourceRGB (60 / 255, 184 / 255, 7 / 255);
				cairo.paint ();
			
			case CANVAS:
				
				var ctx = context.canvas2D;
				
				ctx.fillStyle = "#3CB878";
				ctx.fillRect (0, 0, window.width, window.height);
			
			case DOM:
				
				var element = context.dom;
				
				element.style.backgroundColor = "#3CB878";
			
			case FLASH:
				
				var sprite = context.flash;
				
				sprite.graphics.beginFill (0x3CB878);
				sprite.graphics.drawRect (0, 0, window.width, window.height);
			
			case OPENGL, OPENGLES, WEBGL:
				
				var gl = context.webgl;
				
				gl.viewport (0, 0, window.width, window.height);
				gl.clearColor (60 / 255, 184 / 255, 7 / 255, 1);
				gl.clear (gl.COLOR_BUFFER_BIT);
				
			default:
			
		}
		
	}
	
	
}
