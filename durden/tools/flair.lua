--
-- collection of hooks and effects
--
-- Currently quite barebone, but intended to grow over time to surpass
-- what we would get from something like compiz - complemented with some
-- other tools, e.g. overview.lua (for 3D switcher)
--
-- Missing:
-- 'focus layer'
-- 'lockscreen effect'
-- 'shadow effect'
--

-- reused with many effects
flair_supp_clone = function(wnd)
	local props = image_surface_resolve(wnd.canvas);
	local vid = null_surface(props.width, props.height);
	if (valid_vid(vid)) then
		show_image(vid);
		move_image(vid, props.x, props.y);
		image_sharestorage(wnd.canvas, vid);
		expire_image(vid, gconfig_get("flair_speed")+1);
	end
	return vid;
end

local blur_frag = [[
uniform sampler2D map_tu0;
uniform float obj_opacity;
uniform vec2 obj_output_sz;
uniform vec4 weight;
varying vec2 texco;

void main()
{
	vec4 sum = vec4(0.0);
	float blurh = 1.0 / obj_output_sz.x;
	sum += texture2D(map_tu0, vec2(texco.x - 4.0 * blurh, texco.y)) * 0.05;
	sum += texture2D(map_tu0, vec2(texco.x - 3.0 * blurh, texco.y)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x - 2.0 * blurh, texco.y)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x - 1.0 * blurh, texco.y)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x - 0.0 * blurh, texco.y)) * 0.18;
	sum += texture2D(map_tu0, vec2(texco.x + 1.0 * blurh, texco.y)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x + 2.0 * blurh, texco.y)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x + 3.0 * blurh, texco.y)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x + 4.0 * blurh, texco.y)) * 0.05;

	float blurv = 1.0 / obj_output_sz.y;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 4.0 * blurv)) * 0.05;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 3.0 * blurv)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 2.0 * blurv)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 1.0 * blurv)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y - 0.0 * blurv)) * 0.18;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 1.0 * blurv)) * 0.15;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 2.0 * blurv)) * 0.12;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 3.0 * blurv)) * 0.09;
	sum += texture2D(map_tu0, vec2(texco.x, texco.y + 4.0 * blurv)) * 0.05;
	sum *= weight;
	gl_FragColor = vec4(sum.rgb, sum.a);
}
]]

local blur_shid;
local function setup_lbar_handler(tiler)
	local old_lbar = tiler.lbar;

-- intercept lbar creation and impose the placeholder, might be able
-- to use another slicing range / tool here to also work for content
-- or decoration blurs.
	tiler.lbar =
	function(wm, completion, comp_ctx, opts, ...)
		local opts = opts and opts or {};

		if gconfig_get("flair_hud") == "blur" and valid_vid(tiler.rtgt_id) then
			if not blur_shid then
				blur_shid = build_shader(nil, blur_frag, "flair_blur");
				shader_uniform(blur_shid, "weight", "ffff", 0.5, 0.5, 0.5, 1.0)
			end

-- Draw everything up to the hud layer into a buffer, this blur is rather
-- naive and clamps, so the edges will get a slight bias. To offset that,
-- the darken/vignette shader helps.
			local w = 512;
			local h = 256;
			if wm.effective_width < wm.effective_height then
				w = 256;
				h = 512;
			end

			rendertarget_range(tiler.rtgt_id, 0,
				image_surface_properties(tiler.order_anchor).order - 1);
			local buf = alloc_surface(w, h);
			rendertarget_forceupdate(tiler.rtgt_id);
			resample_image(tiler.rtgt_id, "flair_blur", w, h, buf);

-- statically apply the blur
			for i=1,8 do
				resample_image(buf, blur_shid, w, h, true);
			end

-- restore world
			rendertarget_range(tiler.rtgt_id, -1, -1);

			image_texfilter(buf, FILTER_BILINEAR);
			opts.bg_shader = "vignette";
			opts.bg_shader_group = "simple";
			opts.bg_source = buf;
			opts.bg_alpha = 1.0;
		end

		return old_lbar(wm, completion, comp_ctx, opts, ...);
	end
end

-- slice the window in segments of w/s*h/t subsurfaces and present each
-- to the provided iterator. These have a preset expiration time that the
-- caller may override in the callback
flair_supp_segment = function(wnd, px_s, px_t, callback)
	local tile_sz_w = px_s;
	local tile_sz_h = px_t;
	local props = image_surface_resolve(wnd.canvas);

	local ct = 0;
	local cp_x = props.x + 0.5 * wnd.effective_w;
	local cp_y = props.y + 0.5 * wnd.effective_h;
	local ul_r = math.ceil(wnd.effective_h / tile_sz_h) - 1;
	local ul_c = math.ceil(wnd.effective_w / tile_sz_w) - 1;
	local sf_s = px_s / wnd.effective_w;
	local sf_t = px_t / wnd.effective_h;
	local rm_speed = gconfig_get("flair_speed")+1;

	for row=1,ul_r do
		local cs = 0;
		for col=1,ul_c do
