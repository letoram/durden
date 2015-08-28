-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Display manager takes care of tracking and responding
-- to changes in displays and provides an interface for controlling
-- how workspaces are created and mapped to various displays.
--

local displays = {};

function durden_display_state(action, id)
	if (displays[1].tiler.debug_console) then
		displays[1].tiler.debug_console:system_event("display event: " .. action);
	end

-- display subsystem and input subsystem are connected when it comes
-- to platform specific actions e.g. virtual terminal switching, assume
-- keystate change between display resets.
	if (action == "reset") then
		dispatch_meta_reset();
		return;
	end

	if (action == "added") then
		if (displays[id] == nil) then
			displays[id] = {};
-- find out if there is a known profile for this display, activate
-- corresponding desired resolution, set mapping, create tiler, color
-- correction profile, RGB tuning etc.
		end
	elseif (action == "removed") then
		if (displays[id] == nil) then
			warning("lost unknown display: " .. tostring(id));
			return;
		end

-- sweep workspaces and migrate back to previous display (and toggle
-- rendertarget output on/off), destroy tiler, save settings, if workspace slot
-- is occupied, add to "orphan-" list.
	end
end

function display_manager_init()
	displays[1] = {
		tiler = tiler_create(VRESW, VRESH, {});
	};
end

function active_display()
	return displays[1].tiler;
end

function display_tick()
	displays[1].tiler:tick();
end
