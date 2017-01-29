---
layout: default
---
# Clipboard
Clipboard access is part of the <i>target/clipboard</i> menu path.
There is a global clipboard, and a local one unique to each connected client.

When a client adds something to its local clipboard, it is automatically
copied or "promoted" to the global clipboard. It is also possible to manually
promote something from the clipboard history to be added to the global
clipboard via <i>target/clipboard/promote</i>.

Depending on the archetype a client registered as, the clipboard feature can
be enabled or disabled entirely so if the clipboard menu is not available, it
means that the feature has been blocked for the specific client or the client
has not announced support for clipboard management.

# Filters
When performing a paste operation, a filter can be applied. This filter is a
'per window' tracked property, so setting it in one window will not have an
effect on the pastemode of others. The available set is found at
<i>target/clipboard/mode</i> and performs basic transformations like stripping
trailing/repeated whitespace.

Underneath the surface, it is simply some substitution pattern (you can add
your own inside <i>durden/clipboard.lua</i>) that is applied before a paste
operation is forwarded to a client.

# URL Catcher
URLs that appear on the clipboard gets special treatment, and are automatically
added to a separate list that is used as the menu selection for opening a
target, but can also be found at <i>target/clipboard/urls</i>.

# External Manager
There is a tool in the main arcan source tree, <i>src/tools/aclip</i> that
implements an external clipboard manager. By default, this will be rejected
as the client will get monitor access and/or injection access into the global
clipboard.

To enable this support, go to <i>global/system/external clipboard</i> and set
to full or active or passive. This will allow one active external client that
identify its primary segment as as clipboard to read (passive), write (active)
or both (full) the global clipboard state.

# Offline
The clipboard gets stored in a Lua file that is loaded on startup and flushed
on shutdown/reset. See the <i>durden/clipboard_data.lua</i> file.

# Future Changes
- Support for Audio/Video/Binary paste
- Integration with drag-and-drop style features
- Better promotion controls
- Color code clipboard history navigation
