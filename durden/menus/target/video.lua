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
		name = "none",
		label = "None",
		kind = "action",
		handler = function() set_filterm(FILTER_NONE); end
	},
	{
		name = "linear",
		label = "Linear",
		kind = "action",
		handler = function() set_filterm(FILTER_LINEAR); end
	},
	{
		name = "bilinear",
		label = "Bilinear",
		kind = "action",
		handler = function() set_filterm(FILTER_BILINEAR); end
	}
};

local scalemodes = {
	{
		name = "normal",
		label = "Normal",
		kind = "action",
		handler = function() set_scalef("normal"); end
	},
	{
		name = "stretch",
		label = "Stretch",
		kind = "action",
		handler = function() set_scalef("stretch"); end
	},
	{
		name = "aspect",
		label = "Aspect",
		kind = "action",
		handler = function() set_scalef("aspect"); end
	}
};

return {
	{
		name = "scaling",
		label = "Scaling",
		kind = "action",
		submenu = true,
		handler = scalemodes
	},
	{
		name = "filtering",
		label = "Filtering",
		kind = "action",
		submenu = true,
		handler = filtermodes
	},
	{
		name = "screenshot",
		label = "Screenshot",
		kind = "value",
		hint = "(stored in output/)",
		validator = function(val)
			return string.len(val) > 0 and not resource("output/" .. val) and
				not string.match(val, "%.%.");
		end,
		handler = function(ctx, val)
			save_screenshot("output/" .. val, FORMAT_PNG,
				active_display().selected.canvas);
		end
	},
-- there are tons of controls that could possibly be added here,
-- the better solution is probably to allow a record-tool window with
-- all the knobs needed for mixing, adding / dropping sources etc.
	{
		name = "record",
		label = "Record",
		kind = "value",
		hint = suppl_recarg_hint,
		hintsel = suppl_recarg_eval,
		validator = suppl_recarg_valid,
		eval = function()
			return not active_display().selected.in_record and
				suppl_recarg_eval();
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			wnd.in_record = suppl_setup_rec(wnd, val);
		end
	},
	{
		name = "stop_record",
		label = "Stop Record",
		kind = "action",
		eval = function(val)
			return valid_vid(active_display().selected.in_record);
		end,
		handler = function()
			local wnd = active_display().selected;
			delete_image(wnd.in_record);
			wnd.in_record = nil;
		end
	},
	{
		name = "shader",
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
