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
local displays = {};
local profiles = {};

--uncomment to log display events to a separate file, there are so many
--hw/os/... related issues for plug /unplug edge behaviors that this is
--needed.
-- zap_resource("display.log");
-- local dbgoutp = open_nonblock("display.log", true);
local dbgoutp = nil;
local function display_debug(msg)
	if (dbgoutp) then
		dbgoutp:write(msg);
	end
end

local function get_disp(name)
	local found, foundi;
	for k,v in ipairs(displays) do
		if (type(name) == "string" and v.name == name) then
			found = v;
			foundi = k;
			break;
		elseif (type(name) == "number" and v.id == name) then
			found = v;
			foundi = k;
		end
	end
	return found, foundi;
end

local function tryload(v)
	local res = system_load(v, 0);

	if (not res) then
		warning("parsing error loading display map: " .. v);
		return;
	end

	local okstate, map = pcall(res);
	if (not okstate or type(map) ~= "table") then
		warning("execution error loading map: " .. v);
		return;
	end

	if (type(map.name) ~= "string" or
		type(map.ident) ~= "string") then
		warning("bad obligatory fields in map: " .. v);
		return;
	end

	local rv = {
		name = map.name,
		ident = map.ident
	};

-- copy and sanity check optional fields

	if (type(map.ppcm) == "number" and map.ppcm < 200 and map.ppcm > 10) then
		rv.ppcm = map.ppcm;
	end

	if (type(map.wm) == "string") then
		if (map.wm == "tiler" or map.wm == "ignore") then
			rv.wm = map.wm;
		end
	end

	if (type(map.width) == "number" and map.width > 0) then
		rv.width = map.width;
	end

	if (type(map.height) == "number" and map.height > 0) then
		rv.height = map.width;
	end

	return rv;
end

function display_scanprofiles()
	profiles = {};
	local lst = glob_resource("devmaps/display/*.lua", APPL_RESOURCE);
	if (not lst) then
		return;
	end
	table.sort(lst);
	for k,v in ipairs(lst) do
		local res = tryload("devmaps/display/" .. v);
		if (res) then
			table.insert(profiles, res);
		end
	end
end

display_scanprofiles();

function display_maphint(disp)
	if (type(disp) == "string") then
		disp = get_disp(disp);
	end

	if (type(disp) ~= "table") then
		return HINT_NONE;
	end

	return bit.bor(disp.maphint, (disp.primary and HINT_PRIMARY or 0));
end

local function autohome_spaces(ndisp)
	local migrated = false;

	for i, disp in ipairs(displays) do
		local tiler = disp.tiler;
		if (tiler and tiler ~= ndisp.tiler) then
			for i=1,10 do
				if (tiler.spaces[i] and tiler.spaces[i].home and
					tiler.spaces[i].home == ndisp.name) then
					tiler.spaces[i]:migrate(ndisp.tiler);
					migrated = true;
					display_debug(string.format("migrated %s:%d to %s",
						tiler.name, i, ndisp.name));
				end
			end
		end
	end
end

local function set_mouse_scalef()
	local sf = gconfig_get("mouse_scalef");
	mouse_cursor_sf(sf * displays[displays.main].tiler.scalef,
		sf * displays[displays.main].tiler.scalef);
end

local function run_display_action(disp, cb)
	local save = displays.main;

	if (type(disp) == "number") then
		set_context_attachment(disp);
	else
		set_context_attachment(disp.rt);
	end
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
	set_mouse_scalef();
end

local function set_best_mode(disp, w, h)
end

local function display_data(id)
	local data, hash = video_displaydescr(id);
	local model = "unknown";
	local serial = "unknown";
	if (not data) then
		return;
	end

-- data should typically be EDID, if it is 128 bytes long we assume it is
	if (string.len(data) == 128 or string.len(data) == 256) then
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

local function get_ppcm(pw_cm, ph_cm, dw, dh)
	return (math.sqrt(dw * dw + dh * dh) /
		math.sqrt(pw_cm * pw_cm + ph_cm * ph_cm));
