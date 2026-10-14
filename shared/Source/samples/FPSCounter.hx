package samples;

import haxe.Timer;
import lime.graphics.RenderContext;
import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLShader;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLUniformLocation;
import lime.math.Matrix4;
import lime.text.Font;
import lime.ui.Window;
import lime.utils.Assets;
import lime.utils.Float32Array;
import lime.utils.Int32Array;
import lime.utils.UInt8Array;

/**
	Shows the frame rate and frame time in the top left corner of a window,
	drawn over everything else once each frame.

	Attach one to a window, for instance in `onWindowCreate`, and it does the
	rest:

		new FPSCounter(window);

	Projects using it include the `lime-samples` haxelib:

		<haxelib name="lime-samples" />

	The digits are rasterized once into a small atlas, with `Font.renderGlyph`
	on native targets, or a canvas on HTML5. Each frame then draws a handful
	of quads in two draw calls, and the text is only laid out again when the
	numbers change, twice a second. The GL state it changes is put back, so it
	can be added to a sample that sets its state up only once. OpenGL, OpenGL
	ES, WebGL and canvas windows are supported.
**/
class FPSCounter
{
	private static inline var CHARACTERS = "0123456789. FPSms";
	private static inline var FONT_ID = "lime-samples/fonts/LimeSamplesMono.ttf";
	private static inline var FONT_POINTS = 10;
	private static inline var MAX_CHARACTERS = 24;
	private static inline var PADDING = 4;
	private static inline var UPDATE_SECONDS = 0.5;

	// The atlas is bound to a unit samples are unlikely to use, so the texture
	// a sample has bound is left alone. OpenGL ES 2 has at least 8 units.
	private static inline var ATLAS_UNIT = 7;

	/**
		Whether the counter is drawn. It keeps counting while hidden.
	**/
	public var visible:Bool;

	private var frames:Int;
	private var intervalStart:Float;
	private var text:String;
	private var window:Window;

	private var atlas:GLTexture;
	private var atlasHeight:Int;
	private var atlasWidth:Int;
	private var buffer:GLBuffer;
	private var glyphs:Map<Int, CounterGlyph>;
	private var gl:WebGLRenderContext;
	private var layoutText:String;
	private var lineHeight:Float;
	private var programs:Array<CounterProgram>;
	private var textVertices:Int;
	private var vertices:Float32Array;

	public function new(window:Window)
	{
		this.window = window;

		frames = 0;
		intervalStart = -1;
		text = "";
		visible = true;

		// After the application's own render, which is added at priority 0
		window.onRender.add(render, false, -1000);
		window.onRenderContextLost.add(onRenderContextLost);
	}

	/**
		Stops counting and drawing.
	**/
	public function dispose():Void
	{
		window.onRender.remove(render);
		window.onRenderContextLost.remove(onRenderContextLost);

		if (gl != null)
		{
			if (atlas != null) gl.deleteTexture(atlas);
			if (buffer != null) gl.deleteBuffer(buffer);

			if (programs != null)
			{
				for (counterProgram in programs)
				{
					gl.deleteProgram(counterProgram.program);
				}
			}
		}

		onRenderContextLost();
	}

	private function count():Void
	{
		var now = Timer.stamp();

		if (intervalStart < 0)
		{
			intervalStart = now;
			return;
		}

		frames++;

		var elapsed = now - intervalStart;
		if (elapsed < UPDATE_SECONDS) return;

		var fps = Std.int(frames / elapsed + 0.5);
		var tenths = Std.int(elapsed * 10000 / frames + 0.5);
		text = fps + " FPS " + Std.int(tenths / 10) + "." + (tenths % 10) + " ms";

		frames = 0;
		intervalStart = now;
	}

	private function render(context:RenderContext):Void
	{
		count();

		if (!visible || text == "") return;

		switch (context.type)
		{
			case OPENGL, OPENGLES, WEBGL:
				renderGL(context.webgl);

			case CANVAS:
				renderCanvas(context);

			default:
		}
	}

