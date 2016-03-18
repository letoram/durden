local function set_scalef(mode)
	local wnd = active_display().selected;
	if (wnd) then
		wnd.scalemode = mode;
		wnd:resize(wnd.width, wnd.height);
	end
end

local function set_filterm(mode)
	local wnd = active_display().selected;
	if (mode and wnd) then
		wnd.filtermode = mode;
		image_texfilter(wnd.canvas, mode);
	end
end

local filtermodes = {
	{
		name = "target_filter_none",
		label = "None",
		kind = "action",
		handler = function() set_filterm(FILTER_NONE); end
	},
	{
		name = "target_filter_linear",
		label = "Linear",
		kind = "action",
		handler = function() set_filterm(FILTER_LINEAR); end
	},
	{
		name = "target_filter_bilinear",
		label = "Bilinear",
		kind = "action",
		handler = function() set_filterm(FILTER_BILINEAR); end
	}
};

local scalemodes = {
	{
		name = "target_scale_normal",
		label = "Normal",
		kind = "action",
		handler = function() set_scalef("normal"); end
	},
	{
		name = "target_scale_stretch",
		label = "Stretch",
		kind = "action",
		handler = function() set_scalef("stretch"); end
	},
	{
		name = "target_scale_aspect",
		label = "Aspect",
		kind = "action",
		handler = function() set_scalef("aspect"); end
	}
};

return {
	{
		name = "target_scaling",
		label = "Scaling",
		kind = "action",
		hint = "Scale Mode:",
		submenu = true,
		handler = scalemodes
	},
	{
		name = "target_filtering",
		label = "Filtering",
		kind = "action",
		hint = "Basic Filter:",
		submenu = true,
		handler = filtermodes
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
		name = "screenshot",
		label = "Screenshot",
		kind = "value",
		hint = "(full path)",
		validator = function(val)
			return string.len(val) > 0 and not resource(val);
		end,
		handler = function(ctx, val)
			save_screenshot(val, FORMAT_PNG, active_display().selected.canvas);
		end
	},
	{
		name = "target_shader",
		label = "Shader",
		kind = "value",
		set = function() return shader_list({"effect", "simple"}); end,
		handler = function(ctx, val)
			local key, dom = shader_getkey(val, {"effect", "simple"});
			if (key ~= nil) then
				shader_setup(active_display().selected.canvas, dom, key);
			end
		end
-- really cool preview here would be to have lbar run in tile helper mode,
-- and apply every shader to every tile as a preview
	}
};
