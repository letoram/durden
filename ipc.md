---
layout: default
---

# IPC
There are two main ways of IPC control in durden. The first is through the
three named pipes created in <i>durden/ipc/control,output,status</i> at
statup. The use of <i>status</i> is described in [statusbar](statusbar) and
will not be covered here.

## Control

<i>control</i> can be used to run menu commands. This is slightly dangerous as
quite a number of menu paths were written with an interactive user in mind.
Therefore it is also possible to define a custom whitelist (see
[security](security) so that only benign menu path can be activated externally.

control is split into two IPC channels, <i>control</i> and <i>control_out</i>.

In addition to allowing normal paths, e.g. #/some/thing/here to be activated,
there are a few ftp/filesystem like commands that can be used to query the
current menu state. These are:

<i>read /path/to/something</i>

read will write path-specific data to <i>control_out</i>, terminated by a
single OK line or an EINVAL if the path doesn't exist. Trying to read a
value that leads to a value entry path would output something like:

    name: myname
    label: Name Field
    hint: 0..1
    initial: 0.3

<i>ls /path</i>

ls will write out the contents of a menu directory to <i>control_out</i>,
terminated by a single OK line or an EINVAL if the path doesn't exist. The
contents of each entry is simply the name- field of the corresponding menu
path, with a type specific suffix, / for submenus, = for value paths.

<i>exec /path/to/action</i>

exec will invoke the currently specified path, writing OK on a single line
to <i>control_out</i> or EINVAL if the path does not exist or if it points
to a submenu.

<i>write /path/to/key=value</i>

write will access the specified path and try to assign it the contents of
<i>value</i>. It will write OK on a single line to <i>control_out</i> or
EINVAL if the path does not point to a <i>value</i> entry or if the supplied
value didn't pass validation.

<i>eval /path/to/key=value</i>

eval works just like <i>write</i> with the exception that the actual
values are not committed, you only get OK or EINVAL back if the path accepts
the value in its current form or not.

## Output

<i>output</i> is used to convey custom messages, like when a user-defined
statusbar button is clicked. There is also a hidden menu path (=bind only) that
allows you to pass a custom message to the output channel. This path can be
found at <i>global/system/output_msg</i>.

## Misc

There is also a second, more experimental, IPC mechanism that disguises itself
as a normal connected client and it is more directed towards experienced
developers as you will have to hook into both durden and develop using one of
the arcan-shmif API bindings, e.g. TUI (see the arcan wiki for more information)
. For a simple example on how this is used to implement a clipboard manager,
see [clipboard](clipboard).

This channel can be used for more powerful things as well, like full or partial
display sharing or streaming, input injection.
