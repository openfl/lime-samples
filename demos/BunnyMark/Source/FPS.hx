package;


class FPS {
	
	
	public var current (get, null):Int;
	
	private var totalTime:Int;
	private var times:Array<Float>;
	
	
	public function new () {
		
		totalTime = 0;
		times = new Array ();
		
	}
	
	
	public function update (deltaTime:Int):Void {
		
		totalTime += deltaTime;
		times.push (totalTime);
		
	}
	
	
	
	
	// Get & Set Methods
	
	
	
	
	private function get_current ():Int {
		
		while (times[0] < totalTime - 1000) {
			
			times.shift ();
			
		}
		
		return times.length;
		
	}
	
	
}
