--
-- Mapping and configuration that is shared between all targets,
-- it can be superimposed / overridden with profile/target specific options.
--

local function shared_valid01_float(inv)
	local val = tonumber(inv);
	return val >= 0.0 and val <= 1.0;
end

local symmap = {
};

local shared_actions = {
	{
-- name is used to find this path in scripting or binding interfaces
		name = "reset",
-- label is default english, but can be overridden with a localization script
		label = "Reset",
-- kind : action, number, list
		kind = "action",
		handler = function(ctx)
			reset_target(ctx.source);
		end
	},
	{
		name = "pause",
		label = "Pause",
		kind = "action",
		handler = function(ctx)
			suspend_target(ctx.source);
		end
	},
	{
		name = "resume",
		label = "Resume",
		kind = "action",
		handler = function(ctx)
			resume_target(ctx.source);
		end
	},
};

local shared_settings = {
	{
		name = "set_gain",
		label = "Gain",
		kind = "number",
		validator = shared_valid01_float,
		handler = function(ctx, value)
			if (ctx.wnd.source_audio) then
				audio_gain(ctx.wnd.source_audio, value, gconfig_get("transition_time"));
			end
		end,
	},
	{
		name = "filtering",
		label = "Filtering",
		kind = "list",
		validator = {
			None = FILTER_NONE,
			Linear = FILTER_LINEAR,
			Bilinear = FILTER_BILINEAR,
			Trilinear = FILTER_TRILINEAR
		},
		handler = function(ctx, value)
			image_texfilter(ctx.source, value);
		end
	},
};

return {
	init = shared_init,
	bindings = symmap,
	actions = shared_actions,
	settings = shared_settings
};
