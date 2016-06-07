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
	if (gf[funname] ~= nil) then
		warning("collision with existing global function for " .. funname);
	end

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
	if (sf[funname]) then
		return function()
			if (active_display().selected) then
				return sf[funname](active_display().selected);
			end
		end
	else
		return function() warning("missing shared function " .. funname); end
	end
end

function dispatch_symbol(sym, arg)
	local ms = active_display().selected;
	local ch = string.sub(sym, 1, 1);

	if (DEBUGLEVEL > 2 and active_display().debug_console) then
		active_display().debug_console:add_symbol(sym);
	end

	if (ch == "!") then
		launch_menu_path(active_display(), gf["global_actions"],
			string.sub(sym, 2), nil, "!");
		return;
	elseif (ch == "#") then
		launch_menu_path(active_display(), sf["target_actions"],
			string.sub(sym, 2), nil, "#");
		return;
	end

	if (sf[sym] and ms) then
			sf[sym](ms, arg);
	elseif (gf[sym]) then
		gf[sym](arg);
	else
		warning("keybinding issue, " .. sym .. " does not match any known function");
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

gf["switch_ws_byname"] = function()
	query_ws(function(k)
		active_display():switch_ws(k);
	end, "Find Workspace:"
	);
end

sf["migrate_wnd_bydspname"] = function()
	local res = {};
	local wnd = active_display().selected;

	for d in all_displays_iter() do
		table.insert(res, {
			name = "migrate_" .. hexenc(d.name),
			label = d.name,
			kind = "action",
			handler = function()
				display_migrate_wnd(wnd, d.name);
			end
		});
	end

	return res;
end

gf["migrate_ws_bydspname"] = function()
	local dsp = displays_alive(true);
	local res = {};

	for i,v in ipairs(dsp) do
		table.insert(res, {
			name = "migrate_" .. tostring(i),
			label = v,
			kind = "action",
			handler = function()
				display_migrate_ws(active_display(), v);
			end
		});
	end

	return res;
end

gf["display_cycle"] = function() display_cycle_active(); end

gf["swap_left"] = function() active_display():swap_left(); end
gf["swap_up"] = function() active_display():swap_up(); end
gf["swap_down"] = function() active_display():swap_down(); end
gf["swap_right"] = function() active_display():swap_right(); end

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

local function allsusp(atype)
	for wnd in all_windows(atype) do
		if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
			wnd.temp_suspend = true;
			wnd:set_suspend(true);
		end
	end
end

local function allresume(atype)
	for wnd in all_windows(atype) do
		if (wnd.temp_suspend and
			valid_vid(wnd.external, TYPE_FRAMESERVER)) then
			wnd:set_suspend(false);
		end
	end
end

gf["all_suspend"] = function()
	allsusp();
end

gf["all_resume"] = function()
	allresume();
end

gf["all_media_resume"] = function()
	for k,v in ipairs({"game", "multimedia", "lwa"}) do
		allresume(v);
	end
end

gf["all_media_suspend"] = function()
	for k,v in ipairs({"game", "multimedia", "lwa"}) do
		allsusp(v);
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
	local wnd = disp.selected;
	local space = disp.spaces[disp.space_ind];
	if (valid_vid(wnd.external)) then
		wnd.dispstat_block = true;
	end
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

function fglobal_bind_u8(hook)
	local bwt = gconfig_get("bind_waittime");
	local tbhook = function(sym, done, sym2, iotbl)
		if (not done) then
			return;
		end

		local bar = active_display():lbar(
		function(ctx, instr, done, lastv)
			if (not done) then
				return instr and string.len(instr) > 0 and str_to_u8(instr) ~= nil;
			end

			instr = str_to_u8(instr);
			if (instr and utf8valid(instr)) then
					hook(sym, instr, sym2, iotbl);
			else
				active_display():message("invalid utf-8 sequence specified");
			end
		end, ctx, {label = "specify byte-sequence (like f0 9f 92 a9):"});
		suppl_widget_path(bar, bar.anchor, "special:u8", bar.barh);
	end;

	tiler_bbar(active_display(),
		string.format(LBL_BIND_COMBINATION, SYSTEM_KEYS["cancel"]),
		"keyorcombo", bwt, nil, SYSTEM_KEYS["cancel"], tbhook);