end

function display_count()
	return #displays;
end

-- "hard" fullscreen- mode where the window canvas is mapped directly to
-- the display without going through the detour of a rendertarget. Note that
-- this is not as close as we can go yet, but requires more platform support
-- and loses the ability to apply a shader.
--
-- The 'real' version would require not only a mode-switch but:
--
--  * track producer state and mark that we need a scanout capable buffer
--    (which depend on the buffer format and so on) handle and wrap- shmif
--    vbuf-only drawing into such a buffer. This can already
--
--  * for kms-, have arcan directly wrap the shmif- part into a DMAbuf and
--    send that as the scanout for cases.
--
--  * use more native post-processing for ICC-/ gamma correction
--
function display_fullscreen(name, vid, modesw, mapv)
	local disp = get_disp(name);
	if (not disp) then
		return;
	end

	if  not valid_vid(vid) then
		for i, j in ipairs(displays) do
			if (valid_vid(j.rt)) then
				rendertarget_forceupdate(j.rt, -1);
			end
		end

-- tell the connected tiler to restore old mode so target_hints,
-- locking etc. propagate correctly, it's implemented here rather than in
-- tiler to support different WMs.
		map_video_display(disp.rt, disp.id, display_maphint(disp));
		if (disp.last_m and disp.fs_modesw) then
			video_displaymodes(disp.id, disp.last_m.modeid);
		end
		disp.monitor_vid = nil;
		disp.monitor_sprops = nil;
		if (disp.fs_mode) then
			local ws = disp.tiler.spaces[disp.tiler.space_ind];
			if (type(ws[disp.fs_mode]) == "function") then
				ws[disp.fs_mode](ws);
			end
			disp.fs_mode = nil;
		end
	else

		for i,j in ipairs(displays) do
			if (valid_vid(j.rt)) then
				rendertarget_forceupdate(j.rt, gconfig_get("display_fs_rtrate"));
			end
		end

		disp.monitor_vid = vid;
		local ws = disp.tiler.spaces[disp.tiler.space_ind];
		disp.fs_mode = ws.mode;
		map_video_display(vid, disp.id, display_maphint(disp));
	end

-- will be applied in tick
	disp.fs_modesw = modesw;
end

local function display_load(display)
	if (not display or not display.name) then
		warning("load called on broken display");
		return;
	end

	local pref = "disp_" .. hexenc(display.name) .. "_";
	local keys = match_keys(pref .. "%");
	for i,v in ipairs(keys) do
		local ind = string.find(v, "=");
		if (ind) then
			local key = string.sub(string.sub(v, 1, ind-1), string.len(pref) + 1);
			local val = string.sub(v, ind+1);
			if (key == "ppcm") then
				if (tonumber(val)) then
					display_override_density(display.name, tonumber(val));
				end
			elseif (key == "map") then
				if (tonumber(val)) then
					display_reorient(display.name, tonumber(val));
				end
			elseif (key == "shader") then
				display_shader(display.name, val);
			elseif (key == "bg") then
				display.tiler:set_background(val);
			elseif (key == "primary") then
				display.primary = tonumber(val) == 1;
			else
				warning("unknown stored display setting with key " .. key);
			end
		end
	end

	if (not display.shader) then
		display_shader(display.name, gconfig_get("display_shader"));
	end
end

function display_manager_shutdown()
	local ktbl = {};
	for i,v in ipairs(displays) do
		local pref = "disp_" .. hexenc(v.name) .. "_";
		if (v.ppcm_override) then
			ktbl[pref .. "ppcm"] = v.ppcm;
		end
		if (v.maphint) then
			ktbl[pref .. "map"] = v.maphint;
		end
		if (v.shader) then
			ktbl[pref .. "shader"] = v.shader;
