local function switch_ws_menu()
	local spaces = {};
	for i=1,10 do
		spaces[i] = {
			name = "switch_" .. tostring(i),
			kind = "action",
			label = tostring(i),
			description = "Switch the active workspace to index " .. tostring(i),
			handler = function()
				active_display():switch_ws(i);
			end
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
		name = "new",
		kind = "action",
		label = "Free",
		eval = function()
			for i=1,10 do
				if not active_display().spaces[i] then
					return true;
				end
			end
		end,
		description = "Switch to the first free workspace index",
		handler = function()
			for i=1,10 do
				if not active_display().spaces[i] then
					active_display():switch_ws(i);
					return;
				end
			end
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

local function select_menu()
	local res = {};

-- locate selected window (or revert to first), apply delta and wrap to range
	local find_select = function(i)
		local list = active_display():active_space():linearize();
		local wnd = active_display().selected;
		local item = list[1];
		if wnd then
			local ind = table.find_i(list, wnd);
			if ind then
				ind = ind + i;
				ind = ind > #list and 1 or ind;
				ind = ind < 1 and #list or ind;
				item = list[ind];
			end
		end

		if item and item.select then
			item:select();
		end
	end

	table.insert(res, {
		name = "next",
		kind = "action",
		label = "Next",
		description = "Cycle to the next window in order within the current workspace",
		handler = function()
			find_select(1);
		end
	});
	table.insert(res, {
		name = "prev",
		kind = "action",
		label = "Previous",
		description = "Cycle to the previous window in order within the current workspace",
		handler = function()
			find_select(-1);
		end
	});

-- likely doesn't make much sense exposing the specific windows etc. here
-- too mutable to be bound, the main use here is float where the direction
-- based approach isn't for everyone
	return res;
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
		name = "tile_bsp",
		kind = "action",
		description = "Switch to tiling mode, and set insertion slot to auto-binary space",
		label = "Tile-BSP",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space.insert = "bsp";
			space:tile();
			space.wm:tile_update();
		end
	},
	{
		name = "tile_toggle",
		kind = "action",
		description =
			"Set tile mode or (in tile mode) swap horizontal/vertical insertion",
		label = "Tile-Toggle",
		handler = function()
			local ws = active_display().spaces[active_display().space_ind];
			if (ws.mode ~= "tile") then
				ws:tile();
			else
				ws.insert = ws.insert == "h" and "v" or "h";
			end
			ws.wm:tile_update();
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
	},
	{
		name = "htab",
		kind = "action",
		description = "Switch the workspace management to horiztonal-column tabbed mode",
		label = "Tabbed Column",
		handler = function()
			local space = active_display().spaces[active_display().space_ind];
			space = space and space:htab() or nil;
		end
	}
};

local function load_bg(fn)
	local space = active_display():active_space();
	local kind = suppl_ext_type(fn);

	if (kind == "video") then
-- normal dumb decode
		local decvid = launch_decode(fn, "loop:noaudio",
		function(source, status)
			if status.kind == "terminated" then
				delete_image(source);
			end
		end);

-- forward to tiler workspace handler
		if (valid_vid(decvid)) then
			target_flags(decvid, TARGET_BLOCKADOPT);
			space:set_background(decvid);

-- undecided, but should possibly also suspend/resume playback on workspace
-- visibility, if so, add a hook on the workspace and suspend/resume target
			if (valid_vid(space.background)) then
				link_image(decvid, space.background);
			else
				delete_image(decvid);
			end
		end
	else
		space:set_background(fn);
	end
end

local function query_bg_media()
	dispatch_user_message("Workspace-Background");
	dispatch_symbol_bind(
	function(path)
		dispatch_user_message("");
		if not path then
			return;
		end
		load_bg(path);
	end, "/browse/shared");
end

