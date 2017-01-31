---
layout: default
---

# Lockscreen

The lockscreen is activated via the menu path <i>global/system/lock</i> and it
queries you for a key when activated, so you have the option of binding either
the menu path for the entry itself, or for a specific key when you re-activate.
A common solution for an 'auto-lock' / 'auto-sleep' is to bind the path to an
idle- timer (see [timers](timers)).

When activated, the lockscreen will hide the current screen contents and go
black. When receiving input, it will query for an unlock key. After the first
failed attempt, it will also show the number of failed attempts.

This solution does not tie into any other account management systems. This is
by design as to avoid the dependency to PAM or put restrictions on the
underlying OS setup, but also to encourage the use of a 'throwaway' one-time
locking key rather than burning more secure primitives, such as your normal
account credentials.

It is not intended as a strong [security](security) feature, but rather as
cheap protection against opportunistic unskilled abuse.

# Options

It is possible to set paths that will activate for certain conditions,
though they are currently not exposed through the UI.

You can modify (first time / db- reset state) <i>durden/gconf.lua</i> or
by changing the following database keys (arcan\_db add\_appl\_kv durden ...):

- passmask : set to true to hide the key echo during input and query
- lock\_on : run when lockscreen is activated
- lock\_ok : set to a menu path that should be activated on successful key input
- lock\_fail\_[num] : at [num] failed attempts, execute this path

# Future Changes
- Expose configuration interface / event binding
- Allow device events act as lock/unlock triggers
- Customizable background, whitelist widget set
