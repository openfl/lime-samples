package ;

import lime.graphics.Image;

import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLUniformLocation;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLTexture;

import lime.math.Matrix4;

import lime.utils.Float32Array;

import lime.graphics.WebGLRenderContext;

class OpenglRender
{

	private static var buffer:GLBuffer;
	private static var matrixUniform:GLUniformLocation;
	private static var program:GLProgram;
	private static var texture:GLTexture;
	private static var textureAttribute:Int;
	private static var vertexAttribute:Int;
	
	private static var r:Float;
	private static var g:Float;
	private static var b:Float;
	private static var a:Float;

	public static function init(gl:WebGLRenderContext, background:Int, image:Image, scale:Float):Void {

		r = ((background >> 16) & 0xFF) / 0xFF;
		g = ((background >> 8) & 0xFF) / 0xFF;
		b = ( background & 0xFF) / 0xFF;
		a = ((background >> 24) & 0xFF) / 0xFF;
		
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
			#if (!desktop || rpi)
			"precision mediump float;" +
			#end
			"varying vec2 vTexCoord;
			uniform sampler2D uImage0;
			
			void main(void)
			{
				gl_FragColor = texture2D (uImage0, vTexCoord);
			}";
		
		program = GLProgram.fromSources (gl, vertexSource, fragmentSource);
		gl.useProgram (program);
		
		vertexAttribute = gl.getAttribLocation (program, "aPosition");
		textureAttribute = gl.getAttribLocation (program, "aTexCoord");
		matrixUniform = gl.getUniformLocation (program, "uMatrix");
		var imageUniform = gl.getUniformLocation (program, "uImage0");
		
		gl.enableVertexAttribArray (vertexAttribute);
		gl.enableVertexAttribArray (textureAttribute);
		gl.uniform1i (imageUniform, 0);
		
		var data = [
			image.width*scale, image.height*scale, 0, 1, 1,
			0, image.height*scale, 0, 0, 1,
			image.width*scale, 0, 0, 1, 0,
			0, 0, 0, 0, 0
		];
		
		buffer = gl.createBuffer ();
		gl.bindBuffer (gl.ARRAY_BUFFER, buffer);
		gl.bufferData (gl.ARRAY_BUFFER, new Float32Array (data), gl.STATIC_DRAW);
		gl.bindBuffer (gl.ARRAY_BUFFER, null);
		
		texture = gl.createTexture ();
		gl.bindTexture (gl.TEXTURE_2D, texture);
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
		
		gl.texImage2D (gl.TEXTURE_2D, 0, gl.RGBA, image.buffer.width, image.buffer.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, image.data);
		
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
		gl.bindTexture (gl.TEXTURE_2D, null);
	}


	public static function changeTextureData(gl:WebGLRenderContext, image:Image):Void 
	{
		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texImage2D (gl.TEXTURE_2D, 0, gl.RGBA, image.buffer.width, image.buffer.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, image.data);
	}
	
	
	public static function render(gl:WebGLRenderContext, width:Int, height:Int):Void {
		
		gl.viewport (0, 0, width, height);
		
		gl.clearColor (r, g, b, a);
		gl.clear (gl.COLOR_BUFFER_BIT);
		
		var matrix = new Matrix4 ();
		matrix.createOrtho (0, width, height, 0, -1000, 1000);
		gl.uniformMatrix4fv (matrixUniform, false, matrix);
		
		gl.activeTexture (gl.TEXTURE0);
		gl.bindTexture (gl.TEXTURE_2D, texture);
		
		#if desktop
		gl.enable (gl.TEXTURE_2D);
		#end
		
		gl.bindBuffer (gl.ARRAY_BUFFER, buffer);
		gl.vertexAttribPointer (vertexAttribute, 3, gl.FLOAT, false, 5 * Float32Array.BYTES_PER_ELEMENT, 0);
		gl.vertexAttribPointer (textureAttribute, 2, gl.FLOAT, false, 5 * Float32Array.BYTES_PER_ELEMENT, 3 * Float32Array.BYTES_PER_ELEMENT);
		
		gl.drawArrays (gl.TRIANGLE_STRIP, 0, 4);
	}
	
}