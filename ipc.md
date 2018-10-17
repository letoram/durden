---
layout: default
---

# IPC
There are two main ways of IPC control in durden. The first is through the
three named pipes created in <i>durden/ipc/control,output,status</i> at
statup. The use of <i>status</i> is described in [statusbar](statusbar) and
will not be covered here.

## Control

<i>control</i> is a default-off, unix domain socket that can be used to
perform external control of the entire desktop. There is a tool in the
arcan source distribution, arcan\_cfgfs that can be used with FUSE to
mount the file system so that you can interact with it using the normal
command-line tools.

Otherwise, you can write your own tools to communicate via the trivial
text protocol (commands: ls, read, exec, write, monitor) or use socat
like:

    socat - unix-client:$HOME/.arcan/appl-out/durden/ipc/control

All the commands end with either a single line OK and a linefeed, or
an error message starting with Exxx.

<i>read /path/to/something</i>

Read simply lists the attributes and, depending on the path, additional
metadata about a path.

    name: myname
    label: Name Field
    hint: 0..1
    initial: 0.3

<i>ls /path</i>

ls will list the contents of a menu directory, terminated by a single OK
and linefeed oror an EINVAL if the path doesn't exist.

<i>exec /path/to/action</i>

exec will invoke the currently specified action path.

<i>write /path/to/key=value</i>

write works like <i>exec</i> but is used for value paths, that is paths
which require a value to be provided in order to work properly.

<i>eval /path/to/key=value</i>

### Monitor Mode

The command 'monitor' is special, as it will change the state of the connection
to only accept monitor commands. These are used to listen to one or many of the
event subsystems that make out the core of durden.

    monitor all

Will become very noisy, whileas:

    monitor wm

Will only show window manager events. To get a list of currently available groups
simply call monitor without any arguments and the list will be returned in the
following EINVAL error message.

The second monitor command disable monitoring and returns the connection back to
a normal state.

## Output

<i>output</i> is a FIFO used to convey custom messages, like when a user-defined
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
