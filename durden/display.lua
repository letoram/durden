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
		w = VRESW,
		h = VRESH,
		name = "default"
	};

	displays.simple = gconfig_get("display_simple");
	displays.main = 1;
	displays[1].tiler.name = "default";

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
			local rstr = string.format("%s%d @ %d * %d- %s",
				i == displays.main and "\\#00ff00" or "\\#ffffff", i,
				displays[i].w, displays[i].h,
				displays[i].name and displays[i].name or "no name"
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
		nd.w = width;
		nd.h = height;
		nd.name = name;
		nd.tiler.name = name;
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
	redraw_simulate();
end

-- migrate the ownership of a single workspace to another display
function display_migrate_ws(disp, dstname)
	local dsp2;
	for i,v in ipairs(displays) do
		if (v.name == dstname) then
			dsp2 = v;
			break;
		end
	end

	if (not dsp2) then
		return;
	end

	if (#disp.spaces[disp.space_ind].children > 0) then
		disp.spaces[disp.space_ind]:migrate(dsp2.tiler);
	end
end

-- the active displays is the rendertarget that will (initially) create new
-- windows, though they can be migrated immediately afterwards. This is because
-- both mouse_ implementation and new object attachment points are a global
-- state.
function active_display()
	return displays[displays.main].tiler;
end

function all_displays()
	local i = 0;
	local c = #displays;
	return function()
		i = i + 1;
		return (i <= c) and displays[i] or nil;
	end
end

function all_windows()
	local tbl = {};
	for i,v in ipairs(displays) do
		for j,k in ipairs(v.tiler.windows) do
			table.insert(tbl, k);
		end
	end

	local i = 0;
	local c = #tbl;
	return function()
		i = i + 1;
		return (i <= c) and tbl[i] or nil;
	end
end

function displays_alive(filter)
	local res = {};

	for k,v in ipairs(displays) do
		if (not v.orphan and (not filter or k ~= displays.main)) then
			table.insert(res, v.name);
		end
	end
	return res;
end

function display_tick()
	for k,v in ipairs(displays) do
		if (not v.orphan) then
			v.tiler:tick();
		end
	end
end
