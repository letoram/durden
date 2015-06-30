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
	wnd.settings = merge_menu(sf, settings);
end

-- used by builtin/global to map some functions here to menus
function grab_global_function(funname)
	return gf[funname];
end

-- priority: wnd-specific -> shared -> global
function dispatch_symbol(sym)
	local ms = displays.main.selected;
	if (sf[sym]) then
		if (ms) then
			sf[sym](ms);
		end
	elseif (gf[sym]) then
		gf[sym]();
	else
		warning("keybinding issue, " .. sym .. " does not match any known function");
	end
end

if (DEBUGLEVEL > 0) then
	gf["spawn_test_nobar"] = function() spawn_test(1); end
	gf["spawn_test_bar"] = function() spawn_test(); end
	gf["dump_state"] = function()
		system_snapshot("state.dump");
	end
	gf["random_alert"] = function()
		local ind = math.random(1, #displays.main.windows);
		displays.main.windows[ind]:alert();
	end
end

-- a little messy, but covers binding single- keys for meta 1 and meta 2
gf["rebind_meta"] = function()
	tiler_bbar(displays.main,
			string.format("Press and hold (Meta 1), %s to Abort",
				gconfig_get("cancel_sym")), true, 80, nil, gconfig_get("cancel_sym"),
		function(sym, done)
			if (done) then
				tiler_bbar(displays.main,
					string.format("Press and hold (Meta 2), %s to Abort",
					gconfig_get("cancel_sym")), true, 80, nil, gconfig_get("cancel_sym"),
					function(sym2, done)
						if (done) then
							displays.main:message(
								string.format("Meta 1,2 set to %s, %s", sym, sym2));
							dispatch_meta(sym, sym2);
						end
				end);
			end
		end
	);
end

gf["rename_space"] = function()
	local ictx = displays.main:lbar(function(ctx, instr, done)
		if (done) then
			ctx.space:set_label(instr);
			ctx.space.wm:update_statusbar();
		end
		ctx.ulim = 16;
		return {label = "rename workspace", set = {}};
	end, {space = displays.main.spaces[displays.main.space_ind]});
	ictx:set_label("rename space:");
end

gf["mode_vertical"] = function()
	local wspace = displays.main.spaces[displays.main.space_ind];
	if (wspace) then
		wspace.insert = "vertical";
	end
end
gf["mode_horizontal"] = function()
	local wspace = displays.main.spaces[displays.main.space_ind];
	if (wspace) then
		wspace.insert = "horizontal";
	end
end
gf["tabtile"] = function()
	local wspace = displays.main.spaces[displays.main.space_ind];
	if (wspace) then
		if (wspace.mode == "tab" or wspace.mode == "fullscreen") then
			wspace:tile();
		else
			wspace:tab();
		end
	end
end
gf["vtabtile"] = function()
	local wspace = displays.main.spaces[displays.main.space_ind];
	if (wspace) then
		if (wspace.mode == "vtab" or wspace.mode == "fullscreen") then
			wspace:tile();
		else
			wspace:vtab();
		end
	end
end

-- functions that require a selected window
-- missing swap-right/swap-left, working floating, mouse actions

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
	gf["switch_ws" .. tostring(i)] = function() displays.main:switch_ws(i); end
	sf["assign_ws" .. tostring(i)] = function(wnd) wnd:assign_ws(i); end
end