-- skip if we run out of VIDs
			local cell = null_surface(tile_sz_w, tile_sz_h);
			if (not valid_vid(cell)) then
				return;
			end
			image_mask_set(cell, MASK_UNPICKABLE);
			local cx = props.x + (col-1) * tile_sz_w;
			local cy = props.y + (row-1) * tile_sz_h;

-- reference the storage and tune the texture coordinates
			image_sharestorage(wnd.canvas, cell);
			move_image(cell, cx, cy);
			show_image(cell);
			order_image(cell, props.order);

-- slice the texture coordinates
			image_set_txcos(cell, {
				cs, ct,
				cs + sf_s, ct,
				cs + sf_s, ct + sf_t,
				cs, ct + sf_t
			});
			cs = cs + sf_s;

-- clamp to surface
			local origin_x = cp_x;
			local origin_y = cp_y;

-- automatic cleanup
			expire_image(cell, rm_speed);
			callback(cell, rm_speed, cx, cy, tile_sz_w, tile_sz_h,
				origin_x, origin_y, props.x, props.y, props.width, props.height);
		end

		ct = ct + sf_t;
	end
end

flair_supp_psys = system_load("tools/flair/psys.lua")();

local destroy_effects = system_load("tools/flair/destroy.lua", false)();
local create_effects = system_load("tools/flair/create.lua", false)();
local drag_effects = system_load("tools/flair/drag.lua", false)();
local hide_effects = system_load("tools/flair/hide.lua", false)();
local display_effects = system_load("tools/flair/display.lua", false)();
local background_effects = system_load("tools/flair/background.lua", false)();
local select_effects = system_load("tools/flair/select.lua", false)();

local drag_effect = nil;
-- just route the drag/drop events with extra states for begin/end
local function flair_drag_hook(wm, wnd, dx, dy, last)
-- already in effect, just update
	if (in_drag) then

-- on-drag-leave
		if (last) then
			if (drag_effect) then
				drag_effect.stop(wnd);
				drag_effect = nil;
			end
			in_drag = false;
			show_image(wnd.anchor);

		elseif (drag_effect) then
			drag_effect.update(wnd, dx, dy);
		end
		return;
	end

-- on-drag-enter
	local cv = gconfig_get("flair_drag");
	in_drag = true;
	blend_image(wnd.anchor, gconfig_get("flair_drag_opacity"));

	if (drag_effects) then
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

	if (destroy_effects and destroy_effects[destroy]) then
		display_tiler_action(wm, function()
			destroy_effects[destroy](wm, wnd, space, space_active, popup);
		end);
	end
end

local function flair_wnd_hide(wm, wnd, dx, dy, dw, dh, hide)
	local heffect = gconfig_get("flair_hide");

	if (hide_effects and hide_effects[heffect]) then
		display_tiler_action(wm, function()
			hide_effects[heffect](wm, wnd, dx, dy, dw, dh, hide);
		end);
	else
		if (hide) then
			wnd:hide();
		else
			wnd:show();
		end
	end
end

local function flair_wnd_create(wm, wnd, space, space_active, popup)
	local create = gconfig_get("flair_create");
	if (create_effects and create_effects[create]) then
		display_tiler_action(wm, function()
			create_effects[create](wm, wnd, space, space_active, popup);
		end);
	end
end

local function flair_wnd_select(wm, wnd, space, space_active, popup)
	local sel = gconfig_get("flair_select");
	if (select_effects and select_effects[sel]) then
		display_tiler_action(wm, function()
			select_effects[sel](wm, wnd, space, space_active, popup);
		end);
	end
end

-- only menu/config key registration from this point
gconfig_register("flair_drag", "disabled");
gconfig_register("flair_destroy", "disabled");
gconfig_register("flair_create", "disabled");
gconfig_register("flair_hide", "disabled");
gconfig_register("flair_select", "disabled");
gconfig_register("flair_speed", 50);
gconfig_register("flair_drag_opacity", 1.0);
gconfig_register("flair_select", "disabled");

local drag_set = {"disabled"};
if (drag_effects) then
	for k,v in ipairs(drag_effects) do
		table.insert(drag_set, v.label);
	end
end

local select_set = {"disabled"};
if (select_effects) then
	for k,v in pairs(select_effects) do
		table.insert(select_set, k);
	end
end

local create_set = {"disabled"};
if (create_effects) then
	for k,v in pairs(create_effects) do
		table.insert(create_set, k);
	end
end

local destroy_set = {"disabled"};
if (destroy_effects) then
	for k,v in pairs(destroy_effects) do
		table.insert(destroy_set, k);
	end
end

local hide_set = {"disabled"};
if (hide_effects) then
	for k,v in pairs(hide_effects) do
		table.insert(hide_set, k);
	end
end

