package;


import lime.app.Application;
import lime.graphics.RenderContext;
import lime.math.Matrix3;
import lime.utils.Assets;
import render.CairoTextArea;


class Main extends Application {
	
	
	private var arabic:CairoTextArea;
	private var chinese:CairoTextArea;
	private var english:CairoTextArea;
	private var matrix:Matrix3;
	
	
	public function new () {
		
		super ();
		
		matrix = new Matrix3 ();
		
	}
	
	
	public override function render (context:RenderContext):Void {
		
		if (preloader.complete) {
			
			switch (context.type) {
				
				case CAIRO:
					
					var cairo = context.cairo;
					
					cairo.identityMatrix ();
					cairo.setSourceRGB (1, 1, 1);
					cairo.paint ();
					
					if (arabic == null) {
						
						arabic = new CairoTextArea ("صِف خَلقَ خَودِ كَمِثلِ الشَمسِ إِذ بَزَغَت — يَحظى الضَجيعُ بِها نَجلاءَ مِعطارِ", Assets.getFont ("assets/amiri-regular.ttf"), 16, RTL, ARABIC, "ar");
						english = new CairoTextArea ("The quick brown fox jumps over the lazy dog.", Assets.getFont ("assets/amiri-regular.ttf"), 16, LTR, COMMON, "en");
						chinese = new CairoTextArea ("懶惰的姜貓", Assets.getFont ("assets/fireflysung.ttf"), 32, TTB, HAN, "zh");
						
					}
					
					matrix.tx = 20;
					matrix.ty = 80;
					cairo.matrix = matrix;
					cairo.source = arabic.pattern;
					cairo.paint ();
					
					matrix.tx = 20;
					matrix.ty = 20;
					cairo.matrix = matrix;
					cairo.source = english.pattern;
					cairo.paint ();
					
					matrix.tx = 50;
					matrix.ty = 170;
					cairo.matrix = matrix;
					cairo.source = chinese.pattern;
					cairo.paint ();
				
				case CANVAS:
					
					var ctx = context.canvas2D;
					
					ctx.clearRect (0, 0, ctx.canvas.width, ctx.canvas.height);
					ctx.fillStyle = "white";
					ctx.fillRect (0, 0, ctx.canvas.width, ctx.canvas.height);
					
					ctx.fillStyle = "black";
					
					ctx.font = "16px Amiri";
					ctx.fillText ("صِف خَلقَ خَودِ كَمِثلِ الشَمسِ إِذ بَزَغَت — يَحظى الضَجيعُ بِها نَجلاءَ مِعطارِ", 20, 80);
					
					ctx.font = "16px _sans";
					ctx.fillText ("The quick brown fox jumps over the lazy dog.", 20, 20);
					
					ctx.font = "16px 'AR PL New Sung'";
					ctx.fillText ("懶惰的姜貓", 50, 170);
				
				default:
				
				
			}
			
		}
		
		
	}
	
	
}