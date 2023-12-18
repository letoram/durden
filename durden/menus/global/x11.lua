-- (1 is used for alpha, the k/v mapping comes from tui
return {
{
	name = "autows",
	kind = "value",
	label = "Autoassign Workspace",
	initial = function()
		return gconfig_get("xarcan_autows");
	end,
	eval = function()
		return not gconfig_get("xarcan_seamless");
	end,
	set = {"none", "float", "fullscreen", "tile", "tab"},
	description = "Create a new workspace to host the Xarcan window",
	handler =
	function(ctx, val)
		gconfig_set("xarcan_autows", val);
	end,
},
{
	name = "meta_wm",
	kind = "value",
	label = "WM Integration",
	description = "Let the X11 window manager control the workspace",
	initial = function()
		return gconfig_get("xarcan_metawm") and LBL_YES or LBL_NO;
	end,
	set = {LBL_YES, LBL_NO, LBL_FLIP},
	handler =
	function(ctx, val)
		suppl_flip_handler("xarcan_metawm")(ctx, val);
	end
},
{
	name = "autows_nodecor",
	kind = "value",
	label = "Strip Decoration",
	description = "Remove titlebar and border from Root window",
	eval = function()
		return gconfig_get("xarcan_autows") ~= "none";
	end,
	initial = function()
		return gconfig_get("xarcan_autows_nodecor") and LBL_YES or LBL_NO;
	end,
	set = {LBL_YES, LBL_NO, LBL_FLIP},
	handler =
	function(ctx, val)
		suppl_flip_handler("xarcan_autows_nodecor")(ctx, val);
	end,
},
{
	name = "autows_tagname",
	kind = "value",
	label = "Autotag",
	description = "Tag X11 workspace with DISPLAY",
	eval = function()
		return gconfig_get("xarcan_autows") ~= "none";
	end,
	initial = function()
		return gconfig_get("xarcan_autows_tagname") and LBL_YES or LBL_NO;
	end,
	set = {LBL_YES, LBL_NO, LBL_FLIP},
	handler =
	function(ctx, val)
		suppl_flip_handler("xarcan_autows_tagname")(ctx, val);
	end,
},
};
