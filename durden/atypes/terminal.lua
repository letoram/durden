--
-- terminal- specific behavior and settings profile
--
local symmap = {
	LEFT = "LEFT",
	RIGHT = "RIGHT",
	UP = "UP",
	DOWN = "DOWN",
	PAGEUP = "SCROLL_UP",
	PAGEDOWN = "SCROLL_DOWN"
};

local commands = {
};

local settings = {
};

return {
	init = term_init,
	bindings = symmap,
	settings = term_settings,
	run = term_commands,
	atype = "terminal"
};
