package;


import lime.app.Application;
import lime.graphics.RenderContext;
import lime.math.Vector2;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.Touch;
import openfl.display.Sprite;
import openfl.display.Stage;


class Main extends Application {
	
	
	private var moveDown:Bool;
	private var moveLeft:Bool;
	private var moveRight:Bool;
	private var moveUp:Bool;
	private var square:Sprite;
	private var stage:Stage;
	private var targetPoint:Vector2;
	
	
	public function new () {
		
		super ();
		
	}
	
	
	public override function onKeyDown (key:KeyCode, modifier:KeyModifier):Void {
		
		switch (key) {
			
			case LEFT: moveLeft = true;
			case RIGHT: moveRight = true;
			case UP: moveUp = true;
			case DOWN: moveDown = true;
			default:
			
		}
		
	}
	
	
	public override function onKeyUp (key:KeyCode, modifier:KeyModifier):Void {
		
		switch (key) {
			
			case LEFT: moveLeft = false;
			case RIGHT: moveRight = false;
			case UP: moveUp = false;
			case DOWN: moveDown = false;
			default:
			
		};
		
	}
	
	
	public override function onMouseDown (x:Float, y:Float, button:Int):Void {
		
		if (targetPoint == null) {
			
			targetPoint = new Vector2 ();
			
		}
		
		targetPoint.x = x;
		targetPoint.y = y;
		
	}
	
	
	public override function onMouseMove (x:Float, y:Float):Void {
		
		if (targetPoint != null) {
			
			targetPoint.x = x;
			targetPoint.y = y;
			
		}
		
	}
	
	
	public override function onMouseUp (x:Float, y:Float, button:Int):Void {
		
		targetPoint = null;
		
	}
	
	
	public override function onTouchEnd (touch:Touch):Void {
		
		targetPoint = null;
		
	}
	
	
	public override function onTouchMove (touch:Touch):Void {
		
		if (targetPoint != null) {
			
			targetPoint.x = touch.x * window.width;
			targetPoint.y = touch.y * window.height;
			
		}
		
	}
	
	
	public override function onTouchStart (touch:Touch):Void {
		
		if (targetPoint == null) {
			
			targetPoint = new Vector2 ();
			
		}
		
		targetPoint.x = touch.x * window.width;
		targetPoint.y = touch.y * window.height;
		
	}
	
	
	public override function onWindowCreate ():Void {
		
		#if !flash
		
		stage = new Stage (window, 0xFFFFFF);
		square = new Sprite ();
		
		var fill = new Sprite ();
		fill.graphics.beginFill (0xBFFF00);
		fill.graphics.drawRect (0, 0, 100, 100);
		fill.x = -50;
		fill.y = -50;
		square.addChild (fill);
		
		square.x = window.width / 2;
		square.y = window.height / 2;
		stage.addChild (square);
		
		addModule (stage);
		
		#end
		
	}
	
	
	public override function update (deltaTime:Int):Void {
		
		if (moveLeft) square.x -= (0.6 * deltaTime);
		if (moveRight) square.x += (0.6 * deltaTime);
		if (moveUp) square.y -= (0.6 * deltaTime);
		if (moveDown) square.y += (0.6 * deltaTime);
		
		if (targetPoint != null) {
			
			square.x += (targetPoint.x - square.x) * (deltaTime / 300);
			square.y += (targetPoint.y - square.y) * (deltaTime / 300);
			
		}
		
	}
	
	
}