local function button_query_path(vsym, dir, group)
	dispatch_user_message("Pick Button Action");
	dispatch_symbol_bind(
		function(path)
			dispatch_user_message("");
			if not path then
				return
			end
			table.insert(gconfig_statusbar_buttons, {
				label = vsym,
				direction = dir,
				command = path
			});
			gconfig_statusbar_rebuild();
			for disp in all_tilers_iter() do
				disp:tile_update();
			end
		end
	);
end

local function remove_button(dir)
	local res = {};
		for i,v in ipairs(gconfig_statusbar_buttons) do
			if (not dir or v.direction == string.lower(dir)) then
				table.insert(res, {
					name = tostring(i),
					label = dir .. "_" .. tostring(i),
					description = "Button Label: " .. v.label,
					kind = "action",
					handler = function()
						table.remove(gconfig_statusbar_buttons, i);
						gconfig_statusbar_rebuild();
						for disp in all_tilers_iter() do
							disp:tile_update();
						end
					end
				});
			end
	end

	return res;
end

local function alt_button(dir, group)
	local res = {};
	for i,v in ipairs(gconfig_statusbar_buttons) do
		if (not dir or v.direction == string.lower(dir)) then
			table.insert(res, {
				name = tostring(i),
				label = dir .. "_" .. tostring(i),
				description = "Button Label: " .. v.label,
				kind = "action",
				handler = function()
					dispatch_user_message("Pick Button Alt-action");
					dispatch_symbol_bind(
						function(path)
							dispatch_user_message("");
							v.alt_command = path;
							gconfig_statusbar_rebuild();
							for disp in all_tilers_iter() do
								disp:tile_update();
							end
						end
					);
			end});
		end
	end
	return res;
end

local function extend_button(dir)
	return {
		{
			name = "alternate_click",
			label = "Alternate Click",
			description = "Path activated when an alternate (right) mouse button is used",
			submenu = true,
			kind = "action",
			handler = function()
				return alt_button(dir, "alt_command");
			end,
		},
		{
			name = "drop",
			label = "Drop",
			description = "Path activated when a window is dragged/dropped on the button",
			submenu = true,
			kind = "action",
			handler = function()
				return alt_button(dir, "drag_command");
			end
		}
	};
end

local function statusbar_buttons(dir, lbl)
	local hintstr = "(0x_byte seq | icon_name | string)";
	return
{
	{
		label = "Remove",
		name = "remove",
		kind = "action",
		submenu = true,
		description = "Remove a button",
		eval = function() return #remove_button(dir) > 0; end,
		handler = function()
			return remove_button(dir);
		end
	},
	{
		label = "Extend",
		name = "extend",
		kind = "action",
		submenu = true,
		description = "Add alternate button activation (drag, rclick)",
		eval = function() return #remove_button(dir) > 0; end,
		handler = function()
			return extend_button(dir);
		end
	},
	{
		name = "add",
		label = "Add",
		kind = "value",
		hint = hintstr,
		validator = function(val)
			return suppl_valid_vsymbol(val);
		end,
		widget = "special:icon",
		description = "Add a new button used in all layout modes",
		handler = function(ctx, val)
			button_query_path(val, dir, "all");
		end
	}
};
end

