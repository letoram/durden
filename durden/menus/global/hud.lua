return {
	{
		name = "color",
		label = "Bar Color",
		kind = "value",
		hint = "(r g b)[0..255]",
		initial = function()
			local bc = gconfig_get("lbar_bg");
			return string.format("%.0f %.0f %.0f", bc[1], bc[2], bc[3]);
		end,
		validator = suppl_valid_typestr("fff", 0, 255, 0),
		description = "The color used for the HUD bar",
		handler = function(ctx, val)
			local tbl = suppl_unpack_typestr("fff", val, 0, 255);
			gconfig_set("lbar_bg", tbl);
		end,
	},
	{
		name = "selection_color",
		label = "Selection Color",
		kind = "value",
		hint = "(r g b)[0..255]",
		initial = function()
			local bc = gconfig_get("lbar_seltextbg");
			return string.format("%.0f %.0f %.0f", bc[1], bc[2], bc[3]);
		end,
		validator = suppl_valid_typestr("fff", 0, 255, 0),
		description = "The color used to mark the current selection",
		handler = function(ctx, val)
			local tbl = suppl_unpack_typestr("fff", val, 0, 255);
			gconfig_set("lbar_seltextbg", tbl);
		end,
	},
	{
		name = "opacity",
		label = "Background Opacity",
		kind = "value",
		hint = "(0..1)",
		initial = function() return tostring(gconfig_get("lbar_dim")); end,
		validator = gen_valid_num(0, 1),
		handler = function(ctx, val)
			gconfig_set("lbar_dim", tonumber(val));
		end
	},
	{
		name = "caret_color",
		label = "Caret Color",
		kind = "value",
		hint = "(r g b)[0..255]",
		initial = function()
			local bc = gconfig_get("lbar_caret_col");
			return string.format("%.0f %.0f %.0f", bc[1], bc[2], bc[3]);
		end,
		validator = suppl_valid_typestr("fff", 0, 255, 0),
		description = "The color used to mark the current selection",
		handler = function(ctx, val)
			local tbl = suppl_unpack_typestr("fff", val, 0, 255);
			gconfig_set("lbar_caret_col", tbl);
		end,
	},
	{
		name = "filter_function",
		label = "Filter Function",
		kind = "value",
		description = "Change the default candidate filtering function",
		set = {"prefix", "fuzzy"},
		initial = function() return gconfig_get("lbar_fltfun"); end,
		handler = function(ctx, val) gconfig_set("lbar_fltfun", val); end
	},
	{
		name = "menu_helper",
		label = "Menu Descriptions",
		description = "Set if this helper text should be shown or not",
		kind = "value",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function()
			return gconfig_get("menu_helper") and LBL_YES or LBL_NO;
		end,
		handler = suppl_flip_handler("menu_helper")
	},
	{
		name = "password_mask",
		label = "Mask Password",
		description = "Replace password entry inputs with asterisks ('*')",
		kind = "value",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function()
			return gconfig_get("passmask") and LBL_YES or LBL_NO;
		end,
		handler = suppl_flip_handler("passmask")
	}
};
