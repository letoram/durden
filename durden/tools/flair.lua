--
-- collection of hooks and effects
-- currently quite barebone, but intended to grow over time
-- to surpass what we would get from something like compiz
--
-- we keep the shaders and support script separate from the other
-- subsystems so that the effects are easier to develop, test and
-- share outside a full durden setup
--

-- the cloth effect has a rather verbose setup and use, so split
-- it up into two stages, the simulation and the config/setup
local cloth = system_load("tools/flair/cloth.lua")();
local destroy_effects = system_load("tools/flair/destroy.lua")();
local create_effects = system_load("tools/flair/create.lua")();

local drag_effects = { cloth };
local drag_effect = nil;

-- just route the drag/drop events with extra states for begin/end
local function flair_drag_hook(wm, wnd, dx, dy, last)
	if (drag_effect) then
		if (last) then
			drag_effect.stop(wnd);
			drag_effect= nil;
		else
			drag_effect.update(wnd, dx, dy);
		end
	else
		local cv = gconfig_get("flair_drag");
		for i,v in ipairs(drag_effects) do
			if (v.label == cv) then
				drag_effect = v;
				drag_effect.start(wnd);
				return;
			end
		end
	end
end

-- just dispatch the corresponding effect, the extra little detail
-- is that since the handler is likely to create an intermediate surface
-- with a shared storage, we wrap/set the attachment to match the display
-- of the wm rather than the active_display for multi-display purposes.
local function flair_wnd_destroy(wm, wnd, space, space_active, popup)
	local destroy = gconfig_get("flair_destroy");

	if (destroy and destroy_effects[destroy]) then
		display_tiler_action(wm, function()
			destroy_effects[destroy](wm, wnd, space, space_active, popup);
		end);
	end
end

local function flair_wnd_create(wm, wnd, space, space_active, popup)
	local create = gconfig_get("flair_create");
	if (create and create_effects[create]) then
		display_tiler_action(wm, function()
			create_effects[create](wm, wnd, space, space_active, popup);
		end);
	end
end

-- only menu/config key registration from this point
gconfig_register("flair_drag", "disabled");
gconfig_register("flair_destroy", "disabled");
gconfig_register("flair_speed", 50);

local drag_set = {"disabled"};
for k,v in ipairs(drag_effects) do
	table.insert(drag_set, v.label);
end

local create_set = {"disabled"};
for k,v in pairs(create_effects) do
	table.insert(create_set, k);
end

local destroy_set = {"disabled"};
for k,v in pairs(destroy_effects) do
	table.insert(destroy_set, k);
end

local flair_config_menu = {
	{
		name = "float_drag",
		label = "Float Drag",
		kind = "value",
		set = drag_set,
		initial = function()
			return gconfig_get("flair_drag");
		end,
		handler = function(ctx, val)
			gconfig_set("flair_drag", val);
-- account for the value being changed while we're in drag state
			if (drag_effect) then
				drag_effect.stop(active_display().selected);
				drag_effect = nil;
			end
		end
	},
	{
		name = "destroy",
		label = "Destroy",
		kind = "value",
		set = destroy_set,
		initial = function()
			return gconfig_get("flair_destroy");
		end,
		handler = function(ctx, val)
			gconfig_set("flair_destroy", val);
		end
	},
	{
		name = "create",
		label = "Create",
		kind = "value",
		set = create_set,
		initial = function()
			return gconfig_get("flair_create");
		end,
		handler = function(ctx, val)
			gconfig_set("flair_create", val);
		end
	},
	{
		name = "speed",
		label = "Speed",
		kind = "value",
		initial = function()
			return gconfig_get("flair_speed");
		end,
		validator = gen_valid_num(10, 100),
		handler = function(ctx, val)
			gconfig_set("flair_speed", tonumber(val));
		end
	},
};

for i,v in ipairs(drag_effects) do
	if (v.menu) then
		table.insert(flair_config_menu, v.menu);
	end
end

local in_flair = false;
local function flair_toggle()
	if (in_flair) then
-- deregister hooks
		in_flair = false;
		for wm in all_tilers_iter() do
			table.remove_match(wm.on_wnd_drag, flair_drag_hook);
			table.remove_match(wm.on_wnd_create, flair_wnd_create);
			table.remove_match(wm.on_wnd_destroy, flair_wnd_destroy);
		end
	else
		for wm in all_tilers_iter() do
			table.insert(wm.on_wnd_drag, flair_drag_hook);
			table.insert(wm.on_wnd_create, flair_wnd_create);
			table.insert(wm.on_wnd_destroy, flair_wnd_destroy);
		end
		in_flair = true;
	end
end

global_menu_register("tools",
{
	name = "flair",
	label = "Flair (toggle)",
	kind = "action",
	handler = flair_toggle
});

global_menu_register("settings/tools",
{
	name = "flair",
	label = "Flair",
	kind = "action",
	submenu = true,
	handler = flair_config_menu
});
