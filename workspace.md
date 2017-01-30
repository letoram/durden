---
layout: default
---

# Workspace
Each workspace has a management mode that can be [tiling](tiling), tabbed,
vertical-tabbed, fullscreen or [float](float) - though there are pluginable
tools that can provide others, like [autolayout](autolay). You can switch
these around through the <i>global/workspace/layout</i> path.

On top of that, each workspace can have a background, and a name. The name
will be reflected in the workspace indicators as part of the statusbar.

A workspace belongs to a window manager, which in turn is tied to a display.
A window manager has access to ten slots, and when switching the active
workspace slot to one that has not been used, a new workspace will be created
with the default mode controlled by the <i>global/config/workspaces/default
mode</i> path.

If a workspace gets deselected without any windows, name or background set, it
will be destroyed by default. To change this behavior, you can look at the
<i>global/config/workspaces/autodelete</i> path.

With multiple displays, you can migrate a workspace to another display via
the <i>global/workspace/migrate</i> path. All windows within that workspace
will also receive an update with the density, resolution and similar
properties so density-aware windows can relayout and update accordingly.

If the backing display is disconnected, orphaned workspaces will be migrated
to the next available display and migrate back when the display re-appears. To
disable this behavior, change <i>global/config/workspace/autoadopt</i>.

# Window
Window behavior, layout and size vary with the workspace. A window consists of
a border area, a border, a canvas, a titlebar and a tag. Internally, more
properties are tracked such as type and origin. For tuning the visual
properties, see the page on [visuals](visual).

The window titlebar can be disabled on a per-window basis
(<i>target/titlebar/on,off</i>) or have a default enabled or disabled
policy through <i>global/config/visual/bars/hide titlebar</i> with an
optional exception for the float layout mode via the
<i>global/config/workspaces/float/force-titlebar</i> path.

Although the feature has not been UI mapped yet, it is possible to change the
buttons that are added as part of the titlebar. By default, the titlebar has
no buttons. By changing <i>autorun.lua</i> (user-defined code to run on
startup) you can run something like:

        durden_tbar_buttons("left", "#/window/destroy",
            string.char(0xe2) .. string.char(0x9c) .. string.char(0x96));

Which would add an 'x' symbol in the left button area for all titlebars.
When the button is clicked, the <i>target/window/destroy</i> menu path would
be called.

# Future Changes
- Titlebar button configuration added to menu
- Per window or per window-class titlebar custom buttons
