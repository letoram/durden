---
layout: default
---

# Core-options

It is possible for clients to announce configuration settings for both offline
and online client behavior tuning.

If a client has announced any key/value pairs, these will be available through
the <i>target/options</i> path.

This is a feature that is primarily used by libretro- cores through the game
frameserver but will eventually be extended to bridging tools and TUI
applications as well.

# Future Changes
- Persistance and on-launch activation for clients that are defined through
  the [Launch Targets](targets) feature.