end

gf["bind_utf8"] = function()
	fglobal_bind_u8(function(sym, str, sym2, iotbl)
		SYMTABLE:add_translation(sym2 and sym2 or sym, str);
	end);
end

sf["bind_utf8"] = function(wnd)
	fglobal_bind_u8(function(sym, str, sym2)
		wnd.u8_translation[sym2 and sym2 or sym] = str;
		SYMTABLE:translation_overlay(wnd.u8_translation);
	end);
end

gf["bind_tmenu"] = function(sfun)
	local bwt = gconfig_get("bind_waittime");
	tiler_bbar(active_display(),
		string.format(LBL_BIND_COMBINATION, SYSTEM_KEYS["cancel"]),
		false, bwt, nil, SYSTEM_KEYS["cancel"],
		function(sym, done)
			if (done) then
				dispatch_custom(sym, "target", false, true);
			end
		end
	);
end

gf["bind_menu"] = function(sfun)
	local bwt = gconfig_get("bind_waittime");
	tiler_bbar(active_display(),
		string.format(LBL_BIND_COMBINATION, SYSTEM_KEYS["cancel"]),
		false, bwt, nil, SYSTEM_KEYS["cancel"],
		function(sym, done)
			if (done) then
				dispatch_custom(sym, "global", false);
			end
		end
	);
end

-- ignore: sfun, lbl, cctx
gf["bind_custom"] = function(sfun, lbl, ctx, wnd, m1, m2)
	local bwt = gconfig_get("bind_waittime");

	local ctx = tiler_bbar(active_display(),
		string.format(LBL_BIND_COMBINATION_REP, SYSTEM_KEYS["cancel"]),
		false, bwt, nil, SYSTEM_KEYS["cancel"],
		function(sym, done)
			if (done) then
				launch_menu_hook(function(path)
					IN_CUSTOM_BIND = false;
					local res = dispatch_custom(sym, path, false, wnd, m1);
					active_display():message(res and res .. " unbound" or nil);
				end);
				active_display():message("select function to bind to " .. sym, -1);
				IN_CUSTOM_BIND = true; -- needed for some special options

				local ctx;
				if (wnd == nil) then
					ctx = gf["global_actions"]();
				else
					ctx = sf["target_actions"](wnd);
				end
				ctx.on_cancel = function()
					launch_menu_hook(nil);
					IN_CUSTOM_BIND = false;
					active_display():message(nil);
				end;
			end
		end, gconfig_get("bind_repeat")
	);

	local lbsz = 2 * active_display().scalef * gconfig_get("lbar_sz");
	suppl_widget_path(ctx, ctx.anchor, "special:custg", lbsz);
	ctx.on_cancel = function() IN_CUSTOM_BIND = false; end
end

sf["bind_custom"] = function(wnd)
	local m1, m2 = dispatch_meta();
	gf["bind_custom"](nil, "lbl", {}, wnd, m1, m2);
end

gf["unbind_combo"] = function()
	local bwt = gconfig_get("bind_waittime");
	tiler_bbar(active_display(),
		string.format(LBL_UNBIND_COMBINATION, SYSTEM_KEYS["cancel"]),
		"keyorcombo", bwt, nil, SYSTEM_KEYS["cancel"],
		function(sym, done, sym2)
			if (done) then
				dispatch_custom(sym, nil, true);
				SYMTABLE:add_translation(sym2 == nil and sym or sym2, "");
				dispatch_load();
			end
		end);
end

sf["unbind_custom"] = function()
	local bwt = gconfig_get("bind_waittime");
	tiler_bbar(active_display(),
		string.format(LBL_UNBIND_COMBINATION, SYSTEM_KEYS["cancel"]),
		"keyorcombo", bwt, nil, SYSTEM_KEYS["cancel"],
		function(sym, done, sym2)
			if (done) then
				dispatch_custom(sym, nil, true, active_display().selected);
			end
		end
	);
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

