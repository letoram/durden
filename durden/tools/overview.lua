--
-- support script for building 'expose' and similar overviews
-- to add a new, see (tile) as reference on what is typically needed,
-- and add the new overview to the overview_sub table at the bottom.
--
-- most complexity come from the need to be able to rebuild if the
-- underlying configuration changes while we're active.
--
local last_overview;
local mh_cache = {};

local preview_listener =
function(ws, key, action, target)
end

local function build_preview_set(newt)
	local res = {};

-- just get workspace, window, ... an option would be to also track if
-- the space its on is the current workspace and animate those that are
-- differently
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

-- dim background layer
	local bg = fill_surface(wm.width, wm.height, 255, 0, 0);
	image_tracetag(bg, "lbar_bg");
	shader_setup(bg, "ui", "lbarbg");

	link_image(bg, wm.order_anchor);
	image_inherit_order(bg, true);

	blend_image(bg, gconfig_get("lbar_dim"), time, INTERP_EXPOUT);
	wm.statusbar:hide();

-- set as the current lbar layer, with a destruction handler in case a
-- different one is spawned outside our control
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

			blend_image(bg, gconfig_get("lbar_dim"), 0, INTERP_EXPOUT);
			expire_image(bg, gconfig_get("lbar_dim"));
			if (last_overview) then
				last_overview:destroy(gconfig_get("lbar_dim"));
				last_overview = nil;
			end
			PENDING_FADE = bg;
		end
	});

	cb(wm, bg, set);
end

-- take a set (list of workspaces and relevant parts of windows)
local function build_setlist(wm, anchor, set, base_w, h, spacing)
	local res = {};

	for i=1,#set do
		res[i] = {};
-- build the constrain- region, we link so that it's easy to zoom / slide
-- the one that isn't selected
		local nsrf;
		if (valid_vid(set[i].background)) then
			nsrf = null_surface(base_w, h);
			image_sharestorage(set[i].background, nsrf);
		else
			nsrf = fill_surface(base_w, h, 32, 32, 32);
		end
		link_image(nsrf, anchor, ANCHOR_UR);
		image_inherit_order(nsrf, true);
		show_image(nsrf);
		last = nsrf;
		move_image(nsrf, (spacing + base_w) * (i-1), 0);
		local mh = {
			over = function()
				shader_setup(nsrf, "ui", "regmark");
			end,
			out = function()
				image_shader(nsrf, "DEFAULT");
			end,
			own = function(ctx, vid)
				return vid == nsrf;
			end,
			click = function()
				tiler_lbar_setactive();
				wm:switch_ws(i);
			end,
			name = "overview_mh"
		};
		table.insert(mh_cache, mh);
		mouse_addlistener(mh, {"over", "out", "click"});

-- and generate some kind of descriptive reference
		local str = string.format("%s %d<%s>%s",
			gconfig_get("lbar_textstr"), i, set[i].mode,
			set[i].label and "\\n\\r" .. set[i].label or "");
		local label, _, lbl_w = render_text(str);

		if (valid_vid(label)) then
			image_inherit_order(ns, true);
			link_image(label, nsrf, ANCHOR_LC);
			order_image(label, 100);
			nudge_image(label, -0.5 * lbl_w, 0);
			show_image(label);
		end

		local sx = base_w / wm.width;
		local sy = h / wm.height;
		res[i][1] = nsrf;

-- fill with alias- surfaces
		for _,wnd in ipairs(set[i].windows) do
			local ns = null_surface(wnd.w * sx, wnd.h * sy);
			if (valid_vid(ns)) then
				link_image(ns, nsrf);
				image_inherit_order(ns, true);
				show_image(ns);
				order_image(ns, 1);
				image_sharestorage(wnd.vid, ns);
				image_mask_set(ns, MASK_UNPICKABLE);
				move_image(ns, wnd.x * sx, wnd.y * sy);
				table.insert(res[i], ns);
			end
		end

-- mouse handlers
-- over: switch and select
-- drag: attach to cursor, drop - migrate (float ? with positioning)
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

-- simple carousel
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
		base_w = base_w > wm.height * 0.5 and wm.height * 0.5 or base_w;
		ar = wm.width / wm.height;
		h = math.ceil(base_w / ar);
	end
	calc_size();

-- move in from the middle/right (unless we're rebuilding)
	local anchor;
	local build_anchor = function(time)
		anchor = null_surface(1, 1);
		link_image(anchor, bg);
		image_inherit_order(anchor, true);
		show_image(anchor);
		move_image(anchor, wm.width, 0.5 * (wm.height - h));
		show_image(anchor);
		order_image(anchor, 1);
		move_image(anchor, 0, 0.5 * (wm.height - h), time);
	end

	build_anchor(gconfig_get("transition"));
	build_setlist(wm, anchor, set, base_w, h, spacing);

	last_overview = {
		destroy = function(ctx, time)
			expire_image(anchor, time and time or 1);
			drop_mhs();
			wm:set_input_lock();
		end
	};

-- could possibly be made cheaper by detecting change, but hard
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

-- animations and background changes make this difficult, though
-- theoretically possible to extract and transfer animation states,
-- it's just too error-prone. Just go with a refresh timer.
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

local overview_sub = {
{
	name = "ws_tile",
	label = "Workspace(Tile)",
	kind = "action",
	eval = function()
		return true;
	end,
	handler = function() toggle_ws(tile); end
}
};

global_menu_register("tools",
{
	name = "ws_overview",
	label = "Overview",
	kind = "action",
	eval = function()
		return true;
	end,
	submenu = true,
	handler = overview_sub
});
