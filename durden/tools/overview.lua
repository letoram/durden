--
-- support script for building 'expose' and similar overviews
-- to add a new, see (tile) as reference on what is typically needed,
-- and add the new overview to the overview_sub table at the bottom.
--
-- most complexity come from the need to be able to rebuild if the
-- underlying configuration changes while we're active since timers,
-- IPC etc. can both create, reassign and destroy windows.
--
local last_overview;
local mh_cache = {};

local preview_listener =
function(ws, key, action, target)
end

local function build_preview_set(newt)
	local res = {};

-- sweep each workspace, and build references to the main contents of each
-- (no decorations) along with sizing/positioning metadata
	for i=1,10 do
		if (newt.spaces[i]) then
			local tt = {
				mode = newt.spaces[i].mode,
				label = newt.spaces[i].label,
				background = newt.spaces[i].background,
				windows = {}
			};

			local lst = newt.spaces[i]:linearize();
			for k,v in ipairs(lst) do
				local props = image_surface_resolve(v.canvas);
				table.insert(tt.windows, {
					vid = v.canvas,
					x = props.x,
					y = props.y,
					w = props.width,
					h = props.height,
					z = props.order
				});
			end

-- sort the windows by order so we don't need to reorder the alias- surfaces
			table.sort(tt.windows, function(a, b) return a.z <= b.z; end);
			newt.spaces[i]:add_listener("overview",
			function(...)
				preview_listener(...);
			end);
			table.insert(res, tt);
		end
	end

	return res;
end

-- mouse-handlers need to be manually diassociated when removing the overview
local function drop_mhs()
	for i=#mh_cache,1,-1 do
		mouse_droplistener(mh_cache[i]);
		table.remove(mh_cache, i);
	end
end

local function toggle_ws(cb)
	local wm = active_display();
	local set = build_preview_set(wm);

