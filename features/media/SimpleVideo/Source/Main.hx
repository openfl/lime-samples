package;

import haxe.Timer;
import lime.app.Application;
import lime.app.FrameProfile;
import lime.app.UncapMode;
import lime.app.VSyncMode;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLFramebuffer;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLUniformLocation;
import lime.graphics.RenderContext;
import lime.graphics.WebGLRenderContext;
import lime.math.Matrix4;
import lime.media.VideoClockMode;
import lime.media.VideoColorMatrix;
import lime.media.VideoFrame;
import lime.media.VideoFrameFormat;
import lime.media.VideoSource;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.MouseButton;
import lime.utils.Float32Array;
import samples.FPSCounter;

/**
	A small video player.

	Click the video or press space to pause and resume. The bar at the bottom
	seeks, shows the time and sets the volume, and fades away during playback.
	The arrow keys skip and change the volume, M mutes, and F or a double click
	switches to full screen. Drop a video file on the window to play it.

	On native targets, R switches how frames reach the screen, and the window
	title shows which, along with how many frames were dropped:

	- Texture: the platform decodes into a GPU texture where it can, which is
	  drawn as it is, and Lime uploads the frame for it where it cannot
	- YUV shader: the NV12 planes of each frame are uploaded, and a shader
	  converts them to RGB as they are drawn
	- GPU composite: the planes are converted to an RGB texture first, which is
	  then drawn, as a frame used more than once would be
	- CPU upload: each frame is converted to RGBA on the CPU and uploaded

	C switches what the clock follows: the sound, smoothly (smooth), the sound
	as it is heard (audio), the sound between mixes (interpolated), or the
	system timer, with the sound kept in step (monotonic). T switches the
	frame rate the window is capped at, up to 1000 or uncapped, and the
	counter in the corner shows the rate reached. Uncapped also turns vertical
	sync off, which would hold the rate to the display's.
**/
class Main extends Application
{
	private static inline var BAR_HEIGHT = 44;
	private static inline var HIDE_DELAY = 2.5;

	private static var CLOCK_MODES:Array<VideoClockMode> = [VideoClockMode.SMOOTH, VideoClockMode.AUDIO, VideoClockMode.INTERPOLATED, VideoClockMode.MONOTONIC];
	private static var CLOCK_NAMES = ["smooth", "audio", "interpolated", "monotonic"];
	// 0 is uncapped
	private static var FRAME_RATES = [30, 60, 120, 240, 1000, 0];
	private static var RENDER_FORMATS:Array<VideoFrameFormat> = [VideoFrameFormat.TEXTURE, VideoFrameFormat.NV12, VideoFrameFormat.NV12, VideoFrameFormat.RGBA];
	private static var RENDER_NAMES = ["Texture", "YUV shader", "GPU composite", "CPU upload"];

	private static inline var RENDER_TEXTURE = 0;
	private static inline var RENDER_YUV_SHADER = 1;
	private static inline var RENDER_GPU_COMPOSITE = 2;
	private static inline var RENDER_CPU_UPLOAD = 3;

	private var clockMode:Int;
	private var frame:VideoFrame;
	private var cappedVSyncMode:VSyncMode;
	private var gain:Float;
	private var hasFrame:Bool;
	private var lastClick:Float;
	private var lastMouseMove:Float;
	private var lastSeek:Float;
	private var loads:Int;
	private var mouseX:Float;
	private var mouseY:Float;
	private var muted:Bool;
	private var renderPath:Int;
	private var seekPosition:Float;
	private var seeking:Bool;
	private var settingVolume:Bool;
	private var title:String;
	private var video:VideoSource;

	private var chromaTexture:GLTexture;
	private var compositeFramebuffer:GLFramebuffer;
	private var compositeHeight:Int;
	private var compositeTexture:GLTexture;
	private var compositeWidth:Int;
	private var lumaTexture:GLTexture;
	private var uiBuffer:GLBuffer;
	private var uiColorAttribute:Int;
	private var uiMatrixUniform:GLUniformLocation;
	private var uiPositionAttribute:Int;
	private var uiProgram:GLProgram;
	private var uiVertices:Array<Float>;
	private var uploadHeight:Int;
	private var uploadWidth:Int;
	private var videoBuffer:GLBuffer;
	private var videoMatrixUniform:GLUniformLocation;
	private var videoPositionAttribute:Int;
	private var videoProgram:GLProgram;
	private var videoTexCoordAttribute:Int;
	private var videoTexture:GLTexture;
	private var yuvMatrixUniform:GLUniformLocation;
	private var yuvOffsetUniform:GLUniformLocation;
	private var yuvPositionAttribute:Int;
	private var yuvProgram:GLProgram;
	private var yuvTexCoordAttribute:Int;
	private var yuvTransformUniform:GLUniformLocation;

