--
-- Default Keybindings
--
-- keys match SYMTABLE style fields, with the prefix:
-- m1_ for meta1
-- m2_ for meta2
-- m1_m2_ for meta1+meta2
--
-- the output resolves to an entry in GLOBAL_FUNCTIONS or
-- in a custom per/target config
--
-- special function keys connected to UI components are set in gconf.
-- These are >static defaults< meaning that they can be overridden at runtime
-- and saved in the appl- specific database. If so, they take precedence.
--

local meta_1 = "MENU";
local meta_2 = "RSHIFT";

local tbl = {};
tbl["m1_RETURN"] = "spawn_terminal";
tbl["m1_m2_DELETE"] = "exit";

tbl["m1_F1"] = "debug_testwnd_bar";
tbl["m1_m2_F1"] = "debug_testwnd_nobar";

tbl["m1_g"] = "global_actions";
tbl["m1_m2_g"] = "workspace_actions";
tbl["m1_t"] = "target_actions";
tbl["m1_m2_t"] = "target_settings";
tbl["m1_RIGHT"] = "step_right";
tbl["m1_UP"] = "step_up";
tbl["m1_LEFT"] = "step_left";
tbl["m1_DOWN"] = "step_down";
tbl["m1_m2_d"] = "destroy";
tbl["m1_v"] = "mode_vertical";
tbl["m1_h"] = "mode_horizontal";
tbl["m1_m2_LEFT"] = "shrink_h";
tbl["m1_m2_RIGHT"] = "grow_h";
tbl["m1_m2_UP"] = "shrink_v";
tbl["m1_m2_DOWN"] = "grow_v";
tbl["m1_f"] = "fullscreen";
tbl["m1_e"] = "tabtile";
tbl["m1_r"] = "vtabtile";
tbl["m1_m2_f"] = "float";
tbl["m1_TAB"] = "context_popup";
tbl["m1_m"] = "mergecollapse";
tbl["m1_1"] = "switch_ws1";
tbl["m1_2"] = "switch_ws2";
tbl["m1_3"] = "switch_ws3";
tbl["m1_4"] = "switch_ws4";
tbl["m1_5"] = "switch_ws5";
tbl["m1_6"] = "switch_ws6";
tbl["m1_7"] = "switch_ws7";
tbl["m1_8"] = "switch_ws8";
tbl["m1_9"] = "switch_ws9";
tbl["m1_10"] = "switch_ws10";
tbl["m1_m2_r"] = "rename_space";
tbl["m1_m2_1"] = "assign_ws1";
tbl["m1_m2_2"] = "assign_ws2";
tbl["m1_m2_3"] = "assign_ws3";
tbl["m1_m2_4"] = "assign_ws4";
tbl["m1_m2_5"] = "assign_ws5";
tbl["m1_m2_6"] = "assign_ws6";
tbl["m1_m2_7"] = "assign_ws7";
tbl["m1_m2_8"] = "assign_ws8";
tbl["m1_m2_9"] = "assign_ws9";
tbl["m1_m2_10"] = "assign_ws10";
tbl["m1_l"] = "lock_input";
tbl["m1_d"] = "launch_bar";
tbl["m1_i"] = "cycle_scalemode";

if (DEBUGLEVEL > 0) then
tbl["m1_m2_p"] = "dump_state";
end

-- the following line can be removed if meta state protection is not needed
system_load("meta_guard.lua")();

--
-- We assume that all relevant input related functions go
-- through this one as it is used to map track meta_ key state.
--
local meta_1_state = false;
local meta_2_state = false;

function dispatch_meta(meta1, meta2)
	if (meta1) then
		meta_1 = meta1;
	end

	if (meta2) then
		meta_2 = meta2;
	end
end

function dispatch_lookup(iotbl, keysym, hook_handler)
	local metadrop = false;

	if (keysym == meta_1) then
		meta_1_state = iotbl.active;
		metadrop = true;

	elseif (keysym == meta_2) then
		meta_2_state = iotbl.active;
		metadrop = true;
	end

	local lutsym = "" .. (meta_1_state == true and "m1_" or "") ..
		(meta_2_state == true and "m2_" or "") .. keysym;

	if (hook_handler) then
		hook_handler(displays.main, keysym, iotbl, lutsym);
		return true;
	end

	if (metadrop) then
		return true;
	end

	if (not meta_guard(meta_1_state, meta_2_state)) then
		return true;
	end

	if (tbl[lutsym]) then
		if (iotbl.active) then
			dispatch_symbol(tbl[lutsym]);
		end
		return true;
	end

	return false;
end