	private function renderCanvas(context:RenderContext):Void
	{
		#if (js && html5)
		var ctx = context.canvas2D;
		var size = 13 * window.scale;
		var x = 8 * window.scale;
		var y = 8 * window.scale;

		ctx.save();
		ctx.setTransform(1, 0, 0, 1, 0, 0);
		ctx.font = size + "px monospace";
		ctx.textBaseline = "top";
		var width = ctx.measureText(text).width;
		ctx.fillStyle = "rgba(0, 0, 0, 0.6)";
		ctx.fillRect(x - PADDING, y - PADDING, width + PADDING * 2, size * 1.2 + PADDING * 2);
		ctx.fillStyle = "#ffffff";
		ctx.fillText(text, x, y);
		ctx.restore();
		#end
	}

	private function renderGL(gl:WebGLRenderContext):Void
	{
		if (this.gl != gl)
		{
			// A new context has none of the objects made for the last one
			onRenderContextLost();
			this.gl = gl;
		}

		if (programs == null && !createGLObjects(gl)) return;

		var width = Std.int(window.width * window.scale);
		var height = Std.int(window.height * window.scale);

		if (text != layoutText) layout(gl);

		// The state this changes is saved and put back afterwards
		var lastProgram:GLProgram = gl.getParameter(gl.CURRENT_PROGRAM);
		var lastArrayBuffer:GLBuffer = gl.getParameter(gl.ARRAY_BUFFER_BINDING);
		var lastActiveTexture:Int = gl.getParameter(gl.ACTIVE_TEXTURE);
		var lastViewport:Int32Array = gl.getParameter(gl.VIEWPORT);
		var lastBlend = gl.isEnabled(gl.BLEND);
		var lastBlendSrcRGB:Int = gl.getParameter(gl.BLEND_SRC_RGB);
		var lastBlendDstRGB:Int = gl.getParameter(gl.BLEND_DST_RGB);
		var lastBlendSrcAlpha:Int = gl.getParameter(gl.BLEND_SRC_ALPHA);
		var lastBlendDstAlpha:Int = gl.getParameter(gl.BLEND_DST_ALPHA);
		var lastCullFace = gl.isEnabled(gl.CULL_FACE);
		var lastDepthTest = gl.isEnabled(gl.DEPTH_TEST);
		var lastScissorTest = gl.isEnabled(gl.SCISSOR_TEST);

		// Compatibility contexts only draw with attribute 0 enabled, so the
		// vertices go there when a sample has left it off. When it is on, as a
		// sample that sets its arrays up once leaves it, they go through the last
		// attribute instead, and the sample's attribute 0 is left as it was.
		var attributeZero = isTrue(gl.getVertexAttrib(0, gl.VERTEX_ATTRIB_ARRAY_ENABLED));
		var counterProgram = programs[attributeZero ? 1 : 0];
		var location = counterProgram.location;
		var lastEnabled = attributeZero && isTrue(gl.getVertexAttrib(location, gl.VERTEX_ATTRIB_ARRAY_ENABLED));

		gl.useProgram(counterProgram.program);

		if (width != counterProgram.width || height != counterProgram.height)
		{
			var matrix = new Matrix4();
			matrix.createOrtho(0, width, height, 0, -1, 1);
			gl.uniformMatrix4fv(counterProgram.matrix, false, matrix);
			counterProgram.width = width;
			counterProgram.height = height;
		}

		gl.viewport(0, 0, width, height);
		gl.disable(gl.CULL_FACE);
		gl.disable(gl.DEPTH_TEST);
		gl.disable(gl.SCISSOR_TEST);
		gl.enable(gl.BLEND);
		gl.blendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ONE, gl.ONE_MINUS_SRC_ALPHA);

		gl.activeTexture(gl.TEXTURE0 + ATLAS_UNIT);
		gl.bindTexture(gl.TEXTURE_2D, atlas);

		gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
		gl.enableVertexAttribArray(location);
		gl.vertexAttribPointer(location, 4, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 0);

		// The background, then the text
		gl.uniform4f(counterProgram.color, 0, 0, 0, 0.6);
		gl.drawArrays(gl.TRIANGLES, 0, 6);
		gl.uniform4f(counterProgram.color, 1, 1, 1, 1);
		gl.drawArrays(gl.TRIANGLES, 6, textVertices);

