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