local border_menu = {
	{
		name = "padding",
		label = "Padding",
		description = "Insert padding space between bar and edge",
		kind = "value",
		initial = function()
			return string.format("%.2d %.2d %.2d %.2d",
				gconfig_get("sbar_tspace"), gconfig_get("sbar_lspace"),
				gconfig_get("sbar_dspace"), gconfig_get("sbar_rspace"));
		end,
		hint = "(t l d r) px",
		validator = suppl_valid_typestr("ffff", 0.0, 100.0, 0.0),
		handler = function(ctx, val)
			local elem = string.split(val, " ");
			if (#elem ~= 4) then
				return;
			end
			gconfig_set("sbar_tspace", math.floor(tonumber(elem[1])));
			gconfig_set("sbar_lspace", math.floor(tonumber(elem[2])));
			gconfig_set("sbar_dspace", math.floor(tonumber(elem[3])));
			gconfig_set("sbar_rspace", math.floor(tonumber(elem[4])));
			for disp in all_tilers_iter() do
				disp:tile_update();
				disp:resize();
			end
		end
	},
	{
		name = "border",
		label = "Border",
		description = "Draw a border around the statusbar",
		kind = "value",
		initial = function()
			return string.format("%.2d %.2d %.2d %.2d",
				gconfig_get("sbar_tshadow"), gconfig_get("sbar_lshadow"),
				gconfig_get("sbar_dshadow"), gconfig_get("sbar_rshadow"));
		end,
		hint = "(t l d r) px",
		validator = suppl_valid_typestr("ffff", 0.0, 100.0, 0.0),
		handler = function(ctx, val)
			local elem = string.split(val, " ");
			if (#elem ~= 4) then
				return;
			end
			gconfig_set("sbar_tshadow", math.floor(tonumber(elem[1])));
			gconfig_set("sbar_lshadow", math.floor(tonumber(elem[2])));
			gconfig_set("sbar_dshadow", math.floor(tonumber(elem[3])));
			gconfig_set("sbar_rshadow", math.floor(tonumber(elem[4])));
			for disp in all_tilers_iter() do
				disp:tile_update();
				disp:resize();
			end
		end
	},
	{
		name = "style",
		label = "Style",
		description = "Set the drawing method for the border area (if defined)",
		set = {"none", "soft"},
		kind = "value",
		initial = function()
			return gconfig_get("sbar_shadow");
		end,
		handler = function(ctx, val)
			gconfig_set("sbar_shadow", val);
			for disp in all_tilers_iter() do
				disp:tile_update();
			end
		end
	}
};

local statusbar_buttons_dir = {
	{
		name = "left",
		kind = "action",
		label = "Left",
		description = "Modify buttons in the left group",
		submenu = true,
		handler = statusbar_buttons("left", "Left")
	},
	{
		name = "right",
		kind = "action",
		label = "Right",
		description = "Modify buttons in the right group",
		submenu = true,
		handler = statusbar_buttons("right", "Right");
	},
	{
		name = "force_prefix",
		label = "Number Prefix Buttons",
		kind = "value",
		description = "Force number prefix on tagged workspaces",
		initial = function()
			return gconfig_get("sbar_numberprefix") and LBL_YES or LBL_NO; end,
		set = {LBL_YES, LBL_NO},
		handler = function(ctx, val)
			gconfig_set("sbar_numberprefix", val == LBL_YES);
			for tiler in all_tilers_iter() do
				tiler:tile_update();
			end
		end
	},
	{
		name = "new_ws",
		label = "New Workspace",
		description = "Control the visibility of the dynamic 'new workspace' button",
		kind = "value",
		set = {LBL_YES, LBL_NO},
		handler = function(ctx, val)
			gconfig_set("sbar_wsmeta", val == LBL_YES);
			for tiler in all_tilers_iter() do
				tiler:tile_update();
			end
		end
	},
	{
		name = "ws_buttons",
		label = "Workspace Buttons",
		kind = "value",
		description = "Control the presence of workspace indicator buttons",
		initial = function()
			return gconfig_get("sbar_wsbuttons") and LBL_YES or LBL_NO; end,
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		handler = function(ctx, val)
			suppl_flip_handler("sbar_wsbuttons")(ctx, val);
			for tiler in all_tilers_iter() do
				tiler:tile_update();
			end
		end
	},
	{
		name = "display_buttons",
		label = "Display Buttons",
		description = "Control the presence of dynamic display control buttons",
		initial = function()
			return gconfig_get("sbar_dispbuttons") and LBL_YES or LBL_NO;
		end,
		kind = "value",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		handler = function(ctx, val)
			suppl_flip_handler("sbar_dispbuttons")(ctx, val);
			for tiler in all_tilers_iter() do
				tiler:tile_update();
			end
		end
	}
-- like the normal suppl_append_color_menu but special handling for
-- the possible "dynamic" option where we pick the color from a palette
};

local function add_hex_dynamic(tbl, name, label, descr, key)
	table.insert(tbl, {
		name = name,
		label = label,
		description = descr,
		widget = "special:colorpick_r8g8b8",
		kind = "value",
		hint = "dynamic | hex: r g b",
		initial = function()
			local lbl = gconfig_get(key);
			if (lbl == "dynamic") then
				return lbl;
			else
				local r, g, b = suppl_hexstr_to_rgb(lbl);
				return string.format("%.0f %.0f %.0f", r, g, b);
			end
		end,
		validator = function(val)
			if (val == "dynamic") then
				return true;
			else
				return suppl_valid_typestr("fff", 0, 255, 0)(val);
			end
		end,
		handler = function(ctx, val)
			if (val == "dynamic") then
				gconfig_set(key, val);
			else
				local tbl = suppl_unpack_typestr("fff", val, 0, 255);
				if (not tbl) then
					return;
				end
				gconfig_set(key,
					string.format("\\#%02x%02x%02x", tbl[1], tbl[2], tbl[3])
				);
			end
			for tiler in all_tilers_iter() do
				tiler:tile_update();
			end
		end,
	});
end

add_hex_dynamic(statusbar_buttons_dir, "label", "Label", "Coloring options for the label", "sbar_lblcolor");
add_hex_dynamic(statusbar_buttons_dir, "prefix", "Prefix", "Coloring option for the number prefix", "sbar_prefixcolor");

return {
	{
		name = "border",
		label = "Border",
		kind = "action",
		submenu = true,
		description = "Configure statusbar border attributes (padding, shadow, ...)",
		handler = border_menu
	},
	{
		name = "buttons",
		label = "Buttons",
		kind = "action",
		submenu = true,
		description = "Add/Remove custom buttons",
		handler = statusbar_buttons_dir
	},
	{
		name = "position",
		label = "Position",
		kind = "value",
		description = "Change the statusbar vertical position",
		set = {"top", "bottom", "left", "right"},
		initial = function()
			return gconfig_get("sbar_position");
		end,
		handler = function(ctx, val)
			gconfig_set("sbar_position", val);
			active_display():tile_update();
			active_display():resize();
		end
	},
	{
		name = "centered",
		label = "Centered",
		kind = "value",
		description = "Center the statusbar (with compact or reduced width)",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function()
			return gconfig_get("sbar_centered") and LBL_YES or LBL_NO;
		end,
		handler = suppl_flip_handler("sbar_centered", function()
			gconfig_statusbar_rebuild();
		end)
	},
	{
		name = "color",
		label = "Color",
		kind = "value",
		description = "Change the statusbar background color",
		hint = "(r g b)[0..1]",
		widget = "special:colorpick_r8g8b8",
		initial = function()
			local bc = gconfig_get("sbar_color");
			return string.format("%.0f %.0f %.0f", bc[1], bc[2], bc[3]);
		end,
		handler = function(ctx, val)
			local tbl = suppl_unpack_typestr("fff", val, 0, 255);
			gconfig_set("sbar_color", tbl);
			active_display():tile_update();
		end
	},
	{
		name = "transparency",
		label = "Transparency",
		kind = "value",
		description = "Change the statusbar alpha value",
		initial = function()
			return gconfig_get("sbar_alpha");
		end,
		handler = function(ctx, val)
			gconfig_set("sbar_alpha", tonumber(val));
			for d in all_tilers_iter() do
				d:tile_update();
			end
		end
	},
	{
		name = "min_sz",
		label = "Minimum Size",
		kind = "value",
		initial = function()
			return gconfig_get("sbar_min_sz");
		end,
		validator = gen_valid_num(0, 200),
		hint = "(0=font defined..n_px)",
		description = "Minimum scaled pixel size for statusbar buttons",
		handler = function(ctx, val)
			gconfig_set("sbar_min_sz", tonumber(val));
			for d in all_tilers_iter() do
				d:tile_update();
				d:resize();
			end
		end,
	},
	{
		name = "visibility",
		label = "Visibility",
		kind = "value",
		description = "Control where/if the statusbar should be visible",
		set = {"desktop", "hud", "hidden"},
		initial = function() return gconfig_get("sbar_visible"); end,
		handler = function(ctx, val)
			gconfig_set("sbar_visible", val);

-- special case this as the layouting consequences for left/right are high
			if val == "hud" then
				gconfig_set("sbar_pos", "top")
			end

			for tiler in all_tilers_iter() do
				tiler:tile_update();
				tiler:resize();
			end
		end
	},
	{
		name = "autohide",
		label = "Autohide",
		kind = "value",
		description = "Number of 25Hz ticks before the statusbar hides",
		hint = "(0: disable, 1..25)",
		validator = gen_valid_num(0, 100),
		handler = function(ctx, val)
			gconfig_set("sbar_autohide", tonumber(val))
			for disp in all_tilers_iter() do
				disp:tile_update()
			end
		end
	},
	{
		name = "size",
		label = "Size",
		kind = "value",
		description = "% of width (horizontal) or height (vertical)",
		initial = function()
			return gconfig_get("sbar_sizepct");
		end,
		validator = gen_valid_num(20, 100),
		handler = function(ctx, val)
			gconfig_set("sbar_sizepct", tonumber(val));
			gconfig_statusbar_rebuild();
			for disp in all_tilers_iter() do
				disp:tile_update();
			end
		end
	},
	{
		name = "compact",
		label = "Compact",
		kind = "value",
		description = "Resize the bar to fit only its buttons and sidepad",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function()
			return gconfig_get("sbar_compact") and LBL_YES or LBL_NO;
		end,
		handler = suppl_flip_handler("sbar_compact", function()
			gconfig_statusbar_rebuild();
		end)
	}
};
