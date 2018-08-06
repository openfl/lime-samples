package;


import lime.app.Application;
import lime.graphics.RenderContext;
import lime.math.Vector2;
import lime.ui.Gamepad;
import lime.ui.GamepadAxis;
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
	
	
	public override function onGamepadAxisMove (gamepad:Gamepad, axis:GamepadAxis, value:Float):Void {
		
		switch (axis) {
			
			case GamepadAxis.LEFT_X:
				
				moveLeft = false;
				moveRight = false;
				
				trace (value);
				
				if (value < -0.1) {
					
					moveLeft = true;
					
				} else if (value > 0.1) {
					
					moveRight = true;
					
				}
			
			case GamepadAxis.LEFT_Y:
				
				moveUp = false;
				moveDown = false;
				
				trace (value);
				
				if (value < -0.1) {
					
					moveUp = true;
					
				} else if (value > 0.1) {
					
					moveDown = true;
					
				}
			
			default:
			
		}
		
	}
	
	
	public override function onGamepadConnect (gamepad:Gamepad):Void {
		
		trace ("Gamepad connected: " + gamepad.id + ", " + gamepad.name);
		
	}
	
	
	public override function onGamepadDisconnect (gamepad:Gamepad):Void {
		
		trace ("Gamepad disconnected: " + gamepad.id);
		
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