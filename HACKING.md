Introduction
------------

Durden as a code-base is relatively young in the sense that it is still
adding features at a rather quick pace. When that settles down, some of
the code is likely to be refactored - relying on structures that aren't
covered here is rather unwise, your extensions may break over time.

In addition to the APIs covered here, all the Lua functions that are in
Arcan also apply. See the main arcan code repository, the wiki, and the
doc/ folder (see mangen.rb for conversion to manpages) and the exercise
sets (in the wiki).

General Tips
------
Some of the standard Lua API is not included in Arcan, particularly the
functions that relate to loading code (replaced with system\_load), and
for modifying filesystem contents.

You can use the arcan\_lwa build (make sure to point to a database that
doesn't collide with your normal one) for running in nested mode, which
allows you to get closer to a REPL- style workflow, though an debugging
terminal will eventually be added to arcan itself.

Edge cases that are good for testing is using the system/reset path. It
will force a reload with adoption, which usually activates more complex
code-paths than normal operation - in both clients and durden itself.

Setting up timers to activate your feature, or activating it externally
while in some special state (like the HUD) through the menu via the IPC
control path (exec '/some/path/to/trigger' > durden/ipc/output) is also
a good way of finding bugs.

Using the system\_snapshot call to get a dump of the data model used to
render, along with image\_tracetag can also help to track down problems
you might've found.

For submitting patches, try and mimic the code-style, including some of
the oddities like parenthesis around if () statements, terminating ; on
end of statements and so on. Try and stick to normal extensions via the
tools/ drop-in system, if possible. Changes that affect behavior should
also cover updates and pull-requests against the gh-pages branch, where
applicable. If in doubt, check on the IRC channel first.

Testing
------
For any newly developed feature, figuring out what needs testing is not
an easy task but with some exceptions (multiple displays and in-recover
states), merely poking a path tend to be enough.

The larger states to consider, be sure to check with (when applicable):

 * fullscreen and dedicated fullscreen
 * vtab/htab (rearranges decorations)
 * float (hierarchies mostly ignored)
 * window with popups
 * tile and autolayout mode
 * multiple screens with different densities
 * multiple slices of a window
 * "special" clients, like wayland- ones (very different ruleset) etc.

Big Changes
------
As mentioned in the introduction, some of the code will be reworked in
the near future. A few of the planned changes include:

 * Refactor out the use of 'active\_display().selected', the context
   should always be provided as an arugment
 * Splitting up the larger suppl, tiler etc. script files
 * Extending menus and alerts with translations
 * Allowing for multiple- 'tiler.lua' and enforcing better separation,
   this is partially being done now with the VR- tool
 * Extending the shader interface for multi-pass work
 * Supporting multiple shader dialects

The translations will be kept seperate and act as replacements for the
label field in the menus and shouldn't impose much change at all as it
can be kept as an extension to the normal navigation. Help description
will be added through an additional field in the menu tables that will
return a user-readable string.

Filesystem Layout
------

The most developer- relevant files and folders are as follows:

## /atypes

Atypes is scanned at startup and covers special handlers and bindings
that are segment type dependent, different font- behavior for wayland
windows, for terminals, for x11 windows and so on.

Each atype is expected to return a table with the following fields:

    atype (string) - matching type of the segment, shouldn't collide
                     with what other files in this folder defines, so
                   a handler for an atype can be added only once
    default_shader (group, name) -
    action (table of tables) - custom menu entries that should be
                               added to the target menu for this type,
                               see the "Menu Integration" section
    props (table) - a list of window properties that will be projected
                    over the new window (see "Windows and Displays")
    dispatch (table of functions) - key indexed, where each key match
         the 'kind' field of an event in the event handler. This will
         override the default event handler for this kind/type.

## /shaders

Shaders are GPU based post-processing instructions. They are split in
subgroups based on what they are used for, like display effects, UI
elements and so on. Each shader is defined as a .lua file returning a
specially formatted table that should look something like this:

    return {
            version = 1,
                label = "User-visible name",
                filter = "none", -- can also be linear, bilinear
                uniforms = { -- user- configurable variables
                    myuniform = {
                            label = "My Uniform",
                                utype = "ff",
                                default = {1.0, 0.0}
                        }
                },
                frag = [[
                 uniform sampler 2D map_tu0;
                 uniform float obj_opacity;
                 uniform vec2 myuniform;
                 varying vec2 texco;
                 void main()
                 {
                     gl_FragColor = vec4(texture2D(map_tu0, texco), obj_opacity);
                 }
                ]]
        };

## /cursor

This folder contains cursor-sets, 'default' should always be available and
act as a fallback for any missing cursors defined but not found in the set
pointed to in gconf.lua

## /devmaps

This folder contains user-provided configuration maps for various devices,
ranging from keyboard to touchpad to LED controllers. They are interpreted
by iostatem.lua, symtable.lua and touchm.lua.

## /menus

Split up into the global and per window menu. These make out the user-I/O
exposed feature-set that can be bound to UI elements, keys, gestures, etc
All follow a similar structure for subtyping, naming and so on and is the
central layer for exposing features. See the 'Menu Integration' section.

Most menu system management code is in the menu.lua file with interactive
setup via dispatch.lua, external via ipc.lua and management code in suppl
.lua

## /tools

The tools path is scanned on load/reset and contain more generic anything
goes- scripts that the user can extend/remove at will without losing core
functionality. It is the primary recommended path for creating extensions
to share with others.

## /widgets

The widget path is scanned on load/reset. These are used for hooking into
the global and per-window HUD, primarily for providing helper information
to assist with configuration and so on. See the ' Widgets' section.

## autorun.lua

Executed after system has been brought up to a running state. Can be used
to setup more complicated autorun- behavior than what can be done through
normal config settings.

## display.lua

Contains the output display mapping and hotplug event handling, also sets
up and controls individual tiler instances (to be able to provide display
tailored window managers). See the 'Windows and Displays' section.

## ipc.lua

The external control- layer and statusbar integration protocol are both
implemented in ipc.lua

Clipboard
------

The clipboard is implemented in clipboard.lua. It can be programmatically
accessed via the CLIPBOARD global table and expose the following methods:

    add(source_vid:number, msg:string, multipart:bool)
            add a new message associated with the external clipboard data
                provider matched to the video-id 'source_vid'.

    set_monitor(monitor_function(ctx, msg, src) )
            register a clipboard monitor, this is a singleton and any
                pre-existing monitor will be disabled. monitor_function will
                be called every time something is added to the global clipboard,
                or with a 'nil' msg / src_vid when the monitor will be dropped.

    set_global(msg, src)
            add msg to the global clipboard, with src as a reference to the
                source, which can be a window, a clipboard-segment VID or a
                custom context.


It also has the following members:

    modes: table of key = {label, function(str) return str; end}
           that makes out the available user-selectable paste modes that
                     filter paste- operations.

        history_size (number): number of unique entries (limit), if the limit
                               is exceeded, items will be dropped in a oldest
                               first order.

        mpt_cutoff (number): limit to number of multipart- append operations
                             that a client are allowed to prepare before the
                                          entry is force-marked as finished.

Internationalisation
------
This is one part where Durden is the least developed. Fortunately, there
aren't that many places where it needs to be added in order to make
sense, but right now - this section mostly describes what need to change
and where- in order to get better internationalization support.

input is mostly covered, though a tool that act as IMEs are needed.

Text rendering is not advanced enough to account for shaping. This needs
to be fixed in the engine, not in these scripts.

Other than that, the real part is a tool that loads translation tables and
intercepts menu/ lookups for the label and description fields and replaces
with whatever is in the table.

Configuration
------

There is a global key/value registry that is used almost everywhere in the
codebase, gconf. It is possible for a widget or a tool to register key/val
pairs dynamically - otherwise a valid key and its type should first be set
in the 'defaults' table (gconf.lua) and exposed through a menu path.

The global configuration is persisted at shutdown, although a single entry
can also be force-synched to the arcan appl- database. The first time that
durden is being run, all the key/value pairs will be synched to the active
database, and will be fetched from there henceforth.

The database can be externally manipulated via the arcan\_db tool.

There are five main functions for dealing with the gconfig- system:

    gconfig_register(key, val) - dynamically register a key-value pair
        gconfig_set(key, val, force) - update an existing key, types must match
        gconfig_listen(key, id, fun) - invoke [fun] when [key] has been changed
        gconfig_get(key) -> val - retrieve the current value for a key
        gconfig_shutdown() - synch/store all the key/value pairs

Input-Routing
------

This is the most complicated and scattered subsystem around. The reason comes
from the sheer diversity of devices, as there is support for mice, keyboards,
gamepads, touchpads, touchscreens, external input injection and so on. Recall
the basic needs:

 1. The UI components need an understanding of when a UI function button is
    pressed.
 2. The selected window needs input, and may be a custom 'script-defined'
    window or an external client.
 3. External clients can provide metadata on higher level tags to assign
    inputs, these are unique to a particular client.
 4. Window Management, Keyboard Configuration etc. need to be bindable to
    shortcuts.
 5. Need to handle device failure, device hotplugging.
 6. Need to be able to switch between sets of input mappings (multi-languages)
 7. Need to be able to visually indicate various states.
 8. Need to support accessibility options and account for degrading hardware.
 9. Configuration persistence.
10. Different sets of inputs assigned to different users (cursors/selections)

For keyboards, there is also:
 1. Handle multiple translation tables,
 2. State bleeds between window switching.
 3. Handle synthetic repeats, platform/OS/hardware doesn't always provide
    repeat- information.
 4. Differentiate between multiple states, i.e. latched
    (caps/num/scroll lock), pressed, on-press, on-release, on-held.
 5. Fake delay-release ('sticky') keys.
 6. Absorb sequential inputs ('chords').
 7. Modifier states (shift, alt, ctrl, meta, ...).
 8. n-acretic sequences

For mice, there is also:
 1. Manage both absolute and relative pointer input, depending
    on platform/OS/hardware, only one or the other may be available.
 2. Manage both high and low samplerates.
 3. Minimize physical motion needed to acomplish pointing task.
 4. Being able to be simulated by a keyboard.
 5. Gestures : drag, drop, click, doubleclick, hover
 6. Velocity Information for velocity- dependent action and amplification
 7. Warping and locking/confining to a specific area.
 8. Hardware-accelerated cursors.
 9. Multiple-cursors.
10. Direct- mapping mouse input to a client for low latency paths.

For gamedevices, there is also:
 1. Calibrate/filter analog samples.
 2. Translate analog value regions into digital outputs.
 3. Simulate repeats.
 4. Match with indicator lights and audio outputs (haptics).
 5. Input Routing independent of window selection (redirection).

For touchscreen, there is also:
 1. Calibration, and to switch /detect changes in calibration levels
    (electrical / ambient environment affect quality of touch)
 2. On-screen keyboard.
 3. Gestures.
 4. High driver variation, some give stream of samples, others want
    to provide pre-processed abstract outputs.

Then there are exotic, but relevant, needs:
 1. Some clients need to provide input, such as remoting clients.
 2. Supporting custom external input- event producers.
 3. Positional devices (VR, ...)

And corner cases:
 1. Clients that implements their own understanding of repeats
 2. State-bleed between windows (select wnd1, press button, select
    wnd2, is button still pressed for wnd1? is it pressed for wnd2?)

Finding an input model that fits all of these is quite unpleasant,
and the details of what is currently present is spread out into its
individual sections.

Generic-Input Routing
------

As with anything arcan, the first part is the event entry point, mapped as
applname\_input. This has two global states, one implemented in the
durden\_normal\_input function, and the other in durden\_regionsel\_input.

The regionsel- function is used when the user needs to be queried for an
on-screen visual region, for operations like desktop sharing on OCR.

The normal\_input function:

 1. Feed hotplug events to durden\_iostatus\_handler
 2. Map to input-device ID specific handler (trackpads, ...)
 3. Inject into iostatem- (which deals with filtering and repeats)
 4. Forward to dispatch\_translate in dispatch.lua

**INCOMPLETE**

Keyboard Input
------

**INCOMPLETE**
(pending: see dispatch.lua, symtable.lua, devmaps/keyboard)

Main keyboard input is dealt with in dispatch\_translate as part of
dispatch.lua. Loading / application /switching of keymaps themselves
are

Game Device Input
------

**INCOMPLETE**
(pending:

Mouse Input
------

Most mouse controls are provided by mouse.lua, which is re-used by a lot
of different arcan projects. Its biggest caveat is probably the global
context, which makes it difficult to handle multiple mouse cursors at once.
See the 'Mouse API' section for more information on which functions it
exposes.

Mouse API
------

**INCOMPLETE**
(pending: see mouse.lua)

It setup using one of the following methods:

    mouse_setup(cvid, clayer, pickdepth, cachepick, hidden)
    mouse_setup_native(cvid, hot_x, hot_y)
    mouse_add_cursor(label, img, hot_x, hot_y)

Its state machine is updated by one of the following methods:

    mouse_input()
        mouse_button_input()
    mouse_absinput_masked(x, y, nofwd)
    mouse_absinput(x, y, nofwd)
    mouse_state_save(), mouse_state_restore(warp:boolean)
    mouse_tick()
        mouse_block()
        mouse_unblock()
        mouse_cursor_sf(x, y) - change the visible scale factor
        mouse_custom_cursor(table{
         hotspot_x : number, hotspot_y : number,
         vid
        })
        mouse_switch_cursor(label)
        mouse_select_begin
        mouse_select_end
        mouse_reveal_hook
        mouse_lockto(vid, function, warp, state)
        mouse_destroy() - drop all handlers, cursor and tuning

For querying state properties:

    mouse_over(vid) : boolean
        mouse_xy() : x, y - absolute position
        mouse_state() : table - get access to the raw state table

For debugging purposes, there are:

    mouse_handlercount() : number - returns number of registered handlers
        mouse_dumphandlers() : dumps all handlers as calls to warning()

Where the 'nofwd'

The most relevant bits are how to register and deregister a mouse handler:

    mouse_addlistener(listener, event-list) where the event-list represents
        the list of events that should be registered to this listener.

    required fields in the listener table:
           own => function(vid) : boolean - return true of the handler claims
                                              ownership of this vid or not
             name => string - identifier to assist with debugging

      and functions that match each entry in event-list.

    to de-register a mouse listener, use mouse_droplistener(listener) with
        the same table as reference that was used with mouse_addlistener.

The possible events are:
    click(

        listener is a table with key(event-name) => function.

        and event-list is a n-indexed table of events that should be associated
        with the listener (click, drag, drop, button, press, release, dblclick,
        hover, over, out)
        }, {"click", "dblclick"});

Menu Subsystem
------

**INCOMPLETE**
(pending:

Display Management
------

Each virtual display has an output rendertarget, an output display and a tiler.
The tiler is an instance of the window manager, which can be different for
different displays. Each tiler has a number of windows that are either pending
attachment or attached to a workspace.

**INCOMPLETE**
(pending: see display.lua)

Window Layout / Management
------

**INCOMPLETE**

The abstract 'Window' is the most complicated structure around and wasn't
designed as much as it evolved. A window is a container for clients, both
internal and external.

Properties marked with an (m) prefix indicates that it is part of a set that is
a dynamic property that may be unique to the client.

Static Properties:
name - unique identifier, typically wnd\_(incremenetalcounter)
cfg\_prefix - prefix for window or type used when loading values from db

Properties (probed, monitored and modified practically everywhere):
 (m) gain (float) - current audio gain
 (m) mouse -
 (m) last\_ms -
 (m) rate\_unlimited - don't limit mouse sample propagation
 (m) mouse\_lock\_center -
 (m) suspended - input / updates blocked
 (m) sz\_delta - delta- limiter for resize event forwarding
 (m) kbd\_period - how often held keys should be sent as repeated
 (m) kbd\_delay - how long time before repeats should be considered
 (m) allowed\_segments - type specific set of allowed subsegment types
 (m) save\_gain - per-window audio level
 (m) hint\_w, hint\_h (debug only) track last hint sent
 (m) color\_controls - if the client has access to custom color ramps or not
 (m) source\_audio - reference to aid of external process
 (ms) external - vid ref to external process
 (ms) titlebar\_id custom external titlebar store
 (m) bindings - set of symbol-key bindings for the specific type
 (m) labels - set of known labelhints
 (m) dispatch - symbol to action binding for this window
 (m) coreopt - client- unique key-val settings
 (m) atype - known/registered type
 (m) no\_recover\_attach - saved across script resets, won't get an attached wnd
 mouse\_lock (fun) - mouse event interceptor
 attach\_time - timestamp for when the window turned 'alive'
 in\_drag\_rz - window currently being interactively resized
 delete\_protect - blocks the destroy command
 input\_focus - (vid) popup
 temp\_suspend -
 clipboard\_block - never permit clipboard operations for this window
 mouse\_remap\_range - relative (0..1) region slice for mouse coordinates
 used when dealing with cropped, sliced or otherwise modified window setups.

Visual Properties (covers decorations and so on):
 (m) scalemode - what heuristic should be used to determine the size to send
 to the client and how the actual window size should be calculated.
 (m) title\_text - text to display in titlebar
 (m) cursor (string) - text name of current window cursor state
 (m) custom\_cursor (vid) - vid to client provided cursor image
 (m) font\_block (bool, func) - specialized font handler for window
 (m) last\_font (tbl{xx}) - (set of fonts last sent to client)
 (m) origo\_ll - indicate if the texture coordinates need to invert the t axis
 fullscreen - indicate if the window is in a fullscreen mode
 float\_dim - (tbl(num,num)) display size relative dimensions if in float mode
 (m) autocrop - (bool) calculate cropping texture coordinates
 on resize that is desynched to client
 (m) filtermode - (int) if any of the builtin texture filters should be applied
  pad (\_left, \_right, \_top, \_bottom - reserved space (pixels) used for
 decorations e.g. window physical size is canvas + pad-area.
 border\_w - symmetric (pixels) part of pad area consumed by border
 dispmask - tracks states for minimized, hidden, maximized, focused etc.
 that are used to indicate display state to a client
 effective\_w, effective\_h, max\_w, max\_h, x, y - position, size, limits
 weight, vweight - used as bias in tile layout
 hide\_titlebar (bool) - if the titlebar should be shown or not
 centered (bool) - (tiling mode) set if the window should be centered in
 its alotted cell area.
 displayhint\_block\_wh - if the effective w/h should be forwarded or swapped with
 other, used by autolayouter
 block\_rz\_hint - (debugging) stop resize hints from being forwarded
 canvas - shared vid that references whatever storage that should be drawn currently

Special Properties:
 (m) atype\_props - atype specific subtable
 wayland: (m) geom (x, y, w, h)

(pending: see tiler.lua)

Visuals
------

**INCOMPLETE**
(pending: see shdrmgmt.lua, shaders/)

UI Components
------

These are spread out between uiprim.lua, lbar.lua, bbar.lua and suppl.lua
pending a refactor. By design, Arcan only provides primitives that can be
used for building components, but not completed ones. None of the popular
Lua based UI component libraries have been ported to work.

The purpose-built components that do exist are primarily various
buttonbars, with uiprim\_bar being the most frequently used one.

    uiprim_bar(anchor, anchorp, width, height, shdrtgt, mouseh) => tbl or nil

        tbl-methods:
          methods: resize, invalidate, relayout, switch_state, add_button,
              update, reanchor, hide, show, move, tick, destroy

    iterators:
    all_buttons

    properties:
     anchor, shader, buttons{left{}, right{}, center{}}

**INCOMPLETE**
(pending: see uiprim.lua, lbar.lua, bbar.lua, suppl.lua)

Widgets
------

Widgets are stored in the /widgets folder (with some rudimentary support
script in /widgets/support. Widgets are not user-controlled in a direct
way but rather activated based on what menu path the user has triggered.
They are sized based on the number of text-lines they produce, and are
then positioned automatically. On a 'show' invocation, you get access to
a clipping anchor that you should link to (which will be deleted when the
user hides- or naviagates away from the menu path).

A valid widget script returns a table with the following fields:

    name(string) : unique identifier
    paths(table of strings or functions) : paths to trigger on
    show(function) : invoked with (ctx, anchor, tbl, start_i, stop_i, col_w)
    probe(ctx, yh) : at a fixed number of pixels (yh), return how many groups
                     of yh pixels the widget would need.

The paths can either be normal menu paths, similar to the binding API, or
an evaluation function(taking a context, pathid, stringid and a tag). For
a better view on how these are used, take a look at the included bindings
widget that shows the current keybindings as a helper when the user tries
to bind a key, or the cheatsheet widget which shows cheat-sheets based on
the identity of the selected window.

The API is rather confusing and should, at some point, be replaced with a
better design and better layout manager (binpack, user-movable, ...)

Tools
------

Tools are the preferred way of extending the existing feature-set. Like with
the Widgets, they are scanned once during startup/reset but are not expected
to return some preset table, but mere use the existing API to add themselves
to some menu paths and register settings with gconfig.

A simple tool that would add a 'hi there' message, a submenu to the settings
path and a configurable suffix where the user setting will persist:

    gconfig_register("ht_suffix", "unset");

    local menu = {
        {
            name = "ht_suffix",
                label = "Hi-There",
                kind = "value",
                hint = "(any >0 string)",
                validator = function(val) return string.len(val) > 0; end,
                handler = function(ctx, val)
                    gconfig_set("ht_suffix", val);
                end
        }
        };

    global_menu_register("settings/tools",
            {
                name = "ht_suffix",
                label = "Hi-There",
                submenu = true,
                kind = "action",
                handler = menu
            }
        );

    global_menu_register("tools", {
            name = "hithere", label = "Hi There", kind = "action",
                handler = function()
                 active_display():message("hi there: " .. gconfig_get("ht_message"));
                end
        });

The rest is up to creative use of the other APIs mentioned. Like the case with
any other interactive element in this system, take care to consider activation
outside a button or key-press - there's also timer (both idle, fire-once, ...)
external IPC via ipc/control, and later - a FUSE mount.
