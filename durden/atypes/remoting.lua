--
-- Remoting archetype, settings and menus specific for remoting- frameserver
-- sessions, e.g. keymap switching, bandwidth regulation, clipboard integration
--
return {
	atype = "remoting",
	props = {
		scalemode = "aspect",
		filtermode = FILTER_NONE,
		font_block = true,
		clipboard_block = true,
		rate_unlimited = false
	},
	default_shader = {"simple", "noalpha"}
};
