package render;


import lime.graphics.cairo.Cairo;
import lime.graphics.cairo.CairoAntialias;
import lime.graphics.cairo.CairoFilter;
import lime.graphics.cairo.CairoFontOptions;
import lime.graphics.cairo.CairoFTFontFace;
import lime.graphics.cairo.CairoGlyph;
import lime.graphics.cairo.CairoHintMetrics;
import lime.graphics.cairo.CairoHintStyle;
import lime.graphics.cairo.CairoImageSurface;
import lime.graphics.cairo.CairoPattern;
import lime.text.harfbuzz.HB;
import lime.text.harfbuzz.HBBuffer;
import lime.text.harfbuzz.HBBufferClusterLevel;
import lime.text.harfbuzz.HBDirection;
import lime.text.harfbuzz.HBFTFont;
import lime.text.harfbuzz.HBLanguage;
import lime.text.harfbuzz.HBScript;
import lime.text.Font;


class CairoTextArea {
	
	
	public var pattern:CairoPattern;
	
	private var surface:CairoImageSurface;
	
	
	public function new (text:String, font:Font, size:Int, direction:HBDirection, script:HBScript, language:String) {
		
		@:privateAccess font.__setSize (size);
		var hbFont = new HBFTFont (font);
		
		var buffer = new HBBuffer ();
		buffer.direction = direction;
		buffer.script = script;
		buffer.language = new HBLanguage (language);
		buffer.clusterLevel = HBBufferClusterLevel.CHARACTERS;
		buffer.addUTF8 (text, 0, -1);
		
		HB.shape (hbFont, buffer);
		
		var info = buffer.getGlyphInfo ();
		var positions = buffer.getGlyphPositions ();
		
		var textWidth = 0.0, textHeight = 0.0;
		
		textHeight += (((font.ascender + Math.abs (font.descender)) / font.unitsPerEM) * size);
		
		for (position in positions) {
			
			textWidth += (position.xAdvance / 64);
			
			if (textWidth < Math.abs (position.xOffset / 64)) {
				
				textWidth = Math.abs (position.xOffset / 64);
				
			}
			
			textHeight += (-position.yAdvance / 64);
			
			if (textHeight < Math.abs (position.yOffset / 64)) {
				
				textHeight = Math.abs (position.yOffset / 64);
				
			}
			
		}
		
		surface = new CairoImageSurface (ARGB32, Math.ceil (textWidth), Math.ceil (textHeight));
		pattern = CairoPattern.createForSurface (surface);
		pattern.filter = CairoFilter.GOOD;
		
		var cairo = new Cairo (surface);
		
		var options = new CairoFontOptions ();
		options.hintStyle = CairoHintStyle.SLIGHT;
		options.hintMetrics = CairoHintMetrics.OFF;
		options.antialias = CairoAntialias.GOOD;
		
		cairo.fontOptions = options;
		
		cairo.setSourceRGB (0, 0, 0);
		
		var cairoFont = CairoFTFontFace.create (font, 0);
		cairo.fontFace = cairoFont;
		cairo.setFontSize (size);
		
		var glyphs = [];
		
		var x:Float = 0;
		var y:Float = (font.ascender / font.unitsPerEM) * size;
		
		for (i in 0...positions.length) {
			
			glyphs.push (new CairoGlyph (info[i].codepoint, x + (positions[i].xOffset / 64) + 0.5, y - (positions[i].yOffset / 64) + 0.5));
			x += (positions[i].xAdvance / 64);
			y -= (positions[i].yAdvance / 64);
			
		}
		
		cairo.showGlyphs (glyphs);
		
	}
	
	
}