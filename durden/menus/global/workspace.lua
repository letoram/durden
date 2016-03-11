local function switch_ws_menu()
	local spaces = {};
	for i=1,10 do
		spaces[i] = {
			name = "switch_ws" .. tostring(i),
			kind = "action",
			label = tostring(i),
			handler = grab_global_function("switch_ws" .. tostring(i)),
		};
	end

	return spaces;
end

local workspace_layout_menu = {
	{
		name = "layout_float",
		kind = "action",
		label = "Float",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:float() or nil;
		end
	},
	{
		name = "layout_tile_h",
		kind = "action",
		label = "Tile-Horiz",
		handler = function()
			local space  = active_display().spaces[active_display().space_ind];
			space.insert = "h";
			space:tile();
			space.wm:tile_update();
		end
	},
	{
		name = "layout_tile_v",
		kind = "action",
		label = "Tile-Vert",
		handler = function()
			local space  = active_display().spaces[active_display().space_ind];
			space.insert = "v";
			space:tile();
			space.wm:tile_update();
		end
	},
	{
		name = "layout_tab",
		kind = "action",
		label = "Tabbed",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:tab() or nil;
		end
	},
	{
		name = "layout_vtab",
		kind = "action",
		label = "Tabbed Vertical",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:vtab() or nil;
		end
	}
};

local function load_bg(fn)
	local space = active_display().spaces[active_display().space_ind];
	if (not space) then
		return;
	end
	local m1, m2 = dispatch_meta();
	space:set_background(fn, m1);
end

local save_ws = {
	{
		name = "workspace_save_shallow",
		label = "Shallow",
		kind = "action",
		handler = grab_global_function("save_space_shallow")
	},
--	{
--		name = "workspace_save_deep",
--		label = "Complete",
--		kind = "action",
--		handler = grab_global_function("save_space_deep")
--	},
--	{
--		name = "workspace_save_drop",
--		label = "Drop",
--		kind = "action",
--		eval = function()	return true; end,
--		handler = grab_global_function("save_space_drop")
--	}
};

local function set_ws_background()
	local imgfiles = {
	png = load_bg,
	jpg = load_bg,
	bmp = load_bg};
	browse_file({}, imgfiles, SHARED_RESOURCE, nil);
end

local function swap_ws_menu()
	local res = {};
	local wspace = active_display().spaces[active_display().space_ind];
	for i=1,10 do
		if (active_display().space_ind ~= i and active_display().spaces[i] ~= nil) then
			table.insert(res, {
				name = "workspace_swap",
				label = tostring(i),
				kind = "action",
				handler = function()
					grab_global_function("swap_ws" .. tostring(i))();
				end
			});
		end
	end
	return res;
end

return {
	{
		name = "workspace_background",
		label = "Background",
		kind = "action",
		handler = set_ws_background,
	},
	{
		name = "workspace_rename",
		label = "Rename",
		kind = "action",
		handler = grab_global_function("rename_space")
	},
	{
		name = "workspace_swap",
		label = "Swap",
		kind = "action",
		eval = function() return active_display():active_spaces() > 1; end,
		submenu = true,
		hint = "Swap:",
		handler = swap_ws_menu
	},
	{
		name = "workspace_migrate",
		label = "Migrate Display",
		kind = "action",
		handler = grab_global_function("migrate_ws_bydspname"),
		eval = function()
			return gconfig_get("display_simple") == false and #(displays_alive()) > 1;
		end
	},
	{
		name = "workspace_name",
		label = "Find Workspace",
		kind = "action",
		handler = function() grab_global_function("switch_ws_byname")(); end
	},
	{
		name = "workspace_switch",
		label = "Switch",
		kind = "action",
		submenu = true,
		hint = "Switch To:",
		handler = switch_ws_menu
	},
	{
		name = "workspace_layout",
		label = "Layout",
		kind = "action",
		submenu = true,
		hint = "Layout:",
		handler = workspace_layout_menu
	},
	{
		name = "workspace_save",
		label = "Save",
		kind = "action",
		submenu = true,
		hint = "Save Workspace:",
		handler = save_ws
	},
	{
		name = "workspace_wnd",
		label = "Tagged Window",
		kind = "action",
		handler = function() grab_global_function("switch_wnd_bytag")(); end
	},
};