-- MISSING: pack/unpack shader arguments
		end
		if (v.background) then
			ktbl[pref .. "bg"] = v.background;
		end
		ktbl[pref .. "primary"] = v.primary and 1 or 0;
	end
-- MISSING: mode settings
	store_key(ktbl);
end

local function get_name(id)
-- first mapping nonsense has previously made it easier (?!)
-- getting a valid EDID in some cases
	local name = id == 0 and "default" or "unkn_" .. tostring(id);
	map_video_display(WORLDID, id, HINT_NONE);
	local model, serial = display_data(id);
	if (model) then
		name = string.split(model, '\r')[1] .. "/" .. serial;
		display_debug(string.format(
			"monitor %d resolved to %s, serial %s\n", id, model, serial));
	end
	return name;
end

function display_set_backlight(name, ctrl, ind)
	local disp = get_disp(name);
	if (not disp) then
		return;
	end

	if not (ctrl and ctrl >= 0 and ind and ind >= 0) then
		disp.ledctrl = nil;
		disp.ledid = nil;
		return;
	end

	disp.backlight = 1.0;
	disp.ledctrl = ctrl;
	disp.ledid = ind;

	led_intensity(ctrl, ind, 255.0 * disp.backlight);
end

function display_event_handler(action, id)
	local ddisp, newh;
	if (displays.simple) then
		return;
	end

	display_debug(string.format("id: %d, action: %s\n",
		id and id or -1, action and action or ""));

-- display subsystem and input subsystem are connected when it comes
-- to platform specific actions e.g. virtual terminal switching, assume
-- keystate change between display resets.
	if (action == "reset") then
		dispatch_meta_reset();
		iostatem_reset_flag();
		return;
	end

	if (action == "added") then
		local modes = video_displaymodes(id);
		local dw = VRESW;
		local dh = VRESH;
		local ppcm = VPPCM;
		local subpx = "RGB";

		if (modes and modes[1].width > 0) then
			dw = modes[1].width;
			dh = modes[1].height;

			local wmm = modes[1].phy_width_mm;
			local hmm = modes[1].phy_height_mm;
			subpx = modes[1].subpixel_layout;
			subpx = subpx == "unknown" and "RGB" or subpx;

			if (wmm > 0 and hmm > 0) then
				ppcm = get_ppcm(0.1*wmm, 0.1*hmm, dw, dh);
			end
		end

		if (id == 0) then
			ddisp = displays[1];
			ddisp.id = 0;
			ddisp.name = get_name(0);
			ddisp.primary = true;
			map_video_display(displays[1].rt, 0, display_maphint(displays[1]));
			shader_setup(ddisp.rt, "display", ddisp.shader, ddisp.name);
		else
			ddisp, newh = display_add(get_name(id), dw, dh, ppcm);
			if (not ddisp) then
				return;
			end

			ddisp.id = id;
			map_video_display(ddisp.rt, id, display_maphint(ddisp));
		end
		display_load(ddisp);

-- load possible overrides since before, note that this is slightly
-- inefficient as it will force rebuild of underlying rendertargets
-- etc. but it beats have to cover a number of corner cases / races
		ddisp.ppcm = ppcm;
		ddisp.subpx = subpx;
		if (not ddisp.ramps) then
			ddisp.ramps = video_displaygamma(ddisp.id);
			ddisp.active_ramps = ddisp.ramps;
		end

-- remove on a previous display is more like tagging it as orphan
-- as it may reappear later
	elseif (action == "removed") then
		display_remove(name, id);
	end

	return newh;
end

function display_all_mode(mode)
	for i,v in ipairs(displays) do
		video_display_state(v.id, mode);
	end
end

function display_manager_init()
	displays[1] = {
		tiler = tiler_create(VRESW, VRESH, {scalef = VPPCM / SIZE_UNIT});
		w = VRESW,
		h = VRESH,
		name = get_name(0),
		id = 0,
		ppcm = VPPCM
	};

	displays.simple = gconfig_get("display_simple");
	displays.main = 1;
	local ddisp = displays[1];
	ddisp.tiler.disptbl = {ppcm = VPPCM, width = VRESW, height = VRESH};
	ddisp.tiler.name = "default";

