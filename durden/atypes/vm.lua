return {
	dispatch = {},
-- actions are exposed as target- menu
	actions = {},
-- labels is mapping between known symbol and string to forward
	labels = {},
	atype = "vm",
	props = {
-- keep as client for now, when the server-side rendering can do cropping
-- and clipping correctly for tui surfaces we can reconsider..
		scalemode = "client",
		font_block = true,
		filtermode = FILTER_NONE,
		allowed_segments = {"tui", "handover"}
	},
};