-- the display effects follow the state of the active display, i.e.
-- rebuilds when workspace or workspace mode is switched, disabled when
-- the display is lost etc.
local display_effect = {
{
	name = "reset",
	label = "Reset",
	kind = "action",
	description = "Remove all display effects",
	handler = function()
		for wm in all_tilers_iter() do
			if (wm.display_effects) then
				for _,v in ipairs(wm.display_effects) do
					if (v.destroy) then v:destroy();
					end
				end
			end
		end
	end
}
};

if (display_effects and type(display_effects) == "table") then
	for k,v in ipairs(display_effects) do
		table.insert(display_effect,	{
	name = v.name,
	label = v.label,
	description = v.description,
	handler = function()
		v.create(active_display());
	end,
	kind = "action"
});
	end
end

local flair_config_menu = {
	{
		name = "float_drag",
		label = "Float Drag",
		kind = "value",
		description = "Set the effect that is used 'on window - drag'",
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
		description = "Set the effect that is used 'on window - destroy'",
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
		description = "Set the effect that is used 'on window - create'",
		set = create_set,
		initial = function()
			return gconfig_get("flair_create");
		end,
		handler = function(ctx, val)
			gconfig_set("flair_create", val);
		end
	},
	{
		name = "select",
		label = "Select",
		kind = "value",
		description = "Set the effect that is used 'on window - select'",
		set = select_set,
		initial = function()
			return gconfig_get("flair_select");
		end,
		handler = function(ctx, val)
			gconfig_set("flair_select", val);
		end
	},
	{
		name = "hide",
		label = "Hide",
		description = "Set the effect that is used 'on window - hide'",
		kind = "value",
		set = hide_set,
		initial = function()
			return gconfig_get("flair_hide");
		end,
		handler = function(ctx, val)
			gconfig_set("flair_hide", val);
		end
	},
	{
		name = "speed",
		label = "Speed",
		kind = "value",
		description = "Change the relative speed of all flair- related effects",
		initial = function()
			return gconfig_get("flair_speed");
		end,
		validator = gen_valid_num(10, 100),
		handler = function(ctx, val)
			gconfig_set("flair_speed", tonumber(val));
		end
	},
	{
		name = "drag_opacity",
		label = "Drag Opacity",
		description = "Control window opacity when being dragged",
		kind = "value",
		initial = function()
			return gconfig_get("flair_drag_opacity");
		end,
		validator = gen_valid_float(0.1, 1.0),
		handler = function(ctx, val)
			gconfig_set("flair_drag_opacity", tonumber(val));
		end
	}
};

for i,v in ipairs(drag_effects) do
	if (v.menu) then
		table.insert(flair_config_menu, v.menu);
	end
end

local in_flair = false;

local function set_tiler(wm)
	if (in_flair) then
		table.insert(wm.on_wnd_drag, flair_drag_hook);
		table.insert(wm.on_wnd_create, flair_wnd_create);
		table.insert(wm.on_wnd_destroy, flair_wnd_destroy);
		table.insert(wm.on_wnd_hide, flair_wnd_hide);
		table.insert(wm.on_wnd_select, flair_wnd_select);
	else
		table.remove_match(wm.on_wnd_drag, flair_drag_hook);
		table.remove_match(wm.on_wnd_create, flair_wnd_create);
		table.remove_match(wm.on_wnd_destroy, flair_wnd_destroy);
		table.remove_match(wm.on_wnd_hide, flair_wnd_hide);
		table.remove_match(wm.on_wnd_select, flair_wnd_select);
	end
end

local function display_added(event, name, tiler, id)
	if (tiler.on_wnd_drag) then
		set_tiler(tiler);
	end

-- intercept lbar creation in order to patch in our own background
-- and shader, this is done per display
	if tiler.lbar then
		setup_lbar_handler(tiler);
	end
end

local flair_menu = {
{
	name = "window",
	label = "Window Effects",
	kind = "value",
	set = {LBL_YES, LBL_NO},
	description = "Enable or Disable Window- Effects",
	handler = function(ctx, val)
		in_flair = val == LBL_YES;
		for wm in all_tilers_iter() do
			set_tiler(wm);
		end
	end
},
{
	name = "display",
	label = "Display Effect",
	kind = "action",
	description = "Add an effect to the active display",
	handler = display_effect,
	submenu = true
},
{
	name = "background",
	label = "Background Effect",
	kind = "action",
	submenu = true,
	description = "Set an effect that applies to the active workspace background",
	handler = background_effects,
	eval = function() return false; end
},
{
	name = "hud_background",
	label = "HUD background",
	description = "Set an effect for the HUD background",
	kind = "value",
	set = {"darken", "blur"},
	handler =
	function(ctx, val)
		gconfig_set("flair_hud", val);
	end
}
};

gconfig_register("flair_hud", "darken");
display_add_listener(display_added);

menus_register("global", "tools",
{
	name = "flair",
	label = "Flair",
	description = "Advanced window and desktop effects",
	kind = "action",
	submenu = true,
	handler = flair_menu
}
);

menus_register("global", "settings/tools",
{
	name = "flair",
	label = "Flair",
	description = "Change which effects that will be used by the flair tool",
	kind = "action",
	submenu = true,
	handler = flair_config_menu
});
