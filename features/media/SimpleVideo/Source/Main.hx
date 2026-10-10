package;

import haxe.Timer;
import lime.app.Application;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLUniformLocation;
import lime.graphics.RenderContext;
import lime.graphics.WebGLRenderContext;
import lime.math.Matrix4;
import lime.media.VideoFrame;
import lime.media.VideoSource;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.MouseButton;
import lime.utils.Float32Array;

/**
	A small video player.

	Click the video or press space to pause and resume. The bar at the bottom
	seeks, shows the time and sets the volume, and fades away during playback.
	The arrow keys skip and change the volume, M mutes, and F or a double click
	switches to full screen. Drop a video file on the window to play it.
**/
class Main extends Application
{
	private static inline var BAR_HEIGHT = 44;
	private static inline var HIDE_DELAY = 2.5;

	private var frame:VideoFrame;
	private var gain:Float;
	private var hasFrame:Bool;
	private var lastClick:Float;
	private var lastMouseMove:Float;
	private var lastSeek:Float;
	private var mouseX:Float;
	private var mouseY:Float;
	private var muted:Bool;
	private var seekPosition:Float;
	private var seeking:Bool;
	private var settingVolume:Bool;
	private var video:VideoSource;

	private var uiBuffer:GLBuffer;
	private var uiColorAttribute:Int;
	private var uiMatrixUniform:GLUniformLocation;
	private var uiPositionAttribute:Int;
	private var uiProgram:GLProgram;
	private var uiVertices:Array<Float>;
	private var videoBuffer:GLBuffer;
	private var videoMatrixUniform:GLUniformLocation;
	private var videoPositionAttribute:Int;
	private var videoProgram:GLProgram;
	private var videoTexCoordAttribute:Int;
	private var videoTexture:GLTexture;

	public function new()
	{
		super();

		frame = new VideoFrame();
		gain = 1;
		lastClick = 0;
		lastMouseMove = Timer.stamp();
		lastSeek = 0;
		mouseX = -1;
		mouseY = -1;
		seekPosition = 0;
		uiVertices = [];
	}

	public override function onKeyDown(keyCode:KeyCode, modifier:KeyModifier):Void
	{
		showControls();

		switch (keyCode)
		{
			case SPACE:
				togglePlayback();

			case LEFT:
				skip(-5000);

			case RIGHT:
				skip(5000);

			case UP:
				setGain(gain + 0.1);

			case DOWN:
				setGain(gain - 0.1);

			case M:
				toggleMute();

			case F:
				window.fullscreen = !window.fullscreen;

			default:
		}
	}

	public override function onMouseDown(x:Float, y:Float, button:MouseButton):Void
	{
		if (button != LEFT) return;

		var controlsWereVisible = getControlsAlpha() > 0.5;
		showControls();

		if (controlsWereVisible && y >= window.height - BAR_HEIGHT)
		{
			if (x < 44)
			{
				togglePlayback();
			}
			else if (x >= getSeekLeft() - 6 && x <= getSeekRight() + 6)
			{
				seeking = true;
				seekTo(x, true);
			}
			else if (x >= window.width - 118 && x < window.width - 92)
			{
				toggleMute();
			}
			else if (x >= window.width - 86 - 6)
			{
				settingVolume = true;
				setVolumeAt(x);
			}

			return;
		}

		var now = Timer.stamp();

		if (now - lastClick < 0.3)
		{
			// A double click undoes the pause of its first click
			togglePlayback();
			window.fullscreen = !window.fullscreen;
			lastClick = 0;
		}
		else
		{
			togglePlayback();
			lastClick = now;
		}
	}

	public override function onMouseMove(x:Float, y:Float):Void
	{
		mouseX = x;
		mouseY = y;
		showControls();

		if (seeking) seekTo(x, false);
		if (settingVolume) setVolumeAt(x);
	}

	public override function onMouseUp(x:Float, y:Float, button:MouseButton):Void
	{
		if (seeking)
		{
			seekTo(x, true);
			seeking = false;
		}

		settingVolume = false;
	}

