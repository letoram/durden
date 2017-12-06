--
-- Advanced float handler
-- This is a "silent" plugin which extends float management
-- with controls over window placement etc.
--
-- Kept here as a means to start removing policy from tiler.lua
-- and letting more parts of the codebase be "opt out"
--

-- this hook isn't "safe", someone who calls attach is expecting
-- that the window will have a compliant state afterwards, but we
-- can hide
gconfig_register("advfloat_spawn", "auto");
gconfig_register("advfloat_hide", "statusbar");
gconfig_register("advfloat_actionreg", false);

local cactions = system_load("tools/advfloat/cactions.lua")();

local mode = gconfig_get("advfloat_spawn");
local pending, pending_vid;

local function setup_cursor_pick(wm, wnd)
	wnd:hide();
	pending = wnd;
	local w = math.ceil(wm.width * 0.15);
	local h = math.ceil(wm.height * 0.15);
	pending_vid = null_surface(w, h);
	link_image(pending_vid, mouse_state().cursor);
	image_sharestorage(wnd.canvas, pending_vid);
	blend_image(pending_vid, 1.0, 10);
	image_inherit_order(pending_vid, true);
	order_image(pending_vid, -1);
	nudge_image(pending_vid,
	mouse_state().size[1] * 0.75, mouse_state().size[2] * 0.75);
	shader_setup(pending_vid, "ui", "regmark", "active");
end

local function activate_pending()
	delete_image(pending_vid);
	pending = nil;
end

local function wnd_attach(wm, wnd)
	wnd:ws_attach(true);
	if (wnd.wm.active_space.mode ~= "float") then
		return;
	end

	if (pending) then
		activate_pending();
		if (DURDEN_REGIONSEL_TRIGGER) then
			suppl_region_stop();
		end
	end

	if (mode == "click") then
		setup_cursor_pick(wm, wnd);
		iostatem_save();
		local col = null_surface(1, 1);
		mouse_select_begin(col);
		dispatch_meta_reset();
		dispatch_symbol_lock();
		durden_input = durden_regionsel_input;

-- the region setup and accept/fail is really ugly, but reworking it
-- right now is not really an option
		DURDEN_REGIONFAIL_TRIGGER = function()
			activate_pending();
			wnd:show();
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
		DURDEN_REGIONSEL_TRIGGER = function()
			activate_pending();
			wnd:show();
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
	elseif (mode == "draw") then
		setup_cursor_pick(wm, wnd);
		DURDEN_REGIONFAIL_TRIGGER = function()
			activate_pending();
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
		suppl_region_select(200, 198, 36, function(x1, y1, x2, y2)
			activate_pending();
			local w = x2 - x1;
			local h = y2 - y1;
			if (w > 64 and h > 64) then
				wnd:resize(w, h);
			end
			wnd:move(x1, y1, false, true, true);
			wnd:show();
		end);
-- auto should really be to try and calculate the best fitting free space
	elseif (mode == "cursor" or mode == "auto") then
		local x, y = mouse_xy();
		wnd:move(x, y, false, true, true);
	else
	end
end

