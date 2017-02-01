---
layout: default
---

# Audio
Audio subsystem controls are limited to adjusting volume output globally
and on a per-window basis. Global controls are accessible through
<i>global/audio</i> and covers:

- Toggle (On / Off)
- Absolute Output Volume
- Relative Output Volume Stepping

The same controls exist per window through <i>target/audio</i> but the
volume settings are defined relative to the global one.

Most of the limitations to the audio system are due to the very limited
controls exposed by Arcan. It is marked for rework/refactor on the
[Arcan Roadmap](https://github.com/letoram/arcan/wiki/roadmap).

# Future Changes
- Output routing
- Output filtering
- Input routing
- Input forwarding
- Beamforming input set
