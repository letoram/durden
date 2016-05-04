local function switch_ws_menu()
	local spaces = {};
	for i=1,10 do
		spaces[i] = {
			name = "switch_" .. tostring(i),
			kind = "action",
			label = tostring(i),
			handler = grab_global_function("switch_ws" .. tostring(i)),
		};
	end

	return spaces;
end

local workspace_layout_menu = {
	{
		name = "float",
		kind = "action",
		label = "Float",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:float() or nil;
		end
	},
	{
		name = "tile_h",
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
		name = "tile_v",
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
		name = "tab",
		kind = "action",
		label = "Tabbed",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:tab() or nil;
		end
	},
	{
		name = "vtab",
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
	space:set_background(fn);
end

local save_ws = {
	{
		name = "shallow",
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
				name = "swap_" .. tostring(i),
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
		name = "bg",
		label = "Background",
		kind = "action",
		handler = set_ws_background,
	},
	{
		name = "rename",
		label = "Rename",
		kind = "action",
		handler = grab_global_function("rename_space")
	},
	{
		name = "swap",
		label = "Swap",
		kind = "action",
		eval = function() return active_display():active_spaces() > 1; end,
		submenu = true,
		handler = swap_ws_menu
	},
	{
		name = "migrate",
		label = "Migrate Display",
		kind = "action",
		submenu = true,
		handler = grab_global_function("migrate_ws_bydspname"),
		eval = function()
			return gconfig_get("display_simple") == false and #(displays_alive()) > 1;
		end
	},
	{
		name = "name",
		label = "Find Workspace",
		kind = "action",
		handler = function() grab_global_function("switch_ws_byname")(); end
	},
	{
		name = "switch",
		label = "Switch",
		kind = "action",
		submenu = true,
		handler = switch_ws_menu
	},
	{
		name = "layout",
		label = "Layout",
		kind = "action",
		submenu = true,
		handler = workspace_layout_menu
	},
	{
		name = "save",
		label = "Save",
		kind = "action",
		submenu = true,
		handler = save_ws
	},
	{
		name = "wnd",
		label = "Tagged Window",
		kind = "action",
		handler = function() grab_global_function("switch_wnd_bytag")(); end
	},
};
