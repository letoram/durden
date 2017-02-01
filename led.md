---
layout: default
---

Note that the contents here only apply to the upcoming arcan 0.5.2 /
durden 0.3 versions. The text describes work in progress that is partly
usable/testable but not in a releasable state.

# LED Controllers
The LED Controllers feature covers:

- Keyboard LEDs
- Display backlight
- Gamepads
- External/Custom LED controllers

Some of these may require arcan to be set up with higher privileges or
capabilities, depending on your OS. This is often the case with laptop
backlights. Note that if your laptop backlight control is not working you can
simulate the effect somewhat by using a display shader that adjusts the color
channel weights, see [Display Management](display).

Backlights are accessed through, gamepad LED features via their respective
<i>global/input/all devices</i> subpaths. External controllers receive their
own path in <i>global/input/all devices</i> with a led- prefix.

## Profiles
Another option is to assign a profile to the led controller and let durden
manage its mapping separately. These are handled by profiles loaded from
<i>durden/devmaps/led</i> and their format is documented in the README.md
file in the same folder.

Each profile describes one device, and assigns the device a role. The
different LED controller roles are:

* passive - no special management of the led device
* keymap - have LED controllers reflect current menu bindings
* displaymap - you get access to a custom mapping function that provides
  periodic access to a low resolution sample of the current display
* custom - you get access to a clock function where you can trigger your
  own animations and effects.

## External LED controllers

Arcan expose a simple protocol over a FIFO to hook up with custom
services for LED hardware. It is described in more detail in the
[arcan wiki](https://github.com/letoram/arcan/wiki/LED-Controllers).

The device is refered to as led(fifo) in the <i>global/input/all devices</i>
path, and as (fifo) if writing a profile.
