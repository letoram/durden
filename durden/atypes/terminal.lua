--
-- Terminal archetype, settings and menus specific for terminal-
-- frameserver session (e.g. keymapping, state control)
--

local res = {
	dispatch = {

-- add a sub- protocol for communicating cell dimensions, this is
-- used to cut down on resize calls (as they are ** expensive in
-- terminal land).
		message = function(wnd, source, tbl)
			print("parse terminal font size from tbl", tbl.message);
		end
	},
-- actions are exposed as target- menu
	actions = {},
-- labels is mapping between known symbol and string to forward
	labels = {},
	default_shader = "clamp_crop",
	atype = "terminal",
	props = {
		scalemode = "stretch",
		autocrop = true,
		filtermode = FILTER_NONE
	}
};

-- globally listen for changes to the default opacity and forward
gconfig_listen("term_opa", "aterm",
function(id, newv)
	for wnd in all_windows() do
		if (wnd.atype == "terminal" and
			valid_vid(wnd.external, TYPE_FRAMESERVER)) then
			target_graphmode(wnd.external, 1, newv * 255.0);
		end
	end

	local k, v = shader_getkey("clamp_crop");
	shader_uniform(v.shid, "crop_opa", "f", PERSIST, newv);
end);

res.labels["LEFT"] = "LEFT";
res.labels["UP"] = "UP";
res.labels["DOWN"] = "DOWN";
res.labels["RIGHT"] = "RIGHT"
res.labels["lshift_UP"] = "SCROLL_UP";
res.labels["lshift_DOWN"] = "SCROLL_DOWN";
res.labels["PAGE_UP"] = "PAGE_UP";
res.labels["PAGE_DOWN"] = "PAGE_DOWN";
res.labels["lctrl_t"] = "SIGINFO";
res.labels["lctrl_m"] = "MUTE";
res.labels["lshift_F7"] = "FONTSZ_INC";
res.labels["lshift_F8"] = "FONTSZ_DEC";

return res;
