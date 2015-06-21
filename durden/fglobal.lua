--
-- Mostly boiler-plate mapping a string- based LUT to functions that
-- act on the currently active display and against keybindings.
--
local gf = {};
gf["spawn_terminal"] = spawn_terminal;
gf["exit"] = query_exit;
gf["launch_bar"] = query_launch;
gf["spawn_test_nobar"] = function() spawn_test(1); end
gf["spawn_test_bar"] = function() spawn_test(); end
gf["dump_state"] = function()
	system_snapshot("state.dump");
end
gf["random_alert"] = function()
	local ind = math.random(1, #displays.main.windows);
	displays.main.windows[ind]:alert();
end

gf["cycle_scalemode"] = function()
	local sel = displays.main.selected;
	local modes = displays.main.scalemodes;

	if (sel and modes) then
		local ind = 1;

		for i,v in ipairs(modes) do
			if (v == sel.scalemode) then
				ind = i;
				break;
			end
		end

-- recall that not all displays need to support the same scalemodes, this is
-- due to the cost/filtering capability of some special displays
		ind = (ind + 1 > #modes) and 1 or (ind + 1);
		sel.scalemode = modes[ind];
		sel:resize(sel.width, sel.height);
	end
end

gf["open_menu"] = function()
	query_open();
end

gf["global_menu"] = function()
	launch_menu(GLOBAL_ACTIONS);
end

gf["target_actions"] = function()
	local sel = displays.main.selected;
	if (sel) then
		launch_menu(
			merge_menu(TARGET_ACTIONS, sel.atype_actions)
		);
	end
end

gf["target_settings"] = function()
	if (sel) then
		launch_menu(
			merge_menu(TARGET_SETTINGS, sel.atype_settings)
		);
	end
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
gf["mergecollapse"] = function()
	if (displays.main.selected) then
		if (#displays.main.selected.children > 0) then
			displays.main.selected:collapse();
		else
			displays.main.selected:merge();
		end
	end
end
gf["grow_h"] = function()
	if (displays.main.selected) then
		displays.main.selected:grow(0.05, 0);
	end
end
gf["shrink_h"] = function()
	if (displays.main.selected) then
		displays.main.selected:grow(-0.05, 0);
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
gf["fullscreen"] = function()
	local sw = displays.main.selected;
	if (sw) then
		if (sw.fullscreen) then
			sw.space:tile();
		else
			sw.space:fullscreen();
		end
	end
end
gf["grow_v"] = function()
	if (displays.main.selected) then
		displays.main.selected:grow(0, 0.05);
	end
end
gf["shrink_v"] = function()
	if (displays.main.selected) then
		displays.main.selected:grow(0, -0.05);
	end
end
gf["step_up"] = function()
	if (displays.main.selected) then
		displays.main.selected:prev(1);
	end
end
gf["step_down"] = function()
	if (displays.main.selected) then
		displays.main.selected:next(1);
	end
end
gf["step_left"] = function()
	if (displays.main.selected) then
		displays.main.selected:prev();
	end
end
gf["step_right"] = function()
	if (displays.main.selected) then
		displays.main.selected:next();
	end
end
gf["destroy"] = function()
	if (displays.main.selected) then
		displays.main.selected:destroy();
	end
end

for i=1,10 do
	gf["switch_ws" .. tostring(i)] = function()
		displays.main:switch_ws(i);
	end

	gf["assign_ws" .. tostring(i)] = function()
		if (displays.main.selected) then
			displays.main.selected:assign_ws(i);
		end
	end
end

return gf;
