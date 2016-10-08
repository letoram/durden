Keyboard Maps
=======

Initially, durden always tries to load the keymap with the name
'default' (if such a map exists)

These device configurations files are simply lua scripts that will be
scanned once upon startup. Each is a keymap that can be loaded manually
or bound to a normal meta+key-press combination. The actual format is
a table with a number of subtables and is best configured either through
the user-interface or with a tool to export other native keymaps.

Basic table layout:
 name (string) identifier for scripting
 map (table)
  subtable indexed by modifiers ("lshift", "rshift", "lctrl", "rctrl",
	"lalt", "ralt", "lmeta", "rmeta"} and then indexed by keyboard device
	subid field, e.g.

 map["lshift"][25] = "!" where the lookup value is a valid utf8-sequence.
 symmap (table)
  indexed by subid number and corresponds to a keysym from symtable.lua

 dctbl (table) diacretic sequences, currently unused but is used as a
 table indexed by subid and resolves to a table of additional subids with
 the last value being the utf8- sequence to resolve to:

 dctbl[25] = {25, 49, "!"};

