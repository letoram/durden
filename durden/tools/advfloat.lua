--
-- Advanced float handler
--
-- Kept here as a means to start removing policy from tiler.lua
-- and letting more parts of the codebase be "opt out"
--
-- Since it is rather big, it have been split out into multiple subscripts,
-- while this one is kept as an entry point for consolidating menu
-- mapping and configuration keys.
--
-- cactions : cursor regions - path activation on mouse behavior
-- gridfit  : split the screen into a 9-cell region for pseudo-tiler
-- autolay  : automatic reposition/relayouting heuristics
-- spawnctl : intercept and regulate initial window position and size
-- minimize : minimize- target controls
-- bginput  : input handlers for the wallpaper image (if one is set)
-- icons    : desktop icon support
--

local floatmenu = {
{
	kind = "value",
	name = "spawn_action",
	initial = gconfig_get("advfloat_spawn"),
	label = "Spawn Method",
	description = "Change how new windows are being sized and positioned",
-- missing (split/share selected) or join selected
	set = {"click", "cursor", "draw", "auto"},
	handler = function(ctx, val)
		mode = val;
		gconfig_set("advfloat_spawn", val);
	end
},
};

menus_register("global", "settings/wspaces",
{
	kind = "action",
	name = "float",
	submenu = true,
	label = "Float",
	description = "Advanced float workspace layout",
	handler = floatmenu
});
system_load("tools/advfloat/cactions.lua")();
system_load("tools/advfloat/minimize.lua")();
system_load("tools/advfloat/spawnctl.lua")();
system_load("tools/advfloat/bginput.lua")();
system_load("tools/advfloat/bgicons.lua")();

local workspace_menu = {
{
	kind = "action",
	submenu = true,
	name = "autolayout",
	label = "Layouter",
	description = "Apply an automatic layouting technique",
	handler = system_load("tools/advfloat/autolay.lua")()
}
};

menus_register("target", "window",
{
	kind = "action",
	submenu = true,
	name = "gridalign",
	label = "Grid-Fit",
	eval = function()
		local wnd = active_display().selected;
		return (wnd and wnd.space.mode == "float");
	end,
	description = "Size and fit the current window to a virtual grid cell",
	handler = system_load("tools/advfloat/gridfit.lua")()
});

menus_register("target", "window/move_resize",
{
	kind = "action",
	submenu = false,
	name = "drawrz",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	label = "Draw-Resize",
	handler = system_load("tools/advfloat/rzctl.lua")()
});

menus_register("global", "workspace",
{
	kind = "action",
	name = "float",
	label = "Float",
	submenu = true,
	description = "(advfloat-tool) active workspace specific actions",
	eval = function()
		return active_display().spaces[active_display().space_ind].mode == "float";
	end,
	handler = workspace_menu
});
