--
-- Default Keybindings
--
-- keys match SYMTABLE style fields, with the prefix:
-- m1_ for meta1
-- m2_ for meta2
-- m1_m2_ for meta1+meta2
--
-- the output resolves to an entry in GLOBAL_FUNCTIONS
--

local meta_1 = "MENU";
local meta_2 = "RSHIFT";

local tbl = {};
tbl["m1_RETURN"] = "spawn_terminal";
tbl["m1_ESCAPE"] = "exit";
tbl["m1_F1"] = "spawn_test";
tbl["m1_RIGHT"] = "step_right";
tbl["m1_UP"] = "step_up";
tbl["m1_LEFT"] = "step_left";
tbl["m1_DOWN"] = "step_down";
tbl["m1_d"] = "destroy";
tbl["m1_v"] = "vertical";
tbl["m1_h"] = "horizontal";
tbl["m1_m2_LEFT"] = "shrink_h";
tbl["m1_m2_RIGHT"] = "grow_h";
tbl["m1_m2_UP"] = "shrink_v";
tbl["m1_m2_DOWN"] = "grow_v";
tbl["m1_f"] = "fullscreen";
tbl["m1_t"] = "tab";

--
-- we assume that all relevant input related functions go
-- through this one as it is used to map track meta_ key state
--
local meta_1_state = false;
local meta_2_state = false;

function dispatch_lookup(iotbl, keysym)
	if (keysym == meta_1) then
		meta_1_state = iotbl.active;
		return true;
	elseif (keysym == meta_2) then
		meta_2_state = iotbl.active;
		return true;
	end

	local lutsym = "" .. (meta_1_state == true and "m1_" or "") ..
		(meta_2_state == true and "m2_" or "") .. keysym;

	if (tbl[lutsym] and GLOBAL_FUNCTIONS[tbl[lutsym]]) then
		if (iotbl.active) then
			GLOBAL_FUNCTIONS[tbl[lutsym]]();
		end
		return true;
	end
	return false;
end
