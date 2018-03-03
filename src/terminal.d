/*
 * Copyright (c) 2018 Kripth
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
module terminal;

import std.stdio : File, stdout;
import std.string : fromStringz, toStringz, toUpper, capitalize;
import std.typecons : Flag;
import std.utf : toUTF8;

version(Windows) {

	import core.sys.windows.windows;

	enum ubyte RED = FOREGROUND_RED;
	enum ubyte GREEN = FOREGROUND_GREEN;
	enum ubyte BLUE = FOREGROUND_BLUE;
	enum ubyte BRIGHT = FOREGROUND_INTENSITY;

	alias color_t = ubyte;

	enum Color : color_t {

		black = 0,
		red = RED,
		green = GREEN,
		blue = BLUE,
		yellow = red | green,
		magenta = red | blue,
		cyan = green | blue,
		lightGray = red | green | blue,
		gray = black | BRIGHT,
		brightRed = red | BRIGHT,
		brightGreen = green | BRIGHT,
		brightBlue = blue | BRIGHT,
		brightYellow = yellow | BRIGHT,
		brightMagenta = magenta | BRIGHT,
		brightCyan = cyan | BRIGHT,
		white = lightGray | BRIGHT,

		reset = 255

	}

} else version(Posix) {

	version(linux) {

		struct winsize {

			ushort ws_row;
			ushort ws_col;
			ushort ws_xpixel;
			ushort ws_ypixel;

		}

		enum uint TIOCGWINSZ = 0x5413;
		extern(C) int ioctl(int, int, ...);

	} else {

		import core.sys.posix.sys.ioctl : winsize, TIOCGWINSZ, ioctl;

	}

	alias color_t = ubyte;

	enum Color : ubyte {

		black = 30,
		red = 31,
		green = 32,
		yellow = 33,
		blue = 34,
		magenta = 35,
		cyan = 36,
		lightGray = 37,
		gray = 90,
		brightRed = 91,
		brightGreen = 92,
		brightYellow = 93,
		brightBlue = 94,
		brightMagenta = 95,
		brightCyan = 96,
		white = 97,

		reset = 255

	}

} else {

	static assert(0);

}

private struct Ground(string _type) {

	enum reset = typeof(this)(Color.reset);

	union {

		color_t color;
		ubyte[3] rgb;

	}

	bool isRGB;

	this(color_t color) {
		this.color = color;
		isRGB = false;
	}

	this(ubyte[3] rgb) {
		this.rgb = rgb;
		isRGB = true;
	}

	this(ubyte r, ubyte g, ubyte b) {
		this([r, g, b]);
	}

}

alias Foreground = Ground!"foreground";

alias Background = Ground!"background";

private enum formats = ["bold", "italic", "strikethrough", "underlined", "overlined", "inversed"];

mixin({

	string ret;
	foreach(format ; formats) {
		ret ~= "alias " ~ capitalize(format) ~ "=Flag!`" ~ format ~ "`;";
	}
	return ret;

}());

alias Reset = Flag!"reset";

enum RESET = Reset.yes;

alias reset = RESET;

/**
 * Instance of a terminal.
 */
class Terminal {

	private File _file;

	version(Windows) {

		import std.bitmanip : bitfields;

		private union Attribute {
			
			WORD attributes;
			mixin(bitfields!(
				ubyte, "foreground", 4,
				ubyte, "background", 4,
				// WORD is 16 bits, 8 bits are left out
			));

			alias attributes this;
			
		}

		private Attribute original, current;

		private bool uses256 = false;

	}

	public this(File file=stdout) {

		_file = file;

		version(Windows) {

			CONSOLE_SCREEN_BUFFER_INFO csbi;
			GetConsoleScreenBufferInfo(file.windowsHandle, &csbi);

			// get default colours/formatting
			this.original = Attribute(csbi.wAttributes);
			this.current = Attribute(csbi.wAttributes);

			// check 256-colour support
			auto v = GetVersion();


		} else {

			//TODO get terminal name and check 256-color support

		}

	}

	public final pure nothrow @property @safe @nogc ref File file() {
		return _file;
	}

	// ------
	// titles
	// ------

	/**
	 * Gets the console's title.
	 * Only works on Windows.
	 */
	public @property string title() {
		version(Windows) {
			char[] title = new char[MAX_PATH];
			GetConsoleTitleA(title.ptr, MAX_PATH);
			return fromStringz(title.ptr).idup;
		} else {
			return "";
		}
	}

	/**
	 * Sets the console's title.
	 * The original title is usually restored when the program's execution ends.
	 * Returns: The console's title. On Windows it may be cropped if its length exceeds MAX_PATH.
	 * Example:
	 * ---
	 * terminal.title = "Custom Title";
	 * ---
	 */
	public @property string title(string title) {
		version(Windows) {
			if(title.length > MAX_PATH) title = title[0..MAX_PATH];
			SetConsoleTitleA(toStringz(title));
		} else {
			_file.write("\033]0;" ~ title ~ "\007");
			_file.flush();
		}
		return title;
	}

	// ----
	// size
	// ----

	private static struct Size {

		uint width;
		uint height;

		alias columns = width;
		alias rows = height;

	}

