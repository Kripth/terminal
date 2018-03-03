Colors, formatting and utilities for the terminal.

[![DUB Package](https://img.shields.io/dub/v/terminal.svg)](https://code.dlang.org/packages/terminal)
[![Build Status](https://travis-ci.org/Kripth/terminal-utils.svg?branch=master)](https://travis-ci.org/Kripth/terminal-utils)

## Usage

The module `terminal` contains everything needed to use the library.

The class `Terminal` uses a `File` (`stdout` by default) to perform the actions.

### Title

The console's title can be obtained using the `title` property (Windows only) and set using the same property.

```d
auto terminal = new Terminal();
terminal.title = "My Terminal";
version(Windows) assert(terminal.title == "My Terminal");
```

### Size

The terminal's size (width and height) can be obtained through the `size` property.

```d
auto terminal = new Terminal();
auto size = terminal.size;
assert(size.columns == terminal.width);
assert(size.rows == terminal.height);
```

### Colors and formatting

Colors and formatting can be changed using direct properties or directly in the `Terminal`'s `write` and `writeln` functions.

```d
terminal.background = Color.black;
terminal.foreground = Color.white;
terminal.italic = true;
terminal.writeln("White on black!");
terminal.reset();
```

The color can be changed directly using the `background` and `foreground` properties, setting them to a value from the `Color` enum or an array of 3 bytes (24-bit color).
The `Color.reset` value resets the background or the foreground to its original value.

Available colors:
- black
- red
- green
- blue
- yellow
- magenta
- cyan
- lightGray
- gray
- brightRed
- brightGreen
- brightBlue
- brightYellow
- brightMagenta
- brightCyan
- white

Available formatting (support may vary between various terminals):
- bold
- italic
- strikethrough
- underlined
- overlined
- inversed

```d
terminal.writelnr(Background(Color.black), Foreground(Color.white), Underlined.yes, "Underlined white on black!");
terminal.writelnr(Bold.yes, Foreground(255, 0, 0), "Bold red using 16m colors! ", Bold.no, "Just red.");
terminal.writelnr(Foreground(Color.green), "green text, ", reset, "default text");
```
