---
layout: default
---
# Default Keybindings
If you look into the <i>keybindings.lua</i> file, you can see the default
keybindings that gets pushed into the database at first setup. After that
point, the arcan\_db tool should be used to modify the custk\_ and
custg\_ keybindings.

(m1 = meta1, m2 = meta2)

| key-combo       | action
| --------------- | -----------------------------------------------------
| m1 return       | spawn a new terminal
| m1 d            | show launch target menu
| m1 c            | cycle active display
| m1 g            | global menu
| m1 h            | target menu
| m1 arrow-right  | select window relative-right
| m1 arrow-up     | select window relative-up
| m1 arrow-left   | select window relative-left
| m1 arrow-down   | select window relative-down
| m1 m2 h         | swap with window relative-left
| m1 m2 j         | swap with window relative-up
| m1 m2 k         | swap with window relative-down
| m1 m2 l         | swap with window relative-right
| m1 m2 TAB       | set workspace mode TILE or switch tile-horiz/tile-vert
| m1 t            | set workspace mode TABBED
| m1 r            | set workspace mode FULLSCREEN
| m1 m2 y         | set workspace mode FLOAT
| m1 m            | merge/collapse tree-nodes in TILE
| m2 LEFT         | move window negative-X in FLOAT
| m2 RIGHT        | move window positive-X in FLOAT
| m2 UP           | move window negative-Y in FLOAT
| m2 DOWN         | move window positive-Y in FLOAT
| m1 0..9         | switch to workspace (num)
| m1 m2 0..9      | reassign selected window to workspace (num)
| m1 m2 r         | rename workspace

# System Keys
The system keys are used in durden- UI interaction like the menu or binding
bars and are defined on the level of keysyms (<i>symtable.lua</i>).

| symbol          | action
| --------------- | -----------------------------------------------------
| MENU            | meta-1
| RSHIFT          | meta-2
| RETURN          | accept
| ESCAPE          | cancel
| UP              | next
| DOWN            | previous
| HOME            | move caret to beginning of input
| END             | move caret to end of input
| LEFT            | move caret one character left
| RIGHT           | move caret one character right
| DELETE          | delete character after caret
| BACKSPACE       | delete character before caret

# Future Changes
- Move keybindings into devmaps and allow switching sets at runtime
