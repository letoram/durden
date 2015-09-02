-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Display manager takes care of tracking and responding
-- to changes in displays and provides an interface for controlling
-- how workspaces are created and mapped to various displays.
--

local displays = {
};

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

	displays.simple = gconfig_get("display_simple");
	displays.main = 1;

	if (not displays.simple) then
		displays[1].rt = displays[1].tiler:set_rendertarget(true);
		set_context_attachment(displays[1].rt);
		mouse_querytarget(displays[1].rt);
		show_image(displays[1].rt);
	end
end

function display_each_ws(name_only)
end

-- get the workspaces to only orphaned
function displays_orphan_ws()
end

function displays_each_wnd()
end

-- if we're in "simulated" multidisplay- mode, for development and
-- testing, there's the need to dynamically add and remove to see that
-- workspace migration works smoothly.
local function redraw_simulate()
	local ac = 0;
	for i=1,#displays do
		if (not displays[i].orphan) then
			ac = ac + 1;
		end
	end

	if (valid_vid(displays.txt_anchor)) then
		delete_image(displays.txt_anchor);
	end

	set_context_attachment(WORLDID);
	local font_sz = gconfig_get("font_sz");

	if (ac == 0) then
		for i=1,#displays do
			hide_image(displays[i].rt);
		end
	else
		local w = VRESW / ac;
		local x = 0;

		for i=1,#displays do
			move_image(displays[i].rt, x, 0);
			resize_image(displays[i].rt, w, VRESH - font_sz);
			show_image(displays[i].rt);
			local rstr = string.format("%s%d - %s",
				i == displays.main and "\\#00ff00" or "\\#ffffff", i,
				displays.name and displays.name or "no name"
			);
			local text = render_text(rstr);
			show_image(text);
			move_image(text, x, VRESH - font_sz);
			x = x + w;
		end
	end
	set_context_attachment(displays[displays.main].rt);
end

function display_simulate_add(name, width, height)
	local found;
	for k,v in ipairs(displays) do
		if (v.name == name) then
			found = v;
			break;
		end
	end

	if (found) then
		found.orphan = false;
		show_image(found.rt);
	else
		set_context_attachment(WORLDID);
		local nd = {tiler = tiler_create(width, height, {})};
		table.insert(displays, nd);
		nd.rt = nd.tiler:set_rendertarget(true);
-- in the real case, we'd switch to the last known resolution
-- and then set the display to match the rendertarget
		show_image(nd.rt);
		set_context_attachment(displays[displays.main].rt);
	end

	redraw_simulate();
end

function display_simulate_remove(name)
	local found, index;
	for k,v in ipairs(displays) do
		if (v.name == name) then
			found = v;
			index = k;
			break;
		end
	end

	if (not found) then
		warning("attempt remove unknown display");
		return;
	end

	if (k == displays.main) then
		display_cycle_active(ws);
	end

	redraw_simulate();
end

function display_cycle_active()
	local nd = displays.main;
	repeat
		nd = (nd + 1 > #displays) and 1 or (nd + 1);
	until (nd == displays.main or not displays[nd].orphan);
	displays.main = nd;
	set_context_attachment(displays[displays.main].rt);
	mouse_querytarget(displays[displays.main].rt);
end

-- migrate the ownership of a single workspace to another display
function display_migrate_ws(ws, display)
	if (ws.wm == display) then
		return;
	end

-- recursive detach/attach to all vids associated with the ws,
-- could probably be done by setting another target-rt
end

-- the active displays is the rendertarget that will (initially) create new
-- windows, though they can be migrated immediately afterwards. This is because
-- both mouse_ implementation and new object attachment points are a global
-- state.
function active_display()
	return displays[displays.main].tiler;
end

function display_alive()
	local rv = 1;
	for k,v in ipairs(displays) do
		if (not v.orphan) then
			rv = rv + 1;
		end
	end
	return rv;
end

function display_tick()
	for k,v in ipairs(displays) do
		if (not v.orphan) then
			v.tiler:tick();
		end
	end
end
