--
-- Mostly boiler-plate mapping a string- based LUT to functions that
-- act on the currently active display and against keybindings. Later on,
-- this could be exposed via a scripting layer as well.
--
GLOBAL_FUNCTIONS = {};
GLOBAL_FUNCTIONS["spawn_terminal"] = spawn_terminal;
GLOBAL_FUNCTIONS["exit"] = query_exit;
GLOBAL_FUNCTIONS["spawn_test_nobar"] = function() spawn_test(1); end
GLOBAL_FUNCTIONS["spawn_test_bar"] = function() spawn_test(); end

GLOBAL_FUNCTIONS["mode_vertical"] = function()
	local wspace = displays.main.spaces[displays.main.space_ind];
	if (wspace) then
		wspace.insert = "vertical";
	end
end
GLOBAL_FUNCTIONS["mode_horizontal"] = function()
	local wspace = displays.main.spaces[displays.main.space_ind];
	if (wspace) then
		wspace.insert = "horizontal";
	end
end
GLOBAL_FUNCTIONS["merge"] = function()
	if (displays.main.selected) then
		displays.main.selected:merge();
	end
end
GLOBAL_FUNCTIONS["collapse"] = function()
	if (displays.main.selected) then
		displays.main.selected:collapse();
	end
end
GLOBAL_FUNCTIONS["grow_h"] = function()
	if (displays.main.selected) then
		displays.main.selected:grow(0.05, 0);
	end
end
GLOBAL_FUNCTIONS["shrink_h"] = function()
	if (displays.main.selected) then
		displays.main.selected:grow(-0.05, 0);
	end
end
GLOBAL_FUNCTIONS["mode_tab_tile"] = function()
	local wspace = displays.main.spaces[displays.main.space_ind];
	if (wspace) then
		wspace.mode = wspace.mode == "tile" and "tab" or "tile";
	end
end
GLOBAL_FUNCTIONS["grow_v"] = function()
	if (displays.main.selected) then
		displays.main.selected:grow(0, 0.05);
	end
end
GLOBAL_FUNCTIONS["shrink_v"] = function()
	if (displays.main.selected) then
		displays.main.selected:grow(0, -0.05);
	end
end
GLOBAL_FUNCTIONS["step_up"] = function()
	if (displays.main.selected) then
		displays.main.selected:prev(1);
	end
end
GLOBAL_FUNCTIONS["step_down"] = function()
	if (displays.main.selected) then
		displays.main.selected:next(1);
	end
end
GLOBAL_FUNCTIONS["step_left"] = function()
	if (displays.main.selected) then
		displays.main.selected:prev();
	end
end
GLOBAL_FUNCTIONS["step_right"] = function()
	if (displays.main.selected) then
		displays.main.selected:next();
	end
end
GLOBAL_FUNCTIONS["destroy"] = function()
	if (displays.main.selected) then
		displays.main.selected:destroy();
	end
end

for i=1,10 do
	GLOBAL_FUNCTIONS["switch_ws" .. tostring(i)] = function()
		displays.main:switch_ws(i);
	end

	GLOBAL_FUNCTIONS["assign_ws" .. tostring(i)] = function()
		if (displays.main.selected) then
			displays.main.selected:assign_ws(i);
		end
	end
end
