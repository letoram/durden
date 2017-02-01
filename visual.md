---
layout: default
---

[Workspace Background](#workspace) [Fonts](#fonts) [Shaders](#shaders)
[Per Target Tuning](#target) [Mouse Cursor](#cursor) [Borders](#borders)
[Animations](#animations)

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

# Per Target Tuning <a name="target"/>
Default settings for a window comes from its archetype profile. The accepted
profiles are found in the source tree at <i>durden/atypes/*.lua</i>. Media
and game clients, for instance, will have different default shader and scaling
behavior than terminals and text clients.

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

You can also enable a post-processing shader via the
<i>target/video/shader</i> path.

If you activate <i>target/video/advanced/source fullscreen</i> these settings,
any shaders and filtering will be ignored in favor of direct mode. Check
[display management](displays) for more details.

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

# Borders <a name=borders"/>
Window border decorations are split in two parameters: border area and border
thickness. They are accessed via <i>global/config/visual/border area and border
thickness</i> respectively.

Area covers the entire space that will be reserved, and border area is
constrained to a subset of this space. This is to allow for gaps between
tiles in tiling workspace mode.

# Animations <a name="animations"/>
Durden distinguishes between animations and transitions. Animations cover
the small effects, like the path indicators in the menu. Transitions cover
larger shifts from switching between workspaces and going between workspace
view and the menu HUD.

Animation speed can be tuned via the
<i>global/config/visual/animation speed</i> setting.

The 'switch workspaces' transition effect can be controlled from the
<i>global/config/visual/transition-in,out</i> and you can have different
behavior for the workspace that is leaving and the workspace that is entering.

The speed is controlled from the <i>global/config/visual/transition speed</i>.

# Future Changes
- Privilege state and window meta-data associatd
- Shader lookup texture support
- Window canvas contents as lookup texture input
- Icon support, multi-channel signed distance fields
- Switchable mouse cursor themes
- Border-area shadow controls
- Multipass target- shader effects
- Consistent settings persistance
- Mouse reveal/hide effect control
- Invisible 'padding' windows for non-uniform tiling mode gaps
- Workspace-mode sensitive border configuration
