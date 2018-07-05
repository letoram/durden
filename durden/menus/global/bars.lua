return
{
	{
		name = "sb_top",
		label = "Pad Top",
		kind = "value",
		description = "Insert extra vertical spacing above the bar text",
		initial = function() return gconfig_get("sbar_tpad"); end,
		validator = function() return gen_valid_num(0, gconfig_get("sbar_sz")); end,
		handler = function(ctx, val)
			gconfig_set("sbar_tpad", tonumber(val));
			gconfig_set("tbar_tpad", tonumber(val));
			gconfig_set("lbar_tpad", tonumber(val));
		end
	},
	{
		name = "sb_bottom",
		label = "Pad Bottom",
		kind = "value",
		description = "Insert extra vertical spacing below the bar- text",
		initial = function() return gconfig_get("sbar_bpad"); end,
		validator = function() return gen_valid_num(0, gconfig_get("sbar_sz")); end,
		handler = function(ctx, val)
			gconfig_set("sbar_bpad", tonumber(val));
			gconfig_set("tbar_bpad", tonumber(val));
			gconfig_set("lbar_bpad", tonumber(val));
		end
	},
	{
		name = "tb_color",
		label = "Titlebar Color",
		kind = "value",
		hint = "(r g b)[0..255]",
		initial = function()
			local bc = gconfig_get("titlebar_color");
			return string.format("%.0f %.0f %.0f", bc[1], bc[2], bc[3]);
		end,
		validator = suppl_valid_typestr("fff", 0, 255, 0),
		description = "The color used as the active titlebar color state",
		handler = function(ctx, val)
			local tbl = suppl_unpack_typestr("fff", val, 0, 255);
			for wnd in all_windows(nil, true) do
				image_color(wnd.titlebar.anchor, tbl[1], tbl[2], tbl[3]);
			end
			gconfig_set("titlebar_color", tbl);
		end,
	},
	{
		name = "tb_pattern",
		label = "Titlebar(Pattern)",
		kind = "value",
		description = "Change the format string used to populate the titlebar text",
		initial = function() return gconfig_get("titlebar_ptn"); end,
		hint = "%p (tag) %t (title.) %i (ident.)",
		validator = function(str)
			return string.len(str) > 0 and not string.find(str, "%%", 1, true);
		end,
		handler = function(ctx, val)
			gconfig_set("titlebar_ptn", val);
			for tiler in all_tilers_iter() do
				for i, v in ipairs(tiler.windows) do
					v:set_title();
				end
			end
		end
	},
	{
		name = "tb_hide",
		label = "Hide Titlebar",
		kind = "value",
		description = "Change the default titlebar visibility settings",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function() return
			gconfig_get("hide_titlebar") and LBL_YES or LBL_NO end,
		handler = suppl_flip_handler("hide_titlebar")
	},
};
