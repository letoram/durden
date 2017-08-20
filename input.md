---
layout: default
---

[Keyboard](#keyboard) [Mouse](#mouse) [Touchpad](#touchpad) [Game Devices](#gamedev)

# Input
As mentioned in the section on [The Menu](menu), most paths can be bound to
device inputs, but that is only a small part of the input system. As with the
[display](display) section - the behavior of this layer vary with the platform
arcan is built with. If you are running with the higher-level 'sdl' platform,
you will have access to a different set of controls than with the lower-level
'evdev' or 'freebsd' platform.

The reocurring pattern is that arcan tries to losslessly aggregate and package
input samples and leaves it to the scripts (like durden) to filter/analyze/
translate these into whatever makes sense for the UI at the moment, and to
route or forward to whatever client that should receive the input.

Input samples are indexed by a devid, a subid, a type (digital, analog or
translated) and a number of type-specific fields. <i>Analog</i> carries an
array of sample values, <i>digital</i> carries a pressed/released state and
<i>translated</i> carries a possible symbol value, a keycode, a modifier
bitmap and possibly a unicode codepoint stored as UTF-8.

## Labels
Every client can announce a list of <i>labels</i> that it supports. These are
higher level actions like <i>toggle scrolling</i> or <i>player 2 button a</i>
and appear as they are announced in the <i>target/input/labels/input</i> list.

You can bind these to a supported device on a 'per target basis', or trigger
an input through [IPC](ipc) or other means through the <i>target/input/bind-</i>
set of options.

# Keyboard<a name="keyboard"/>
Keyboard controls can be found in <i>Global/Input/Keyboard</i> and covers
things like <i>repeat behavior</i> (delay, rate), <a href="#rawlock">raw
lock</a> and active keyboard map. It is also possible to remap custom UTF-8
sequences to various keyboard combinations.

Durden makes a few controversial decisions when it comes to keyboard
management.

1. Dropping the OS provided keyboard formats.
2. Removal of the caps-lock and num-lock states.

First is due to the fact that that there really isn't a good format available
for keyboard maps. Not only is the translation highly dependent on the OS and
even on the configuration of the OS kernel, but the formats that have been used
traditionally (like Xkb for X and Wayland) are excessively complicated (f'in
insane) or incomplete/limited (like the console linux keyboard maps or the ones
used in Android).

The removal of caps-lock / num-lock was to cut down on the management
complexity and to free up these buttons for other uses. Similar behavior can
be added by simply binding the menu path for switching keylayout to one that
has the desired translation and match your view of caps lock or num lock state.

## Multicasting
When working with hierarchies of clients that should have the same keyboard
input reflected, popular with "multiboxing" games and for managing many remote
shells at once, you can turn on multicasting for a group.

This feature is accessible by going to <i>target/input/multicast</i> and will
affect all children (deep-recursive) that has not explicitly had its own (or
a parents) multicast behavior set to false.

## Layouts
As mentioned about, keyboard maps or 'layouts' are quite a tricky business.
There is a custom internal format that can be found in the source in
<i>durden/devmaps/keyboard</i>. It is also possible to both modify, switch
and save layout as part of the <i>global/input/keyboard/maps</i> path.

A map should provide, at least, a translated unicode codepoint output and a
keyboard symbol. The symbol is part of a rather short and restricted table
of logical names that are used in the UI when you bind or navigate keys, and
are part of a table that can be found in the symtable.lua file.

Bear in mind that some clients, like those connected using Xarcan and
arcan-wayland can actually not bind correctly.

## Sticky Meta
Sticky meta adds a delay to the meta1- and meta2- bound keys that will defer
the release of a meta key a certain number of ticks (in ~40ms steps). This
feature can be configured through <i>Global/Input/Keyboard/Sticky Meta</i>.

## Raw Lock<a name="rawlock"/>
If you double-tap the META2 (default) key, you may see the statusbar turning
red. This means that all other keybindings will be disabled, and keyboard input
will be forwarded to the selected client with little additional interpretation.
This is reverted by double-tapping META2 again. The feature cancels the ability
for clients such as VMs to 'grab keyboard input' in order for special
keys to be ignored and forwarded to a particular VM.

# Mouse<a name="mouse"/>
Even though Durden is a 'keyboard first' desktop environment, there are a lot of
tunable features that can make the mouse more or less painful to work with.

## Button Behavior
With the <i>global/input/mouse/reorder</i> set of options you can re-order the
buttons to fit your hand style (change from left(1),middle(2),right(3) to
left(3),middle(2),right(1) for instance).

With the <i>global/input/mouse/debounce</i> you can add a filter to prevent
shadow- 'clicks' due to the hardware actuator bouncing. It works simply by
introducing a minimum time (in 25Hz steps) that need to elapse before a
release- event will be acknowledged.

With the <i>global/input/mouse/double click</i> you can control the time
(in 25Hz steps) that need to elapse for a double click to be registered.

## Focus Behavior
When the mouse cursor is used to switch window focus, you have a few options
available as part of <i>global/input/mouse/focus event</i> where it is possible
to have focus follow mouse by clicking a window, hovering inside a window,
moving immediately with the cursor or disable mouse controlled window
focus entirely.

## Visibility
You can control the mouse cursor look in a few ways. For accessibility
reasons, you might want to make it bigger, <i>config/visual/mouse/scale</i> can
be used for that.

The cursor can be set to autohide (default:on) after a number of ticks which
can be changed through <i>global/input/mouse/autohide</i>. After a while, it
might be hard to find the cursor if it has been hidden. The reveal/hide
(default:on) feature as part of <i>global/input/mouse/reveal-hide</i> will
spawn and animate a number of green rectangles at the point where the cursor
went from hidden to visible.

## Motion/Position Behavior
The constant sensitivity factor can be adjusted through
<i>global/input/mouse/sensitivity</i>. In addition, the default behavior is for
durden to "remember mouse position", meaning that when you move window focus
using the keyboard, the mouse cursor warps to the last known position when that
window was least selected. This feature can be disabled through
<i>global/input/mouse/remember-position</i>.

## Rate Limiting
A lot of modern mouse devices output a high sample rate and a high sample
resolution, that can range in the thousands of samples per second. On the other
hand, quit few clients are actually able to take advantage of this though they
will still attempt to process such events.

For some clients, durden automatically clamps the sample rate to a lower clock,
25Hz instead of 1000Hz in order to save precious mobile battery. this behavior
can be enabled/disabled through the <i>target/input/mouse/rate limit</i> menu
path.

## Locking
Traditionally, X clients had the ability to 'grab' control over the mouse in
order to do proper relative mouse motion interpretation in games and so on.

This is not a client controlled action in durden, but can easily be toggled
on a case-by-case basis. The <i>target/input/mouse/lock</i> path allows you
to confine the mouse cursor to the canvas of the selected window, either by
preventing it to move outside, or by forcing it in the center (a behavior that
some first-person shooter games etc. may require).

# Touchpad<a name="touchpad"/>
Touchpads are quite complicated devices; the quality and behavior of devices
vary wildly between different models, environment conditions and over time
through simple wear and tear.

There is not a 'one size fits all' approach here, and right now, you are forced
to manually tune a touchpad profile.

This profile is found in the <i>durden/devmaps/touch/</i> source path and are
scanned at startup/reset. There is a README.md with an example profile, or you
can just modify the 'default' profile to fit your needs. This includes:

 - scaling/ranging values
 - activation zone
 - gesture analyzer
 - menu path to activate on various gestures, such as "
   "3-finger-swipe right should map to !workspace/switch/next"

# Game Devices<a name="gamedev"/>
Any device that is not detected as a keyboard/mouse/touchpad will be treated
as a game device. Devices can be enabled/masked and tuned through
the <i>global/input/all devices/...</i> path.

If durden detects gamepad input devices, it will try and match these to a
profile in <i>durden/devmaps/game</i>. Right now, this profile only reorders
and packs buttons/axes so their labels become the more predictable
PLAYERn\_BUTTON1.

These devices can then (same <i>global/input/all devices/devname/slot</i>) be
assigned a player slot, like player 1, player 2 and so on, which a target
game window can hopefully make more sense out of.

It is also possible to direct all slotted input to one specific target game
window through the <i>target/game/slotted grab</i> menu path. This allows you
to work with another window focused and continue to forward gaming related
input.

# Future Changes
- On-Screen keyboard
- Arbitrary sticky keys
- Arbitrary autofire
- Arbitrary key/button debounce
- Touchpad calibration tool
- Advanced gesture analysis
- Keyboard layout conversion tools
- On touchscreen- activation / deactivation hooks
- Better analog axis filtering/configuration
