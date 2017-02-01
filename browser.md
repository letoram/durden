---
layout: default
---

# Media/File Browser
Multiple features require some way of selecting files to be used as input.
There is a limited browser that covers the 'shared resources' namespace.
It can be accessed via the <i>global/open/browse</i> path.

It is still quite primitive, and only offers limited preview of image
resources.

<center><a href="images/browser.png">
	<img alt="browser" src="images/browser.png" style="width: 50%"/>
</a></center>

Holding meta1 while activating a resource will spawn the resource in the
background while keeping the menu active.

# Future Changes
- Allow adding files to a stack than can then be atomically
  packed/deleted/forwarded/transformed/queued for 'playlist'
- Map client bchunk- hint events to spawn browser for universal
  open/save file-picking
- Video playback in preview windows
- Namespace selection
- Extend menu bindings to cover browser paths
- Controllable pattern to target- mapping