	public override function onPreloadComplete():Void
	{
		if (!VideoSource.isSupported)
		{
			trace("Video is not supported on this target");
			return;
		}

		var path = "assets/lime.mp4";

		#if sys
		for (arg in Sys.args())
		{
			if (!StringTools.startsWith(arg, "-")) path = arg;
		}
		#end

		open(path);
	}

	public override function onWindowDropFile(file:String):Void
	{
		open(file);
	}

	public override function render(context:RenderContext):Void
	{
		switch (context.type)
		{
			case CANVAS:
				var ctx = context.canvas2D;

				ctx.fillStyle = "#000000";
				ctx.fillRect(0, 0, window.width, window.height);

				if (video != null && (video.readFrame(frame) || hasFrame))
				{
					// On HTML5 the frame is the <video> element itself
					hasFrame = true;
					var rect = getVideoRect();
					ctx.drawImage(frame.src, rect[0], rect[1], rect[2], rect[3]);
				}

			case DOM:
				var element = context.dom;
				element.style.backgroundColor = "#000000";

				if (video != null && !hasFrame && video.readFrame(frame))
				{
					// The browser's own player, with its own controls
					hasFrame = true;
					frame.src.controls = true;
					frame.src.style.width = "100%";
					frame.src.style.height = "100%";
					element.appendChild(frame.src);
				}

			case OPENGL, OPENGLES, WEBGL:
				var gl = context.webgl;

				if (videoProgram == null) initGL(gl);

				if (video != null && video.readFrame(frame))
				{
					hasFrame = true;

					#if (js && html5)
					// WebGL uploads the <video> element directly
					gl.bindTexture(gl.TEXTURE_2D, videoTexture);
					gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, frame.src);
					#end
				}

				gl.viewport(0, 0, Std.int(window.width * window.scale), Std.int(window.height * window.scale));
				gl.clearColor(0, 0, 0, 1);
				gl.clear(gl.COLOR_BUFFER_BIT);

				var matrix = new Matrix4();
				matrix.createOrtho(0, window.width, window.height, 0, -1000, 1000);

				if (hasFrame) drawVideo(gl, matrix);
				if (video != null) drawControls(gl, matrix);

			default:
		}
	}

	private function drawControls(gl:WebGLRenderContext, matrix:Matrix4):Void
	{
		uiVertices = [];

		var width = window.width;
		var height = window.height;
		var white = 0.92;

		// A large play symbol while paused
		if (!video.playing && !seeking)
		{
			var cx = width / 2;
			var cy = (height - BAR_HEIGHT) / 2;
			addRect(cx - 40, cy - 40, 80, 80, 0, 0, 0, 0.45);
			addTriangle(cx - 14, cy - 22, cx - 14, cy + 22, cx + 24, cy, white, white, white, 0.9);
		}

		var alpha = getControlsAlpha();

		if (alpha > 0)
		{
			var top = height - BAR_HEIGHT;
			var middle = top + BAR_HEIGHT / 2;

			addRect(0, top, width, BAR_HEIGHT, 0, 0, 0, 0.6 * alpha);

			// Play or pause
			if (video.playing)
			{
				addRect(14, middle - 9, 5, 18, white, white, white, alpha);
				addRect(24, middle - 9, 5, 18, white, white, white, alpha);
			}
			else
			{
				addTriangle(14, middle - 10, 14, middle + 10, 31, middle, white, white, white, alpha);
			}

			// Elapsed and total time
			var position = seeking ? seekPosition : video.currentTime;
			var x = addTime(48, middle - 6, position, alpha);
			addRect(x + 3, middle - 1, 5, 2, white, white, white, alpha * 0.6);
			addTime(x + 11, middle - 6, video.length, alpha * 0.6);

			// Seek bar
			var left = getSeekLeft();
			var right = getSeekRight();
			var progress = video.length > 0 ? Math.max(0, Math.min(1, position / video.length)) : 0;
			var head = left + (right - left) * progress;
			addRect(left, middle - 2, right - left, 4, 1, 1, 1, 0.25 * alpha);
			addRect(left, middle - 2, head - left, 4, 117 / 255, 187 / 255, 66 / 255, alpha);
			addRect(head - 6, middle - 6, 12, 12, white, white, white, alpha);

			// Mute and volume
			var speaker = width - 116;
			addRect(speaker, middle - 4, 6, 8, white, white, white, alpha);
			addTriangle(speaker + 4, middle - 1, speaker + 13, middle - 9, speaker + 13, middle + 9, white, white, white, alpha);
			addTriangle(speaker + 4, middle + 1, speaker + 13, middle + 9, speaker + 4, middle - 1, white, white, white, alpha);

			if (muted)
			{
				addLine(speaker + 16, middle - 6, speaker + 24, middle + 6, 2, alpha);
				addLine(speaker + 16, middle + 6, speaker + 24, middle - 6, 2, alpha);
			}

			var volumeLeft = width - 86;
			var volumeWidth = 70;
			var volume = muted ? 0 : gain;
			addRect(volumeLeft, middle - 2, volumeWidth, 4, 1, 1, 1, 0.25 * alpha);
			addRect(volumeLeft, middle - 2, volumeWidth * volume, 4, white, white, white, alpha);
		}

		if (uiVertices.length == 0) return;

		gl.useProgram(uiProgram);
		gl.uniformMatrix4fv(uiMatrixUniform, false, matrix);
		gl.enable(gl.BLEND);
		gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

		gl.bindBuffer(gl.ARRAY_BUFFER, uiBuffer);
		gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(uiVertices), gl.DYNAMIC_DRAW);
		gl.enableVertexAttribArray(uiPositionAttribute);
		gl.enableVertexAttribArray(uiColorAttribute);
		gl.vertexAttribPointer(uiPositionAttribute, 2, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 0);
		gl.vertexAttribPointer(uiColorAttribute, 4, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);
		gl.drawArrays(gl.TRIANGLES, 0, Std.int(uiVertices.length / 6));
		gl.disableVertexAttribArray(uiPositionAttribute);
		gl.disableVertexAttribArray(uiColorAttribute);
		gl.disable(gl.BLEND);
	}

	private function drawVideo(gl:WebGLRenderContext, matrix:Matrix4):Void
	{
		var rect = getVideoRect();
		var left = rect[0], top = rect[1], right = rect[0] + rect[2], bottom = rect[1] + rect[3];

		// Texture frames start with the top row of the picture
		var data = [

			right, bottom, 1, 1,
			 left, bottom, 0, 1,
			right,    top, 1, 0,
			 left,    top, 0, 0

		];

		gl.useProgram(videoProgram);
		gl.uniformMatrix4fv(videoMatrixUniform, false, matrix);

		gl.activeTexture(gl.TEXTURE0);
		#if (js && html5)
		gl.bindTexture(gl.TEXTURE_2D, videoTexture);
		#else
		gl.bindTexture(gl.TEXTURE_2D, frame.texture);
		#end

		gl.bindBuffer(gl.ARRAY_BUFFER, videoBuffer);
		gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(data), gl.DYNAMIC_DRAW);
		gl.enableVertexAttribArray(videoPositionAttribute);
		gl.enableVertexAttribArray(videoTexCoordAttribute);
		gl.vertexAttribPointer(videoPositionAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 0);
		gl.vertexAttribPointer(videoTexCoordAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);
		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
		gl.disableVertexAttribArray(videoPositionAttribute);
		gl.disableVertexAttribArray(videoTexCoordAttribute);
	}

	private function getControlsAlpha():Float
	{
		if (video == null) return 0;
		if (!video.playing || seeking || settingVolume) return 1;

		// Keep the bar while the mouse is over it, otherwise fade it out
		if (mouseY >= window.height - BAR_HEIGHT && mouseY < window.height) return 1;

		var idle = Timer.stamp() - lastMouseMove;
		return Math.max(0, Math.min(1, (HIDE_DELAY - idle) / 0.5));
	}

	private function getSeekLeft():Float
	{
		return 140;
	}

	private function getSeekRight():Float
	{
		return window.width - 136;
	}

	private function getVideoRect():Array<Float>
	{
		// Fit the video inside the window, keeping its shape
		var scale = Math.min(window.width / video.width, window.height / video.height);
		var width = video.width * scale;
		var height = video.height * scale;

		return [(window.width - width) / 2, (window.height - height) / 2, width, height];
	}

	private function initGL(gl:WebGLRenderContext):Void
	{
		var precision = #if !desktop "precision mediump float;" #else "" #end;

		videoProgram = GLProgram.fromSources(gl, "attribute vec2 aPosition;
			attribute vec2 aTexCoord;
			varying vec2 vTexCoord;
			uniform mat4 uMatrix;

			void main(void) {
				vTexCoord = aTexCoord;
				gl_Position = uMatrix * vec4(aPosition, 0.0, 1.0);
			}", precision + "varying vec2 vTexCoord;
			uniform sampler2D uImage0;

			void main(void) {
				gl_FragColor = vec4(texture2D(uImage0, vTexCoord).rgb, 1.0);
			}");

		videoPositionAttribute = gl.getAttribLocation(videoProgram, "aPosition");
		videoTexCoordAttribute = gl.getAttribLocation(videoProgram, "aTexCoord");
		videoMatrixUniform = gl.getUniformLocation(videoProgram, "uMatrix");
		gl.useProgram(videoProgram);
		gl.uniform1i(gl.getUniformLocation(videoProgram, "uImage0"), 0);
		videoBuffer = gl.createBuffer();

		uiProgram = GLProgram.fromSources(gl, "attribute vec2 aPosition;
			attribute vec4 aColor;
			varying vec4 vColor;
			uniform mat4 uMatrix;

			void main(void) {
				vColor = aColor;
				gl_Position = uMatrix * vec4(aPosition, 0.0, 1.0);
			}", precision + "varying vec4 vColor;

			void main(void) {
				gl_FragColor = vColor;
			}");

		uiPositionAttribute = gl.getAttribLocation(uiProgram, "aPosition");
		uiColorAttribute = gl.getAttribLocation(uiProgram, "aColor");
		uiMatrixUniform = gl.getUniformLocation(uiProgram, "uMatrix");
		uiBuffer = gl.createBuffer();

		#if (js && html5)
		videoTexture = gl.createTexture();
		gl.bindTexture(gl.TEXTURE_2D, videoTexture);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		#end
	}

	private function open(path:String):Void
	{
		// Texture frames stay on the GPU when the platform decodes there, so
		// drawing them is all that is left to do
		VideoSource.loadFromFile(path, TEXTURE).onComplete(function(source)
		{
			if (video != null) video.dispose();

			video = source;
			video.gain = muted ? 0 : gain;
			hasFrame = false;
			video.play();
		}).onError(function(error)
		{
			trace(error);
		});
	}

	private function seekTo(x:Float, force:Bool):Void
	{
		var progress = Math.max(0, Math.min(1, (x - getSeekLeft()) / (getSeekRight() - getSeekLeft())));
		seekPosition = progress * video.length;

		// Dragging seeks a few times a second rather than on every mouse move
		var now = Timer.stamp();

		if (force || now - lastSeek > 0.1)
		{
			video.currentTime = Std.int(seekPosition);
			lastSeek = now;
		}
	}

	private function setGain(value:Float):Void
	{
		gain = Math.max(0, Math.min(1, value));
		muted = false;
		if (video != null) video.gain = gain;
	}

	private function setVolumeAt(x:Float):Void
	{
		setGain((x - (window.width - 86)) / 70);
	}

	private function showControls():Void
	{
		lastMouseMove = Timer.stamp();
	}

	private function skip(milliseconds:Int):Void
	{
		if (video == null) return;
		video.currentTime = Std.int(Math.max(0, Math.min(video.length, video.currentTime + milliseconds)));
	}

	private function toggleMute():Void
	{
		muted = !muted;
		if (video != null) video.gain = muted ? 0 : gain;
	}

	private function togglePlayback():Void
	{
		if (video == null) return;

		if (video.playing) video.pause() else video.play();
	}

	// Drawing helpers, adding triangles of x, y, r, g, b, a

	private function addLine(x0:Float, y0:Float, x1:Float, y1:Float, thickness:Float, alpha:Float):Void
	{
		var dx = x1 - x0;
		var dy = y1 - y0;
		var length = Math.sqrt(dx * dx + dy * dy);
		var nx = -dy / length * thickness / 2;
		var ny = dx / length * thickness / 2;

		addTriangle(x0 + nx, y0 + ny, x1 + nx, y1 + ny, x0 - nx, y0 - ny, 1, 1, 1, alpha);
		addTriangle(x1 + nx, y1 + ny, x1 - nx, y1 - ny, x0 - nx, y0 - ny, 1, 1, 1, alpha);
	}

	private function addRect(x:Float, y:Float, width:Float, height:Float, r:Float, g:Float, b:Float, a:Float):Void
	{
		if (width <= 0 || height <= 0) return;

		addTriangle(x, y, x + width, y, x, y + height, r, g, b, a);
		addTriangle(x + width, y, x + width, y + height, x, y + height, r, g, b, a);
	}

	private function addTime(x:Float, y:Float, milliseconds:Float, alpha:Float):Float
	{
		// m:ss in seven-segment digits, returning where the text ends
		var seconds = Std.int(Math.max(0, milliseconds) / 1000);
		var text = Std.int(seconds / 60) + ":" + StringTools.lpad(Std.string(seconds % 60), "0", 2);

		for (i in 0...text.length)
		{
			var char = text.charAt(i);

			if (char == ":")
			{
				addRect(x + 1, y + 3, 2, 2, 1, 1, 1, alpha);
				addRect(x + 1, y + 8, 2, 2, 1, 1, 1, alpha);
				x += 6;
			}
			else
			{
				addDigit(x, y, Std.parseInt(char), alpha);
				x += 10;
			}
		}

		return x;
	}

	private function addDigit(x:Float, y:Float, digit:Int, alpha:Float):Void
	{
		// Segments a to g, as bits
		var segments = [0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F][digit];
		var w = 7.0, h = 12.0, t = 1.6;

		if (segments & 0x01 != 0) addRect(x, y, w, t, 1, 1, 1, alpha);
		if (segments & 0x02 != 0) addRect(x + w - t, y, t, h / 2, 1, 1, 1, alpha);
		if (segments & 0x04 != 0) addRect(x + w - t, y + h / 2, t, h / 2, 1, 1, 1, alpha);
		if (segments & 0x08 != 0) addRect(x, y + h - t, w, t, 1, 1, 1, alpha);
		if (segments & 0x10 != 0) addRect(x, y + h / 2, t, h / 2, 1, 1, 1, alpha);
		if (segments & 0x20 != 0) addRect(x, y, t, h / 2, 1, 1, 1, alpha);
		if (segments & 0x40 != 0) addRect(x, y + (h - t) / 2, w, t, 1, 1, 1, alpha);
	}

	private function addTriangle(x0:Float, y0:Float, x1:Float, y1:Float, x2:Float, y2:Float, r:Float, g:Float, b:Float, a:Float):Void
	{
		uiVertices.push(x0);
		uiVertices.push(y0);
		uiVertices.push(r);
		uiVertices.push(g);
		uiVertices.push(b);
		uiVertices.push(a);
		uiVertices.push(x1);
		uiVertices.push(y1);
		uiVertices.push(r);
		uiVertices.push(g);
		uiVertices.push(b);
		uiVertices.push(a);
		uiVertices.push(x2);
		uiVertices.push(y2);
		uiVertices.push(r);
		uiVertices.push(g);
		uiVertices.push(b);
		uiVertices.push(a);
	}
}