-- simple mode does not permit us to do much of the fun stuff, like different
-- color etc. correction shaders or rotate/fit/...
	if (not displays.simple) then
		rendertarget_forceupdate(WORLDID, 0);
		ddisp.rt = ddisp.tiler:set_rendertarget(true);
		ddisp.maphint = HINT_NONE;
		ddisp.shader = gconfig_get("display_shader");
		shader_setup(ddisp.rt, "display", ddisp.shader, ddisp.name);
		switch_active_display(1);
		display_load(displays[1]);
	end

	return displays[1].tiler;
end

function display_attachment()
	if (displays.simple) then
		return nil;
	else
		return displays[1].rt;
	end
end

function display_override_density(name, ppcm)
	local disp, dispi = get_disp(name);
	if (not disp) then
		return;
	end

-- it might be that the selected display is not currently the main one
	run_display_action(disp, function()
		disp.ppcm = ppcm;
		disp.ppcm_override = ppcm;
		disp.tiler:update_scalef(ppcm / SIZE_UNIT, {ppcm = ppcm});
		set_mouse_scalef();
	end);
end

-- override the default shader setting to packval, that can be expanded
-- upon display identification and shader setup
function display_shader_uniform(name, uniform, packval)
--	print("update uniform persistance", name, uniform, packval);
end

function display_shader(name, key)
	local disp, dispi = get_disp(name);
	if (not disp or not valid_vid(disp.rt)) then
		return;
	end

	if (key) then
		shader_setup(disp.rt, "display", key, disp.name);
		--set_key("disp_" .. hexenc(disp.name) .. "_shader", key);
		disp.shader = key;
	end

	return disp.shader;
end

function display_add(name, width, height, ppcm)
	local found = get_disp(name);
	local new = nil;

	width = math.clamp(width, width, MAX_SURFACEW);
	height = math.clamp(height, height, MAX_SURFACEH);

-- for each workspace, check if they are homed to the display
-- being added, and, if space exists, migrate
	if (found) then
		display_debug(string.format(
			"adding display matched known orphan: %s", found.name));
		found.orphan = false;
		image_resize_storage(found.rt, found.w, found.h);
		display_load(found);

	else
		local prof;
		for k,v in ipairs(profiles) do
			if (string.match(name, v.ident)) then
				prof = v;
				break;
			end
		end

		if (prof) then
-- facility for supporting more window management styles in the future
			if (prof.wm == "ignore") then
				return;
			end

			if (prof.width) then
				width = math.clamp(prof.width, prof.width, MAX_SURFACEW);
			end
			if (prof.height) then
				height = math.clamp(prof.height, prof.height, MAX_SURFACEW);
			end
			if (prof.ppcm) then
				ppcm = prof.ppcm;
			end
		end

		set_context_attachment(WORLDID);
		local nd = {
			tiler = tiler_create(width, height, {name=name, scalef=ppcm/SIZE_UNIT}),
			w = width,
			h = height,
			name = name,
			primary = false,
			maphint = HINT_NONE
		};
		nd.disptbl = {ppcm = ppcm, width = width, height = height};
		table.insert(displays, nd);
		nd.tiler.name = name;
		nd.ind = #displays;
		new = nd.tiler;

-- this will rebuild tiler with all its little things attached to rt
-- we hide it as we explicitly map to a display and do not want it visible
-- in the WORLDID domain, eating fillrate.
		nd.rt = nd.tiler:set_rendertarget(true);
		hide_image(nd.rt);

-- in the real case, we'd switch to the last known resolution
-- and then set the display to match the rendertarget
		found = nd;
		set_context_attachment(displays[displays.main].rt);
	end

-- this also takes care of spaces that are saved as preferring a certain disp.
	autohome_spaces(found);

	if (found.last_m) then
		display_ressw(name, found.last_m);
	end
	return found, new;
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

