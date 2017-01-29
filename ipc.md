---
layout: default
---

# IPC
There are two main ways of IPC control in durden. The first is through the
three named pipes created in <i>durden/ipc/control,output,status</i> at
statup. The use of <i>status</i> is described in [statusbar](statusbar) and
will not be covered here.

<i>control</i> can be used to run menu commands. This is slightly dangerous as
quite a number of menu paths were written with an interactive user in mind.
Therefore it is also possible to define a custom whitelist (see
[security](security) so that only benign menu path can be activated externally.

<i>output</i> is used to convey custom messages, like when a user-defined
statusbar button is clicked. There is also a hidden menu path (=bind only) that
allows you to pass a custom message to the output channel. This path can be
found at <i>global/system/output_msg</i>.

There is also a second, more experimental, IPC mechanism that disguises itself
as a normal connected client and it is more directed towards experienced
developers as you will have to hook into both durden and develop using one of
the arcan-shmif API bindings, e.g. TUI (see the arcan wiki for more information)
. For a simple example on how this is used to implement a clipboard manager,
see [clipboard](clipboard).

This channel can be used for more powerful things as well, like full or partial
display sharing or streaming, input injection.

# Future Changes
 - mountable FUSE for menu access