local function set_ws_background()
	local res = {
		{
			name = "browse",
			label = "Browse",
			kind = "action",
			handler = query_bg_media,
			description = "Browse for an image or video to set as the workspace background",
		},
		{
			name = "external",
			label = "External",
			kind = "value",
			validator = suppl_valid_name,
			eval = function()
				return false;
			end,
			description = "Open an external connection point to serve as background",
			handler = function(ctx, val)
			end
		},
		{
			name = "color",
			label = "Color",
			kind = "value",
			description = "Pick a color to set as the background"
		}
	};

	suppl_append_color_menu({0, 0, 0}, res[#res],
	function(str, r, g, b)
		local col = fill_surface(4, 4, r, g, b);
		active_display():active_space():set_background(col);
		delete_image(col);
	end);

	return res;
end

local function swap_ws_menu()
	local res = {};
	local wspace = active_display().spaces[active_display().space_ind];
	for i=1,10 do
		if (active_display().space_ind ~= i and active_display().spaces[i] ~= nil) then
			table.insert(res, {
				name = "swap_" .. tostring(i),
				label = tostring(i),
				description =
					"Swap the current workspace with the one in slot " .. tostring(i),
				kind = "action",
				handler = function()
					active_display():swap_ws(i);
				end
			});
		end
	end
	return res;
end

local function gen_ws_menu(dsp)
	local spaces = {};
	for i=1,10 do
		if dsp.tiler.spaces[i] then
			table.insert(spaces,
			{
				name = "ws_" .. tostring(i),
				label = tostring(i),
				kind = "action",
				handler =
				function()
					local dsp2 = active_display(false, true)
					dsp.tiler.spaces[i]:migrate(
						dsp2.tiler,
						{
							ppcm = dsp2.ppcm,
							width = dsp2.tiler.width,
							height = dsp2.tiler.height
						});
					dsp.tiler:tile_update();
					dsp2.tiler:tile_update();
				end
			})
		end
	end
	return spaces;
end

local function import_ws_bydsp()
	local dsp = displays_alive(true, true);
	local res = {};
	for i,v in ipairs(dsp) do
		table.insert(res, {
			name = "import_disp_" .. tostring(i),
			label = v.name,
			kind = "action",
			submenu = true,
			eval = function()
				return #gen_ws_menu(v) > 0;
			end,
			handler = function()
				return gen_ws_menu(v);
			end,
		});
	end
	return res;
end

local function migrate_ws_bydsp()
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

local function gen_wnd_menu(space, key)
	local lst = space:linearize();
	local res = {};
	for i,v in ipairs(lst) do
		if not key or v[key] then
			table.insert(res, {
				name = v.name,
				label = v.name,
				description = v.title,
				kind = "action",
				submenu = true,
				handler = function()
					return menu_path_for_set({v}, "/target");
				end
			});
		end
	end
	return res;
end

local function ws_wnd_menu(space)
	return {
		{
			name = "all",
			label = "All",
			kind = "action",
			submenu = true,
			handler = function()
				return gen_wnd_menu(space);
			end
		},
		{
			name = "hidden",
			label = "Hidden",
			kind = "action",
			submenu = true,
			handler = function()
				return gen_wnd_menu(space, "hidden");
			end
		}
	};
end

return {
	{
		name = "bg",
		label = "Background",
		kind = "action",
		submenu = true,
		description = "Workspace background image controls",
		handler = set_ws_background,
	},
	{
		name = "rename",
		label = "Rename",
		kind = "value",
		eval = function()
			return active_display().spaces[active_display().space_ind] ~= nil;
		end,
		description = "Assign a custom text tag to the current workspace",
		handler = function(ctx, val)
			active_display().spaces[active_display().space_ind]:set_label(val);
		end
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
		description = "Move the current workspace and all its windows to another display",
		submenu = true,
		handler = migrate_ws_bydsp,
		eval = function()
			return #(displays_alive()) > 1;
		end
	},
	{
		name = "import",
		label = "Import Display",
		kind = "action",
		description = "Import a workspace and all its windows from another display",
		submenu = true,
		handler = import_ws_bydsp,
		eval = function()
			return #(displays_alive()) > 1;
		end
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
		eval = function()
			return #(ui_scheme_menu("workspace",
				active_display().spaces[active_display().space_ind])) > 0;
		end,
		handler = function()
			return ui_scheme_menu("workspace",
				active_display().spaces[active_display().space_ind]);
		end
	},
	{
		name = "windows",
		label = "Windows",
		kind = "action",
		submenu = true,
		description = "Control the windows currently attached to the active workspace",
		eval = function()
			return #active_display():active_space():linearize() > 0;
		end,
		handler = function()
			return ws_wnd_menu(active_display():active_space());
		end
	},
	{
		name = "select",
		label = "Select",
		kind = "action",
		submenu = true,
		description = "Change selected window within this workspace",
		eval = function()
			return #(active_display():active_space():linearize()) > 0;
		end,
		handler = select_menu
	}
};
