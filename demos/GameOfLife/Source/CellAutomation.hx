package ;

import lime.graphics.Image;

// coded by Sylvio Sell, 2014 rostock germany
// for algorithm look here: http://www.conwaylife.com/wiki/Cellular_automaton 

class CellAutomation
{
	// some Rules
	public static var cellRules = [
		'0/2',        // Live Free or Die
		'23/3',       // Conway's Game of Life :)
		'5/345',
		'23/36',      // HighLife
		'34/34',
		'023/3',
		'245/368',
		'245/368',
		'238/357',
		'1245/3',     // Mazetric
		'12345/3',    // Maze
		'1234/3',
		'1345/3',
		'1345/32',
		'45678/3',    // Coral
		'1358/357',	  // Amoeba
		'4567/345',
		'1357/1357',  // Replicator
		'2345/45678',
		'35678/4678',
		'34678/3678', // DayNight
		'02468/1357',
		'235678/378',
		'235678/3678'
	];
		
		
	public static function getRandomRule():String
	{
		return cellRules[ Math.floor(Math.random() * cellRules.length) ]; 
	}
	
	
	public static function genRandomCells(img:Image, posx:Float, posy:Float, bgColor:Int, fgColor:Int):Void {
		for (x in 0...10)
			for (y in 0...10)
				if (Math.random() > 0.5)
					img.setPixel32(Math.round(posx-5 + x), Math.round(posy-5 + y), fgColor);
	}
	
	
	// ------------------------------------------------------------------------------
	// ----------------------- algorythm for cell automation ------------------------
	// ------------------------------------------------------------------------------
	
	public static function nextLifeGeneration( src_img:Image, dest_img:Image, rule:String, bgColor:Int, fgColor:Int, swap:Bool = false):Void
	{
		if (swap) { nextLifeGeneration( dest_img, src_img, rule, bgColor, fgColor ); return; }		
		
		var s_rule:UInt = 0; // survival rule
		var b_rule:UInt = 0; // birth_rule
		
		var c:String;
		
		for (c in rule.split('/')[0].split('') ) s_rule |= 1 << Std.parseInt(c);
		for (c in rule.split('/')[1].split('') ) b_rule |= 1 << Std.parseInt(c);
		
		var x:Int, y:Int, x_neg:Int, y_neg:Int, x_pos:Int, y_pos:Int;
		var sum:UInt;
		var w:Int = src_img.width;
		var h:Int = src_img.height;
		
		for (y in 0...h)
		{
			y_neg = (y - 1) % h; if (y_neg < 0) y_neg += h;
			y_pos = (y + 1) % h;
			
			for (x in 0...w)
			{	
				x_neg = (x - 1) % w; if (x_neg < 0) x_neg += w;
				x_pos = (x + 1) % w;
				sum = 0; // number of neighbours
				
				// +alife top neighbours
				sum += (src_img.getPixel32(x_neg, y_neg) == fgColor) ? 1 : 0;
				sum += (src_img.getPixel32(x    , y_neg) == fgColor) ? 1 : 0;
				sum += (src_img.getPixel32(x_pos, y_neg) == fgColor) ? 1 : 0;
				
				// +alife middle neighbours
				sum += (src_img.getPixel32(x_neg, y    ) == fgColor) ? 1 : 0;
				sum += (src_img.getPixel32(x_pos, y    ) == fgColor) ? 1 : 0;
				
				// +alife bottom neighbours
				sum += (src_img.getPixel32(x_neg, y_pos) == fgColor) ? 1 : 0;
				sum += (src_img.getPixel32(x    , y_pos) == fgColor) ? 1 : 0;
				sum += (src_img.getPixel32(x_pos, y_pos) == fgColor) ? 1 : 0;
				
				sum = 1 << sum;
				
				//trace(x,y,x_pos,y_pos,x_neg,y_neg,sum,s_rule,b_rule);
				if (src_img.getPixel32(x, y) == fgColor) // old cell is alife
				{	
					if ( (s_rule & sum) > 0 )
						dest_img.setPixel32(x,y,fgColor); // life again
					else
						dest_img.setPixel32(x,y,bgColor); // dead
				}
				else                                     // old cell is dead
				{	
					if ( (b_rule & sum) > 0 )
						dest_img.setPixel32(x,y,fgColor); // birthday
					else
						dest_img.setPixel32(x,y,bgColor); // still dead
				}
			}
		}
		
	}


}