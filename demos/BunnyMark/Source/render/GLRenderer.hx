package render;


import lime.graphics.Image;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLTexture;
import lime.graphics.WebGLRenderContext;
import lime.math.Matrix4;
import lime.utils.Float32Array;


class GLRenderer {
	
	
	private var buffer:GLBuffer;
	private var bufferData:Float32Array;
	private var gl:WebGLRenderContext;
	private var height:Int;
	private var image:Image;
	private var numBunnies:Int;
	private var program:GLProgram;
	private var texture:GLTexture;
	private var textureAttribute:Int;
	private var vertexAttribute:Int;
	private var width:Int;
	
	
	public function new (gl:WebGLRenderContext, image:Image, width:Int, height:Int) {
		
		this.gl = gl;
		this.image = image;
		this.width = width;
		this.height = height;
		
		numBunnies = 0;
		
		createShader ();
		createBuffer ();
		createMatrix ();
		createTexture ();
		
		gl.clearColor (1, 1, 1, 1);
		gl.blendFunc (gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
		gl.enable (gl.BLEND);
		
	}
	
	
	private function createBuffer ():Void {
		
		vertexAttribute = gl.getAttribLocation (program, "aVertexPosition");
		
		buffer = gl.createBuffer ();
		gl.bindBuffer (gl.ARRAY_BUFFER, buffer);
		
		bufferData = new Float32Array (0);
		gl.enableVertexAttribArray (vertexAttribute);
		
		gl.vertexAttribPointer (vertexAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 0);
		
	}
	
	
	private function createMatrix ():Void {
		
		var matrixUniform = gl.getUniformLocation (program, "uMatrix");
		var matrix = new Matrix4 ();
		matrix.createOrtho (0, width, height, 0, -1000, 1000);
		gl.uniformMatrix4fv (matrixUniform, false, matrix);
		
	}
	
	
	private function createShader ():Void {
		
		var vertexSource = "
			
			attribute vec2 aVertexPosition;
			attribute vec2 aTexCoord;
			uniform mat4 uMatrix;
			varying vec2 vTexCoord;
			
			void main (void) {
				
				vTexCoord = aTexCoord;
				gl_Position = uMatrix * vec4 (aVertexPosition, 0.0, 1.0);
				
			}
			
		";
		
		var fragmentSource = 
			
			#if (!desktop || rpi)
			"precision mediump float;" +
			#end
			"varying vec2 vTexCoord;
			uniform sampler2D uImage0;
			
			void main (void) {
				
				gl_FragColor = texture2D (uImage0, vTexCoord);
				
			}
			
		";
		
		program = GLProgram.fromSources (gl, vertexSource, fragmentSource);
		gl.useProgram (program);
		
	}
	
	
	private function createTexture ():Void {
		
		textureAttribute = gl.getAttribLocation (program, "aTexCoord");
		gl.enableVertexAttribArray (textureAttribute);
		
		var imageUniform = gl.getUniformLocation (program, "uImage0");
		gl.uniform1i (imageUniform, 0);
		
		texture = gl.createTexture ();
		gl.bindTexture (gl.TEXTURE_2D, texture);
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
		#if js
		gl.texImage2D (gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image.src);
		#else
		gl.texImage2D (gl.TEXTURE_2D, 0, gl.RGBA, image.buffer.width, image.buffer.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, image.data);
		#end
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		
		gl.vertexAttribPointer (textureAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);
		
	}
	
	
	private function resizeBuffer (length:Int):Void {
		
		
		
	}
	
	
	public function updateBuffer (bunnies:Array<Bunny>):Void {
		
		if (bunnies.length > numBunnies) {
			
			var data = new Float32Array (bunnies.length * 24);
			
			for (i in 0...bufferData.length) {
				
				data[i] = bufferData[i];
				
			}
			
			var offset;
			
			for (i in numBunnies...bunnies.length) {
				
				offset = i * 24;
				
				data[offset + 2] = 0;
				data[offset + 3] = 0;
				data[offset + 6] = 1;
				data[offset + 7] = 0;
				data[offset + 10] = 0;
				data[offset + 11] = 1;
				
				data[offset + 14] = 0;
				data[offset + 15] = 1;
				data[offset + 18] = 1;
				data[offset + 19] = 0;
				data[offset + 22] = 1;
				data[offset + 23] = 1;
				
			}
			
			bufferData = data;
			numBunnies = bunnies.length;
			
		}
		
		var bunnyWidth = image.width;
		var bunnyHeight = image.height;
		var bunny, x, y, x2, y2, offset;
		
		for (i in 0...numBunnies) {
			
			offset = i * 24;
			
			bunny = bunnies[i];
			x = bunny.x;
			y = bunny.y;
			x2 = x + bunnyWidth;
			y2 = y + bunnyHeight;
			
			bufferData[offset + 0] = x;
			bufferData[offset + 1] = y;
			bufferData[offset + 4] = x2;
			bufferData[offset + 5] = y;
			bufferData[offset + 8] = x;
			bufferData[offset + 9] = y2;
			
			bufferData[offset + 12] = x;
			bufferData[offset + 13] = y2;
			bufferData[offset + 16] = x2;
			bufferData[offset + 17] = y;
			bufferData[offset + 20] = x2;
			bufferData[offset + 21] = y2;
			
		}
		
		gl.bufferData (gl.ARRAY_BUFFER, bufferData, gl.STATIC_DRAW);
		
	}
	
	
	public function render ():Void {
		
		gl.viewport (0, 0, width, height);
		gl.clear (gl.COLOR_BUFFER_BIT);
		
		gl.drawArrays (gl.TRIANGLES, 0, numBunnies * 6);
		
	}
	
}