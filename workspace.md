---
layout: default
---

# Workspace
Each workspace has a management mode that can be [tiling](tiling), tabbed,
vertical-tabbed, fullscreen or [float](float) - though there are pluginable
tools that can provide others, like [autolayout](autolay).

On top of that, each workspace can have a background, and a name. The name
will be reflected in the workspace swit

A workspace belongs to a window manager, which in turn is tied to a display.
A window manager has access to ten slots, and when switching the active
workspace slot to one that has not been used, a new workspace will be created
with the default mode controlled by the <i>global/config/workspaces/default
mode</i> path.

If a workspace gets deselected without any windows or background set, it
will be automatically deleted by default. To modify this behavior, you can
look at the <i>global/config/workspaces/autodelete</i>

# Window
Window behavior, layout and size vary with the workspace. A window consists of
a border area, a border, a canvas, a titlebar and a tag. Internally, more
properties are tracked such as type and origin. For tuning the visual
properties, see the page on [visuals](visual).

The window titlebar can be disabled on a per-window bases
(<i>target/titlebar/on,off</i>) or have a default enabled or disabled
policy through <i>global/config/

