---
layout: default
---

# Launch Targets

When 'whitelisted' execution is mentioned, the 'launch targets' are what is
being referred to. The available ones are accessed through the
<i>global/open/targets</i> path and they are added, configured or removed by
using the arcan\_db tool on the database that durden is running against.

The details of this feature is mostly out of scope for durden itself, and
is covered in the Arcan documentation. You can also check the manpage for
the arcan\_db tool for detailed information on use and setup.

Each target tracks the following properties:
 - key/value store (appl- specific metadata)
 - tag (appl- specific hint)
 - libs (for interpositioning)
 - environment variables
 - arguments
 - configurations
 - binary format

You can define multiple configurations, but there needs to be at least
one in order for durden to list the target as available. Each configuration
can extend the arguments and the environment defined by its associated target,
and also provides an additional key/value store.

Durden does not currently use the key/value stores for settings persistance, or
define any tags.

## External Launch

Arcan distinguishes between internal and external launch. The external launch
will have the environment serialize-and-suspend.

# Future Changes
- Add [core options](coreopt) and target settings persistance
- Expose external launch