	/**
	 * Gets the terminal's width (columns) and height (rows).
	 * Example:
	 * ---
	 * auto size = terminal.size;
	 * foreach(i ; 0..size.width)
	 *    write("*");
	 * ---
	 */
	public @property Size size() {
		version(Windows) {
			CONSOLE_SCREEN_BUFFER_INFO csbi;
			GetConsoleScreenBufferInfo(_file.windowsHandle, &csbi);
			with(csbi.srWindow) return Size(Right - Left + 1, Bottom - Top + 1);
		} else {
			winsize ws;
			ioctl(_file.fileno, TIOCGWINSZ, &ws);
			return Size(ws.ws_col, ws.ws_row);
		}
	}

	public @property uint width() {
		return this.size.width;
	}

	public @property uint height() {
		return this.size.height;
	}

	// -------
	// colours
	// -------

	public alias foreground = colorImpl!("foreground", 0);

	public alias background = colorImpl!("background", 10);

	private template colorImpl(string type, int add) {

		public void colorImpl(color_t color) {
			version(Windows) {
				if(color == Color.reset) color = mixin("original." ~ type);
				mixin("current." ~ type) = color;
				this.update();
			} else {
				if(color == Color.reset) color = 39;
				this.update(color + add);
			}
		}

		public void colorImpl(ubyte[3] rgb) {
			_file.writef("\033[%d;2;%d;%d;%dm", 38 + add, rgb[0], rgb[1], rgb[2]);
			version(Windows) this.uses256 = true;
		}

		public void colorImpl(Ground!type ground) {
			if(ground.isRGB) mixin(type)(ground.rgb);
			else mixin(type)(ground.color);
		}

	}

	// ----------
	// formatting
	// ----------

	public alias bold = formatImpl!(1, 22);
	
	public alias italic = formatImpl!(3, 23);

	public alias strikethrough = formatImpl!(9, 29);

	public alias underlined = formatImpl!(4, 24, "underscore");
	
	public alias overlined = formatImpl!(53, 55, "grid_horizontal");

	public alias inversed = formatImpl!(7, 27, "reverse_video");

	private template formatImpl(int start, int stop, string windowsAttr="") {

		version(Windows) {

			// save an alias to the attribute's value
			private enum hasAttribute = windowsAttr.length > 0;
			static if(hasAttribute) private enum attribute = mixin("COMMON_LVB_" ~ windowsAttr.toUpper());

		}

		version(Posix) {

			// save the current state into a variable as it is not stored in an attribute
			private bool _active = false;

		}

		public @property bool formatImpl() {
			version(Windows) {
				static if(hasAttribute) return (current.attributes & attribute) != 0;
				else return false;
			} else {
				return _active;
			}
		}
		
		/// ditto
		public @property bool formatImpl(bool active) {
			version(Windows) {
				static if(hasAttribute) {
					if(active) current.attributes |= attribute;
					else current.attributes &= attribute ^ WORD.max;
					this.update();
					return active;
				} else {
					return false;
				}
			} else {
				this.update(active ? start : stop);
				return _active = active;
			}
		}

	}

	/**
	 * Resets the colour (foreground and background) and formatting.
	 */
	public void reset() {
		version(Windows) {
			current.attributes = original.attributes;
			this.update();
			if(this.uses256) {
				_file.write("\033[0m");
				this.uses256 = false;
			}
		} else {
			static foreach(format ; formats) {
				mixin(format) = false;
			}
			this.update(0); // reset colours
		}
	}
	
	version(Windows) private void update() {
		_file.flush();
		SetConsoleTextAttribute(_file.windowsHandle, current.attributes);
	}
	
	version(Posix) private void update(int ec) {
		_file.writef("\033[%dm", ec);
	}

	// -------------
	// write methods
	// -------------

	void write(E...)(E args) {
		foreach(arg ; args) {
			static if(is(typeof(arg) == Foreground)) {
				foreground = arg;
			} else static if(is(typeof(arg) == Background)) {
				background = arg;
			} else static if(is(typeof(arg) == Reset)) {
				reset();
			} else {
				mixin({
					string ret;
					foreach(format ; formats) {
						ret ~= "static if(is(typeof(arg) == " ~ capitalize(format) ~ ")){" ~ format ~ "=cast(bool)arg;}else ";
					}
					return ret ~ "_file.write(arg);";
				}());
			}
		}
	}

	void writeln(E...)(E args) {
		write(args, "\n");
	}

	void writelnr(E...)(E args) {
		writeln(args);
		reset();
	}

	~this() {
		//this.reset();
	}

}

unittest {

	import std.stdio;

	auto terminal = new Terminal();

	terminal.title = "terminal-color's unittest";

	// test rgb palette
	ubyte conv(int num) {
		return cast(ubyte)(num * 16);
	}
	foreach(r ; 0..16) {
		foreach(g ; 0..16) {
			foreach(b ; 0..16) {
				terminal.write(Background([conv(r), conv(g), conv(b)]), "  ");
			}
			writeln();
		}
		writeln();
	}
	
	// test foreground
	foreach(color ; __traits(allMembers, Color)) {
		terminal.foreground = mixin("Color." ~ color);
		write("@");
	}
	writeln();
	
	// test foreground
	foreach(color ; __traits(allMembers, Color)) {
		terminal.background = mixin("Color." ~ color);
		write(" ");
	}
	writeln();
	
	writeln();
	
	// test formats
	static foreach(format ; formats) {
		mixin("terminal." ~ format) = true;
		terminal.writelnr(format);
	}
	
	terminal.writelnr();

	// size
	writeln(terminal.size);

	writeln();

}
