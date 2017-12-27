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
--
system_load("tools/advfloat/cactions.lua")();
system_load("tools/advfloat/minimize.lua")();
system_load("tools/advfloat/spawnctl.lua")();

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

shared_menu_register("window",
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

global_menu_register("workspace",
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

global_menu_register("settings/wspaces/float",
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
});

global_menu_register("settings/wspaces/float",
{
	kind = "value",
	name = "icons",
	label = "Icons",
	description = "Control how the tool should manage icons",
	eval = function() return false; end,
	set = {"disabled", "global", "workspace"},
	initial = gconfig_get("advfloat_icon"),
	handler = function(ctx, val)
		gconfig_set("advfloat_icon", val);
	end
});
