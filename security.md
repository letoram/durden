---
layout: default
---
[Meta Guard](#metaguard) [Fallback](#fallback) [External Connections](#extcon)
[Crash Recovery](#crashrec) [Data Sharing](#datashare)
[Clipboard Access](#clipboard) [Display Control](#dispctrl)
[Screen Recording](#screenrec) [Rate Limiting](#ratelimit)
[Protected Terminal](#protterm) [Delete Protect](#deleteproect)

# Security and Safety Features
There are a number of mitigations in place to prevent abuse, loss of work and
loss of access due to device or software failure. Some require cooperation from
Arcan, some are implemented as part of Durden. Be aware that the current
timeline for Arcan development treats security as a lesser priority than many
other tasks.

# Meta Guard <a name="metaguard"/>
The meta guard is the first feature you were exposed to, when active, it waits
a certain number (~30) of keypresses and expects one of them to be a valid
meta- menu path. If not, it assumes your keyboard is broken or has switched
layout and provides an option to rebind the keys necessary to regain control.

This feature is reactivated if the keyboard device is lost or replaced.

# Delete Protect <a name="deleteprotect"/>
Keyboard repeat actions are disabled on meta bound paths for the reason that
a possible I/O stall in the wrong moment on a loaded system could trigger
dangerous cascades like a destroy-window action being triggered accidentally.

To further protect against unwanted destruction of windows with important
contents, you can enable delete protect through the <i>target/window/delete
protect</i> path. This blocks the window-destroy action until the delete
protection is removed.

# Fallback Application <a name="fallback"/>
A fallback application is simply an alternate set of scripts that can be
activated if a scripting error occurs in the ones that are currently running.

This is part of arcan and needs to be enabled explicitly (see the -b argument).
It can be set to re-run the same application (:self) or switch to another.

The engine will try and migrate external to the new script context.  This means
that unsaved window settings will be lost, along with negotiated extra
resources and protocols, but a client will retain its primary connection and be
adopted into a setting where it should be possible to save / recovery any
important work.

The same feature is used for resetting/reloading (<i>global/system/reset</i>)
and switching (<i>global/system/reset/switch appl</i>).

# External Connections <a name="extcon"/>
The default settings expose an external connection point with the name 'durden'.
You can rename this connection point through the
<i>global/config/system/connection path</i> menu path.

Doing so can help you to avoid conflicts if you want to run multiple instances,
or set it to the special ':disabled' to remove support for external connections
entirely. If so, only whitelisted targets/configs and builtin- frameservers can
be hooked up to the arcan instance.

# Crash Recovery <a name="crashrec"/>
This is part of arcan, but is enabled explicitly in durden IF external
connections are allowed. Should arcan crash, connected/compliant clients will
attempt to reconnect (with a backoff in delays) to the recovery connection
point provided by durden on external client connection.

# Data Sharing <a name="datashare"/>
If your threat model does not include hostile local clients, you may want to
open up further features for external control. Default settings do not permit
any external control over sensitive data-paths, but some can be opened up -
if desired.

## Clipboard Access <a name="clipboard"/>
As mentioned in [clipboard](clipboard), external clipboard
managers are disabled by default but can be activated via the
<i>global/config/system/clipboard bridge</i> path, allowing clients that
identify with their primary segment id as CLIPBOARD and CLIPBOARD\_PASTE to
inject and/or monitor global clipboard events.

## Display Control <a name="dispctrl"/>
As mentioned in the color section in [display management](display), clients
are not granted access to the color ramp subprotocol that allows access to
monitor hardware information and modification of accelerated display LUTs.

This can be toggled on a client-by-client basis via the
<i>target/video/advanced/color sync</i> option, with the added risk that a
malfunctioning client can make the screen contents unreadable.

It can also be globally allowed via the
<i>global/config/system/gamma bridge</i> path, with the added risk of clients
fighting eachother for control over the LUTs. This will be mitigated later by
allowing LUT state to follow client window selection.

## Screen Recording <a name="screenrec"/>
Clients that requests an output segment, either as primary registration segid
or as secondary subsegments will have their request rejected for the time
being. To compenstate, the 'encode' frameserver role can still be used for
user-initiated screen sharing and recording. See [record, stream,
share](recstr) for more information.

## Rate Limiting <a name="ratelimit"/>
To protect against fork-bombing style denial of service (clients stalling the
server by requesting lots of connections or subsegments), there is configurable
rate-limiting in place, though it is not enabled by default.

The relevant menu paths are found in <i>global/config/system/rate limiting</i>:

 - Rate Limit : Force n ticks between each accepted external connection
 - Grace Period : Disable Rate Limit for the n first ticks (faster recovery)
 - External Windows Limit : Set an upper limit
   to the number of concurrent external connections
 - Window Subsegment Limit : Limit the amount of windows
   a client is allowed to spawn

It is also possible to force-disable handle passing (GPU resource starvation)
through the <i>target/video/advanced/toggle handle passing</i>.

Arcan already favors platform- delivered events over external clients when
multiplexing on a half-saturated event queue, and each individual client has
a short event-queue to prevent starvation and priority-inversion.

# IPC Controls <a name="ipc"/>
The <i>control, status and output</i> IPC pipes are only protected by their
default unix permissions. There is no authentication step and preventing access
to the appl\_path is the responsibility of the user when setting up arcan
namespacing. To disable these features, simply set their respective names to
<i>:disabled</i>, or enable whitelisting (<i>global/config/</i>) and only permit certain
menu paths from being activated via external IPC.

# Protected Terminal <a name="protterm"/>
The [drop-down terminal tool](tools) is designed to be used for a command-line
shell that needs extra protection. It has a direct input path, separate
management of font typeface, size and color scheme. It is not accessible from
any of the normal menu paths, no clipboard interaction and is drawn with a
separate border in a non-client controllable part of the UI with clear
indication when it is active or not.

## Future Changes
- Enforced sandboxing on frameservers
- All arcan-side parsers moved to decode frameserver
- Display-Control LUT safeguards
- Privilege Level Border indicators (color)
- Fine-grained GPU access control and load-balancing
- Event-queue load-balacing factors split into internal/whitelist/external
