--
-- Terminal archetype, settings and menus specific for terminal-
-- frameserver session (e.g. keymapping, state control)
--

local res = {
	dispatch = {},
-- actions are exposed as target- menu
	actions = {},
-- labels is mapping between known symbol and string to forward
	labels = {},
	default_shader = "nostretch",
	atype = "terminal",
	props = {
		scalemode = "stretch",
		autocrop = true,
		filtermode = FILTER_NONE
	}
};

-- should set a custom "nocrop" shader here that uses cropping mode for
-- shrink operations and pad-with-background-color for grow when visible
-- size deviates from storage size.
res.labels["LEFT"] = "LEFT";
res.labels["UP"] = "UP";
res.labels["DOWN"] = "DOWN";
res.labels["RIGHT"] = "RIGHT";
res.labels["ctrl_t"] = "SIGINFO";
res.labels["ctrl_m"] = "MUTE";

return res;
