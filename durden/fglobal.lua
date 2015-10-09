--
-- Contains global / shared commmand and settings management.
--
-- builtin/global and builtin/shared initially call a lot of register_global,
-- register_shared for the functions needed for their respective menus.
-- keybindings.lua generate strings that resolve to entries in either and the
-- associated function will be called (for shared, with reference to the
-- currently selected window).
--
-- the functions set here are a sort of bare-minimal, so that navigation,
-- testing and debugging can be shared with appls that derive from this
-- codebase, but don't necessarily want to support the more advanced ones.
--
-- symbol_dispatch order:
--  1. menu command (! or #) -> run_menu_path
--  2. part of sf? lookup selected window and run
--  3. part of gf? lookup and run
--

local gf = {};
local sf = {};

function register_global(funname, funptr)
	if (gf[funname] ~= nil) then
		warning("attempt to override pre-existing function:" .. funname);
		if (DEBUGLEVEL > 0) then
			print(debug.traceback());
		end
	else
		gf[funname] = funptr;
	end
end

function register_shared(funname, funptr)
	if (sf[funname] ~= nil) then
		warning("attempt to override pre-existing shared function:" .. funname);
		if (DEBUGLEVEL > 0) then
			print(debug.traceback());
		end
	else
		sf[funname] = funptr;
	end
end

function register_shared_atype(wnd, actions, settings, keymap)
	wnd.dispatch = merge_menu(sf, actions);
end

-- used by builtin/global to map some functions here to menus
function grab_global_function(funname)
	return gf[funname];
end

function grab_shared_function(funname)
	return sf[funname];
end

function dispatch_symbol(sym, arg)
	local ms = active_display().selected;
	local ch = string.sub(sym, 1, 1);

	if (ch == "!") then
		launch_menu_path(active_display(), gf["global_actions"],
			string.sub(sym, 2));
		return;
	elseif (ch == "#") then
-- run menu command on window- specific menu
	end

	if (sf[sym]) then
		if (ms) then
			sf[sym](ms, arg);
		end
	elseif (gf[sym]) then
		gf[sym](arg);
	else
		warning("keybinding issue, " .. sym .. " does not match any known function");
	end
end

local test_gc = 0;
local testwnd_spawn = function(bar)
	if (DEBUGLEVEL > 0) then
		local img = fill_surface(math.random(200, 600), math.random(200, 600),
			math.random(64, 255), math.random(64, 255), math.random(64, 255),
			VRESW * 0.1, VRESH * 0.1);
		show_image(img);

		local wnd = active_display():add_window(img, {scalemode = "stretch"});
		if (bar) then
			wnd:set_title("test window_" .. tostring(test_gc));
			test_gc = test_gc + 1;
		end
	end
end

gf["switch_wnd_bytag"] = function()
	local tags = {};
	for i,v in ipairs(active_display().windows) do
		if (v.title_prefix and string.len(v.title_prefix) > 0) then
			table.insert(tags, v.title_prefix);
		end
	end
	if (#tags == 0) then
		active_display():message("no tagged windows found");
	end
	local bar = active_display():lbar(tiler_lbarforce(tags, function(cfstr)
		for k,v in ipairs(active_display().windows) do
			if (v.title_prefix and v.title_prefix == cfstr) then
				active_display():switch_ws(v.space);
				v:select();
				return;
			end
		end
	end), {}, {label = "Find Tagged Window:", force_completion = true});
end

local function query_ws(fptr, label)
	local names = {};
	for k,v in pairs(active_display().spaces) do
		if (v.label) then
			table.insert(names, v.label);
		end
	end
	if (#names == 0) then
		active_display():message("no labeled workspaces available");
	end

	local bar = active_display():lbar(tiler_lbarforce(names, function(cfstr)
		fptr(cfstr);
	end), {}, {label = "Find Workspace:", force_completion = true}
	);
end

sf["reassign_wnd_bywsname"] = function(wnd)
	query_ws(function(k)
		wnd:assign_ws(k);
	end, "Reassign to:");
end

gf["switch_ws_byname"] = function()
	query_ws(function(k)
		active_display():switch_ws(k);
	end, "Find Workspace:"
	);
end

sf["migrate_wnd_bydspname"] = function(wnd)
	local dsp = displays_alive(true);
	if (#dsp > 0) then
		active_display():lbar(tiler_lbarforce(dsp, function(cfstr)
			display_migrate_wnd(wnd, cfstr);
		end));
	end
end

gf["migrate_ws_bydspname"] = function()
	local dsp = displays_alive(true);
	if (#dsp > 0) then
		active_display():lbar(tiler_lbarforce(dsp, function(cfstr)
			display_migrate_ws(active_display(), cfstr);
		end));
	end
end

gf["display_cycle"] = function() display_cycle_active(); end

gf["swap_left"] = function() active_display():swap_left(); end
gf["swap_up"] = function() active_display():swap_up(); end
gf["swap_down"] = function() active_display():swap_down(); end
gf["swap_right"] = function() active_display():swap_right(); end

gf["debug_testwnd_bar"] = function() testwnd_spawn(true); end
gf["debug_testwnd_nobar"] = function() testwnd_spawn(); end

gf["debug_dump_state"] = function()
	local stm = benchmark_timestamp(0);
	system_snapshot(string.format("debug/state.%d.dump", stm));
end

gf["debug_random_alert"] = function()
	if (DEBUGLEVEL > 0) then
		local ind = math.random(1, #active_display().windows);
		active_display().windows[ind]:alert();
	end
end

-- sweep the entire bindings table
gf["rebind_basic"] = function(chain)
	local tbl = {
		{"Accept", "accept"},
		{"Cancel", "cancel"},
		{"Next", "next"},
		{"Previous", "previous"}
	};

	local used = {};

	local runsym = function(self)
		local ent = table.remove(tbl, 1);
		if (ent == nil) then
			if (chain and type(chain) == "function") then chain(); end
			return;
		end
		tiler_bbar(active_display(),
			string.format("Bind %s, press current: %s or hold new to rebind.",
				ent[1], SYSTEM_KEYS[ent[2]]), true, gconfig_get("bind_waittime"),
				SYSTEM_KEYS[ent[2]], nil,
				function(sym, done)
					if (done) then
						dispatch_system(ent[2], sym);
						table.insert(used, {sym, ent[2]});
						self(self);
					else
						for k,v in ipairs(used) do
							if (v[1] == sym) then
								return "Already bound to " .. v[2];
							end
						end
					end
				end
		);
	end

	runsym(runsym);
end

sf["wnd_tobg"] = function(wnd)
	local disp = active_display();
	local space = disp.spaces[disp.space_ind];
	space:set_background(wnd.canvas);
end

gf["drop_custom"] = dispatch_reset;

local function str_to_u8(instr)
-- drop spaces and make sure we have %2
	instr = string.gsub(instr, " ", "");
	local len = string.len(instr);
	if (len % 2 ~= 0 or len > 8) then
		return;
	end

	local s = "";
	for i=1,len,2 do
		local num = tonumber(string.sub(instr, i, i+1), 16);
		if (not num) then
			return nil;
		end
		s = s .. string.char(num);
	end

	return s;
end

local function bind_u8(hook)
	local bwt = gconfig_get("bind_waittime");
	local tbhook = function(sym, done)
		if (done) then
			active_display():lbar(
			function(ctx, instr, done, lastv)
				if (done) then
					instr = str_to_u8(instr);
					if (instr and utf8valid(instr)) then
							hook(sym, instr);
					else
						active_display():message("invalid utf-8 sequence specified");
					end
				end
			end, ctx, {label = "specify byte-sequence (like f0 9f 92 a9):"});
		end
	end;

	tiler_bbar(active_display(),
		string.format(LBL_BIND_COMBINATION, SYSTEM_KEYS["cancel"]),
		"keyorcombo", bwt, nil, SYSTEM_KEYS["cancel"], tbhook);
end

gf["bind_utf8"] = function()
	bind_u8(function(sym, str)
		SYMTABLE:add_translation(sym, str);
	end);
end

sf["bind_utf8"] = function(wnd)
	bind_u8(function(sym, str)
		wnd.u8_translation[sym] = str;
		SYMTABLE:translation_overlay(wnd.u8_translation);
	end);
end

gf["bind_menu"] = function(sfun)
	local bwt = gconfig_get("bind_waittime");
	tiler_bbar(active_display(),
		string.format(LBL_BIND_COMBINATION, SYSTEM_KEYS["cancel"]),
		false, bwt, nil, SYSTEM_KEYS["cancel"],
		function(sym, done)
			if (done) then
				dispatch_custom(sym, "global_actions", true);
			end
		end
	);
end

gf["bind_custom"] = function(sfun)
	local bwt = gconfig_get("bind_waittime");
	IN_CUSTOM_BIND = true; -- needed for some special options

	tiler_bbar(active_display(),
		string.format(LBL_BIND_COMBINATION, SYSTEM_KEYS["cancel"]),
		false, bwt, nil, SYSTEM_KEYS["cancel"],
		function(sym, done)
			if (done) then
				launch_menu_hook(function(path)
					IN_CUSTOM_BIND = false;
					local res = dispatch_custom(sym, path);
					if (res ~= nil) then
						active_display():message(res .. " unbound");
					end
				end);
				active_display():message("select function to bind to " .. sym, -1);
				local ctx = gf["global_actions"]();
				ctx.on_cancel = function()
					launch_menu_hook(nil);
					IN_CUSTOM_BIND = false;
					active_display():message(nil);
				end;
			end
		end
	);
end

gf["unbind_combo"] = function()
	local bwt = gconfig_get("bind_waittime");
	tiler_bbar(active_display(),
		string.format(LBL_UNBIND_COMBINATION, SYSTEM_KEYS["cancel"]),
		"keyorcombo", bwt, nil, SYSTEM_KEYS["cancel"],
		function(sym, done)
			if (done) then
				dispatch_custom(sym, nil);
				SYMTABLE:add_translation(sym, nil);
				dispatch_load();
			end
		end);
end

-- a little messy, but covers binding single- keys for meta 1 and meta 2
gf["rebind_meta"] = function(chain)
	local bwt = gconfig_get("bind_waittime");
	tiler_bbar(active_display(),
			string.format("Press and hold (Meta 1), %s to Abort",
				SYSTEM_KEYS["cancel"]), true, bwt, nil, SYSTEM_KEYS["cancel"],
		function(sym, done)
			if (done) then
				tiler_bbar(active_display(),
					string.format("Press and hold (Meta 2), %s to Abort",
					SYSTEM_KEYS["cancel"]), true, bwt, nil, SYSTEM_KEYS["cancel"],
					function(sym2, done)
						if (done) then
							active_display():message(
								string.format("Meta 1,2 set to %s, %s", sym, sym2));
							dispatch_system("meta_1", sym);
							dispatch_system("meta_2", sym2);
							meta_guard_reset();
							if (chain and type(chain) == "function") then chain(); end
						end
						if (sym2 == sym) then
							return "Already bound to Meta 1";
						end
				end);
			end
		end
	);
end

gf["query_launch"] = function()
	local	targets = list_targets();
	if (targets == nil or #targets == 0) then
		active_display():message("Database does not contain any targets");
	else
		active_display():lbar(tiler_lbarforce(targets, function(str)
			local cfgs = target_configurations(str);
			if (cfgs == nil or #cfgs == 0) then
				return;
			end

			if (#cfgs > 1) then
				active_display():lbar(tiler_lbarforce(cfgs, function(cfstr)
					vid = launch_target(str, cfstr, LAUNCH_INTERNAL, def_handler);
					if (valid_vid(vid)) then
						durden_launch(vid, cfstr, str);
					end
				end), {}, {label = str .. ", Config:", force_completion = true});
			else
				vid = launch_target(str, cfgs[1], LAUNCH_INTERNAL, def_handler);
				if (valid_vid(vid)) then
					durden_launch(vid, cfstr, str);
				end
			end

		end), {}, {label = "Target:", force_completion = true});
	end
end

gf["rename_space"] = function()
	active_display():lbar(function(ctx, instr, done)
			if (done) then
				ctx.space:set_label(instr);
				ctx.space.wm:update_statusbar();
			end
			ctx.ulim = 16;
			return {set = {}};
		end,
		{space = active_display().spaces[active_display().space_ind]},
		{label = "Rename Space:"}
	);
end

gf["mouse_sensitivity"] = function(val)
	gconfig_set("mouse_factor")(val and tonumber(val) or 1.0);
	mouse_state().accel_x = gconfig_get("mouse_factor");
	mouse_state().accel_y = gconfig_get("mouse_factor");
end

local function allgain(val)
	for wnd in all_windows() do
		if (wnd.source_audio) then
			audio_gain(wnd.source_audio,
				val * (wnd.source_gain and wnd.source_gain or 1.0),
		  	gconfig_get("gain_fade"));
		end
	end
end

gf["gain_stepv"] = function(val)
	val = val or 0.1;
	local gv = gconfig_get("global_gain");
	gv = gv + val;
	gv = (gv > 1.0 and 1.0 or gv) < 0.0 and 0.0 or gv;
	gconfig_set("global_gain", gv);
	allgain(gv);
end

gf["toggle_audio"] = function()
	local new_state = not gconfig_get("global_mute");
	allgain(new_state and 0.0 or gconfig_get("global_gain"));
	gconfig_set("global_mute", new_state);
end

gf["save_space_shallow"] = function()
	local wspace = active_display().spaces[active_display().space_ind];
	if (not wspace) then
		return;
	end

	wspace:save(true);
end

gf["save_space_deep"] = function()
	gf["save_space_shallow"]();
	warning("save layout (wnd, type, ...), + affinity and scale ratios");
end

gf["save_space_drop"] = function()
	warning("reset layout, should confirm");
end

gf["mode_vertical"] = function()
	local wspace = active_display().spaces[active_display().space_ind];
	if (wspace) then
		wspace.insert = "vertical";
		wspace.wm:tile_update();
	end
end
gf["mode_horizontal"] = function()
	local wspace = active_display().spaces[active_display().space_ind];
	if (wspace) then
		wspace.insert = "horizontal";
		wspace.wm:tile_update();
	end
end
gf["tabtile"] = function()
	local wspace = active_display().spaces[active_display().space_ind];
	if (wspace) then
		if (wspace.mode == "tab" or wspace.mode == "fullscreen") then
			wspace:tile();
		else
			wspace:tab();
		end
	end
end
gf["float"] = function()
	local wspace = active_display().spaces[active_display().space_ind];
	if (wspace) then
		wspace:float();
	end
end

gf["vtabtile"] = function()
	local wspace = active_display().spaces[active_display().space_ind];
	if (wspace) then
		if (wspace.mode == "vtab" or wspace.mode == "fullscreen") then
			wspace:tile();
		else
			wspace:vtab();
		end
	end
end

sf["fullscreen"] = function(wnd)
	(wnd.fullscreen and wnd.space.tile or wnd.space.fullscreen)(wnd.space);
end
sf["mergecollapse"] = function(wnd)
	(#wnd.children > 0 and wnd.collapse or wnd.merge)(wnd);
end
sf["grow_v"] = function(wnd) wnd:grow(0, 0.05); end
sf["shrink_v"] = function(wnd) wnd:grow(0, -0.05); end
sf["grow_h"] = function(wnd) wnd:grow(0.05, 0); end
sf["shrink_h"] = function(wnd) wnd:grow(-0.05, 0); end
sf["step_up"] = function(wnd) wnd:prev(1); end
sf["step_down"] = function(wnd) wnd:next(1); end
sf["step_left"] = function(wnd)	wnd:prev(); end
sf["step_right"] = function(wnd) wnd:next(); end
sf["destroy"] = function(wnd) wnd:destroy(); end

for i=1,10 do
	gf["switch_ws" .. tostring(i)] = function() active_display():switch_ws(i); end
	sf["assign_ws" .. tostring(i)] = function(wnd) wnd:assign_ws(i); end
	gf["swap_ws" .. tostring(i)] = function() active_display():swap_ws(i); end
end