-- toggle off?
	if (last_overview) then
		tiler_lbar_setactive();
		return;
	end

	if (#set <= 1 or not cb) then
		return;
	end

-- the setup here is similar to tiler_lbar
	local time = gconfig_get("transition");
	if (valid_vid(PENDING_FADE)) then
		delete_image(PENDING_FADE);
		time = 0;
	end
	PENDING_FADE = nil;

-- set shader and background based on config
	local bg = fill_surface(wm.width, wm.height, 0, 0, 0);
	blend_image(bg, gconfig_get("overview_tilebg_opa"), time, INTERP_SMOOTHSTEP);
	image_tracetag(bg, "overview_bg");
	local lookup_key = gconfig_get("overview_tilebg_shader");
	local key, dom = shader_getkey(lookup_key, {"effect", "simple"});

	if (key ~= nil) then
		shader_setup(bg, dom, key);
	end

	link_image(bg, wm.order_anchor);
	image_inherit_order(bg, true);

-- the statusbar is more complicated than it seems as it can either be hidden
-- already, be part of "show-on-HUD" mode or "show-on-desktop" mode.
	wm.statusbar:hide();

-- set as the current lbar layer, with a destruction handler in case a
-- different one is spawned outside our control. The same destruction handler
-- will be used when/if a workspace gets activated.
	tiler_lbar_setactive({
		destroy = function()
			if (not gconfig_get("sbar_hud")) then
				wm.statusbar:show();
			end

-- drop all listeners
			for i=1,10 do
				if (wm.spaces[i]) then
					wm.spaces[i]:add_listener("overview");
				end
			end
			drop_mhs();

-- fade out based on normal transition time settings
			expire_image(bg, gconfig_get("transition"));
			blend_image(bg, 0.0, gconfig_get("transition"));
			if (last_overview) then
				last_overview:destroy(gconfig_get("transition"));
				last_overview = nil;
			end
			PENDING_FADE = bg;
		end
	});

	cb(wm, bg, set);
end

-- Take a set from build_preview_set (list of workspaces, backgrounds
-- and relevant parts of windows) and construct new visual objects.
local function build_setlist(wm, anchor, set, base_w, h, spacing)
	local res = {};

	for i=1,#set do
		res[i] = {};
-- build the constrain- region and either a grey background to indicate
-- where there isn't a background in the workspace
		local nsrf;
		if (valid_vid(set[i].background)) then
			nsrf = null_surface(base_w + 2, h + 2);
			image_sharestorage(set[i].background, nsrf);
		else
			nsrf = fill_surface(base_w + 2, h + 2, 32, 32, 32);
		end
		link_image(nsrf, anchor, ANCHOR_UR);
		image_inherit_order(nsrf, true);
		show_image(nsrf);
		last = nsrf;
		move_image(nsrf, (spacing + base_w) * (i-1), 0);

-- and generate some kind of descriptive label
		local str = string.format("%s %d<%s>%s",
			gconfig_get("lbar_textstr"), i, set[i].mode,
			set[i].label and "\\n\\r" .. set[i].label or "");
		local label, _, lbl_w = render_text(str);

-- attach the label to the cell, anchor at the lower center
		if (valid_vid(label)) then
			image_inherit_order(label, true);
			link_image(label, nsrf, ANCHOR_LC);
			order_image(label, 1);
			nudge_image(label, -0.5 * lbl_w, 0);
			show_image(label);
		end

		local sx = base_w / wm.width;
		local sy = h / wm.height;
		table.insert(res[i], nsrf);

-- fill with alias- surfaces, maintain aspect
		for _,wnd in ipairs(set[i].windows) do
			local ns = null_surface(wnd.w * sx, wnd.h * sy);
			if (valid_vid(ns)) then
				link_image(ns, nsrf);
				image_inherit_order(ns, true);
				show_image(ns);
				order_image(ns, wnd.z);
				image_sharestorage(wnd.vid, ns);
				image_mask_set(ns, MASK_UNPICKABLE);
				move_image(ns, 1 + wnd.x * sx, 1 + wnd.y * sy);
				table.insert(res[i], ns);
			end
		end
	end

	return res;
end

local function tile_input(wm, sym, iotbl, lutsym, meta)
	local num = tonumber(lutsym);
	if (lutsym == SYSTEM_KEYS["cancel"]) then
		tiler_lbar_setactive();
	elseif (lutsym == SYSTEM_KEYS["accept"]) then
	elseif (lutsym == SYSTEM_KEYS["next"]) then
	elseif (lutsym == SYSTEM_KEYS["previous"]) then
	elseif (num and wm.spaces[num]) then
		tiler_lbar_setactive();
		wm:switch_ws(num);
	end
end

-- simple horizontal list
-- placement around 1D dominant axis, size based on number of cells
-- 2x zoom on mouse-over (bias displace in largest neg- or positive)
-- show window identifier "on over"
-- number of carousels and placement vary with the number of windows
-- navigation:
-- numbers to switch selected ws
--
local function tile(wm, bg, set)
	local spacing;
	local base_w;
	local ar;
	local h;

	local calc_size = function()
		spacing = wm.width * 0.02;
		base_w = math.floor((wm.width - #set * spacing) / (#set));
		base_w = base_w > wm.height * 0.7 and wm.height * 0.7 or base_w;
		ar = wm.width / wm.height;
		h = math.ceil(base_w / ar);
		spacing = (wm.width - base_w * #set) / #set;
	end
	calc_size();

-- add another anchor that we use as a container to animate everything
	local anchor;
	local build_anchor = function(time)
		anchor = null_surface(1, 1);
		link_image(anchor, bg);
		image_mask_clear(anchor, MASK_OPACITY);
		image_inherit_order(anchor, true);
		blend_image(anchor, 1, time, INTERP_SMOOTHSTEP);
		move_image(anchor, spacing * 0.5, 0.5 * (wm.height - h));
		order_image(anchor, 1);
	end
	build_anchor(gconfig_get("transition"));

-- (re-) generate the actual set of preview cells
	local res = build_setlist(wm, anchor, set, base_w, h, spacing);

-- attach a mouse handler that highlights on 'mouse over/out', switch on click
	for i,v in ipairs(res) do
		local mh = {
			over = function()
				shader_setup(v[1], "ui", "regmark");
			end,
			out = function()
				image_shader(v[1], "DEFAULT");
			end,
			own = function(ctx, vid)
				return vid == v[1];
			end,
			click = function()
				image_shader(v[1], "DEFAULT");
				tiler_lbar_setactive();
				wm:switch_ws(i);
			end,
			name = "overview_mh"
		};
		table.insert(mh_cache, mh);
		mouse_addlistener(mh, {"over", "out", "click"});
	end

-- update the file-scope hook with a destroy handler
	last_overview = {
		destroy = function(ctx, time)
			expire_image(anchor, time and time or 1);
			blend_image(anchor, 0.0, time and time or 1, INTERP_SMOOTHSTEP);
			drop_mhs();
			wm:set_input_lock();
		end
	};

-- used whenever the underlying data source is invalidated, resolution changes,
-- windows appearing / disappearing and so on.
	local rebuild = function()
		if (not valid_vid(anchor)) then
			return;
		end

		delete_image(anchor);
		calc_size();
		set = build_preview_set(wm);
		anchor = null_surface(1, 1);
		build_anchor(0);
		build_setlist(wm, anchor, set, base_w, h, spacing);
	end

-- register a timer that periodically rebuilds the contents of this surface to
-- account for pending animations and that kind of dynamic relayouting. This
-- doesn't look very pretty or smooth but is cleaner than trying to create the
-- alias surface with equivalent transformation chains - think what happens if
-- a slow window is animated and the preview gets activated...
	preview_listener = function(ws, key, action, target)
		if (action == "resized") then
			if (gconfig_get("wnd_animation") > 0) then
				timer_add_periodic("overview",
					gconfig_get("wnd_animation")+1, true, rebuild, true);
			end
		else
			rebuild();
		end
	end

	wm:set_input_lock(tile_input);
end

gconfig_register("overview_tilebg_opa", 0.8);
gconfig_register("overview_tilebg_shader", "default");

local overview_sub = {
{
	name = "ws_tile",
	label = "Workspace(Tile)",
	kind = "action",
	description = "Evenly space out tiles that represent each workspace",
	eval = function()
		return true;
	end,
	handler = function() toggle_ws(tile); end
}
};

local overview_cfg = {
{
	name = "ws_tile_shader",
	label = "Shader(Tile)",
	kind = "value",
	description = "Shader used on the overview HUD background",
	initial = function() return gconfig_get("overview_tilebg_shader"); end,
	set = function() return shader_list({"effect", "simple"}); end,
	handler = function(ctx, val)
		local key, dom = shader_getkey(val, {"effect", "simple"});
		if (key ~= nil) then
			gconfig_set("overview_tilebg_shader", key);
		end
	end
},
{
	name = "ws_tile_opa",
	label = "Bg-Opacity(Tile)",
	kind = "value",
	description = "Background opacity of the individual tiles",
	initial = function() return gconfig_get("overview_tilebg_opa"); end,
	validator = gen_valid_float(0.0, 1.0),
	handler = function(ctx, val)
		gconfig_set("overview_tilebg_opa", tonumber(val));
	end
}
};

global_menu_register("settings/tools",
{
	name = "overview",
	label = "Overview",
	kind = "action",
	description = "Change the look and feel of the overview workspace selector",
	submenu = true,
	handler = overview_cfg
});

global_menu_register("tools",
{
	name = "overview",
	label = "Overview",
	kind = "action",
	description = "Show a workspace selection HUD",
	submenu = true,
	handler = overview_sub
});
