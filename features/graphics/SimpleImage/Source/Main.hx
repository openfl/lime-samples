package;


import lime.app.Application;
import lime.graphics.cairo.*;
import lime.graphics.opengl.*;
import lime.graphics.Image;
import lime.graphics.Renderer;
import lime.math.Matrix4;
import lime.utils.Float32Array;
import lime.utils.GLUtils;
import lime.Assets;


class Main extends Application {
	
	
	private var cairoSurface:CairoSurface;
	private var glBuffer:GLBuffer;
	private var glMatrixUniform:GLUniformLocation;
	private var glProgram:GLProgram;
	private var glTexture:GLTexture;
	private var glTextureAttribute:Int;
	private var glVertexAttribute:Int;
	private var image:Image;
	
	
	public function new () {
		
		super ();
		
	}
	
	
	public override function render (renderer:Renderer):Void {
		
		if (image == null && preloader.complete) {
			
			image = Assets.getImage ("assets/lime.png");
			
			switch (renderer.context) {
				
				case CAIRO (cairo):
					
					image.format = BGRA32;
					image.premultiplied = true;
					
					cairoSurface = CairoImageSurface.fromImage (image);
				
				case CANVAS (context):
					
					context.fillStyle = "#" + StringTools.hex (config.windows[0].background, 6);
					context.fillRect (0, 0, window.width, window.height);
					context.drawImage (image.src, 0, 0, image.width, image.height);
				
				case DOM (element):
					
					element.style.backgroundColor = "#" + StringTools.hex (config.windows[0].background, 6);
					element.appendChild (image.src);
				
				case FLASH (sprite):
					
					#if flash
					var bitmap = new flash.display.Bitmap (image.src);
					sprite.addChild (bitmap);
					#end
				
				case OPENGL (gl):
					
					var gl:WebGLContext = gl;
					
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
						
						#if !desktop
						"precision mediump float;" +
						#end
						"varying vec2 vTexCoord;
						uniform sampler2D uImage0;
						
						void main(void)
						{
							gl_FragColor = texture2D (uImage0, vTexCoord);
						}";
					
					glProgram = GLUtils.createProgram (vertexSource, fragmentSource);
					gl.useProgram (glProgram);
					
					glVertexAttribute = gl.getAttribLocation (glProgram, "aPosition");
					glTextureAttribute = gl.getAttribLocation (glProgram, "aTexCoord");
					glMatrixUniform = gl.getUniformLocation (glProgram, "uMatrix");
					var imageUniform = gl.getUniformLocation (glProgram, "uImage0");
					
					gl.enableVertexAttribArray (glVertexAttribute);
					gl.enableVertexAttribArray (glTextureAttribute);
					gl.uniform1i (imageUniform, 0);
					
					gl.blendFunc (gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
					gl.enable (gl.BLEND);
					
					var data = [
						
						image.width, image.height, 0, 1, 1,
						0, image.height, 0, 0, 1,
						image.width, 0, 0, 1, 0,
						0, 0, 0, 0, 0
						
					];
					
					glBuffer = gl.createBuffer ();
					gl.bindBuffer (gl.ARRAY_BUFFER, glBuffer);
					gl.bufferData (gl.ARRAY_BUFFER, new Float32Array (data), gl.STATIC_DRAW);
					gl.bindBuffer (gl.ARRAY_BUFFER, null);
					
					glTexture = gl.createTexture ();
					gl.bindTexture (gl.TEXTURE_2D, glTexture);
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
					#if js
					gl.texImage2D (gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image.src);
					#else
					gl.texImage2D (gl.TEXTURE_2D, 0, gl.RGBA, image.buffer.width, image.buffer.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, image.data);
					#end
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
					gl.bindTexture (gl.TEXTURE_2D, null);
				
				default:
				
			}
			
		}
		
		switch (renderer.context) {
			
			case CAIRO (cairo):
				
				var r = ((config.windows[0].background >> 16) & 0xFF) / 0xFF;
				var g = ((config.windows[0].background >> 8) & 0xFF) / 0xFF;
				var b = (config.windows[0].background & 0xFF) / 0xFF;
				var a = ((config.windows[0].background >> 24) & 0xFF) / 0xFF;
				
				cairo.setSourceRGB (r, g, b);
				cairo.paint ();
				
				image.format = BGRA32;
				image.premultiplied = true;
				
				cairo.setSourceSurface (cairoSurface, 0, 0);
				cairo.paint ();
			
			case OPENGL (gl):
				
				gl.viewport (0, 0, window.width, window.height);
				
				var r = ((config.windows[0].background >> 16) & 0xFF) / 0xFF;
				var g = ((config.windows[0].background >> 8) & 0xFF) / 0xFF;
				var b = (config.windows[0].background & 0xFF) / 0xFF;
				var a = ((config.windows[0].background >> 24) & 0xFF) / 0xFF;
				
				gl.clearColor (r, g, b, a);
				gl.clear (gl.COLOR_BUFFER_BIT);
				
				if (image != null) {
					
					var matrix = Matrix4.createOrtho (0, window.width, window.height, 0, -1000, 1000);
					gl.uniformMatrix4fv (glMatrixUniform, false, matrix);
					
					gl.activeTexture (gl.TEXTURE0);
					gl.bindTexture (gl.TEXTURE_2D, glTexture);
					
					#if desktop
					gl.enable (gl.TEXTURE_2D);
					#end
					
					gl.bindBuffer (gl.ARRAY_BUFFER, glBuffer);
					gl.vertexAttribPointer (glVertexAttribute, 3, gl.FLOAT, false, 5 * Float32Array.BYTES_PER_ELEMENT, 0);
					gl.vertexAttribPointer (glTextureAttribute, 2, gl.FLOAT, false, 5 * Float32Array.BYTES_PER_ELEMENT, 3 * Float32Array.BYTES_PER_ELEMENT);
					
					gl.drawArrays (gl.TRIANGLE_STRIP, 0, 4);
					
				}
				
			default:
			
		}
		
	}
	
	
}