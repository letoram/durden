--
-- Terminal archetype, settings and menus specific for terminal-
-- frameserver session (e.g. keymapping, state control)
--

local res = {
	dispatch = {},
	actions = {},
	labels = {},
	atype = "terminal"
};

res.labels["LEFT"] = "LEFT";
res.labels["UP"] = "UP";
res.labels["DOWN"] = "DOWN";
res.labels["RIGHT"] = "RIGHT";
res.labels["ctrl_t"] = "SIGINFO";
res.labels["ctrl_m"] = "MUTE";

return res;
