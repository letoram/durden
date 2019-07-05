return
{
	{
		name = "pad_top",
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
		name = "pad_bottom",
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
	}
};
