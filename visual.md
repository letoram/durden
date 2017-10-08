---
layout: default
---

[Workspace Background](#workspace) [Fonts](#fonts) [Shaders](#shaders)
[Per Target Tuning](#target) [Mouse Cursor](#cursor) [Borders](#borders)
[Animations](#animations) [Slicing](#slicing) [UI scheme](#schemes)

# Visual Enhancements
Most parts of the user interface can be tuned to look more or less bland,
and almost all tuning can be accessed from [the menu](menu) from either the
<i>global/config/visual</i> path or the <i>target/video</i> path
with the exception of some minor details like the palette used to colorize
widget text (see <i>durden/gconf.lua</i>).

# Workspace Background <a name="workspace"/>
Workspace background image is set with the
<i>global/config/workspace/background and default-background</i> paths.
The default-background path changes the global default for newly created
workspaces. To unset, simply cancel the browser being spawned.

It is also possible to assign the contents of a window as a background image
source. This feature is accessed with the
<i>target/window/workspace-background</i> path.

# Fonts <a name="fonts"/>
The same font settings are used for all windows except terminals and
[TUI](https://github.com/letoram/arcan/wiki/TUI) clients. Font settings are
found via the <i>global/config/visual/font</i> menu path and covers the size,
hinting, typeface and a fallback. The fallback is used when a specific glyph
(for internationalization or emojii support) is not found in the main typeface.

As a security/safety feature, arcan limits font access to the ARCAN\_FONTPATH
namespace, which can be controlled as an startup environment variable
parameter.  It defaults to applname/fonts (so durden/fonts) in this case.

# Shaders <a name="shaders"/>
For more advanced configuration, it is also possible to associate UI
elements with a shader, with a few predefined roles and states for each UI
component. These can be found in the source tree as <i>durden/shaders/ui</i>
and cover some lua- defined metadata an a vertex/fragment step in GLSL120.

The uniforms defined in a shader can be accessed in-UI from
<i>global/config/visual/shaders/*target*/*shader state*</i>.

Values changed in this way do not currently persist, either change the default
values in the shader file, or activate the menu path through the
<i>durden/autorun.lua</i> file for the time being.

There are also shader groups for last-stage display corrections, per window
canvas scaling effects and workspace background.

# Slicing <a name="slicing"/>
For cases when you are only interested in a portion of a window, want a clone
of a window, optionally with different scaling behavior and so on, there's
the option to create a window slice. The feature can be found via
<i>target/window/slice_clone=Active</i> or <i>=Passive</i>. This switches the
mouse cursor to selection mode where you can select the region you want to
slice out. The difference between _active_ and _passive_ mode is that in
_active_ mode, all input that the window receives will be forwarded to the
source.

A trick that can be done here is to combine slicing with the _overlay tool_
in order to constantly keep track about some important part of a client with
minimal impact to your normal workflow.

# Per Target Tuning <a name="target"/>
Default settings for a window comes from its archetype profile. The accepted
profiles are found in the source tree at <i>durden/atypes/*.lua</i>. Media
and game clients, for instance, will have different default shader and scaling
behavior than terminals and text clients.

## Server-Side Scaling
The actual size of a window is partly determined by the workspace layout mode
and partly by the current scaling settings. <i>target/video/scaling</i> allows
you to switch between different sizing behaviors.

With <i>normal</i>, a window will prefer the client supplied dimensions, and in
tiling modes, force a downscale if the client exceeds the alloted size and
ignores sizing hints.

With <i>stretch</i> a window will use whatever size you set to it and the
client will be force-scaled to those dimensions.

<i>aspect</i> behaves like <i>stretch</i> but will maintain the width/height
ratio of the source transfer size.

With <i>client</i> a window will bias towards the dimensions a possible
connected client itself has provided, and the display dimension hint that
is sent to clients as a friendly suggestion will not be the user-set size
but rather the slot allocated maximum.

## Custom Post-processing
There is a number of post processing shaders that can be applied to adjust
or filter colors, and for more advanced effects e.g. content-aware upscaling
of low-resolution data sources. The available ones can be found via the
<i>target/video/shader</i> path and are stored in the <i>shaders/simple</i>
path in the source repository.

## Dedicated Fullscreen
In performance and latency- sensitive applications, it is possible to forego
compositing, saving precious video memory bandwidth and, if input/output
formats match, route a client buffer to scanout directly. This can be toggled
via  <i>target/video/advanced/source fullscreen</i>, best combined with a
more aggressive synchronization strategy (Check [display management](displays)
for more details).

## Density Override
It is also possible to override the expected output on a per-display or a
per-window basis. This is useful in cases where you'd want the contents of a
(density-aware client) to appear bigger or smaller.
Normally, the client gets these values based on the display it is currently
bound to, but you can force different values via the <i>target/video/advanced/density_override</i> path.

# Mouse Cursor <a name="cursor"/>
There are three options that affect the visual look of the mouse cursor.

The first is the scale parameter, controlled by
<i>global/config/visual/mouse scale</i>. The second is the reveal animation
from <i>global/input/mouse/reveal,hide</i> that spawns little green squared
when returning from a hidden state.

The last is the local mouse state, which is partly controlled by the client
(it can send hints) or forced by your own hand through
<i>target/input/mouse/cursor</i> where you can force-hide the cursor on a
client that insists on software rendering its own.

# Borders <a name="borders"/>
Window border decorations are split in two parameters: border area and border
thickness. They are accessed via <i>global/config/visual/border area and border
thickness</i> respectively. The visual effect itself is controlled via the
<i>shaders/ui/border.lua</i> shader.

<i>Border area</i> covers the entire space that will be reserved, and
<i>border thickness</i> the actual size of the visible border itself. This
separation is to allow for gaps between tiles in tiling workspace mode, but
also effects the "drag-resize" mouse state activation regions.

# Animations <a name="animations"/>
Durden distinguishes between animations and transitions. Animations cover
the small effects, like the path indicators in the menu. Transitions cover
larger shifts from switching between workspaces and going between workspace
view and the menu HUD.

Animation speed can be tuned via the
<i>global/config/visual/animation speed</i> setting. There is also a separate
window animation speed property that, if set, adds animations to window
resizing, movement and swapping when in tile mode and in float mode.

The 'switch workspaces' transition effect can be controlled from the
<i>global/config/visual/transition-in,out</i> and you can have different
behavior for the workspace that is leaving and the workspace that is entering.

The speed is controlled from the <i>global/config/visual/transition speed</i>.

# Schemes <a name="schemes"/>
Visual schemes are profiles that are scanned on startup from the
<i>devmaps/schemes</i> filesystem path. They can be applied globally, per
display, per workspace or for a single window. Arbitrary menu paths for both
the global and the target menu namespace can be added, and also forward color
scheme information to clients that support that feature. The idea is to provide
more comprehensive presets to mimic other desktop environments and let you
dynamically switch between different schemes. See the default.lua profile for
an example. This profile is also activated by the included autorun.lua startup
script.

This is an advanced feature that may terminate or render the current session
useless if you are not careful. There is no filtering of which menu paths that
can be activated, but the main intent is to batch actions that changes the
visual/interactive profile in a non-destructive way.

# Future Changes
- Shader lookup texture support
- Window canvas contents as lookup texture input
- Icon support, multi-channel signed distance fields
- Loader for RetroArch shader format
- Switchable mouse cursor themes
- Border-area shadow controls
- Multipass target- shader effects
- Consistent settings persistance
- Mouse reveal/hide effect control
- Invisible 'padding' windows for non-uniform tiling mode gaps
- Workspace-mode sensitive border configuration
