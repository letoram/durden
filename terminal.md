---
layout: default
---

# Terminal
The terminal, or better put, the command-line shell, is treated as a first
class citizen in both Arcan and Durden as it is one of the frameserver
'archetypes' that can receive special input, scheduling, sandboxing and
other profile- driven behaviors.

It can be activated via the <i>global/terminal</i> path, and is default-
bound to meta1-return.

The terminal exposes a number of custom binds for cursor, selection/clipboard
and other controls via the [input labels](input) system.

Most changes to the visual configuration are activated globally and immediately,
and cover properties like the active font, fallback/alternate glyph source,
font size, background opacity and so on. These properties can be be accessed
through the <i>global/config/terminal</i> menu path.

The default settings and behavior for the terminal archetype can be low-level
inspected via the <i>durden/atypes/terminal.lua</i> source.

# Terminal (group)
This mode looks and feels just like the terminal, but with one important
distinction. A unique connection point is generated for the terminal, and all
clients that are spawned within the terminal will be routed to that connection
point. Connections that are initiated via this connection point will be
attached as an 'alternate' window to the terminal window.

An 'alternate' window is one that shares the position and hierarchy with
another window, and can be swapped in and out. This assists in tiling modes as
you can now force clients to be inserted in a tab-like way and swap back and
forth without causing the mess that a new window insertion might.

A window that is in grouped mode gets additional menu paths in
<i>target/window/alternate</i> where each alternate window can be activated
by its current slot position (creation order), swapped with the last active
or cycled forward/backwards.
