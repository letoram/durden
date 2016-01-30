-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
--
-- Description: The display- set of functions tracks connected displays
-- and respond to plug/unplug events. They are also responsible for the
-- creation of tiler- window managers and manual or automatic migration
-- between window managers and their corresponding display.
--

local SIZE_UNIT = 38.4;
local displays = {
	simulate_md = false
};

-- arcan does not expose display gamma ramps or DRM/KMS- like interface
-- to adjustning gamming, so for the moment we do this basic correction
-- here and later expand with support for daltonization, ICC, profiles.
local frag_dispcorr = [[
uniform sampler2D map_tu0;
uniform vec3 gamma_exp;
varying vec2 texco;

void main(){
	vec3 col = pow(texture2D(map_tu0, texco).rgb, 1.0 / gamma_exp);
	gl_FragColor = vec4(col, 1.0);
}
]];
local corr_shid = build_shader(nil, frag_dispcorr, "color_correction");
shader_uniform(corr_shid, "gamma_exp", "fff", 2.2, 2.2, 2.2);

local function get_disp(name)
	local found, foundi;
	for k,v in ipairs(displays) do
		if (v.name == name) then
			found = v;
			foundi = k;
			break;
		end
	end
	return found, foundi;
end

local function autohome_spaces(ndisp)
	for i, disp in ipairs(displays) do
		local tiler = disp.tiler;
		if (tiler and tiler ~= ndisp.tiler) then
			for i=1,10 do
				if (tiler.spaces[i] and tiler.spaces[i].home and
					tiler.spaces[i].home == ndisp.name) then
					tiler.spaces[i]:migrate(ndisp.tiler);
				end
			end
		end
	end
end

local function run_display_action(disp, cb)
	local save = displays.main;
	set_context_attachment(disp.rt);
	cb();
	set_context_attachment(displays[save].rt);
end

local function switch_active_display(ind)
	if (displays[ind] == nil or not valid_vid(displays[ind].rt)) then
		return;
	end

	displays[displays.main].tiler:deactivate();
	displays[ind].tiler:activate();
	displays.main = ind;
	set_context_attachment(displays[ind].rt);
	mouse_querytarget(displays[ind].rt);
