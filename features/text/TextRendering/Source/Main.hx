package;


import lime.app.Application;
import lime.graphics.cairo.Cairo;
import lime.graphics.cairo.CairoAntialias;
import lime.graphics.cairo.CairoFontFace;
import lime.graphics.cairo.CairoFontOptions;
import lime.graphics.cairo.CairoFTFontFace;
import lime.graphics.cairo.CairoGlyph;
import lime.graphics.cairo.CairoHintMetrics;
import lime.graphics.cairo.CairoHintStyle;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLUniformLocation;
import lime.graphics.opengl.WebGLContext;
import lime.graphics.Image;
import lime.graphics.Renderer;
import lime.math.Matrix4;
import lime.text.Font;
import lime.text.TextLayout;
import lime.ui.Window;
import lime.utils.Assets;
import lime.utils.Float32Array;
import lime.utils.GLUtils;
import lime.utils.UInt8Array;


class Main extends Application {
	
	
	private var glImageUniform:GLUniformLocation;
	private var glMatrixUniform:GLUniformLocation;
	private var glProgram:GLProgram;
	private var glTextureAttribute:Int;
	private var glVertexAttribute:Int;
	private var textFields = new Array<TextRender> ();
	
	
	public function new () {
		
		super ();
		
	}
	
	
	public override function onPreloadComplete ():Void {
		
		var font = Assets.getFont ("assets/amiri-regular.ttf");
		var textLayout = new TextLayout ("صِف خَلقَ خَودِ كَمِثلِ الشَمسِ إِذ بَزَغَت — يَحظى الضَجيعُ بِها نَجلاءَ مِعطارِ", font, 16, RIGHT_TO_LEFT, ARABIC, "ar");
		textFields.push (new TextRender (textLayout, window.width, 80));
		
		var textLayout = new TextLayout ("The quick brown fox jumps over the lazy dog.", font, 16);
		textFields.push (new TextRender (textLayout, 20, 20));
		
		var font = Assets.getFont ("assets/fireflysung.ttf");
		var textLayout = new TextLayout ("懶惰的姜貓", font, 32, TOP_TO_BOTTOM, HAN, "zh");
		textFields.push (new TextRender (textLayout, 50, 170));
		
		for (textField in textFields) {
			
			textField.init (this);
			
		}
		
	}
	
	
	public override function onWindowCreate (window:Window):Void {
		
		switch (window.renderer.context) {
			
			case OPENGL (gl):
				
				var vertexSource =
					
					"attribute vec4 aPosition;
					attribute vec2 aTexCoord;
					varying vec2 vTexCoord;
					
					uniform mat4 uMatrix;
					
					void main(void) {
						
						vTexCoord = aTexCoord;
						gl_Position = uMatrix * aPosition;
						
					}";
				
				var fragmentSource =
					
					"#ifdef GL_ES
					precision mediump float;
					#endif
					varying vec2 vTexCoord;
					uniform sampler2D uImage0;
					
					void main(void)
					{
						gl_FragColor = vec4 (0, 0, 0, texture2D (uImage0, vTexCoord).a);
					}";
				
				glProgram = GLUtils.createProgram (vertexSource, fragmentSource);
				gl.useProgram (glProgram);
				
				glVertexAttribute = gl.getAttribLocation (glProgram, "aPosition");
				glTextureAttribute = gl.getAttribLocation (glProgram, "aTexCoord");
				glMatrixUniform = gl.getUniformLocation (glProgram, "uMatrix");
				glImageUniform = gl.getUniformLocation (glProgram, "uImage0");
				
				gl.enableVertexAttribArray (glVertexAttribute);
				gl.enableVertexAttribArray (glTextureAttribute);
				gl.uniform1i (glImageUniform, 0);
				
				#if desktop
				gl.enable (gl.TEXTURE_2D);
				#end
				
				gl.blendFunc (gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
				gl.enable (gl.BLEND);
				
				gl.viewport (0, 0, window.width, window.height);
				
			default:
				
			
		}
		
	}
	
	
	public override function render (renderer:Renderer):Void {
		
		switch (renderer.context) {
			
			case OPENGL (gl):
				
				var r = ((config.windows[0].background >> 16) & 0xFF) / 0xFF;
				var g = ((config.windows[0].background >> 8) & 0xFF) / 0xFF;
				var b = (config.windows[0].background & 0xFF) / 0xFF;
				var a = ((config.windows[0].background >> 24) & 0xFF) / 0xFF;
				
				gl.clearColor (r, g, b, a);
				gl.clear (gl.COLOR_BUFFER_BIT);
				
				var matrix = Matrix4.createOrtho (0, window.width, window.height, 0, -10, 10);
				gl.uniformMatrix4fv (glMatrixUniform, 1, false, matrix);
				
				for (textField in textFields) {
					
					textField.render (renderer, glVertexAttribute, glTextureAttribute);
					
				}
			
			case CAIRO (cairo):
				
				var r = ((config.windows[0].background >> 16) & 0xFF) / 0xFF;
				var g = ((config.windows[0].background >> 8) & 0xFF) / 0xFF;
				var b = (config.windows[0].background & 0xFF) / 0xFF;
				
				cairo.setSourceRGB (r, g, b);
				cairo.paint ();
				
				for (textField in textFields) {
					
					textField.render (renderer);
					
				}
			
			default:
				
			
		}
		
		
		
	}
	
	
}


class TextRender {
	
	
	private var cairoFontFace:CairoFontFace;
	private var cairoFontOptions:CairoFontOptions;
	private var cairoGlyphs:Array<CairoGlyph>;
	private var glIndexBuffer:GLBuffer;
	private var glNumTriangles:Int;
	private var glTexture:GLTexture;
	private var glVertexBuffer:GLBuffer;
	private var images:Map<Int, Image>;
	private var textLayout:TextLayout;
	private var x:Float;
	private var y:Float;
	
	
	public function new (textLayout:TextLayout, x:Float = 0, y:Float = 0) {
		
		this.textLayout = textLayout;
		this.x = x;
		this.y = y;
		
		images = textLayout.font.renderGlyphs (textLayout.glyphs, textLayout.size);
		
	}
	
	
	public function init (application:Application) {
		
		if (textLayout.direction == RIGHT_TO_LEFT) {
			
			var width = 0.0;
			
			for (position in textLayout.positions) {
				
				width += position.advance.x;
				
			}
			
			x -= width;
			
		}
		
		switch (application.renderer.context) {
			
			case OPENGL (gl):
				
				var gl:WebGLContext = gl;
				var vertices = new Array<Float> ();
				var indices = new Array<Int> ();
				var left, top, right, bottom;
				
				var buffer = null;
				
				for (position in textLayout.positions) {
					
					if (position.glyph != 0 && images.exists (position.glyph)) {
						
						var image = images.get (position.glyph);
						
						buffer = image.buffer;
						
						left = image.offsetX / buffer.width;
						top = image.offsetY / buffer.height;
						right = left + image.width / buffer.width;
						bottom = top + image.height / buffer.height;
						
						var pointLeft = x + position.offset.x + image.x;
						var pointTop = y + position.offset.y - image.y;
						var pointRight = pointLeft + image.width;
						var pointBottom = pointTop + image.height;
						
						vertices.push (pointRight);
						vertices.push (pointBottom);
						vertices.push (right);
						vertices.push (bottom);
						
						vertices.push (pointLeft);
						vertices.push (pointBottom);
						vertices.push (left);
						vertices.push (bottom);
						
						vertices.push (pointRight);
						vertices.push (pointTop);
						vertices.push (right);
						vertices.push (top);
						
						vertices.push (pointLeft);
						vertices.push (pointTop);
						vertices.push (left);
						vertices.push (top);
						
						var i = Std.int (indices.length / 6) * 4;
						indices.push (i);
						indices.push (i + 1);
						indices.push (i + 2);
						indices.push (i + 1);
						indices.push (i + 2);
						indices.push (i + 3);
						
					}
					
					x += position.advance.x;
					y -= position.advance.y; // flip because of y-axis direction
					
				}
				
				glNumTriangles = indices.length;
				
				glVertexBuffer = gl.createBuffer ();
				gl.bindBuffer (gl.ARRAY_BUFFER, glVertexBuffer);
				gl.bufferData (gl.ARRAY_BUFFER, new Float32Array (vertices), gl.STATIC_DRAW);
				
				glIndexBuffer = gl.createBuffer ();
				gl.bindBuffer (gl.ELEMENT_ARRAY_BUFFER, glIndexBuffer);
				gl.bufferData (gl.ELEMENT_ARRAY_BUFFER, new UInt8Array (indices), gl.STATIC_DRAW);
				
				var format = (buffer.bitsPerPixel == 8 ? gl.ALPHA : gl.RGBA);
				glTexture = gl.createTexture ();
				gl.bindTexture (gl.TEXTURE_2D, glTexture);
				gl.texImage2D (gl.TEXTURE_2D, 0, format, buffer.width, buffer.height, 0, format, gl.UNSIGNED_BYTE, buffer.data);
				gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
				gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
			
			case CAIRO (cairo):
				
				cairoGlyphs = [];
				
				for (position in textLayout.positions) {
					
					if (position == null || position.glyph == 0) continue;
					
					cairoGlyphs.push (new CairoGlyph (position.glyph, x + position.offset.x + 0.5, y + position.offset.y + 0.5));
					
					x += position.advance.x;
					y -= position.advance.y;
					
				}
				
				cairoFontOptions = new CairoFontOptions ();
				cairoFontOptions.hintStyle = CairoHintStyle.SLIGHT;
				cairoFontOptions.hintMetrics = CairoHintMetrics.OFF;
				cairoFontOptions.antialias = CairoAntialias.GOOD;
				
				cairoFontFace = CairoFTFontFace.create (textLayout.font, 0);
			
			default:
				
			
		}
		
	}
	
	
	public function render (renderer:Renderer, ?glVertexAttribute:Int, ?glTextureAttribute:Int) {
		
		switch (renderer.context) {
			
			case OPENGL (gl):
				
				gl.activeTexture (gl.TEXTURE0);
				gl.bindTexture (gl.TEXTURE_2D, glTexture);
				
				gl.bindBuffer (gl.ARRAY_BUFFER, glVertexBuffer);
				gl.vertexAttribPointer (glVertexAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 0);
				gl.vertexAttribPointer (glTextureAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);
				
				gl.bindBuffer (gl.ELEMENT_ARRAY_BUFFER, glIndexBuffer);
				gl.drawElements (gl.TRIANGLES, glNumTriangles, gl.UNSIGNED_BYTE, 0);
			
			case CAIRO (cairo):
				
				cairo.translate (0, 0);
				cairo.setSourceRGB (0, 0, 0);
				
				cairo.setFontSize (textLayout.size);
				cairo.fontOptions = cairoFontOptions;
				cairo.fontFace = cairoFontFace;
				
				cairo.showGlyphs (cairoGlyphs);
			
			default:
				
			
		}
		
	}
	
	
}