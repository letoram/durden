local log, fmt = suppl_add_logfn("tools")

gconfig_register("bgicon_size_px", 96)
gconfig_register("bgicon_grid_px", 164)
gconfig_register("bgicon_border_px", 8)

local wsicons = {}

-- active options:
--  show label
--  status-symbol (window, alert)
--
-- 1. load icons from key config
--    [trigger = path:/]
--    [rtrigger = path:/]
--    [source = icon:/name, bitmap_path]
--    [label = ..]
--
local iconmenu =
{
	{
		name = "add_random",
		kind = "action",
		eval = function()
			return DEBUGLEVEL > 0;
		end,
		handler = function()
			table.insert(
				wsicons, build_icon({},
				function(size_px)
					color_surface(size_px, size_px,
						math.random(127, 255), math.random(127, 255), math.random(127, 255));
				end))
		end
	}
};

local function disable_all()
	local ad = active_display()
	if ad.icons then
		ad.icons:destroy()
	end
end

local function enable_all()
	local ad = active_display()
	if ad.icons then
		return
	end

	log("kind=status:enable_desktop_icons")

	ad.icons = uiprim_spawn_icons(
		ad.width, ad.height, {
			allow_pan = false,
			allow_zoom = false,
			animation_speed = gconfig_get("animation_speed"),
			grid_snap = true,
			grid_w = math.floor(gconfig_get("bgicon_grid_px") * ad.scalef),
			grid_h = math.floor(gconfig_get("bgicon_grid_px") * ad.scalef),
			border = math.floor(gconfig_get("bgicon_border_px") * ad.scalef)
		}
	)

	mouse_addlistener(ad.icons.mouse)
	link_image(ad.icons.clipping_anchor, ad.anchor)

	for _, v in ipairs(wsicons) do
		local icn = build_icon(v);
	end
end

local function disable_all(set)
	for _,v in ipairs(wsicons) do
		if valid_vid(v.vid) then
			delete_image(v.vid);
		end
		v.vid = nil;
	end
end

local iconmenu = {
	{
	label = "Enabled",
	kind = "value",
	name = "enabled",
	set = {LBL_YES, LBL_NO, LBL_FLIP},
	initial = function()
		return gconfig_get("bgicons_enable") and LBL_YES or LBL_NO;
	end,
	handler = suppl_flip_handler("bgicons_enable",
	function(state)
		if state then
			enable_all();
		else
			disable_all();
		end
	end);
	}
}

menus_register("global", "settings/wspaces/float",
{
	kind = "action",
	submenu = true,
	label = "Icons",
	name = "icons",
	description = "Control desktop icon presence and behaviour",
	handler = iconmenu
}
);
