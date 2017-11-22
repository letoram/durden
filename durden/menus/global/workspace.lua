local function switch_ws_menu()
	local spaces = {};
	for i=1,10 do
		spaces[i] = {
			name = "switch_" .. tostring(i),
			kind = "action",
			label = tostring(i),
			description = "Switch the active workspace to index " .. tostring(i),
			handler = grab_global_function("switch_ws" .. tostring(i)),
		};
	end

	table.insert(spaces,
	{
		name = "next",
		kind = "action",
		label = "Next",
		description = "Switch workspace to the next in line",
		handler = function()
			active_display():step_ws(1);
		end
	});

	table.insert(spaces,
	{
		name = "last",
		kind = "action",
		label = "Last Active",
		description = "Switch workspace to the previously active one",
		eval = function() return active_display().space_last_ind ~= nil; end,
		handler = function()
			active_display():switch_ws(active_display().space_last_ind);
		end
	});

	table.insert(spaces,
	{
		name = "prev",
		kind = "action",
		description = "Switch workspace to one with a lower index than the current",
		label = "Previous",
		handler = function()
			active_display():step_ws(-1);
		end
	});

	return spaces;
end

local workspace_layout_menu = {
	{
		name = "float",
		kind = "action",
		label = "Float",
		description = "Change workspace management mode to 'floating'",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:float() or nil;
		end
	},
	{
		name = "tile_h",
		kind = "action",
		label = "Tile-Horiz",
		description = "Switch to tiling mode, and set insertion slot to horizontal",
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
		description = "Switch to tiling mode, and set insertion slot to vertical",
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
		description = "Switch the workspace management to horizontal-tabbed mode",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:tab() or nil;
		end
	},
	{
		name = "vtab",
		kind = "action",
		description = "Switch the workspace management to vertically-tabbed mode",
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
		description = "Perform a shallow save of the workspace configuration",
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
				description = "Swap the current workspace with the one in slot " .. tostring(i),
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
		description = "Select a background image for the current workspace",
		handler = set_ws_background,
	},
	{
		name = "drop_bg",
		label = "Drop Background",
		kind = "action",
		description = "Remove the currently set background image",
		eval = function()
			return valid_vid(
				active_display().spaces[active_display().space_ind].background);
		end,
		handler = function()
			active_display().spaces[active_display().space_ind]:set_background();
		end
	},
	{
		name = "rename",
		label = "Rename",
		kind = "action",
		description = "Assign a custom text tag to the current workspace",
		handler = grab_global_function("rename_space")
	},
	{
		name = "swap",
		label = "Swap",
		kind = "action",
		description = "Swap workspace indices",
		eval = function() return active_display():active_spaces() > 1; end,
		submenu = true,
		handler = swap_ws_menu
	},
	{
		name = "migrate",
		label = "Migrate Display",
		kind = "action",
		description = "Move the workspace and all its windows to another display",
		submenu = true,
		handler = grab_global_function("migrate_ws_bydspname"),
		eval = function()
			return gconfig_get("display_simple") == false and #(displays_alive()) > 1;
		end
	},
	{
		name = "name",
		label = "Find Workspace",
		description = "Select a workspace based on a previously set custom tag",
		kind = "action",
		handler = function() grab_global_function("switch_ws_byname")(); end
	},
	{
		name = "switch",
		label = "Switch",
		kind = "action",
		submenu = true,
		description = "Change the currently active workspace index",
		handler = switch_ws_menu
	},
	{
		name = "layout",
		label = "Layout",
		kind = "action",
		submenu = true,
		description = "Change the winow management mode for the current workspace",
		handler = workspace_layout_menu
	},
	{
		name = "scheme",
		label = "Scheme",
		kind = "action",
		submenu = true,
		description = "Activate a UI / interaction scheme on this workspace",
		eval = function() return #(ui_scheme_menu("workspace",
			active_display().spaces[active_display().space_ind])) > 0; end,
		handler = function() return ui_scheme_menu("workspace",
			active_display().spaces[active_display().space_ind]); end
	},
	{
		name = "save",
		label = "Save",
		kind = "action",
		description = "Save the state of the current workspace",
		submenu = true,
		handler = save_ws
	},
	{
		name = "wnd",
		label = "Tagged Window",
		kind = "action",
		description = "Locate a window based on a custom set tag",
		handler = function() grab_global_function("switch_wnd_bytag")(); end
	},
};
