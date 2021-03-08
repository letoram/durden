Keyboard Maps
=============

Initially, durden always tries to load the keymap with the name
'default' (if such a map exists)

These device configurations files are simply lua scripts that will be
scanned once upon startup. Each is a keymap that can be loaded manually
or bound to a normal meta+key-press combination. The actual format is
a table with a number of subtables and is best configured either through
the user-interface or with a tool to export other native keymaps.

Basic table layout:

    return {
        name = "mymap",
        map = {
            [plain]  = {[25] = "a"},,
            ["lalt"] = {[25] = "!"},
            ["ralt"] = {[21] = "@"},
            ["rctrl"] = {},
            ["lctrl"] = {},
            ["lmeta"] = {},
            ["rmeta"] = {},
            ["num"] = {}
        },
        symmap =
        {
            [58] = "ESCAPE"
        },
        dctbl =
        {
            [25] = {25, 49, "!"}
        }
        meta_1_sym = "COLON",
        meta_2_sym = "GREATER"
     }

The map table takes the subids of the translated device input table,
applies the platform tracked modifier and sets the 'utf8' field to
whatever codepoint it corresponds to.

The dctbl table walks the subtable of subids until the entire sequence
is provided, then adds/emits the utf8 codepoint at the end of the table.

This is used for combinatory marks, e.g. 'e' + '!' -> ~
if the chain is broken, the normal map applies for the initial character.

The symmap table remaps raw symbols, often used together with meta\_1\_sym
and meta\_2\_sym for application specific keybindings.

The symbolic names are lifted from SDL1.2, and shown in builtin/keyboard.lua
