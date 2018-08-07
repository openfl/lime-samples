package;

import lime.app.Application;
import lime.graphics.RenderContext;
import lime.math.Rectangle;
import lime.math.Vector2;
import lime.ui.Window;
import lime.graphics.Image;
// import lime.graphics.utils.ImageCanvasUtil;
import lime.utils.Assets;
import lime.utils.Log;

import haxe.Timer;

class Main extends Application {
	
	var lastTime:Float;
	var time:Float = 0.05;
	var swap:Bool = false;
	var spawnCells:Bool = false;
	
	var rule:String = '23/3'; // Conway's
	
	#if flash
	var src_bitmap:flash.display.Bitmap;
	var dest_bitmap:flash.display.Bitmap;
	#end
	
	var src_image:Image;
	var dest_image:Image;
	
	var scale:Float = 4.0;
	
	var bgColor:Int = 0x000000ff;
	var fgColor:Int = 0x70f409ff;
	
	var w:Int = 300;
	var h:Int = 200;
	
	public function new () {
		super ();
	}
	
	public override function onWindowCreate ():Void {
		
		src_image  = new Image(null, 0, 0, w, h, bgColor);
		dest_image = new Image(null, 0, 0, w, h, bgColor);
		
		switch (window.context.type) {
			
			case CANVAS:
				var ctx = window.context.canvas2D;
				ctx.fillStyle = "#" + StringTools.hex (window.context.attributes.background, 6);
				ctx.fillRect (0, 0, window.width, window.height);
			
			case DOM:
				var element = window.context.dom;
				element.style.backgroundColor = "#" + StringTools.hex (window.context.attributes.background, 6);
				element.style.margin = "auto";
				element.appendChild (src_image.src);
				
			case FLASH:
				#if flash
				var sprite = window.context.flash;
				dest_bitmap = new flash.display.Bitmap (dest_image.src);
				dest_bitmap.scaleX = dest_bitmap.scaleY = scale;
				sprite.addChild (dest_bitmap);
				
				src_bitmap = new flash.display.Bitmap (src_image.src);
				src_bitmap.scaleX = src_bitmap.scaleY = scale;
				sprite.addChild (src_bitmap);
				#end
				
			case OPENGL, OPENGLES, WEBGL:
				var gl = window.context.webgl;
				bgColor -= 255; // alpha reverse
				fgColor -= 255; // alpha reverse
				OpenglRender.init(gl, window.context.attributes.background, src_image, scale);
				
			default:
				
				Log.warn ("Current render context not supported by this sample");
		}
		
		CellAutomation.genRandomCells( src_image , 100, 80, bgColor, fgColor);
		CellAutomation.genRandomCells( src_image , 120, 85, bgColor, fgColor);
		CellAutomation.genRandomCells( src_image , 110, 90, bgColor, fgColor);
		
		lastTime = Timer.stamp();
	}	
	
	public override function onMouseDown (x:Float, y:Float, button:Int):Void {	
		CellAutomation.genRandomCells(src_image , x/scale, y/scale, bgColor, fgColor);
		CellAutomation.genRandomCells(dest_image, x/scale, y/scale, bgColor, fgColor);
	}	
	
	public override function render (context:RenderContext):Void {
		
		// not at full fps:
		if (Timer.stamp()-lastTime > time)
		{
			lastTime = Timer.stamp();
			
			// change cell automation rule randomly
			if (Math.random() < 0.1) rule = CellAutomation.getRandomRule();

			// calculate next state depending on prev state
			CellAutomation.nextLifeGeneration ( src_image, dest_image, rule, bgColor, fgColor, swap );
			swap = ! swap;
			
			switch (context.type) {
				case CANVAS:
					var ctx = context.canvas2D;
					ctx.imageSmoothingEnabled = false; // disable antialiasing 
					untyped ctx.mozImageSmoothingEnabled = false; // firefox hack
					untyped ctx.oImageSmoothingEnabled = false; // opera hack
					untyped ctx.webkitImageSmoothingEnabled = false; // safari hack
					untyped ctx.msImageSmoothingEnabled = false; // ie hack
					
					if (swap) {
						// ImageCanvasUtil.sync (src_image, true);
						ctx.drawImage (src_image.src , 0, 0, src_image.width  * scale, src_image.height  * scale);
					}
					else {
						// ImageCanvasUtil.sync (dest_image, true);
						ctx.drawImage (dest_image.src, 0, 0, dest_image.width * scale, dest_image.height * scale);
					}
				
				case DOM:
					var element = context.dom;
					element.removeChild(element.firstChild);
					var dom_image:Image = new Image(null, 0, 0, w, h, bgColor);
					if (swap) {
						// ImageCanvasUtil.sync (src_image, true);
						dom_image.copyPixels(src_image, new Rectangle(0, 0, w, h), new Vector2(0, 0) );
					}
					else {
						// ImageCanvasUtil.sync (dest_image, true);
						dom_image.copyPixels(dest_image, new Rectangle(0, 0, w, h), new Vector2(0, 0) );
					}
					// ImageCanvasUtil.resize(dom_image, Math.floor(w * scale), Math.floor(h * scale) );
					element.appendChild (dom_image.src);
					
				case FLASH:
					#if flash
					var sprite = context.flash;
					sprite.swapChildren(src_bitmap, dest_bitmap);
					#end
					
				case OPENGL, OPENGLES, WEBGL:
					var gl = context.webgl;
					if (swap)
						OpenglRender.changeTextureData(gl, src_image);
					else
						OpenglRender.changeTextureData(gl, dest_image);
						
				default:
			}
			
		}
		
		// OpenGl Draw (every frame):
		switch (context.type) {
			case OPENGL, OPENGLES, WEBGL:
				var gl = context.webgl;
				OpenglRender.render(gl, window.width, window.height);
			default:
		}
		
	}
	
	
}