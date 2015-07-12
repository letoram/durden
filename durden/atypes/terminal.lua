--
-- Terminal archetype, settings and menus specific for terminal-
-- frameserver session (e.g. keymapping, state control)
--
local symmap = {
	LEFT = "LEFT",
	RIGHT = "RIGHT",
	UP = "UP",
	DOWN = "DOWN",
	PAGEUP = "SCROLL_UP",
	PAGEDOWN = "SCROLL_DOWN"
};

return {
	actions = {},
	settings = {},
	labels = symmap,
	atype = "terminal"
};
