local function rebuild()
	for disp in all_tilers_iter() do
		disp:tile_update();
	end
end

local tab_menu = {
	{
		label = "Column Weight",
		description = "Percentage of screen width reserved for tab column",
		name = "htab_weight",
		kind = "value",
		initial = function(ctx) return tostring(gconfig_get("htab_barw")); end,
		validator = gen_valid_num(0.01, 0.5),
		handler = function(ctx, val)
			gconfig_set("htab_barw", tonumber(val));
			rebuild();
		end,
	},
	{
		name = "htab_pad",
		label = "Border Padding",
		description = "Insert titlebar column padding",
		kind = "value",
		initial = function()
			return string.format("%.2d %.2d %.2d", gconfig_get("htab_lpad"),
				gconfig_get("htab_lpad"), gconfig_get("htab_rpad"));
		end,
		hint = "(t l r) px",
		validator = suppl_valid_typestr("fff", 0.0, 100.0, 0.0),
		handler = function(ctx, val)
			local elem = string.split(val, " ");
			if (#elem ~= 3) then
				return;
			end
			gconfig_set("htab_tpad", math.floor(tonumber(elem[1])));
			gconfig_set("htab_lpad", math.floor(tonumber(elem[2])));
			gconfig_set("htab_rpad", math.floor(tonumber(elem[3])));
			rebuild();
		end
	},
};

local tile_menu = {
	{
		label = "Horizontal Gap",
		name = "horizontal_gap",
		kind = "value",
		description = "Change the relayouting gap width spacing",
		hint = "(px)",
		initial = function()
			return gconfig_get("tile_gap_w");
		end,
		validator = gen_valid_num(0, 100),
		handler = function(ctx, val)
			gconfig_set("tile_gap_w", tonumber(val));
-- for all tilers, force a resize
		end
	},
	{
		label = "Vertical Gap",
		name = "vertical_gap",
		kind = "value",
		description = "Change the relayouting gap width spacing",
		hint = "(px)",
		initial = function()
			return gconfig_get("tile_gap_h");
		end,
		validator = gen_valid_num(0, 100),
		handler = function(ctx, val)
			gconfig_set("tile_gap_h", tonumber(val));
		end
	},
	{
		label = "Subwindow Spawn",
		name = "subwindow",
		kind = "value",
		set = {"normal", "child"},
		description = "Control if child windows are inserted relative to their parent or follow normal spawn rules",
		handler	= function(ctx, val)
			gconfig_set("tile_insert_child", val);
		end
	}
};

local spawn_menu = {
	{
		name = "destination",
		label = "New",
		kind = "value",
		description = "Set spawn workspace for new, unassigned windows",
		set = {"current", "1", "2", "3", "4", "5", "6", "7", "8", "9"},
		handler = function(ctx, val)
			if (val == "current") then
				active_display().space_default_ind = nil;
			else
				active_display().space_default_ind = tonumber(val);
			end
		end,
	},
	{
		name = "child",
		label = "Child",
		kind = "value",
		description = "Control if child windows should derive from its parent or as a new window",
		initial = function()
			return gconfig_get("ws_child_default");
		end,
		set = {"default", "parent"},
		handler = function(ctx, val)
			gconfig_set("ws_child_default", val);
		end
	}
};

return {
	{
		name = "autodel",
		label = "Autodelete",
		kind = "value",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		description = "Automatically destroy workspaces that do not have any windows",
		initial = function() return
			gconfig_get("ws_autodestroy") and LBL_YES or LBL_NO end,
		handler = suppl_flip_handler("ws_autodestroy")
	},
	{
		name = "defmode",
		label = "Default Mode",
		kind = "value",
		set = {"tile", "tab", "vtab", "float"},
		initial = function() return tostring(gconfig_get("ws_default")); end,
		handler = function(ctx, val)
			gconfig_set("ws_default", val);
		end
	},
	{
		name = "adopt",
		label = "Autoadopt",
		kind = "value",
		description = "Let displays adopt orphaned workspaces automatically",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function()
			return gconfig_get("ws_autoadopt") and LBL_YES or LBL_NO;
		end,
		handler = suppl_flip_handler("ws_autoadopt")
	},
	{
		name = "tiled",
		label = "Tiled",
		description = "Configuration options for tiled workspace layouts",
		kind = "action",
		submenu = true,
		handler = tile_menu
	},
	{
		name = "tabbed",
		label = "Tabs",
		description = "Configuration options for tabbed workspace layouts",
		kind = "action",
		submenu = true,
		handler = tab_menu
	},
	{
		name = "spawn",
		label = "Spawn",
		kind = "action",
		submenu = true,
		description = "Window-workspace spawn controls",
		handler = spawn_menu
	},
};