gf["rename_space"] = function()
	active_display():lbar(function(ctx, instr, done)
			if (done) then
				ctx.space:set_label(instr);
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
	audio_gain(BADID, val);
	for wnd in all_windows() do
		if (wnd.source_audio) then
			audio_gain(wnd.source_audio,
				val * (wnd.gain and wnd.gain or 1.0),
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

gf["global_gain"] = function(val)
	allgain(val);
	gconfig_set("global_gain", val);
end

-- separate toggle, we don't care about previously set gain value
sf["toggle_audio"] = function(wnd)
	if (not wnd or not wnd.source_audio) then
		return;
	end

	if (wnd.save_gain) then
		wnd.gain = wnd.save_gain;
		audio_gain(wnd.source_audio, gconfig_get("global_gain") * wnd.gain);
		wnd.save_gain = nil;
	else
		wnd.save_gain = wnd.gain;
		wnd.gain = 0.0;
		audio_gain(wnd.source_audio, 0.0);
	end
end

gf["toggle_audio"] = function()
	local new_state = not gconfig_get("global_mute");
	active_display():message("Global mute set to [" ..
		(new_state and LBL_YES or LBL_NO) .. "]");
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
		wspace.insert = "v";
		wspace.wm:tile_update();
	end
end
gf["mode_horizontal"] = function()
	local wspace = active_display().spaces[active_display().space_ind];
	if (wspace) then
		wspace.insert = "h";
		wspace.wm:tile_update();
	end
end
gf["tiletog"] = function()
	local wspace = active_display().spaces[active_display().space_ind];
	if (wspace) then
		if (wspace.mode ~= "tile") then
			wspace:tile();
		else
			wspace.insert = wspace.insert == "h" and "v" or "h";
		end
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

gf["tab"] = function()
	local wspace = active_display().spaces[active_display().space_ind];
	if (wspace) then
		wspace:tab();
	end
end

gf["vtab"] = function()
	local wspace = active_display().spaces[active_display().space_ind];
	if (wspace) then
		wspace:vtab();
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

-- reduced version of durden input that only uses dispatch_lookup to
-- figure out of we are running a symbol that maps to input_lock_* functions
local ign_input = function(iotbl)
	local ok, sym, outsym, lutval = dispatch_translate(iotbl, true);
	if (iotbl.kind == "status") then
		durden_iostatus_handler(iotbl);
		return;
	end

	if (iotbl.active and lutval) then
		lutval = lutval == "!input/input_toggle" and "input_lock_toggle" or lutval;
		if (lutval == "input_lock_toggle" or lutval == "input_lock_off" or
			lutval == "input_lock_on") then
			gf[lutval]();
		end
	end
end

gf["input_lock_toggle"] = function()
	if (durden_input == ign_input) then
		gf["input_lock_off"]();
	else
		gf["input_lock_on"]();
	end
end

gf["input_lock_on"] = function()
	durden_input = ign_input;
	dispatch_meta_reset();
	iostatem_save();
	iostatem_repeat(0, 0);
	active_display():message("Ignore input enabled");
end

gf["input_lock_off"] = function()
	durden_input = durden_normal_input;
	dispatch_meta_reset();
	iostatem_restore(iostate);
	dispatch_meta_reset();
	active_display():message("Ignore input disabled");
end

sf["fullscreen"] = function(wnd)
	if (not wnd) then
		print(debug.traceback());
	end

	if (wnd.fullscreen) then
		wnd.space[wnd.space.last_mode and wnd.space.last_mode or "tile"](wnd.space);
	else
		wnd.space.fullscreen(wnd.space);
	end
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
sf["move_nx"] = function(wnd)
	wnd:move(-1*(gconfig_get("float_tile_sz")[1]), 0, true);
end
sf["move_px"] = function(wnd)
	wnd:move(gconfig_get("float_tile_sz")[1], 0, true);
end
sf["move_ny"] = function(wnd)
	wnd:move(0, -1*(gconfig_get("float_tile_sz")[1]), true);
end
sf["move_py"] = function(wnd)
	wnd:move(0, gconfig_get("float_tile_sz")[1], true);
end
sf["step_right"] = function(wnd) wnd:next(); end
sf["destroy"] = function(wnd) wnd:destroy(); end

for i=1,10 do
	gf["switch_ws" .. tostring(i)] = function() active_display():switch_ws(i); end
	sf["assign_ws" .. tostring(i)] = function(wnd) wnd:assign_ws(i); end
	gf["swap_ws" .. tostring(i)] = function() active_display():swap_ws(i); end
end