		if (!lastEnabled) gl.disableVertexAttribArray(location);
		gl.bindBuffer(gl.ARRAY_BUFFER, lastArrayBuffer);
		gl.activeTexture(lastActiveTexture);
		gl.useProgram(lastProgram);
		gl.viewport(lastViewport[0], lastViewport[1], lastViewport[2], lastViewport[3]);
		gl.blendFuncSeparate(lastBlendSrcRGB, lastBlendDstRGB, lastBlendSrcAlpha, lastBlendDstAlpha);
		if (!lastBlend) gl.disable(gl.BLEND);
		if (lastCullFace) gl.enable(gl.CULL_FACE);
		if (lastDepthTest) gl.enable(gl.DEPTH_TEST);
		if (lastScissorTest) gl.enable(gl.SCISSOR_TEST);
	}

	private function createGLObjects(gl:WebGLRenderContext):Bool
	{
		var coverage = renderAtlas();
		if (coverage == null) return false;

		var precision = #if !desktop "precision mediump float;" #else "" #end;
		var vertexShader = compileShader(gl, gl.VERTEX_SHADER, "attribute vec4 aVertex;
			varying vec2 vTexCoord;
			uniform mat4 uMatrix;

			void main(void) {
				vTexCoord = aVertex.zw;
				gl_Position = uMatrix * vec4(aVertex.xy, 0.0, 1.0);
			}");
		var fragmentShader = compileShader(gl, gl.FRAGMENT_SHADER, precision + "varying vec2 vTexCoord;
			uniform sampler2D uAtlas;
			uniform vec4 uColor;

			void main(void) {
				gl_FragColor = vec4(uColor.rgb, uColor.a * texture2D(uAtlas, vTexCoord).a);
			}");

		// The same shader, reading its vertices from attribute 0 or from the last
		var lastAttribute:Int = gl.getParameter(gl.MAX_VERTEX_ATTRIBS);
		programs = [];

		for (location in [0, lastAttribute - 1])
		{
			var counterProgram = linkProgram(gl, vertexShader, fragmentShader, location);

			if (counterProgram == null)
			{
				programs = null;
				visible = false;
				break;
			}

			programs.push(counterProgram);
		}

		gl.deleteShader(vertexShader);
		gl.deleteShader(fragmentShader);

		if (programs == null) return false;

		var lastActiveTexture:Int = gl.getParameter(gl.ACTIVE_TEXTURE);
		var lastUnpackAlignment:Int = gl.getParameter(gl.UNPACK_ALIGNMENT);
		gl.activeTexture(gl.TEXTURE0 + ATLAS_UNIT);
		atlas = gl.createTexture();
		gl.bindTexture(gl.TEXTURE_2D, atlas);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
		gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.ALPHA, atlasWidth, atlasHeight, 0, gl.ALPHA, gl.UNSIGNED_BYTE, coverage);
		gl.pixelStorei(gl.UNPACK_ALIGNMENT, lastUnpackAlignment);
		gl.activeTexture(lastActiveTexture);

		// A background quad and the text, six vertices each
		vertices = new Float32Array((MAX_CHARACTERS + 1) * 6 * 4);
		buffer = gl.createBuffer();
		layoutText = null;
		return true;
	}

	private function layout(gl:WebGLRenderContext):Void
	{
		var scale = window.scale;
		var left = 8 * scale;
		var top = 8 * scale;
		var baseline = Math.round(top + lineHeight * 0.8);
		var x = left;
		var index = 24;
		var count = 0;

		for (i in 0...text.length)
		{
			if (count == MAX_CHARACTERS) break;

			var glyph = glyphs.get(text.charCodeAt(i));
			if (glyph == null) continue;

			if (glyph.width > 0)
			{
				// Whole pixels keep the nearest sampled glyphs sharp
				var x0 = Math.round(x + glyph.left);
				var y0 = baseline - glyph.top;
				index = addQuad(index, x0, y0, x0 + glyph.width, y0 + glyph.height, glyph.u0, glyph.v0, glyph.u1, glyph.v1);
				count++;
			}

			x += glyph.advance;
		}

		// The background sits behind the text, from the opaque corner of the atlas
		var padding = PADDING * scale;
		var solid = 0.5 / atlasWidth;
		var solidV = (atlasHeight - 0.5) / atlasHeight;
		addQuad(0, left - padding, top - padding, x + padding, top + lineHeight + padding, solid, solidV, solid, solidV);

		textVertices = count * 6;

		var lastArrayBuffer:GLBuffer = gl.getParameter(gl.ARRAY_BUFFER_BINDING);
		gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
		gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.DYNAMIC_DRAW);
		gl.bindBuffer(gl.ARRAY_BUFFER, lastArrayBuffer);

		layoutText = text;
	}

	private function addQuad(index:Int, x0:Float, y0:Float, x1:Float, y1:Float, u0:Float, v0:Float, u1:Float, v1:Float):Int
	{
		index = addVertex(index, x0, y0, u0, v0);
		index = addVertex(index, x1, y0, u1, v0);
		index = addVertex(index, x0, y1, u0, v1);
		index = addVertex(index, x1, y0, u1, v0);
		index = addVertex(index, x1, y1, u1, v1);
		return addVertex(index, x0, y1, u0, v1);
	}

	private inline function addVertex(index:Int, x:Float, y:Float, u:Float, v:Float):Int
	{
		vertices[index] = x;
		vertices[index + 1] = y;
		vertices[index + 2] = u;
		vertices[index + 3] = v;
		return index + 4;
	}

	private function linkProgram(gl:WebGLRenderContext, vertexShader:GLShader, fragmentShader:GLShader, location:Int):CounterProgram
	{
		var program = gl.createProgram();
		gl.attachShader(program, vertexShader);
		gl.attachShader(program, fragmentShader);
		gl.bindAttribLocation(program, location, "aVertex");
		gl.linkProgram(program);

		if (!isTrue(gl.getProgramParameter(program, gl.LINK_STATUS)))
		{
			trace("FPSCounter: " + gl.getProgramInfoLog(program));
			gl.deleteProgram(program);
			return null;
		}

		var counterProgram = new CounterProgram(program, location);
		counterProgram.color = gl.getUniformLocation(program, "uColor");
		counterProgram.matrix = gl.getUniformLocation(program, "uMatrix");

		var lastProgram:GLProgram = gl.getParameter(gl.CURRENT_PROGRAM);
		gl.useProgram(program);
		gl.uniform1i(gl.getUniformLocation(program, "uAtlas"), ATLAS_UNIT);
		gl.useProgram(lastProgram);

		return counterProgram;
	}

	private function compileShader(gl:WebGLRenderContext, type:Int, source:String):GLShader
	{
		var shader = gl.createShader(type);
		gl.shaderSource(shader, source);
		gl.compileShader(shader);

		if (!isTrue(gl.getShaderParameter(shader, gl.COMPILE_STATUS)))
		{
			trace("FPSCounter: " + gl.getShaderInfoLog(shader));
		}

		return shader;
	}

	// Native targets give GL flags as numbers, and HTML5 as booleans
	private static inline function isTrue(value:Dynamic):Bool
	{
		return value == true || value == 1;
	}

	private function onRenderContextLost():Void
	{
		atlas = null;
		buffer = null;
		gl = null;
		layoutText = null;
		programs = null;
	}

	private function renderAtlas():UInt8Array
	{
		// Renders the characters once into one coverage image, with an opaque
		// row at the bottom for the background
		if (!Assets.isLocal(FONT_ID)) return null;

		var font = Assets.getFont(FONT_ID);
		if (font == null) return null;

		glyphs = new Map();

		#if (lime_cffi && !macro)
		// Each glyph is rendered once, and packed side by side into the atlas
		var points = Std.int(FONT_POINTS * window.scale + 0.5);
		var images = [];
		var advances = [];

		atlasWidth = 1;
		atlasHeight = 1;

		for (i in 0...CHARACTERS.length)
		{
			var glyph = font.getGlyph(CHARACTERS.charAt(i));
			var image = font.renderGlyph(glyph, points);

			// After rendering, the font is at this size, with advances in 64ths of a pixel
			advances.push(font.getGlyphMetrics(glyph).advance.x / 64);
			images.push(image);

			if (image != null)
			{
				atlasWidth += image.width + 1;
				if (image.height + 1 > atlasHeight) atlasHeight = image.height + 1;
			}
		}

		// The bottom row is opaque, for the background
		var coverage = new UInt8Array(atlasWidth * atlasHeight);

		for (i in 0...atlasWidth)
		{
			coverage[(atlasHeight - 1) * atlasWidth + i] = 255;
		}

		// Points are rendered at 96 DPI
		lineHeight = points * 96 / 72 * 1.2;

		var x = 0;

		for (i in 0...CHARACTERS.length)
		{
			var image = images[i];
			var counterGlyph = new CounterGlyph(advances[i]);

			if (image != null)
			{
				// Glyphs come as 32-bit white with coverage in alpha, or 8-bit
				// coverage from older versions of Lime
				var data = image.buffer.data;
				var bytesPerPixel = Std.int(image.buffer.bitsPerPixel / 8);
				var rowBytes = image.buffer.width * bytesPerPixel;

				for (row in 0...image.height)
				{
					for (column in 0...image.width)
					{
						var source = (row + image.offsetY) * rowBytes + (column + image.offsetX) * bytesPerPixel + bytesPerPixel - 1;
						coverage[row * atlasWidth + x + column] = data[source];
					}
				}

				counterGlyph.left = image.x;
				counterGlyph.top = image.y;
				counterGlyph.width = image.width;
				counterGlyph.height = image.height;
				counterGlyph.u0 = x / atlasWidth;
				counterGlyph.v0 = 0;
				counterGlyph.u1 = (x + image.width) / atlasWidth;
				counterGlyph.v1 = image.height / atlasHeight;

				x += image.width + 1;
			}

			glyphs.set(CHARACTERS.charCodeAt(i), counterGlyph);
		}

		return coverage;
		#elseif (js && html5)
		// The browser draws the font, so the atlas comes from a canvas
		var size = Std.int(13 * window.scale + 0.5);
		var cell = Std.int(size * 1.4);
		var canvas = js.Browser.document.createCanvasElement();
		canvas.width = cell * CHARACTERS.length;
		canvas.height = cell + 1;

		var ctx = canvas.getContext2d();
		ctx.font = size + "px '" + font.name + "', monospace";
		ctx.fillStyle = "#ffffff";
		ctx.textBaseline = "alphabetic";
		ctx.fillRect(0, cell, canvas.width, 1);

		atlasWidth = canvas.width;
		atlasHeight = canvas.height;
		lineHeight = size * 1.2;

		var ascent = Std.int(size * 0.8);

		for (i in 0...CHARACTERS.length)
		{
			var character = CHARACTERS.charAt(i);
			ctx.fillText(character, i * cell, ascent);

			var counterGlyph = new CounterGlyph(ctx.measureText(character).width);
			counterGlyph.left = 0;
			counterGlyph.top = ascent;
			counterGlyph.width = cell;
			counterGlyph.height = cell;
			counterGlyph.u0 = (i * cell) / atlasWidth;
			counterGlyph.v0 = 0;
			counterGlyph.u1 = ((i + 1) * cell) / atlasWidth;
			counterGlyph.v1 = cell / atlasHeight;
			glyphs.set(character.charCodeAt(0), counterGlyph);
		}

		var pixels = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
		var coverage = new UInt8Array(atlasWidth * atlasHeight);

		for (i in 0...coverage.length)
		{
			coverage[i] = pixels[i * 4 + 3];
		}

		return coverage;
		#else
		return null;
		#end
	}
}

private class CounterGlyph
{
	public var advance:Float;
	public var height:Float;
	public var left:Float;
	public var top:Float;
	public var u0:Float;
	public var u1:Float;
	public var v0:Float;
	public var v1:Float;
	public var width:Float;

	public function new(advance:Float)
	{
		this.advance = advance;

		height = 0;
		left = 0;
		top = 0;
		u0 = 0;
		u1 = 0;
		v0 = 0;
		v1 = 0;
		width = 0;
	}
}

private class CounterProgram
{
	public var color:GLUniformLocation;
	public var height:Int;
	public var location:Int;
	public var matrix:GLUniformLocation;
	public var program:GLProgram;
	public var width:Int;

	public function new(program:GLProgram, location:Int)
	{
		this.program = program;
		this.location = location;

		height = 0;
		width = 0;
	}
}
