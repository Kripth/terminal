﻿/*
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
module terminalcolor;

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

	alias color_t = ubyte;

	enum Color : ubyte {

		black = 30,
		red = 31,
		green = 32,
		blue = 33,
		yellow = 34,
		magenta = 35,
		cyan = 36,
		lightGray = 37,
		gray = 90,
		brightRed = 91,
		brightGreen = 92,
		brightBlue = 93,
		brightYellow = 94,
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

private enum formats = ["bold", "strikethrough", "underlined", "italic", "inversed"];

mixin({

	import std.string : capitalize;

	string ret;
	foreach(format ; formats) {
		ret ~= "alias " ~ capitalize(format) ~ "=Flag!`" ~ format ~ "`;";
	}
	return ret;

}());

alias Reset = Flag!"reset";

/**
 * Resets the colours and the formatting.
 */
enum RESET = Reset.yes;

/// ditto
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
	
		private HANDLE handle;
		private CONSOLE_SCREEN_BUFFER_INFO sbi;

		private Attribute original, current;

		private bool uses256 = false;

	}

	public this(File file=stdout) {

		_file = file;

		version(Windows) {

			this.handle = file.windowsHandle;
			CONSOLE_SCREEN_BUFFER_INFO csbi;
			GetConsoleScreenBufferInfo(this.handle, &csbi);

			// get default colours/formatting
			this.original = Attribute(csbi.wAttributes);
			this.current = Attribute(csbi.wAttributes);

		} else {

			//TODO get terminal name and check 256-color support

		}

	}

	// ------
	// titles
	// ------

	/**
	 * Gets the console's title.
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

	public @property string title(string title) {
		version(Windows) {
			if(title.length > MAX_PATH) title = title[0..MAX_PATH];
			SetConsoleTitleA(toStringz(title));
			return title;
		} else {
			//TODO
			return "";
		}
	}

	// -------
	// colours
	// -------

	public alias foreground = colorImpl!("foreground", 0);

	public alias background = colorImpl!("background", 10);

	protected template colorImpl(string type, int add) {

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

	public alias strikethrough = formatImpl!(9, 29);

	public alias underlined = formatImpl!(4, 24, "underscore");

	public alias italic = formatImpl!(3, 23);

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
		SetConsoleTextAttribute(this.handle, current.attributes);
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

	writeln("TITLE: ", terminal.title);
	terminal.title = "terminal-color's unittest";

	terminal.foreground = Color.brightRed;
	writeln("RED TEXT!");
	writeln("I SAID RED!!!");

	terminal.background = Color.green;
	writeln("RED TEXT, GREEN BACKGROUND");

	terminal.background = Color.reset;
	writeln("BACKGROUND WAS RESETTED");

	terminal.underlined = true;
	writeln("UNDERLINED!!!");
	assert(terminal.underlined);

	terminal.bold = false;
	assert(terminal.underlined);

	terminal.reset();
	writeln("DEFAULT COLOURS");

	terminal.foreground = Color.white;
	terminal.underlined = true;
	writeln("UNDERLINED WHITE");

	terminal.underlined = false;
	terminal.bold = true;
	writeln("NOT UNDERLINED, BUT BOLD");

	terminal.reset();
	writeln("RESETTED");

	terminal.foreground = Color.white;
	terminal.background = Color.black;
	writeln("WHITE ON BLACK");

	terminal.inversed = true;
	writeln("NOW INVERSED");

	terminal.reset();

	terminal.writelnr("Writing", Foreground(Color.green), Underlined.yes, " from", Underlined.no, Foreground(Color.black), " the", Foreground(Color.brightRed), " terminal");
	terminal.writelnr("Using ", Background(Color.white), Foreground(255, 0, 255), Bold.yes, "violet", RESET, " from writeln");

	terminal.foreground = Color.brightGreen;
	write("TEST");
	terminal.foreground = Color.white;
	writeln("WHITE");

	terminal.reset();

	terminal.writelnr(Italic.yes, "This could be italic");
	terminal.writelnr(Strikethrough.yes, "This could have a line in the middle");

	writeln();

	// test RGB
	terminal.foreground = [255, 0, 255];
	writeln("TEST RGB");

	writeln();
	terminal.reset();

}
