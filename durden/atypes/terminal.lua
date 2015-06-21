--
-- terminal- specific behavior and settings profile
--
local symmap = {
	"LEFT" = "LEFT",
	"RIGHT" = "RIGHT",
	"UP" = "UP",
	"DOWN" = "DOWN",
	"PAGEUP" = "SCROLL_UP",
	"PAGEDOWN" = "SCROLL_DOWN"
};

return {
	init = term_init,
	bindings = symmap,
	settings = term_menu,
	run = term_run
};