function display_remove(name, id)
	local found, foundi = get_disp(name);

-- first by name, then by id
	if (not found) then
		for k,v in ipairs(displays) do
			if (id and v.id == id) then
				found = v;
				foundi = k;
				break;
			end
		end

		if (not found) then
			warning("attempted to remove unknown display: " .. name);
			return;
		end
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
end

-- special little hook in LWA mode that handles resize requests from
-- parent. We treat that as a 'normal' resolution switch.
function VRES_AUTORES(w, h, vppcm, flags, source)
	local disp = displays[1];
	display_debug(string.format("autores(%f, %f, %f, %d, %d)",
		w, h, vppcm, flags, source));

	for k,v in ipairs(displays) do
		if (v.id == source) then
			disp = v;
			break;
		end
	end

	if (gconfig_get("lwa_autores")) then
		if (displays.simple) then
			resize_video_canvas(w, h);
			disp.tiler:resize(w, h, true);
		else
			run_display_action(disp, function()
				if (video_displaymodes(source, w, h)) then
					map_video_display(disp.rt, WORLDID, disp.maphint);
					resize_video_canvas(w, h);
					image_set_txcos_default(disp.rt);
					disp.tiler:resize(w, h);
					disp.tiler:update_scalef(disp.ppcm / SIZE_UNIT, {ppcm = disp.ppcm});
				end
			end);
		end
	end

end

function display_ressw(name, mode)
	local disp = get_disp(name);
	if (not disp) then
		warning("display_ressww(), invalid display reference for "
			.. tostring(name));
		return;
	end

-- track this so we can recover if the display is lost, readded and homed to def
	disp.last_m = mode;
	disp.ppcm = get_ppcm(0.1 * mode.phy_width_mm,
		0.1 * mode.phy_height_mm, mode.width, mode.height);

	run_display_action(disp, function()
		disp.w = mode.width;
		disp.h = mode.height;
		video_displaymodes(disp.id, mode.modeid);
		if (valid_vid(disp.rt)) then
			image_set_txcos_default(disp.rt);
			map_video_display(disp.rt, disp.id, display_maphint(disp));
		end
		disp.tiler:resize(mode.width, mode.height) --, true);
		disp.tiler:update_scalef(disp.ppcm / SIZE_UNIT, {ppcm = disp.ppcm});
		set_mouse_scalef();
	end);

	if (disp.maphint) then
		display_reorient(name, disp.maphint);
	end

-- as the dimensions have changed
	if (active_display(true) == disp.rt) then
		mouse_querytarget(disp.rt);
	end
end

