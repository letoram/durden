Menu Selectors
==============
Menu selectors are simply profiles that can be used to generate customised
slices of various menu paths. These are dynamically generated each time they
are 'triggered'. They register in the /menus/ path, with the name matching
that of the filename of the .lua file itself.

The big caveat to this approach is that it is possible to create menus with
name collisions, and in the event on such collisions, the name of the entries
will be modified to have a _n where appended.

If the entry is a table of strings instead of a string, the first entry will
be treated as the new label (allowing renaming) and the second as the menu
path.

Some menus are referenced as part of other uielements, the included wsbtn,
for instance, is the default for right-click on statusbar workspace icons
as per the gconfig(ws_popup) key.

Example
=======
        return {
					"/global/open/terminal=",
					"/global/open/target",
					{"Dropdown", "/global/tools/dterm"}
				};