	public function new()
	{
		super();

		clockMode = 0;
		frame = new VideoFrame();
		gain = 1;
		lastClick = 0;
		lastMouseMove = Timer.stamp();
		lastSeek = 0;
		loads = 0;
		mouseX = -1;
		mouseY = -1;
		renderPath = RENDER_TEXTURE;
		seekPosition = 0;
		uiVertices = [];
	}

	public override function onWindowCreate():Void
	{
		new FPSCounter(window);
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

			#if !(js && html5)
			case R:
				setRenderPath((renderPath + 1) % RENDER_NAMES.length);

			case C:
				setClockMode((clockMode + 1) % CLOCK_MODES.length);

			case T:
				setFrameRate();
			#end

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

		title = window.title;

		var path = "assets/lime.mp4";

		#if sys
		for (arg in Sys.args())
		{
			if (!StringTools.startsWith(arg, "-")) path = arg;
		}
		#end

		open(path, 0, true);
	}

	public override function onWindowDropFile(file:String):Void
	{
		open(file, 0, true);
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
					#else
					uploadFrame(gl);
					#end
				}

				gl.viewport(0, 0, Std.int(window.width * window.scale), Std.int(window.height * window.scale));
				gl.clearColor(0, 0, 0, 1);
				gl.clear(gl.COLOR_BUFFER_BIT);

				var matrix = new Matrix4();
				matrix.createOrtho(0, window.width, window.height, 0, -1000, 1000);

				if (hasFrame) drawVideo(gl, matrix);
				if (video != null) drawControls(gl, matrix);

				updateTitle();

