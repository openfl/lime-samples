package;


import lime.app.Application;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLUniformLocation;
import lime.graphics.Image;
import lime.graphics.Renderer;
import lime.math.Matrix4;
import lime.text.Font;
import lime.text.TextLayout;
import lime.ui.Window;
import lime.utils.Float32Array;
import lime.utils.GLUtils;
import lime.utils.UInt8Array;
import lime.Assets;


class Main extends Application {
	
	
	private var imageUniform:GLUniformLocation;
	private var matrixUniform:GLUniformLocation;
	private var program:GLProgram;
	private var textFields = new Array<TextRender> ();
	private var textureAttribute:Int;
	private var vertexAttribute:Int;
	
	
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
				
				program = GLUtils.createProgram (vertexSource, fragmentSource);
				gl.useProgram (program);
				
				vertexAttribute = gl.getAttribLocation (program, "aPosition");
				textureAttribute = gl.getAttribLocation (program, "aTexCoord");
				matrixUniform = gl.getUniformLocation (program, "uMatrix");
				imageUniform = gl.getUniformLocation (program, "uImage0");
				
				gl.enableVertexAttribArray (vertexAttribute);
				gl.enableVertexAttribArray (textureAttribute);
				gl.uniform1i (imageUniform, 0);
				
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
				gl.uniformMatrix4fv (matrixUniform, false, matrix);
				
				for (textField in textFields) {
					
					textField.render (renderer, vertexAttribute, textureAttribute);
					
				}
				
			default:
				
		}
		
	}
	
	
}


class TextRender {
	
	
	private var vertexBuffer:GLBuffer;
	private var images:Map<Int, Image>;
	private var indexBuffer:GLBuffer;
	private var numTriangles:Int;
	private var textLayout:TextLayout;
	private var texture:GLTexture;
	private var x:Float;
	private var y:Float;
	
	
	public function new (textLayout:TextLayout, x:Float = 0, y:Float = 0) {
		
		this.textLayout = textLayout;
		this.x = x;
		this.y = y;
		
		images = textLayout.font.renderGlyphs (textLayout.glyphs, textLayout.size);
		
	}
	
	
	public function init (application:Application) {
		
		switch (application.renderer.context) {
			
			case OPENGL (gl):
				
				var vertices = new Array<Float> ();
				var indices = new Array<Int> ();
				var left, top, right, bottom;
				
				if (textLayout.direction == RIGHT_TO_LEFT) {
					
					var width = 0.0;
					
					for (position in textLayout.positions) {
						
						width += position.advance.x;
						
					}
					
					x -= width;
					
				}
				
				var buffer = null;
				
				for (position in textLayout.positions) {
					
					if (images.exists (position.glyph)) {
						
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
				
				numTriangles = indices.length;
				
				vertexBuffer = gl.createBuffer ();
				gl.bindBuffer (gl.ARRAY_BUFFER, vertexBuffer);
				gl.bufferData (gl.ARRAY_BUFFER, new Float32Array (vertices), gl.STATIC_DRAW);
				
				indexBuffer = gl.createBuffer ();
				gl.bindBuffer (gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
				gl.bufferData (gl.ELEMENT_ARRAY_BUFFER, new UInt8Array (indices), gl.STATIC_DRAW);
				
				var format = (buffer.bitsPerPixel == 1 ? gl.ALPHA : gl.RGBA);
				texture = gl.createTexture ();
				gl.bindTexture (gl.TEXTURE_2D, texture);
				gl.texImage2D (gl.TEXTURE_2D, 0, format, buffer.width, buffer.height, 0, format, gl.UNSIGNED_BYTE, buffer.data);
				gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
				gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
				
			default:
				
			
		}
		
	}
	
	
	public function render (renderer:Renderer, vertexAttribute:Int, textureAttribute:Int) {
		
		switch (renderer.context) {
			
			case OPENGL (gl):
				
				gl.activeTexture (gl.TEXTURE0);
				gl.bindTexture (gl.TEXTURE_2D, texture);
				
				gl.bindBuffer (gl.ARRAY_BUFFER, vertexBuffer);
				gl.vertexAttribPointer (vertexAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 0);
				gl.vertexAttribPointer (textureAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);
				
				gl.bindBuffer (gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
				gl.drawElements (gl.TRIANGLES, numTriangles, gl.UNSIGNED_BYTE, 0);
				
			default:
				
			
		}
		
	}
	
	
}