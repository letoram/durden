return {
	{
		name = "anim_speed",
		label = "Animation Speed",
		kind = "value",
		hint = "(1..100)",
		description = "Change the animation speed used for UI elements",
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("animation")); end,
		handler = function(ctx, val)
			gconfig_set("animation", tonumber(val));
		end
	},
	{
		name = "trans_speed",
		label = "Transition Speed",
		kind = "value",
		hint = "(1..100)",
		description = "Change the animation speed used in state transitions",
		validator = gen_valid_num(1, 100),
		initial = function() return tostring(gconfig_get("transition")); end,
		handler = function(ctx, val)
			gconfig_set("transition", tonumber(val));
		end
	},
	{
		name = "wnd_speed",
		label = "Window Animation Speed",
		kind = "value",
		hint = "(0..50)",
		description = "Change the animation speed used with window position/size",
		validator = gen_valid_num(0, 50),
		initial = function() return tostring(gconfig_get("wnd_animation")); end,
		handler = function(ctx, val)
			gconfig_set("wnd_animation", tonumber(val));
		end
	},
	{
		name = "anim_in",
		label = "Transition-In",
		kind = "value",
		description = "Change the effect used when moving a workspace on-screen",
		set = {"none", "fade", "move-h", "move-v"},
		initial = function() return tostring(gconfig_get("ws_transition_in")); end,
		handler = function(ctx, val)
			gconfig_set("ws_transition_in", val);
		end
	},
	{
		name = "anim_out",
		label = "Transition-Out",
		kind = "value",
		description = "Change the effect used when moving a workspace off-screen",
		set = {"none", "fade", "move-h", "move-v"},
		initial = function() return tostring(gconfig_get("ws_transition_out")); end,
		handler = function(ctx, val)
			gconfig_set("ws_transition_out", val);
		end
	},
};