-- system_defaultfont(gconfig_get("font_sz") * displays[ind].sf
-- mouse_scale(displays[ind].sf);
-- switch mouse scaling factor
end

local function display_data(id)
	local data, hash = video_displaydescr(id);
	local model = "unknown";
	local serial = "unknown";
	if (not data) then
		return;
	end

-- data should typically be EDID, if it is 128 bytes long we assume it is
	if (string.len(data) == 128) then
		for i,ofs in ipairs({54, 72, 90, 108}) do

			if (string.byte(data, ofs+1) == 0x00 and
			string.byte(data, ofs+2) == 0x00 and
			string.byte(data, ofs+3) == 0x00) then
				if (string.byte(data, ofs+4) == 0xff) then
					serial = string.sub(data, ofs+5, ofs+5+12);
				elseif (string.byte(data, ofs+4) == 0xfc) then
						model = string.sub(data, ofs+5, ofs+5+12);
				end
			end

		end
	end

	local strip = function(s)
		local outs = {};
		local len = string.len(s);
		for i=1,len do
			local ch = string.sub(s, i, i);
			if string.match(ch, '[a-zA-Z0-9]') then
				table.insert(outs, ch);
			end
		end
		return table.concat(outs, "");
	end

	return strip(model), strip(serial);
end

local known_dispids = {};

function durden_display_state(action, id)
	if (displays.simple) then
		return;
	end

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

	local model, serial = display_data(id);
	local name = "unkn_" .. tostring(id);
	if (model) then
		name = string.split(model, '\r')[1] .. ":" .. serial;
	end

	if (action == "added") then
-- first mapping nonsense has previously made it easier (?!)
-- getting a valid EDID in some cases
		map_video_display(WORLDID, id, HINT_NONE);

		local modes = video_displaymodes(id);

		local dw = VRESW;
		local dh = VRESH;
		local ppcm = VPPCM;
		local subpx = "RGB";

-- we unfairly treat pixels as square and prefer subpixel hinting
		if (modes and modes[1].width > 0) then
			dw = modes[1].width;
			dh = modes[1].height;

			local wmm = modes[1].phy_width_mm;
			local hmm = modes[1].phy_height_mm;
			subpx = modes[1].subpixel_layout;
			subpx = subpx == "unknown" and "RGB" or subpx;

			if (wmm > 0 and hmm > 0) then
				ppcm = 0.1 * (math.sqrt(dw * dw + dh * dh) /
					math.sqrt(wmm * wmm + hmm * hmm));
			end
		end

-- default display is treated differently
		local ddisp;
		if (id == 0) then
			map_video_display(displays[1].rt, 0, displays[1].maphint);
			ddisp = displays[1];
			ddisp.id = 0;
			ddisp.primary = true;
		else
			ddisp = display_add(name, dw, dh, ppcm);
			ddisp.id = id;
			map_video_display(ddisp.rt, id, 0, ddisp.maphint);
			ddisp.primary = false;
		end
		ddisp.ppcm = ppcm;
		ddisp.subpx = subpx;
		known_dispids[id+1] = ddisp;

-- remove on a previous display is more like tagging it as orphan
-- as it may reappear later
	elseif (action == "removed") then
		known_dispids[id] = nil;
		display_remove(name);
	end
end

function display_manager_init()
	displays[1] = {
		tiler = tiler_create(VRESW, VRESH, {scalef = VPPCM / SIZE_UNIT});
		w = VRESW,
		h = VRESH,
		name = "default",
		ppcm = VPPCM,
	};

	displays.simple = gconfig_get("display_simple");
	displays.main = 1;
	displays[1].tiler.name = "default";

-- simple mode does not permit us to do much of the fun stuff, like different
-- color etc. correction shaders or rotate/fit/...
	if (not displays.simple) then
		displays[1].rt = displays[1].tiler:set_rendertarget(true);
		displays[1].maphint = HINT_NONE;
		show_image(displays[1].rt);
		image_shader(displays[1].rt, corr_shid);
		switch_active_display(1);
	end
end

function display_attachment()
	if (displays.simple) then
		return nil;
	else
		return displays[1].rt;
	end
end

-- if we're in "simulated" multidisplay- mode, for development and testing,
-- there's the need to dynamically add and remove to see that workspace
-- migration works smoothly.
local function redraw_simulate()
	if (not displays.simulate_md) then
		return;
	end

	local ac = 0;
	for i=1,#displays do
		if (not displays[i].orphan) then
			ac = ac + 1;
		end
	end

	if (valid_vid(displays.txt_anchor)) then
		delete_image(displays.txt_anchor);
	end
	displays.txt_anchor = null_surface(1,1);
	show_image(displays.txt_anchor);

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
			link_image(text, displays.txt_anchor);
			move_image(text, x, VRESH - font_sz);
			x = x + w;
		end
	end
	set_context_attachment(displays[displays.main].rt);
end

function display_override_density(name, ppcm)
	local disp = get_disp(name);
	if (not disp) then
		return;
	end

	disp.ppcm = ppcm;
end

function display_add(name, width, height, ppcm)
	local found = get_disp(name);
	width = width < MAX_SURFACEW and width or MAX_SURFACEW;
	height = height < MAX_SURFACEH and height or MAX_SURFACEH;

-- for each workspace, check if they are homed to the display
-- being added, and, if space exists, migrate
	if (found) then
		found.orphan = false;
		image_resize_storage(found.rt, found.w, found.h);
	else
		set_context_attachment(WORLDID);
		local nd = {
			tiler = tiler_create(width, height, {name=name, scalef=ppcm/SIZE_UNIT}),
			w = width,
			h = height,
			name = name,
			maphint = HINT_NONE
		};
		table.insert(displays, nd);
		nd.tiler.name = name;
		nd.ind = #displays;

-- this will rebuild tiler with all its little things attached to rt
		nd.rt = nd.tiler:set_rendertarget(true);

-- in the real case, we'd switch to the last known resolution
-- and then set the display to match the rendertarget
		show_image(nd.rt);
		found = nd;
		set_context_attachment(displays[displays.main].rt);
	end

	autohome_spaces(found);
	redraw_simulate();
	return found;
end

-- linear search all spaces in all displays except disp and
-- return the first empty one that is found
local function find_free_display(disp)
	for i,v in ipairs(displays) do
		if (not v.orphan and v ~= disp) then
			for j=1,10 do
				if (v.tiler:empty_space(j)) then
					return v;
				end
			end
		end
	end
end

-- sweep all used workspaces of the display and find new parents
local function autoadopt_display(disp)
	for i=1,10 do
		if (not disp.tiler:empty_space(i)) then
			local ddisp = find_free_display(disp);
			local space = disp.tiler.spaces[i];
			space:migrate(ddisp.tiler);
			space.home = disp.name;
		end
	end
end

function display_remove(name)
	local found, foundi = get_disp(name);

	if (not found) then
		warning("attempt remove unknown display");
		return;
	end

	found.orphan = true;
	image_resize_storage(found.rt, 32, 32);
	hide_image(found.rt);

	if (gconfig_get("ws_autoadopt") and autoadopt_display(found)) then
		found.orphan = false;
	end

	if (foundi == displays.main) then
		display_cycle_active(ws);
	end

	redraw_simulate();
end

function display_ressw(name, mode)
	local disp = get_disp(name);
	if (not disp) then
		warning("display_ressww(), invalid display reference for " .. tostring(name));
		return;
	end

	run_display_action(disp, function()
		video_displaymodes(disp.id, mode.modeid);
		disp.tiler:resize(mode.width, mode.height);
		image_set_txcos_default(disp.rt);
		map_video_display(disp.rt, disp.id, disp.maphint);
	end);
end

-- should only be used for debugging, disables normal multidisplay
-- and adds simulated ones on the main rendertarget
function display_simulate()
	displays.simulate_md = true;
end

function display_cycle_active()
	local nd = displays.main;
	repeat
		nd = (nd + 1 > #displays) and 1 or (nd + 1);
	until (nd == displays.main or not displays[nd].orphan);

	switch_active_display(nd);
	redraw_simulate();
end

function display_migrate_wnd(wnd, dstname)
	local dsp2 = get_disp(dstname);
	if (not dsp2) then
		return;
	end

	wnd:migrate(dsp2.tiler);
end

-- migrate the ownership of a single workspace to another display
function display_migrate_ws(disp, dstname)
	local dsp2 = get_disp(dstname);
	if (not dsp2) then
		return;
	end

	if (#disp.spaces[disp.space_ind].children > 0) then
		disp.spaces[disp.space_ind]:migrate(dsp2.tiler);
	end
end

function display_reorient(name, hint)
	if (displays.simple) then
		return;
	end

	local disp = get_disp(name);
	if (not disp) then
		warning("display_reorient on missing display:" .. tostring(name));
		return;
	end

	if (hint ~= nil) then
		disp.maphint = hint;
	else
		if (disp.maphint == HINT_ROTATE_CW_90 or
			disp.maphint == HINT_ROTATE_CCW_90) then
			disp.maphint = HINT_NONE;
		else
			disp.maphint = HINT_ROTATE_CW_90;
		end
	end

	local neww = disp.w;
	local newh = disp.h;
	if (disp.maphint == HINT_ROTATE_CW_90 or
		disp.maphint == HINT_ROTATE_CCW_90) then
		neww = disp.h;
		newh = disp.w;
	end

	run_display_action(disp, function()
		disp.tiler:resize(neww, newh);
		map_video_display(disp.rt, disp.id, disp.maphint);
	end);
end

function display_share(args, recfn)
	local disp = displays[displays.main];
	if (not valid_vid(disp.rt)) then
		return;
	end

	if (disp.share_slot) then
		delete_image(disp.share_slot);
		disp.share_slot = nil;
	else
-- this one can't handle resolution switching and we ignore audio for the
-- time being or we'd need to do a lot of attachment tracking
		disp.share_slot = alloc_surface(disp.w, disp.h, true);
		define_recordtarget(disp.share_slot,
		recfn, args, {disp.rt}, {}, RENDERTARGET_NODETACH, RENDERTARGET_NOSCALE, 1,
		function(src, status)
		end
		);
	end
end

-- the active displays is the rendertarget that will (initially) create new
-- windows, though they can be migrated immediately afterwards. This is because
-- both mouse_ implementation and new object attachment points are a global
-- state.
function active_display(rt)
	if (rt) then
		return displays[displays.main].rt;
	else
		return displays[displays.main].tiler;
	end
end

function all_displays(ref)
	return known_dispids;
end

local function save_active_display()
	return displays.main;
end

--
-- These iterators are primarily for archetype handlers and similar where we
-- need "all windows regardless of display".  Don't break- out of this or
-- things may get the wrong attachment later.
--
function all_displays_iter()
	local tbl = {};
	for i,v in ipairs(displays) do
		table.insert(tbl, {i, v});
	end
	local c = #tbl;
	local i = 0;
	local save = displays.main;

	return function()
		i = i + 1;
		if (i <= c) then
			switch_active_display(tbl[i][1]);
			return tbl[i][2].tiler;
		else
			switch_active_display(save);
			return nil;
		end
	end
end

function all_spaces_iter()
	local tbl = {};
	for i,v in ipairs(displays) do
		for k,l in pairs(v.tiler.spaces) do
			table.insert(tbl, {i,l});
		end
	end
	local c = #tbl;
	local i = 0;
	local save = displays.main;

	return function()
		i = i + 1;
		if (i <= c) then
			switch_active_display(tbl[i][1]);
			return tbl[i][2];
		else
			switch_active_display(save);
			return nil;
		end
	end
end

function all_windows(tiler, atype)
	local tbl = {};
	for i,v in ipairs(displays) do
		for j,k in ipairs(v.tiler.windows) do
			table.insert(tbl, {i, k});
		end
	end

	local i = 0;
	local c = #tbl;
	local save = displays.main;

	return function()
		i = i + 1;
		while (i <= c) do
			if (not atype or (atype and tbl[i][2].atype == atype)) then
				switch_active_display(tbl[i][1]);
				return tbl[i][2];
			else
				i = i + 1;
			end
		end
		switch_active_display(save);
		return nil;
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
