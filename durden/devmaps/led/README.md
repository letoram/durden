LED Device
==========

These confguration files are lua scripts that are loaded/scanned once on
startup. They are matched by the label field of the added device event, though
you can also explicitly bind them to a LED device through the normal menu
system by either devid or label.

There is also support for an engine routed FIFO protocol to be able to hook up
Led controllers where we don't have built-in support. This is often preferred
since they often rely on ugly USB protocols where the processing doesn't fit
well with the model used in the engine code.

For more information on this protocol, please see the arcan wiki entry on
'LED Controllers'.

A valid profile is expected to return a table looking like this:

    return {
        label = "User-facing label",
        role = "passive",
        matchflt = "Led-Dev-Name",
        matchdev = 1234
    }

where the role will determine how durden will make use of the device, the
matchflt is a normal Lua pattern for matching against the device, or for a
specific devid (though those are not always reliable / applicable).

If a role is not specified, the 'passive' role is assumed.

Its role indicates how durden will treat the controller and which fields
are expected to be part of the profile.

Role: "passive"
No extra fields are needed for this role, all LED control and activation
comes from explicitly triggering the corresponding menu path.

Role: "keymap"
For this role, durden will colorize LEDs based on current keyboard state
and the actions that would be triggered if a certain key would be pressed.

Add the following fields where num match the corresponding led index:
      m1_id = num,
			m2_id = num,
			default_color = {255, 255, 255},

      -- optional colors below, if missing, default_color will be used
      global_color = = {0, 255, 0},
			global_destructive_color = {255, 0, 0},
			target_generic_color = {0, 255, 255},
			target_destructive_color = {0, 0, 255},

			symtable =
			 {
				ESCAPE = num,
				SPACE = num,
				F1 = num
			 }

Role: displaymap
This is an advanced role map since you are required to define a sample
function that describes how the input buffer should map to led commands.

The map function will be called every *samplerate* ticks, with *inbuf*
being a table that match arcan/doc/define\_calctarget.lua. Return an
array with a number of elements that are evenly divisible with 4. The
array will be interpreted packed as [ledind, rval, gval, bval] where
r,g,bvals in the 0..255 range.

The source- field specifies the source display for the mapping from
either 'current', 'primary' or a specific display name matching a path
in global/display/displays.

Add the following fields to the returned structure:

				samplerate = 5, -- update every five ticks
				source = "current",
				map = function(inbuf, width, height)
				end

Role: "custom"
This is an advanced role map where you decide your own timing. Add the
following field to the returned structure:

        tickrate = 2,
				clock = function()
				end

