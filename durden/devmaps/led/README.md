LED Device
==========

These configuration files are lua scripts that are loaded/scanned once on
startup and describe which behaviors that should be associated with known
LED devices. Majority of the implementation residefs in durden/ledm.lua

There is also support for an engine routed FIFO protocol to be able to hook up
Led controllers where we don't have built-in support. This is often preferred
since they often rely on ugly USB protocols where the processing doesn't fit
well with the model used in the engine. Up to 9 such devices can be added, and
the fifo-paths are pointed to through the ext\_led, ext\_led\_2, ext\_led\_3
and so on keys in the 'arcan' or 'arcan\_lwa' reserved appl in the database.

Adding such a device can thus be done via (example):

    arcan_db add_appl_kv arcan ext_led /tmp/fifo

The corresponding name for matchlbl (below) will be (led-fifo num) where
num represents the device number (1 for ext\_led, 2 for ext\_led\_2 etc).

For more information on this protocol, please see the arcan wiki entry on
'LED Controllers'.

Each file is expected to provide ONE profile, as a table returned with a
number of expected fields. Failure to provide a correct table may lead to
durden shutting down or the device profile being ignored. Check the syntax
of the file with 'luac', and make sure the expected fields are present.

An example of a simple profile matching an external fifo controller:

    return {
				label = "FIFO(1)",
				name = "fifo1",
        role = "passive",
        matchlbl = "(led-fifo 1)"
    }

label is a user-presentable string, name is a menu-system integrateable
name, role is either 'passive', 'keymap', 'custom'. Depending
on the role, additional fields may be needed.

Matchlbl is a string to match against the device presented label, or,
for input-platform specific device matching, a matchdev which corresponds
to the devid of the related input device. This is used in order to deal
with LEDs that are part of some aggregated complex device.

If a role is not specified or a profile is not found for a device,
the 'passive' role will always be assumed.

Role: "passive"
No extra fields are needed for this role, all LED control and activation
comes from explicitly triggering the corresponding menu path, that will
be global/config/leds/devid or, if a profile override was presented,
global/config/leds/name-from-profile. There will be a menu entry for
each supported led (up to 256 depending on the device) where a value

Role: "keymap"
For this role, durden will colorize LEDs based on current keyboard state
and the actions that would be triggered if a certain key would be pressed.

Add the following fields where num match the corresponding led index:
      m1_id = num,
			m2_id = num,
			default_color = {255, 255, 255},

      -- optional colors below, if missing, default_color will be used
      global_color = {0, 255, 0},
			global_destructive_color = {255, 0, 0},
			target_generic_color = {0, 255, 255},
			target_destructive_color = {0, 0, 255},
			target_custom_color = {255, 0, 255},

      -- special overrides based on action, path or path-prefix
      path_colors = {
			 ["destroy"] = {255, 0, 0},
			 ["/global/open/target"] = {64, 20, 64},
			 ["/global/open/*"] = {20, 64, 80}
			}

      -- optional proxy function when state needs to be mixed
      proxy = function(devid, ledind, r, g, b, commit)
				set_led_rgb(devid, ledind, r, g, b, commit)
			end,

			symtable =
			 {
				ESCAPE = num,
				SPACE = num,
				F1 = num
			 }

Role: "custom"
This is an advanced role map where you decide your own timing. Add the
following field to the returned structure:

        tickrate = 2,
				clock = function(devid)
				end

where you are free to call set\_led\_rgb and similar functions based on
some custom data source.
