---
layout: default
---
[Rotation](#rotation) [Multiple Displays](#multidisp) [Density Control](#density)
[Hotplug](#hotplug) [Color Management](#color)

# Display Management
Most of this section is written based on arcan using the low level egl-dri
platform; the other platforms put you inside a window, so there is not much
display management going on.

By default, arcan just picks the display 'connector' that comes first in
enumeration order - or if you explicitly specify -w 320 -h 200, the first
connector that has a display that can accomodate this resolution.

This can be tuned further through the environment variables shown when
running 'arcan' without any arguments.

Most display changes can be initiated from the <i>Global/Display/Displays</i>
menu path where there will be explicitly named monitor references, and the
abstract "Current" that refers to the display that has input focus at the
moment.

# Rotation / Resolution <a name="rotation"/>
To switch your current display from horizontal to vertical orientation,
simply activate the <i>global/display/displays/current/orientation/toggle HV</i>
menu path.

Resolution switching also works in a similar way, the subdirectory
<i>global/display/displays/current/resolution</i> will show an estimate of
the resolutions that the platform currently supports (estimate because this
might actually change in multimonitor settings depending on how you setup
your monitors).

# Multiple Displays <a name="multidisp"/>
Each workspace is tied to a display, and each display can have up to 10
workspaces. If a display disappears, the workspace will be re-homed to another
display (if possible), otherwise it will be marked as orphaned and adopted when
a free slot becomes available somewhere. If the parent display appears, the
original workspace migrates back to this display. This behavior can be
overridden by explicitly migrating workspaces via the
<i>global/workspace/migrate</i> or on a per-window basis with
<i>target/window/migrate</i>.

A problem for arcan is to determine how to deal with the synchronization of
screen contents transfers. One would naively think that just aligning with the
VSYNC of a display would be fine, but but this is not always possible due to
driver limitations and the multi-display situations where the individual
display synchs do not have a common divisor and buffering is not a workable
solution.

All underlying platforms currently lack access to a decent signal-fencing
interface for more advanced synchronization. There are two levels of
synchronization to work with. One is a "synchronization strategy" which
regulates HOW the engine is supposed to prioritize display synchronization.
This matters when you have more variable- rate displays like FreeSync or GSync,
but also as a power management strategy on mobile devices. The other is the
notion of letting a set of primary displays force-synch, and just let the
others update whenever they can. Synchronization strategies are found as part
of <i>global/display/synchronization</i> and toggle if a single display belong
to the primary synch group or not through
<i>global/display/displays/current/force synch</i>.

# Display Density <a name="density"/>
Durden should automatically account for variations in display density across
multiple displays. If the detection is wrong, which can happen with poor
displays that provide the wrong EDID, driver bugs or an interfering KVM switch,
you can override the detected density with the
<i>global/display/displays/current/density</i> menu path. Note that the density
is expressed in pixels per centimeter.

Though the internal UI should reflect density changes instantaneously,
connected clients that rely on relative integral scaling factors or are entirely
ignorant of output density will not be so lucky. As a band-aid solution, you
can try and change the scaling behavior on a per-window basis using the
<i>target/video/scaling/</i> to force-scale the window contents. There are more
options for this to explore in the [visual](visual) section.

# Hotplug <a name="hotplug"/>
By default, there is no active hotplug action. one reason for this is that the
lower level APIs do not provide a sane interface for this, but rather expects
you to bind to udev, which is on the arcan blacklist. Another reason
is that the platform needs to do a full rescan of GPUs and their connectors,
which impose a rather heavy (hundreds of miliseconds to seconds) stall on the
entire graphics pipeline, with a high chance for driver/kernel crashes if you
respond to a hotplug too quickly, particularly with complex display protocols
like "display port".

If you still want automatic hotplug behavior, you can use the [IPC](ipc)
facility to hook up the global/display/rescan path to whatever hotplug daemon
you are running on your system.

# Color Correction <a name="color"/>
Each display output can have a post-processing on-GPU program ("shader")
applied to it. The default output shader performs no transformation,
while-as others can weight the different output shaders or apply some
power funtion.

The shaders are scanned at startup, and are presented in the
<i>global/display/displays/current/shader</i> path. The individual parameters
in that shader will be accessible through the
<i>global/display/displays/current/shader weights</i> path that appears when
you have picked a shader.

If you want to write your own shader, look in the <i>durden/shaders/display</i>
path for code templates to copy and modify.

# Future Changes
 - Specify lookup texture to display shader

 - Vector- defined icons for perfect scaling in mixed DPI settings

 - With Arcan 0.5.2 / Durden 0.3, other processes can be put in charge of
   managing color for one or several displays. This feature is enabled per
   target basis through <i>target/video/advanced/toggle color sync</i>.
