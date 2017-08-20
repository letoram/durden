---
layout: default
---

# Floating Layout

The floating workspace layout mode mimics the more common desktop window
management paradigm where windows are free 'floating' with the user
dragging the windows around to match his or hers preferences.

Though you can, of course, manage floating mode with the mouse cursor, efforts
have been taken to make sure it can be controlled from the keyboard (i.e. the
menu).

With the <i>target/window/move-resize</i> menu path, you get access for
controls to:

- move relative: <i>move(px_x,px_y)</i>
- move absolute: <i>set(px_x,px_y)</i>
- resize absolute: <i>set(px_w,px_h)</i>
- specialized: <i>toggle fullscreen, toggle maximize</i>

The navigation key bindings like select-switch up/down/left/right are treated
positionally, so the switch is made based on the relative distance between
window switching positions.

Durden treats windows in float mode as having a history. This means that
if you switch back to float from a different mode, the last known float
positions and sizing ratios will be restored (if possible).

The cursor management is the common pattern of double clicking the titlebar
to switch between maximized and normal and click-drag the border to resize.

# Future Changes
The float mode is treated with a lesser priority than the rest, but as the
durden development settles and drifts towards maintenance and upkeep, the
following features are planned to be added:

- Draw-to-spawn like in prio
- Desktop Icons
- Configurable Minimize Action (to icon, statusbar, ...)
- Definable Drag Regions
- Input forward to background source when no window is selected
- Alternative menu access UI (popup- style rather than HUD style)
