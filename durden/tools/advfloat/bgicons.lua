local log, fmt = suppl_add_logfn("tools")

gconfig_register("bgicon_size_px", 64)
gconfig_register("bgicon_grid_px", 92)
gconfig_register("bgicon_border_px", 8)
gconfig_register("bgicon_grid_snap", true)
gconfig_register("bgicon_enable", false)
gconfig_register("bgicon_zoom", false)
gconfig_register("bgicon_pan", false)

local wsicons = {}
-- load / unpack keys into wsicons

--
-- [bringup]
--
--   regular icon with single color factory
--   double-click or single-rclick to trigger
--   drag and drop receiver to drag icons from browser or files from clients
--   load/store current set
--   controls for settings (e.g. size, unlock panning)
--      -> forward into spawn_iconview as opts
--   keyboard controls (move selection, delection, trigger) (need input capture)
--   minimize to non-persistent icon
--   hover to show full text if cropped
--
-- [advanced]
--   zooming
--   region select
--   workspace/display controls
--   stateful images
--   non-uniform sizes
--

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

local function build_icon(v)
	local icons = active_display().icons
	return icons:add(v.name)

-- use the icon manager to request image source
-- unpack
end

local function disable_all()
	local ad = active_display()
	if ad.icons then
		ad.icons:destroy()
	end
end

local function synch_all()
	local ad = active_display()
	local icons = ad.icons
	if not icons then
		return
	end

	icons.icon_w = gconfig_register("bgicon_size_px") * ad.scalef
	icons.icon_h = ad.icons.icon_w
	icons.allow_pan = gconfig_get("bgicon_pan")
	icons.allow_zoom = gconfig_get("bgicon_zoom")
	icons.grid.snap = gconfig_get("bgicon_grid_snap")
	icons.grid.w = gconfig_get("bgicon_grid_px") * ad.scalef
	icons.border = gconfig_get("bgicon_border_px") * ad.scalef

-- trigger the resize/realign
	icons:resize(ad.effective_width, ad.effective_height)
end

local function enable_all()
	local ad = active_display()
	if ad.icons then
		return
	end

	log("kind=status:enable_desktop_icons")

	ad.icons =
	uiprim_icon_spawn(
		ad.width, ad.height,
		{
			allow_pan = false,
			allow_zoom = false,
			animation_speed = gconfig_get("animation_speed"),
			grid_snap = gconfig_get("bgicon_grid_snap"),
			icon_w = gconfig_get("bgicon_size_px") * ad.scalef,
			icon_h = gconfig_get("bgicon_size_px") * ad.scalef,
			grid_w = math.floor(gconfig_get("bgicon_grid_px") * ad.scalef),
			grid_h = math.floor(gconfig_get("bgicon_grid_px") * ad.scalef),
			border = math.floor(gconfig_get("bgicon_border_px") * ad.scalef),
			selection_shader =
			function(vid)
				shader_setup(vid, "ui", "regsel", "active");
			end,
			check_modifier =
			function()
				local m1, m2 = dispatch_meta()
				return m1 or m2
			end,
			click_through =
			function(ind, x, y)
				if ind == MOUSE_RBUTTON then
					local action = gconfig_get("float_bg_rclick")
					if action then
						dispatch_symbol(action)
					end
				end
			end
		}
	)

-- need to anchor to ws.anchor and swap when workspace is supposed to
-- switch
	mouse_addlistener(ad.icons.mouse)
	link_image(ad.icons.clipping_anchor, ad.anchor)
	order_image(ad.icons.clipping_anchor, 4)

-- get set from key_value store, encode as packed shmif-arg in value
--
--   useful subkeys:
--     label
--     path
--     altpath
--     source (to icon-manager)
--

	for _, v in ipairs(wsicons) do
		local icn = build_icon(v)
	end
end

local function disable_all()
	active_display().icons:destroy()
end

if gconfig_get("bgicon_enable") then
	enable_all()
end

local iconmenu = {
	{
	label = "Enabled",
	kind = "value",
	name = "enabled",
	set = {LBL_YES, LBL_NO, LBL_FLIP},
	initial = function()
		return gconfig_get("bgicon_enable") and LBL_YES or LBL_NO;
	end,
	handler = suppl_flip_handler("bgicon_enable",
	function(state)
		if state == LBL_YES then
			enable_all();
		else
			disable_all();
		end
	end);
	},
	{
		name = "icon_sz",
		label = "Icon Size",
		description = "Set the default unit pixel size for the icons at 1x scale",
		kind = "value",
		validator = gen_valid_num(16, 256),
		hint = "(16..256)",
		handler =
		function(ctx, val)
			local num = tonumber(val)
			gconfig_set("bgicon_size_px", val)
			synch_all()
		end
	},
	{
		name = "grid_sz",
		label = "Grid Size",
		description = "Set the default unit pixel size for grid alignment",
		kind = "value",
		initial = function()
			return gconfig_get("bgicon_size_px")
		end,
		hint = "(16..256)",
		validator = gen_valid_num(16, 256),
		function(ctx, val)
			local num = tonumber(val)
			gconfig_set("bgicon_grid_px", num)
			synch_all()
		end
	},
	{
		name = "grid_align_toggle",
		label = "Grid Snap",
		description = "Set if icon drag should force align to grid",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function()
			return gconfig_get("bgicon_enable") and LBL_YES or LBL_NO;
		end,
		handler = suppl_flip_handler("bgicon_enable",
			function(state)
				synch_all()
			end
		)
	},
	{
		name = "add_random",
		label = "Add Random",
		kind = "action",
		eval = function()
			return gconfig_get("bgicon_enable") and DEBUGLEVEL > 0;
		end,
		handler = function()
			table.insert(
				wsicons, build_icon({
					label = tostring(CLOCK),
					trigger = "/global",
					rtrigger = "/global/system",
					factory =
					function(size_px)
						color_surface(
							size_px,
							size_px,
							math.random(127, 255),
							math.random(127, 255),
							math.random(127, 255)
						);
					end
				})
			)
		end
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
