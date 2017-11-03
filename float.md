---
layout: default
---

# Floating Layout

The floating workspace layout mode mimics the more common desktop window
management paradigm where windows are free 'floating' with the user dragging
the windows around to match his or her preferences.

Though you can, of course, manage floating mode with the mouse cursor, efforts
have been taken to make sure it can be controlled by other devices by binding
the following menu paths (target/window/):

- move relative: <i>move(px_x,px_y)</i>
- move absolute: <i>set(px_x,px_y)</i>
- resize absolute: <i>set(px_w,px_h)</i>
- specialized: <i>toggle fullscreen, toggle maximize</i>

The navigation key bindings such as select-switch up/down/left/right are
relative to the window position, so the switch is made based on the relative
distance between window switching positions.

The navigation key bindings like select-switch up/down/left/right are treated
positionally, so the switch is made based on the relative distance between
window switching positions.

Durden treats windows in float mode as having a history. This means that if you
switch back to float from a different mode, the last known float positions and
sizing ratios will be restored (if possible).

The cursor management follows the common pattern of double clicking the
titlebar to switch between maximized and normal, press-drag to move and and
click-drag the border to resize.

It is possible to force-enable titlebars only for float layout-mode. This
can be done through <i>global/settings/workspaces/float-titlebar</i>

# Spawn Controls
The tools/advfloat.lua script (if present) extends the floating layout mode
with additional features. One of them is spawn control, so that when a new
window is to be created, you have more interactive options for position and
size.

The added settings are registered under
<i>global/settings/workspaces/float/advfloat_spawn</i> and can be set to:

- click: window spawns with initial size at cursor position when clicked
- draw: cursor switches to draw-region mode which sets size and position
- auto: default, a position is selected automatically.

the Keyboard(attach, split, place) options uses the currently selected
window and your 'left/right/up/down' bindings to position and place the
window. <i>Attach</i> means that the window will be positionally and
life-cycle linked to the currently selected window. <i>Split</i> means
that the selected window will be shrunk by half in one axis so that the
old window and new window together share space.

# Future Changes
The float mode is treated with a lesser priority than the rest, but as the
durden development settles and drifts towards maintenance and upkeep, the
following features are planned to be added:

- Desktop Icons
- Configurable Titlebar Gestures
- Configurable Minimize Action (to icon, statusbar, ...)
- Definable Mouse-action regions (drag to edge to maximize etc.)
- Input forward to background source when no window is selected
- Alternative menu access UI (popup- style rather than HUD style)
- More efficient border-drawing