function display_cycle_active(ind)
	if (type(ind) == "boolean") then
		switch_active_display(displays.main);
		return;
	end

	local nd = displays.main;
	repeat
		nd = (nd + 1 > #displays) and 1 or (nd + 1);
	until (nd == displays.main or not
		(displays[nd].orphan or displays[nd].disabled));

	switch_active_display(nd);
end

function display_migrate_wnd(wnd, dstname)
	local dsp2 = get_disp(dstname);
	if (not dsp2) then
		return;
	end

	wnd:migrate(dsp2.tiler, {ppcm = dsp2.ppcm,
		width = dsp2.tiler.width, height = dsp2.tiler.height});
end

-- migrate the ownership of a single workspace to another display
function display_migrate_ws(tiler, dstname)
	local dsp2 = get_disp(dstname);
	if (not dsp2) then
		return;
	end

	if (#tiler.spaces[tiler.space_ind].children > 0) then
		tiler.spaces[tiler.space_ind]:migrate(dsp2.tiler,
			{ppcm = dsp2.ppcm,
			width = dsp2.tiler.width, height = dsp2.tiler.height
		});
		tiler:tile_update();
		dsp2.tiler:tile_update();
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

	local mfl = bit.bor(HINT_ROTATE_CW_90, HINT_ROTATE_CCW_90);
	if (hint ~= nil) then
		disp.maphint = bit.bor(disp.maphint, hint);
	else
		if (bit.band(disp.maphint, mfl) > 0) then
			disp.maphint = bit.band(disp.maphint, bit.bnot(mfl));
		else
			disp.maphint = bit.bor(disp.maphint, HINT_ROTATE_CW_90);
		end
	end

	local neww = disp.w;
	local newh = disp.h;
	if (bit.band(disp.maphint, mfl) > 0) then
		neww = disp.h;
		newh = disp.w;
	end

	run_display_action(disp, function()
		map_video_display(disp.rt, disp.id, display_maphint(disp));
		disp.tiler:resize(neww, newh);
		disp.tiler:update_scalef(disp.tiler.scalef);
	end);

-- as the dimensions have changed
	if (active_display(true) == disp.rt) then
		mouse_querytarget(disp.rt);
	end
end

function display_simple()
	return displays.simple;
end

function display_share(disp, args, recfn)
	if (not valid_vid(disp.rt)) then
		return;
	end

	if (disp.share_slot) then
		delete_image(disp.share_slot);
		disp.share_slot = nil;
	else
-- this one can't handle resolution switching and we ignore audio for the
-- time being or we'd need to do a lot of attachment tracking
		local isp = image_storage_properties(disp.rt);
		disp.share_slot = alloc_surface(isp.width, isp.height, true);
		local indir = null_surface(isp.width, isp.height);
		show_image(indir);
		image_sharestorage(disp.rt, indir);
		define_recordtarget(disp.share_slot,
		recfn, args, {indir}, {}, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -1,
		function(src, status)
		end
		);
	end
end

-- the active displays is the rendertarget that will (initially) create new
-- windows, though they can be migrated immediately afterwards. This is because
-- both mouse_ implementation and new object attachment points are a global
-- state.
function active_display(rt, raw)
	if (raw) then
		return displays[displays.main];
	elseif (rt) then
		return displays[displays.main].rt;
	else
		return displays[displays.main].tiler;
	end
end

local function save_active_display()
	return displays.main;
end

--
-- These iterators are primarily for archetype handlers and similar where we
-- need "all windows regardless of display".  Don't break- out of this or
-- things may get the wrong attachment later.
--
local function aditer(rawdisp, showorph, showdis)
	local tbl = {};
	for i,v in ipairs(displays) do
		if ((not v.orphan or showorph) and (not v.disabled or showdis)) then
			table.insert(tbl, {i, v});
		end
	end
	local c = #tbl;
	local i = 0;
	local save = displays.main;

	return function()
		i = i + 1;
		if (i <= c) then
			switch_active_display(tbl[i][1]);
			return rawdisp and tbl[i][2] or tbl[i][2].tiler;
		else
			switch_active_display(save);
			return nil;
		end
	end
end

function all_tilers_iter()
	return aditer(false);
end

function all_displays_iter()
	return aditer(true);
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

function all_windows(atype)
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
		if (not (v.orphan or v.disabled) and (not filter or k ~= displays.main)) then
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

-- periodically check source for dedicated fullscreen mode
		if (not displays.simple and v.monitor_vid) then

-- on death, set "BADID" (which will revert mapping to normal rt)
			if (not valid_vid(v.monitor_vid, TYPE_FRAMESERVER)) then
				display_fullscreen(v.name, BADID);
			else
				local isp = image_storage_properties(v.monitor_vid);

-- deferred resize- propagation due to cost of mode switch, this could probably
-- be even more conservative, though resolution switches in the source will
-- cause a visual glitch for the 'incorrect' frames.
				if (not v.monitor_sprops or isp.width ~= v.monitor_sprops.width or
					isp.height ~= v.monitor_sprops.height) then
					v.monitor_sprops = isp;
					if (v.fs_modesw) then
						set_best_mode(v, isp.width, isp.height);
					end
-- remap so crop-center works
				end
			end
		end
	end
end
