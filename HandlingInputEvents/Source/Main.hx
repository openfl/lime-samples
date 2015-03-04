package;


import lime.app.Application;
import lime.graphics.RenderContext;
import lime.math.Vector2;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import openfl.display.Sprite;
import openfl.display.Stage;

@:access(openfl.display.Stage)


class Main extends Application {
	
	
	private var down:Bool;
	private var left:Bool;
	private var right:Bool;
	private var up:Bool;
	
	private var mouseDown:Bool;
	
	private var box:Sprite;
	private var stage:Stage;
	private var targetPoint:Vector2;
	
	
	public function new () {
		
		super ();
		
		targetPoint = new Vector2 (-1, -1);
		
	}
	
	
	public override function init (context:RenderContext):Void {
		
		stage = new Stage (window.width, window.height, 0x000000);
		
		box = new Sprite ();
		box.graphics.beginFill (0xFF0000);
		box.graphics.drawRect (0, 0, 100, 100);
		box.x = (window.width - box.width) / 2;
		box.y = (window.height - box.height) / 2;
		
		stage.addChild (box);
		
	}
	
	
	public override function onKeyDown (key:KeyCode, modifier:KeyModifier):Void {
		
		switch (key) {
			
			case LEFT: left = true;
			case RIGHT: right = true;
			case UP: up = true;
			case DOWN: down = true;
			default:
			
		}
		
	}
	
	
	public override function onKeyUp (key:KeyCode, modifier:KeyModifier):Void {
		
		switch (key) {
			
			case LEFT: left = false;
			case RIGHT: right = false;
			case UP: up = false;
			case DOWN: down = false;
			default:
			
		};
		
	}
	
	
	public override function onMouseDown (x:Float, y:Float, button:Int):Void {
		
		mouseDown = true;
		
		targetPoint.x = x;
		targetPoint.y = y;
		
	}
	
	
	public override function onMouseMove (x:Float, y:Float, button:Int):Void {
		
		if (mouseDown) {
			
			targetPoint.x = x;
			targetPoint.y = y;
			
		}
		
	}
	
	
	public override function onMouseUp (x:Float, y:Float, button:Int):Void {
		
		mouseDown = false;
		
		targetPoint.x = -1;
		targetPoint.y = -1;
		
	}
	
	
	public override function onTouchEnd (x:Float, y:Float, id:Int):Void {
		
		mouseDown = false;
		
		targetPoint.x = -1;
		targetPoint.y = -1;
		
	}
	
	
	public override function onTouchMove (x:Float, y:Float, button:Int):Void {
		
		if (mouseDown) {
			
			targetPoint.x = x;
			targetPoint.y = y;
			
		}
		
	}
	
	
	public override function onTouchStart (x:Float, y:Float, id:Int):Void {
		
		mouseDown = true;
		
		targetPoint.x = x;
		targetPoint.y = y;
		
	}
	
	
	public override function onWindowResize (width:Int, height:Int):Void {
		
		stage.stageWidth = width;
		stage.stageHeight = height;
		
	}
	
	
	public override function render (context:RenderContext):Void {
		
		stage.__render (context);
		
	}
	
	
	public override function update (deltaTime:Int):Void {
		
		var speed = 0.5;
		
		if (targetPoint.x > -1 && targetPoint.y > -1) {
			
			var step = speed * deltaTime;
			var diffX = targetPoint.x - box.x;
			var diffY = targetPoint.y - box.y;
			
			if (Math.abs (diffX) < step) {
				
				box.x = targetPoint.x;
				
			} else {
				
				if (diffX > 0) {
					
					box.x += step;
					
				} else {
					
					box.x -= step;
					
				}
				
			}
			
			if (Math.abs (diffY) < step) {
				
				box.y = targetPoint.y;
				
			} else {
				
				if (diffY > 0) {
					
					box.y += step;
					
				} else {
					
					box.y -= step;
					
				}
				
			}
			
		}
		
		if (left) box.x -= (speed * deltaTime);
		if (right) box.x += (speed * deltaTime);
		if (up) box.y -= (speed * deltaTime);
		if (down) box.y += (speed * deltaTime);
		
	}
	
	
}