local swap_menu = {
	{
		name = "up",
		label = "Up",
		kind = "action",
		handler = grab_global_function("swap_up")
	},
	{
		name = "merge_collapse",
		label = "Merge/Collapse",
		kind = "action",
		handler = grab_shared_function("mergecollapse")
	},
	{
		name = "down",
		label = "Down",
		kind = "action",
		handler = grab_global_function("swap_down")
	},
	{
		name = "left",
		label = "Left",
		kind = "action",
		handler = grab_global_function("swap_left")
	},
	{
		name = "right",
		label = "Right",
		kind = "action",
		handler = grab_global_function("swap_right")
	},
};

local moverz_menu = {
{
	name = "grow_shrink_h",
	label = "Resize(H)",
	kind = "value",
	validator = gen_valid_num(-0.5, 0.5),
	hint = "(step: -0.5 .. 0.5)",
	handler = function(ctx, val)
		local num = tonumber(val);
		local wnd = active_display().selected;
		wnd:grow(val, 0);
	end
},
{
	name = "grow_shrink_v",
	label = "Resize(V)",
	kind = "value",
	validator = gen_valid_num(-0.5, 0.5),
	hint = "(-0.5 .. 0.5)",
	handler = function(ctx, val)
		local num = tonumber(val);
		local wnd = active_display().selected;
		wnd:grow(0, val);
	end
},
{
	name = "maxtog",
	label = "Toggle Maximize",
	kind = "action",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	handler = function()
		active_display().selected:toggle_maximize();
	end
},
{
	name = "move_h",
	label = "Move(H)",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	kind = "value",
	validator = function(val) return tonumber(val) ~= nil; end,
	handler = function(ctx, val)
		active_display().selected:move(tonumber(val), 0, true);
	end
},
{
	name = "move_v",
	label = "Move(V)",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	kind = "value",
	validator = function(val) return tonumber(val) ~= nil; end,
	handler = function(ctx, val)
		active_display().selected:move(0, tonumber(val), true);
	end
}
};

local function gen_wsmove(wnd)
	local res = {};
	local adsp = active_display().spaces;

	for i=1,10 do
		table.insert(res, {
			name = "move_space_" .. tostring(k),
			label = (adsp[i] and adsp[i].label) and adsp[i].label or tostring(i);
			kind = "action",
			handler = function()
				wnd:assign_ws(i);
			end
		});
	end
	return res;
end

return {
	{
		name = "tag",
		label = "Tag",
		kind = "value",
		validator = function() return true; end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (wnd) then
				wnd:set_prefix(string.gsub(val, "\\", "\\\\"));
			end
		end
	},
	{
		name = "swap",
		label = "Swap",
		kind = "action",
		submenu = true,
		handler = swap_menu
	},
	{
		name = "reassign_name",
		label = "Reassign",
		kind = "action",
		submenu = true,
		eval = function() return #gen_wsmove(active_display().selected) > 0; end,
		handler = function()
			return gen_wsmove(active_display().selected);
		end
	},
	{
		name = "canvas_to_bg",
		label = "Workspace-Background",
		kind = "action",
		handler = grab_shared_function("wnd_tobg");
	},
	{
		name = "titlebar_toggle",
		label = "Titlebar On/Off",
		kind = "action",
		handler = function()
			local wnd = active_display().selected;
			wnd.hide_titlebar = not wnd.hide_titlebar;
			wnd:set_title(wnd.title_text);
		end
	},
	{
		name = "target_opacity",
		label = "Opacity",
		kind = "value",
		hint = "(0..1)",
		validator = gen_valid_num(0, 1),
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (wnd) then
				local opa = tonumber(val);
				blend_image(wnd.border, opa);
				blend_image(wnd.canvas, opa);
			end
		end
	},
	{
		name = "delete_protect",
		label = "Delete Protect",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		initial = function() return active_display().selected.delete_protect and
			LBL_YES or LBL_NO; end,
		handler = function(ctx, val)
			active_display().selected.delete_protect = val == LBL_YES;
		end
	},
	{
		name = "migrate",
		label = "Migrate",
		kind = "action",
		submenu = true,
		handler = grab_shared_function("migrate_wnd_bydspname"),
		eval = function()
			return gconfig_get("display_simple") == false and #(displays_alive()) > 1;
		end
	},
	{
		name = "destroy",
		label = "Destroy",
		kind = "action",
		handler = function()
			grab_shared_function("destroy")();
		end
	},
	{
		name = "moverz",
		label = "Move/Resize",
		kind = "action",
		handler = moverz_menu,
		submenu = true
	}
};