-- install omniscient mouse-action handlers, currently for on-over triggers
local function install_maction(wm)
	for k,v in ipairs(cactions) do
		if (v.on_over) then
			if (not v.mactions) then
				v.mactions = {};
			end
			if (not v.mactions[wm] and v.region and #v.region == 4) then
				local x1 = v.region[1] * wm.width;
				local y1 = v.region[2] * wm.height;
				local x2 = v.region[3] * wm.width;
				local y2 = v.region[4] * wm.height;
				local surf = null_surface(x2 - x1, y2 - y1);
				if (valid_vid(surf)) then
					v.mactions[wm] = {
						vid = surf,
						name = "advfloat_caction",
						own = function(ctx, vid) return vid == surf; end,
						over = function(ctx, ...) v:on_over(); end
					};
					show_image(surf);
					order_image(surf, 65534);
					move_image(surf, x1, y1);
					mouse_addlistener(v.mactions[wm], {"over"});
				end
			end
		end
	end
end

-- the custom mouse actions live in every wm, so we actually need to
-- react on both display- creation events and tiler resize events
local function wm_resize(wm)
	for k,v in ipairs(cactions) do
		if (v.mactions and v.mactions[wm]) then
			if (valid_vid(v.mactions[wm].vid)) then
				local x1 = v.region[1] * wm.width;
				local y1 = v.region[2] * wm.height;
				local x2 = v.region[3] * wm.width;
				local y2 = v.region[4] * wm.height;
				move_image(v.mactions[wm].vid, x1, y1);
				resize_image(v.mactions[wm.vid], x2 - x1, y2 - y1);
			end
		end
	end
end

-- hook displays so we can decide spawn mode between things like
-- spawn hidden, cursor-click to position, draw to spawn
display_add_listener(
function(event, name, tiler, id)
	if (event == "added" and tiler) then
		tiler.attach_hook = wnd_attach;
		table.insert(tiler.on_tiler_resize, wm_resize);
		install_maction(tiler);
	end
end
);

local drag_targets = {};
local in_drag = false;
local function creg_drag(wm, wnd, dx, dy, last)
	if (last) then
-- hide all region
		for i,v in ipairs(cactions) do
			if (valid_vid(v.temporary)) then
				local dt = gconfig_get("transition");
				blend_image(v.temporary, 0.0, dt);
				expire_image(v.temporary, dt);
			end
			v.temporary = nil;
		end
-- and run any event handler
		for i,v in ipairs(drag_targets) do
			if (v.on_drop) then
				v:on_drop(wnd);
			end
		end
		in_drag = false;
		return;
	end

-- draw possible targets and translate into display coordinates
	if (not in_drag) then
		in_drag = true;
		for i,v in ipairs(cactions) do
			v.screen_region = {
				v.region[1] * wm.width,
				v.region[2] * wm.height,
				v.region[3] * wm.width,
				v.region[4] * wm.height
			};
			local order = image_surface_resolve(wnd.anchor).order;
			if (v.visible) then
				v.temporary = color_surface(
					v.screen_region[3] - v.screen_region[1],
					v.screen_region[4] - v.screen_region[2],
				255, 255, 255);

				blend_image(v.temporary, 0.5, gconfig_get("transition"));
				order_image(v.temporary, order - 1);
				move_image(v.temporary, v.region[1], v.region[2]);
			end
		end
	end

-- check if anything enters the drag_targets
	local mx, my = mouse_xy();
	for i,v in ipairs(cactions) do
		if (valid_vid(v.temporary) and image_hit(v.temporary, mx, my)) then
			if (not table.find_i(drag_targets, v)) then
				table.insert(drag_targets, v);
				if (v.on_drag_over) then
					v:on_drag_over(wnd, v.temporary);
				end
			end
		else
			if (table.remove_match(drag_targets, v)) then
				if (v.on_drag_out) then
					v:on_drag_out(wnd, v.temporary);
				end
			end
		end
	end
end

-- simple "take constraints + list of nodes" (x, y, w, h),
-- update x, y positions and mark if it was used (fitted) or not
-- https://codeincomplete.com/posts/bin-packing/
local function simple_solver(nodes, w, h)
	table.sort(nodes, function(a, b) return a.h > b.h; end);

	local get_node;
	get_node = function(n, w, h)
		if (n.used) then
			local r = get_node(n.r, w, h);
			if (r) then
				return r;
			else
				return get_node(n.d, w, h);
			end
		elseif (w <= n.w and h <= n.h) then
			n.used = true;
			n.d = {x = n.x,     y = n.y + h, w = n.w,     h = n.h - h};
			n.r = {x = n.x + w, y = n.y,     w = n.w - w, h = h      };
			return n;
		end
	end

	local root = {x = 0, y = 0, w = w, h = h};
	for _, v in ipairs(nodes) do
		local n = get_node(root, v.w, v.h);
		if (n) then
			v.x = n.x; v.y = n.y;
		end
	end
	return nodes;
end

local in_creg = false;
local function toggle_creg(act)
	for wm in all_tilers_iter() do

-- always drop omniscient generic mouse event catchers
		for k,v in ipairs(cactions) do
			if (v.maction and v.maction[wm]) then
				mouse_droplistener(v.maction[wm]);
				if (valid_vid(v.actions[wm].vid)) then
					delete_image(v.maction[wm].vid);
				end
				v.maction[wm] = nil;
			end
		end

		table.remove_match(wm.on_wnd_drag, creg_drag);
		if (act) then
			table.insert(wm.on_wnd_drag, creg_drag);
			install_maction(wm);
		end
	end
end

local function do_hide(wnd, tgt)
	if (tgt == "statusbar-left" or tgt == "statusbar-right") then
		local old_show = wnd.show;
		local btn;

-- deal with window being destroyed while we're hidden
		local on_destroy = function()
			if (btn) then
				btn:destroy();
			end
		end;

		local wm = wnd.wm;
		local pad = gconfig_get("sbar_tpad") * wm.scalef;
		local str = string.sub(tgt, 11);

-- actual button:
-- click: migrate+reveal
-- rclick: not-yet: select+popup
		btn = wm.statusbar:add_button(str, "sbar_item_bg",
			"sbar_item", wnd:get_name(), pad, wm.font_resfn, nil, nil,
			{
				click = function()
					local props = image_surface_resolve(btn.bg);
					wnd.show = old_show;
					wnd:drop_handler("destroy", on_destroy);
					btn:destroy();
					wnd.wm:switch_ws(wnd.space);
					wnd:select();
					if (#wm.on_wnd_hide > 0) then
						for k,v in ipairs(wm.on_wnd_hide) do
							v(wm, wnd, props.x, props.y, props.width, props.height, false);
						end
					else
						wnd:show();
					end
				end
			}
		);

-- out of VIDs
		if (not btn) then
			warning("hide-to-button: creation failed");
			return;
		end

-- safeguard against show being called from somewhere else
		wnd.show = function(wnd)
			if (btn.bg) then
				btn:click();
			else
				wnd.show = old_show;
				old_show(wnd);
			end
		end;

-- safeguard against window being destroyed while hidden
		wnd:add_handler("destroy", on_destroy);
		wnd:deselect();

-- event handler registered? (flair tool)
		if (#wm.on_wnd_hide > 0) then
			local props = image_surface_resolve(btn.bg);
			for k,v in ipairs(wm.on_wnd_hide) do
				v(wm, wnd, props.x, props.y, props.width, props.height, true);
			end
		else
			wnd:hide();
		end
	else
		warning("unknown hide target: " .. tgt);
	end
end

toggle_creg(gconfig_get("advfloat_actionreg"));

local action_submenu = {
{
	kind = "value",
	name = "active",
	label = "Active",
	description = "Chose if mouse-action regions are active or not",
	initial = function()
		return gconfig_get("advfloat_actionreg") and LBL_YES or LBL_NO;
	end,
	set = {LBL_YES, LBL_NO},
	handler = function(ctx, val)
		toggle_creg(val == LBL_YES);
		gconfig_set("advfloat_actionreg", val == LBL_YES);
	end
}
};

local function run_layouter(method)
	local wm = active_display();
	local space = wm.spaces[wm.space_ind];
	local lst = {};

-- special cases, windows with an assigned 'toplevel' (wayland..)
	for _,wnd in ipairs(space:linearize()) do
		table.insert(lst, {src = wnd,
			x = wnd.x, y = wnd.y, w = wnd.width, h = wnd.height});
	end
	if (#lst == 0) then
		return;
	end
	lst = method(lst, wm.effective_width, wm.effective_height);
	local props = image_surface_resolve(wm.anchor);
	for _, v in ipairs(lst) do
		v.src:move(v.x + props.x, v.y + props.y, false, true);
	end
end

local layouters_menu = {
{
	kind = "action",
	name = "simple",
	label = "Simple",
	description = "Sort by height and recursive binary fill",
	handler = function()
		run_layouter(simple_solver);
	end
}
};

local workspace_menu = {
{
	kind = "action",
	submenu = true,
	name = "autolayout",
	label = "Layouter",
	description = "Apply an automatic layouting technique",
	handler = layouters_menu
}
};

-- all_spaces_iter

shared_menu_register("window",
{
	kind = "action",
	name = "hide",
	label = "Hide",
	description = "Hide or Minimize the window to a preset location",
	kind = "action",
	eval = function()
		return
			gconfig_get("advfloat_hide") ~= "disabled" and
				active_display().selected.space.mode == "float";
	end,
	handler = function()
		local wnd = active_display().selected;
		if (not wnd.hide) then
			return;
		end
		local tgt = gconfig_get("advfloat_hide");
		do_hide(wnd, tgt);
	end
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
	name = "action_regions",
	kind = "action",
	submenu = true,
	description = "Manage the mouse-action regions",
	label = "Action Region",
	handler = action_submenu
});

global_menu_register("settings/wspaces/float",
{
	kind = "value",
	name = "hide_target",
	description = "Chose where the window hide option will compress the window",
	initial = gconfig_get("advfloat_hide"),
	label = "Hide Target",
	set = {"disabled", "statusbar-left", "statusbar-right"},
	handler = function(ctx, val)
		gconfig_set("advfloat_hide", val);
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