			default:
		}
	}

	private function composite(gl:WebGLRenderContext):Void
	{
		// Converts the planes into an RGB texture the size of the frame, once,
		// which can then be drawn like any other texture
		if (compositeFramebuffer == null)
		{
			compositeFramebuffer = gl.createFramebuffer();
			compositeTexture = createTexture(gl);
		}

		gl.bindTexture(gl.TEXTURE_2D, compositeTexture);

		if (compositeWidth != frame.width || compositeHeight != frame.height)
		{
			gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, frame.width, frame.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
			compositeWidth = frame.width;
			compositeHeight = frame.height;
		}

		gl.bindFramebuffer(gl.FRAMEBUFFER, compositeFramebuffer);
		gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, compositeTexture, 0);
		gl.viewport(0, 0, frame.width, frame.height);

		// The texture keeps the top row of the picture first, as frames do
		var matrix = new Matrix4();
		matrix.createOrtho(0, frame.width, 0, frame.height, -1000, 1000);
		drawYUV(gl, matrix, 0, 0, frame.width, frame.height);

		gl.bindFramebuffer(gl.FRAMEBUFFER, null);
	}

	private function createTexture(gl:WebGLRenderContext):GLTexture
	{
		var texture = gl.createTexture();
		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		return texture;
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

	private function drawQuad(gl:WebGLRenderContext, positionAttribute:Int, texCoordAttribute:Int, left:Float, top:Float, right:Float, bottom:Float):Void
	{
		// Texture frames start with the top row of the picture
		var data = [

			right, bottom, 1, 1,
			 left, bottom, 0, 1,
			right,    top, 1, 0,
			 left,    top, 0, 0

		];

		gl.bindBuffer(gl.ARRAY_BUFFER, videoBuffer);
		gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(data), gl.DYNAMIC_DRAW);
		gl.enableVertexAttribArray(positionAttribute);
		gl.enableVertexAttribArray(texCoordAttribute);
		gl.vertexAttribPointer(positionAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 0);
		gl.vertexAttribPointer(texCoordAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);
		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
		gl.disableVertexAttribArray(positionAttribute);
		gl.disableVertexAttribArray(texCoordAttribute);
	}

	private function drawVideo(gl:WebGLRenderContext, matrix:Matrix4):Void
	{
		var rect = getVideoRect();

		#if !(js && html5)
		if (renderPath == RENDER_YUV_SHADER)
		{
			drawYUV(gl, matrix, rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3]);
			return;
		}
		#end

		gl.useProgram(videoProgram);
		gl.uniformMatrix4fv(videoMatrixUniform, false, matrix);

		gl.activeTexture(gl.TEXTURE0);
		#if (js && html5)
		gl.bindTexture(gl.TEXTURE_2D, videoTexture);
		#else
		if (renderPath == RENDER_GPU_COMPOSITE) gl.bindTexture(gl.TEXTURE_2D, compositeTexture);
		else if (renderPath == RENDER_CPU_UPLOAD) gl.bindTexture(gl.TEXTURE_2D, videoTexture);
		else gl.bindTexture(gl.TEXTURE_2D, frame.texture);
		#end

		drawQuad(gl, videoPositionAttribute, videoTexCoordAttribute, rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3]);
	}

	private function drawYUV(gl:WebGLRenderContext, matrix:Matrix4, left:Float, top:Float, right:Float, bottom:Float):Void
	{
		gl.useProgram(yuvProgram);
		gl.uniformMatrix4fv(yuvTransformUniform, false, matrix);

		// Each frame says how its YCbCr samples become RGB
		var kr = 0.2126;
		var kb = 0.0722;

		if (frame.colorMatrix == VideoColorMatrix.BT601)
		{
			kr = 0.299;
			kb = 0.114;
		}
		else if (frame.colorMatrix == VideoColorMatrix.BT2020)
		{
			kr = 0.2627;
			kb = 0.0593;
		}

		var kg = 1 - kr - kb;

		// Video range spreads luma 16-235 and chroma 16-240 over the full range
		var lumaScale = frame.fullRange ? 1.0 : 255 / 219;
		var chromaScale = frame.fullRange ? 1.0 : 255 / 224;

		// Columns for Y, Cb and Cr
		gl.uniformMatrix3fv(yuvMatrixUniform, false, new Float32Array([
			lumaScale, lumaScale, lumaScale,
			0, -2 * (1 - kb) * kb / kg * chromaScale, 2 * (1 - kb) * chromaScale,
			2 * (1 - kr) * chromaScale, -2 * (1 - kr) * kr / kg * chromaScale, 0
		]));
		gl.uniform3f(yuvOffsetUniform, frame.fullRange ? 0 : 16 / 255, 128 / 255, 128 / 255);

		gl.activeTexture(gl.TEXTURE1);
		gl.bindTexture(gl.TEXTURE_2D, chromaTexture);
		gl.activeTexture(gl.TEXTURE0);
		gl.bindTexture(gl.TEXTURE_2D, lumaTexture);

		drawQuad(gl, yuvPositionAttribute, yuvTexCoordAttribute, left, top, right, bottom);
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

		var vertexSource = "attribute vec2 aPosition;
			attribute vec2 aTexCoord;
			varying vec2 vTexCoord;
			uniform mat4 uMatrix;

			void main(void) {
				vTexCoord = aTexCoord;
				gl_Position = uMatrix * vec4(aPosition, 0.0, 1.0);
			}";

		videoProgram = GLProgram.fromSources(gl, vertexSource, precision + "varying vec2 vTexCoord;
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

		// NV12 has a full size luma plane, and a quarter size plane of Cb and Cr
		// pairs, uploaded as luminance and alpha
		yuvProgram = GLProgram.fromSources(gl, vertexSource, precision + "varying vec2 vTexCoord;
			uniform sampler2D uLuma;
			uniform sampler2D uChroma;
			uniform mat3 uYUVMatrix;
			uniform vec3 uYUVOffset;

			void main(void) {
				vec3 yuv = vec3(texture2D(uLuma, vTexCoord).r, texture2D(uChroma, vTexCoord).ra) - uYUVOffset;
				gl_FragColor = vec4(clamp(uYUVMatrix * yuv, 0.0, 1.0), 1.0);
			}");

		yuvPositionAttribute = gl.getAttribLocation(yuvProgram, "aPosition");
		yuvTexCoordAttribute = gl.getAttribLocation(yuvProgram, "aTexCoord");
		yuvTransformUniform = gl.getUniformLocation(yuvProgram, "uMatrix");
		yuvMatrixUniform = gl.getUniformLocation(yuvProgram, "uYUVMatrix");
		yuvOffsetUniform = gl.getUniformLocation(yuvProgram, "uYUVOffset");
		gl.useProgram(yuvProgram);
		gl.uniform1i(gl.getUniformLocation(yuvProgram, "uLuma"), 0);
		gl.uniform1i(gl.getUniformLocation(yuvProgram, "uChroma"), 1);

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

		chromaTexture = createTexture(gl);
		lumaTexture = createTexture(gl);
		videoTexture = createTexture(gl);
	}

	private function open(path:String, time:Int, play:Bool):Void
	{
		// The format is chosen when a video opens, so switching how frames are
		// drawn opens it again, where it was. The last video plays on until the
		// next one is ready, and a video opened since makes this one stale.
		var load = ++loads;

		VideoSource.loadFromFile(path, RENDER_FORMATS[renderPath]).onComplete(function(source)
		{
			if (load != loads)
			{
				source.dispose();
				return;
			}

			if (video != null) video.dispose();

			video = source;
			video.clockMode = CLOCK_MODES[clockMode];
			video.gain = muted ? 0 : gain;
			hasFrame = false;
			uploadWidth = 0;
			uploadHeight = 0;

			if (time > 0) video.currentTime = time;
			if (play) video.play();
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

	private function setClockMode(index:Int):Void
	{
		clockMode = index;
		if (video != null) video.clockMode = CLOCK_MODES[clockMode];
		trace("Clock: " + CLOCK_NAMES[clockMode]);
	}

	private function setFrameRate():Void
	{
		// The next rate after the window's own, which can start at any rate
		var current = frameProfile == FrameProfile.Uncapped ? 0 : Std.int(window.frameRate);
		var rate = FRAME_RATES[(FRAME_RATES.indexOf(current) + 1) % FRAME_RATES.length];

		if (rate == 0)
		{
			// Uncapped also stops waiting for the display, which vertical sync does
			cappedVSyncMode = vsyncMode;
			vsyncMode = VSyncMode.Off;
			frameProfile = FrameProfile.Uncapped;
			frameOptions = {uncapMode: UncapMode.Hard};
		}
		else
		{
			if (frameProfile == FrameProfile.Uncapped)
			{
				frameOptions = {uncapMode: UncapMode.Off};
				frameProfile = FrameProfile.Balanced;
				if (cappedVSyncMode != null) vsyncMode = cappedVSyncMode;
			}

			window.frameRate = rate;
		}

		trace("Frame rate: " + (rate == 0 ? "uncapped" : Std.string(rate)));
	}

	private function setGain(value:Float):Void
	{
		gain = Math.max(0, Math.min(1, value));
		muted = false;
		if (video != null) video.gain = gain;
	}

	private function setRenderPath(index:Int):Void
	{
		renderPath = index;
		trace("Render path: " + RENDER_NAMES[renderPath]);
		if (video != null) open(video.source, video.currentTime, video.playing);
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

	private function updateTitle():Void
	{
		#if !(js && html5)
		if (video == null || title == null) return;

		// Says which keys switch each, for anyone trying the sample
		var text = title + " - " + RENDER_NAMES[renderPath] + " (R to switch) - " + CLOCK_NAMES[clockMode] + " clock (C to switch) - "
			+ (frameProfile == FrameProfile.Uncapped ? "uncapped" : Std.int(window.frameRate) + " fps cap") + " (T to switch) - "
			+ video.droppedFrames + " dropped";
		if (window.title != text) window.title = text;
		#end
	}

	private function uploadFrame(gl:WebGLRenderContext):Void
	{
		// Texture frames are already on the GPU
		if (frame.format == VideoFrameFormat.TEXTURE) return;

		// Rows of planes with odd widths are not padded
		gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);

		var resized = frame.width != uploadWidth || frame.height != uploadHeight;
		uploadWidth = frame.width;
		uploadHeight = frame.height;

		if (frame.format == VideoFrameFormat.RGBA)
		{
			gl.bindTexture(gl.TEXTURE_2D, videoTexture);
			var pixels = frame.data.subarray(0, frame.width * frame.height * 4);

			if (resized) gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, frame.width, frame.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
			else gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, frame.width, frame.height, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
			return;
		}

		var luma = frame.data.subarray(0, frame.chromaOffset);
		var chroma = frame.data.subarray(frame.chromaOffset, frame.chromaOffset + frame.chromaWidth * frame.chromaHeight * 2);

		gl.bindTexture(gl.TEXTURE_2D, lumaTexture);
		if (resized) gl.texImage2D(gl.TEXTURE_2D, 0, gl.LUMINANCE, frame.width, frame.height, 0, gl.LUMINANCE, gl.UNSIGNED_BYTE, luma);
		else gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, frame.width, frame.height, gl.LUMINANCE, gl.UNSIGNED_BYTE, luma);

		gl.bindTexture(gl.TEXTURE_2D, chromaTexture);
		if (resized) gl.texImage2D(gl.TEXTURE_2D, 0, gl.LUMINANCE_ALPHA, frame.chromaWidth, frame.chromaHeight, 0, gl.LUMINANCE_ALPHA, gl.UNSIGNED_BYTE, chroma);
		else gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, frame.chromaWidth, frame.chromaHeight, gl.LUMINANCE_ALPHA, gl.UNSIGNED_BYTE, chroma);

		if (renderPath == RENDER_GPU_COMPOSITE) composite(gl);
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
