---
layout: default
---

# Timers

Timers can be accessed from the <i>global/settings/timers</i> menus and are used
to add delayed, periodic or on-idle triggered menu path bindings. Internally,
it is used for things like polling external IPC (timer name: status\_control).

You can list, suspend or cancel currently active timers through the
<i>global/settings/timers/suspend or delete</i> paths.

The different timer types are:
- Periodic : repeat every n seconds
- Once : wait n seconds, activate then remove
- Idle : after n seconds of inactivity, run path
- Idle-Once : after n seconds of activity, run path then remove

The idle timers are useful for things like activating lock-screen, power-save
behavior and so on. Two actions are bound to a timer and you can bind one
action on activation, and another on inactivation.

It is also possible to temporary disable idle timers via the
<i>global/settings/timers/block or unblock idle</i> paths. Useful when you have
media playback in fullscreen and do not want idle- timers to interfere.

# Future Changes
- Better precision
- Add timers through IPC
- Absolute time support
