local function swallow_menu(wnd)
	return {
		{
		label = "Swap",
		name = "first",
		kind = "action",
		description = "Swap in the first swallowed / hidden window",
		handler = function()
			local wnd = active_display().selected
			local swallow = wnd.swallow_window

-- user lingered on the menu and the window died in the background
			if not swallow then
				return
			end

			swallow.swallow_window = wnd
			wnd.swallow_master = swallow
			swallow.swallow_master = nil
			wnd:hide()
			swallow:show()
			swallow:select()
			wnd.space:resize()
		end
		}
	}
end

local swap_menu = {
	{
		name = "up",
		label = "Up",
		kind = "action",
		description = "Swap position with window parent",
		handler = function()
			active_display():swap_up();
		end
	},
	{
		name = "down",
		label = "Down",
		description = "Swap position with first window child",
		kind = "action",
		handler = function()
			active_display():swap_down();
		end
	},
	{
		name = "left",
		label = "Left",
		description = "Swap position with parent sibling (to the left)",
		kind = "action",
		handler = function()
			active_display():swap_left();
		end
	},
	{
		name = "right",
		label = "Right",
		kind = "action",
		description = "Swap position with parent sibling (to the right)",
		handler = function()
			active_display():swap_right();
		end
	},
	{
		name = "join_left",
		label = "Join Left",
		kind = "value",
		description = "Join n windows to the left as children",
		validator = function(val)
			return val and tonumber(val) ~= nil;
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			wnd:merge(true, tonumber(val));
		end
	},
	{
		name = "join_right",
		label = "Join Right",
		kind = "value",
		description = "Join n windows to the right as children",
		validator = function(val)
			return val and tonumber(val) ~= nil;
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			wnd:merge(false, tonumber(val));
		end
	},
	{
		name = "merge_collapse",
		label = "Merge/Collapse",
		description = "(Tiling) split or absorb same-level nodes and children slots",
		kind = "action",
		handler = function()
			local wnd = active_display().selected;
			if (#wnd.children > 0) then
				wnd:collapse();
			else
				wnd:merge();
			end
		end
	},
	{
		name = "swallow",
		label = "Swallow",
		kind = "action",
		submenu = true,
		eval = function()
			return active_display().selected.swallow_window ~= nil
		end,
		description = "Switch window with one in the swallowed set",
		handler = function(wnd)
			return swallow_menu(wnd)
		end
	}
};

local select_menu = {
	{
		name = "up",
		label = "Up",
		kind = "action",
		description = "Select the tiling-parent or (float) closest in negative Y",
		handler = function()
			active_display().selected:prev(1);
		end
	},
	{
		name = "down",
		label = "Down",
		description = "Select the first tiling-child or (float) closest in positive Y",
		kind = "action",
		handler = function()
			active_display().selected:next(1);
		end
	},
	{
		name = "left",
		label = "Left",
		kind = "action",
		description = "Select the previous sibling or (float) closest in negative X",
		handler = function()
			active_display().selected:prev();
		end
	},
	{
		name = "right",
		label = "Right",
		kind = "action",
		description = "Select the next sibling or (float) closest in positive X",
		handler = function()
			active_display().selected:next();
		end
	}
};

local moverz_menu = {
{
	name = "resize_h",
	label = "Resize(H)",
	kind = "value",
	description = "Change the relative width with a factor of (-0.5..x..0.5)",
	validator = gen_valid_num(-0.5, 0.5),
	hint = "(step: -0.5 .. 0.5)",
	handler = function(ctx, val)
		local num = tonumber(val);
		local wnd = active_display().selected;
		wnd:grow(num, 0);
	end
},
{
	name = "resize_v",
	label = "Resize(V)",
	kind = "value",
	validator = gen_valid_num(-0.5, 0.5),
	description = "Change the relative height with a factor of (-0.5..x..0.5)",
	hint = "(-0.5 .. 0.5)",
	handler = function(ctx, val)
		local num = tonumber(val);
		local wnd = active_display().selected;
		wnd:grow(0, num);
	end
},
{
	name = "fullscreen",
	label = "Toggle Fullscreen",
	kind = "action",
	description = "Set workspace as fullscreen, with this window as its main contents",
	handler = function()
		local wnd = active_display().selected;
		if (not wnd.space) then
			return;
		end

		local mode = wnd.space.last_mode and wnd.space.last_mode or "tile";
		if (wnd.fullscreen) then
			wnd.space[mode](wnd.space);
		else
			wnd.space:fullscreen();
		end
	end
},
{
	name = "maximize",
	label = "Toggle Maximize",
	kind = "action",
	description = "(Float) size the window based on workspace client area size",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	handler = function()
		active_display().selected:toggle_maximize();
	end
},
{
	name = "rel_x",
	label = "Move(H)",
	description = "(Float) move the window left or right",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	kind = "value",
	validator = function(val) return tonumber(val) ~= nil; end,
	handler = function(ctx, val)
		active_display().selected:move(tonumber(val), 0, true, false, true);
	end
},
{
	name = "rel_y",
	label = "Move(V)",
	description = "(Float) move the window up or down",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	kind = "value",
	validator = function(val) return tonumber(val) ~= nil; end,
	handler = function(ctx, val)
		active_display().selected:move(0, tonumber(val), true, false, true);
	end
},
{
	name = "rel_fx",
	label = "Move(fH)",
	description = "(Float) Move the window in the x axis, relative to screen size",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	kind = "value",
	hint = "(-0.2..0.2)",
	validator = gen_valid_num(-0.2,0.2),
	handler = function(ctx, val)
		local disp = active_display();
		disp.selected:move(disp.width * tonumber(val), 0, true, false, true);
	end
},
{
	name = "rel_fy",
	label = "Move(fV)",
	description = "(Float) Move the window in the y axis, relative to screen size",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	kind = "value",
	validator = gen_valid_num(-0.2,0.2),
	hint = "(-0.2..0.2)",
	handler = function(ctx, val)
		local disp = active_display();
		disp.selected:move(0, disp.width * tonumber(val), true, false, true);
	end
},
{
	name = "abs_x",
	label = "Set(X)",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	description = "(Float) move the window to a specific x coordinate",
	kind = "value",
	initial = function(val)
		return tostring(image_surface_properties(
			active_display().selected.anchor).x);
	end,
	validator = function(val) return tonumber(val) ~= nil; end,
	handler = function(ctx, val)
		local wnd = active_display().selected;
		wnd:move(tonumber(val), wnd.y, false, true);
	end
},
{
	name = "abs_y",
	label = "Set(Y)",
	description = "(Float) move the window to a specific y coordinate",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	kind = "value",
	initial = function(val)
		return tostring(image_surface_properties(
			active_display().selected.anchor).y);
	end,
	validator = function(val) return tonumber(val) ~= nil; end,
	handler = function(ctx, val)
		local wnd = active_display().selected;
		wnd:move(wnd.x, tonumber(val), false, true);
	end
},
{
	name = "to_cursor",
	label = "To Cursor",
	description = "(Float) move the window to the current cursor position",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	kind = "action",
	handler = function(ctx, val)
		local x, y = mouse_xy();
		local wnd = active_display().selected;
		wnd:move(x, y, false, true);
	end
},
{
	name = "set_width",
	label = "Set(W)",
	kind = "value",
	description = "(Float) set the window to x pixels wide",
	eval = function(ctx, val)
		return active_display().selected.space.mode == "float";
	end,
	validator = gen_valid_num(32, VRESW),
	handler = function(ctx, val)
		local wnd = active_display().selected;
		wnd:resize(tonumber(val), wnd.height);
	end
},
{
	name = "set_height",
	label = "Set(H)",
	kind = "value",
	description = "(Float) set the window to y pixels high",
	eval = function(ctx, val)
		return active_display().selected.space.mode == "float";
	end,
	validator = gen_valid_num(32, VRESH),
	handler = function(ctx, val)
		local wnd = active_display().selected;
		wnd:resize(wnd.width, tonumber(val));
	end
}
};

local function setup_slice_wnd(cwin, wnd, dyn, w, h)
	if not dyn then
		return;
	end

	local lw = w / wnd.width;
	local lh = h / wnd.height;

-- This is in conflict with decoration cropping and similar viewport
-- properties, something more uniform should probably be put together.
-- If there are overlays present, we should composite those
	local mh = function(wnd, rx, ry)
		cwin.last_mh_x = rx;
		cwin.last_mh_y = ry;
		local props = image_surface_resolve(wnd.canvas);
		local lx = (rx - props.x) / props.width;
		local ly = (ry - props.y) / props.height;

		local x1 = math.clamp(lx - lw * 0.5, 0);
		local y1 = math.clamp(ly - lh * 0.5, 0);
		local x2 = math.clamp(x1 + lw, 0, 1);
		local y2 = math.clamp(y1 + lh, 0, 1);
		x1 = math.clamp(x2 - lw, 0);
		y1 = math.clamp(y2 - lh, 0);

		image_set_txcos(cwin.canvas, {x1, y1, x2, y1, x2, y2, x1, y2});
	end


-- add meta+mwheel zoom, could also add tick-pan + zoom controls in cwin
	local cbh = function(wnd, ind, pressed)
		if not pressed or not dispatch_meta() then
			return;
		end

		local sign = 1;
		if ind == 4 then
			sign = -1;
		elseif ind == 5 then
		else
			return;
		end
		lw = math.clamp(lw + 0.05 * sign, 0.01, 1.0);
		lh = math.clamp(lh + 0.05 * sign, 0.01, 1.0);
		mh(wnd, cwin.last_mh_x, cwin.last_mh_y);
	end

	wnd:add_handler("mouse_motion", mh);
	wnd:add_handler("mouse_button", cbh);
	wnd:add_handler("destroy", function()
		if cwin.destroy then
			cwin:destroy();
		end
	end);

	cwin:add_handler("destroy", function()
		if wnd.drop_handler then
			wnd:drop_handler("mouse_motion", mh);
			wnd:add_handler("mouse_button", cbh);
		end
	end);

	mh(wnd, wnd.x, wnd.y);
end

-- remove is a bit complicated due to the presence of groups and
-- the _default group and that we need to remove both from the active
-- group (if that hits the chosen item) and from the current set
local function remove_button(wnd, dir, lbl)
	local res = {};

	for group,list in pairs(wnd.titlebar.groups) do
		for i,v in ipairs(list) do
			if (v.align == dir) then
				table.insert(res, {
					name = tostring(i),
					label = group .. "_" .. tostring(i),
					description = string.format("Button Label: %s", v.lbl),
					kind = "action",
					handler = function()
						table.remove(list, i);
						wnd.titlebar.group = "_inval";
						wnd.titlebar:switch_group(group);
					end
				});
			end
		end

	end
	return res;
end

local function button_query_path(wnd, vsym, dir, group)
	local ok, vsym = suppl_valid_vsymbol(vsym);
	if (not ok) then
		return;
	end

	dispatch_symbol_bind(function(path)
		local wm = active_display();
		local new_wnd = wm.selected;
		if (not path) then
			return;
		end
-- can actually change during interaction time so verify
		if (wnd ~= new_wnd) then
			return;
		end
		wnd.titlebar:add_button(dir, "titlebar_iconbg",
			"titlebar_icon", vsym, gconfig_get("sbar_tpad") * wm.scalef,
			wm.font_resfn, nil, nil, suppl_button_default_mh(wnd, path),
			{group = group});
	end);
end

local function titlebar_buttons(dir, lbl)
	local wnd = active_display().selected;
	local hintstr = "(0x:byte seq | icon:ref | string)";
	return
	{
		{
		label = "Remove",
		name = "remove",
		kind = "action",
		submenu = true,
		description = "Remove a button",
		eval = function()
			for k,v in pairs(wnd.titlebar.groups) do
				for i,j in ipairs(v) do
					if (j.align == dir) then
						return true;
					end
				end
			end
		end,
		handler = function()
			return remove_button(wnd, dir, lbl);
		end
		},
		{
		label = "Add",
		name = "add",
		kind = "value",
		hint = hintstr,
		widget = "special:icon",
		validator = function(val)
			return suppl_valid_vsymbol(val);
		end,
		description = "Add a new button used in all layout modes",
		handler = function(ctx, val)
			button_query_path(active_display().selected, val, dir);
		end
		},
		{
		label = "Add (Tile)",
		name = "add_tile",
		kind = "value",
		widget = "special:icon",
		hint = hintstr,
		description = "Add a new button for tiled layout modes",
		validator = function(val)
			return suppl_valid_vsymbol(val);
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			button_query_path(active_display().selected, val, dir, "tile");
		end
		},
		{
		label = "Add (Float)",
		name = "add_float",
		kind = "value",
		widget = "special:icon",
		hint = hintstr,
		validator = function(val)
			return suppl_valid_vsymbol(val);
		end,
		description = "Add a new button for floating layout mode",
		handler = function(ctx, val)
			button_query_path(active_display().selected, val, dir, "float");
		end
		}
	}
end

local titlebar_buttons = {
	{
		name = "left",
		kind = "action",
		label = "Left",
		description = "Modify buttons in the left group",
		submenu = true,
		handler = function()
			return titlebar_buttons("left", "Left");
		end
	},
	{
		name = "right",
		kind = "action",
		submenu = true,
		label = "Right",
		description = "Modify buttons in the right group",
		submenu = true,
		handler = function()
			return titlebar_buttons("right", "Right");
		end
	}
};

local function gen_wsmove(wnd)
	local res = {};
	local adsp = active_display().spaces;

	for i=1,10 do
		table.insert(res, {
			name = "reassign_" .. tostring(i),
			label = (adsp[i] and adsp[i].label) and adsp[i].label or tostring(i),
			description = "Reassign the window to workspace " .. tostring(i),
			kind = "action",
			handler = function()
				wnd:assign_ws(i);
			end
		});
	end
	table.insert(res, {
		name = "reassign_new",
		label = "New",
		kind = "action",
		description = "Reassign the window to a new workspace",
		eval = function()
			for i=1,10 do
				if not active_display().spaces[i] then
					return true;
				end
			end
		end,
		handler = function()
			for i=1,10 do
				if not active_display().spaces[i] then
					wnd:assign_ws(i);
					return;
				end
			end
		end
	});
	return res;
end

local function setup_surface(wnd, vid, px)
	local st = px / image_storage_properties(wnd.canvas).height;
	local txcos = image_get_txcos(wnd.canvas);
	txcos[2] = txcos[2] - st;
	txcos[6] = txcos[2] + st;
	txcos[4] = txcos[4] - st;
	txcos[8] = txcos[4] + st;
	image_set_txcos(vid, txcos);
	move_image(vid, 0, -px);
end

local function send_mouse_xy(wnd, x, y, rx, ry)
	local iotbl = {
		kind = "analog",
		mouse = true,
		devid = 0,
		subid = 0,
		samples = {x, rx}
	};
	local iotbl2 = {
		kind = "analog",
		mouse = true,
		devid = 0,
		subid = 1,
		samples = {y, ry}
	};

	if (wnd.in_drag_move or wnd.in_drag_rz or
		not valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		return;
	end
	target_input(wnd.external, iotbl);
	target_input(wnd.external, iotbl2);
end

local function set_impostor(wnd, px)
	local tbar_reg = null_surface(wnd.effective_w, px);
	wnd.titlebar.last_impostor = px;

	if (px == -1) then
-- distance-field / raymarch horiz- vert in order to find an edge even if the source has
-- a gradient, and if no such gradient is found, go with the possible symmetry in pad-
-- vs contents.
		px = 40;
	end

	show_image(tbar_reg);
	image_sharestorage(wnd.canvas, tbar_reg);
	setup_surface(wnd, tbar_reg, px);

	wnd.titlebar:set_impostor(tbar_reg,
		function(bar, w, h, dt, interp)
			resize_image(tbar_reg, w, px, dt, interp);
			setup_surface(wnd, tbar_reg, px);
		end,

-- just forward to the normal handlers, but remove the crop values temporarily
-- so that the remapping that is normally done to account for the impostor is removed
		{
		button =
			function(ctx, vid, ind, pressed, x, y)
			if (wnd.handlers and wnd.handlers.mouse.canvas.button) then
				local cv = wnd.crop_values;
				wnd.crop_values = nil;
				wnd.handlers.mouse.canvas:button(vid, ind, pressed, x, y);
				wnd.crop_values = cv;
			end
		end,
		motion =
		function(ctx, vid, x, y, rx, ry)
			if (wnd.handlers and wnd.handlers.mouse.canvas.motion) then
				local aprop = image_surface_resolve(vid);
				send_mouse_xy(wnd,
					x - aprop.x + wnd.crop_values[2],
					y - aprop.y + wnd.crop_values[1] - px, rx, ry
				);
			end
		end
		}
	);
end

local border_table = {
{
	name = "color",
	label = "Color",
	description = "Change the titlebar color",
},
{
	name = "enabled",
	label = "Enabled",
	kind = "value",
	description = "Toggle border rendering on / off (still used in layout)",
	set = {LBL_YES, LBL_NO, LBL_FLIP},
	handler = function(ctx, val)
		local wnd = active_display().selected;
		if (val == LBL_FLIP) then
			wnd:set_border(not wnd.show_border, true, true);
		elseif (val == LBL_YES) then
			wnd:set_border(true, true);
		else
			wnd:set_border(false, true);
		end
	end
}
};

-- these have a common factroy as we really want to provide a more advanced
-- picking widget later that can take both various common swatches and cubes,
-- but also grab from clients and quantized versions of clients
suppl_append_color_menu(gconfig_get("border_color"), border_table[1],
function(fmt, r, g, b)
	image_color(active_display().selected.border, r, g, b);
end
);

local titlebar_table = {
	{
		name = "color",
		label = "Color",
		description = "Change the titlebar color",
	},
	{
		name = "swap",
		label = "Swap",
		kind = "action",
		description = "Switch between server side controlled titlebar and impostor",
		handler = function()
			local wnd = active_display().selected;
			wnd.titlebar:swap_impostor();
		end
	},
	{
		name = "toggle",
		label = "Toggle",
		kind = "action",
		description = "Toggle the server-side decorated titlebar on/off",
		handler = function()
			local wnd = active_display().selected;
			wnd:set_titlebar(not wnd.show_titlebar, true);
		end
	},
	{
		name = "buttons",
		label = "Buttons",
		kind = "action",
		description = "Alter titlebar button bindings",
		submenu = true,
		handler = titlebar_buttons
	},
	{
		name = "text",
		label = "Text",
		kind = "value",
		description = "Change the format string used to populate the titlebar text",
		initial = function()
			local wnd = active_display().selected;
			return
				wnd.titlebar_ptn and wnd.titlebar_ptn or gconfig_get("titlebar_ptn");
		end,
		hint = "%p (tag) %t (title.) %i (ident.)",
		validator = function(str)
			return string.len(str) > 0 and not string.find(str, "%%", 1, true);
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			wnd.titlebar_ptn = val;
			wnd:set_title();
		end
	},
	{
		name = "impostor",
		label = "Impostor",
		hint = "(-1 (auto), 0 (disable), >0 (set px)",
		kind = "value",
		description = "Define an impostor region that will be mapped into the titlebar",
		validator = function(val)
			return (val and string.len(val) > 0 and tonumber(val) and tonumber(val) > -1);
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			local num = tonumber(val);

-- reset impostor state before adding new
			if (wnd.titlebar.last_impostor) then
				wnd:append_crop(-wnd.titlebar.last_impostor, 0, 0, 0);
				wnd.titlebar:destroy_impostor();
				wnd.titlebar.last_impostor = nil;
				if (num == 0) then
					return;
				end
			end

			wnd:append_crop(num, 0, 0, 0);
			set_impostor(wnd, num);
		end
	}
};
-- these have a common factroy as we really want to provide a more advanced
-- picking widget later that can take both various common swatches and cubes,
-- but also grab from clients and quantized versions of clients
suppl_append_color_menu(gconfig_get("titlebar_color"), titlebar_table[1],
function(fmt, r, g, b)
	image_color(active_display().selected.titlebar.anchor, r, g, b);
end
);

return {
	{
		name = "tag",
		label = "Tag",
		description = "Assign a custom text-tag",
		kind = "value",
		validator = function(val)
			return true;
		end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (wnd) then
				wnd:set_prefix(string.gsub(val, "\\", "\\\\"));
			end
		end
	},
	{
		name = "group_tag",
		label = "Group Tag",
		description = "Assign the window to an action group",
		kind = "value",
		initial = function()
			local wnd = active_display().selected;
			return wnd.group_tag and wnd.group_tag or "(none)";
		end,
		hint = "(a-Z 0-9)",
		validator = suppl_valid_name,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			wnd:set_tag(val);
		end
	},
	{
		name = "swap",
		label = "Swap",
		kind = "action",
		submenu = true,
		eval = function() return active_display().selected.space.mode == "tile"; end,
		description = "Swap controls for swapping places with another window",
		handler = swap_menu
	},
	{
		name = "select",
		label = "Select",
		kind = "action",
		submenu = true,
		description = "Window-relative selection change controls",
		handler = select_menu
	},
	{
		name = "reassign",
		label = "Reassign",
		kind = "action",
		submenu = true,
		description = "Reassign to another workspace",
		eval = function() return #gen_wsmove(active_display().selected) > 0; end,
		handler = function()
			return gen_wsmove(active_display().selected);
		end
	},
	{
		name = "titlebar",
		label = "Titlebar",
		kind = "action",
		submenu = true,
		description = "Titlebar look and feel",
		handler = titlebar_table
	},
	{
		name = "border",
		label = "Border",
		kind = "action",
		submenu = true,
		description = "Border look and feel",
		handler = border_table
	},
	{
		name = "hide",
		label = "Hide",
		description = "Detach window from the window visibility/layouting hierarchy",
		kind = "action",
		eval = function()
			return not active_display().selected.hidden;
		end,
		handler = function()
			local wnd = active_display().selected;
			wnd:hide();
			wnd.space:resize();
		end
	},
	{
		name = "show",
		label = "Show",
		description = "Show a previously hidden window",
		kind = "action",
		eval = function()
			return active_display().selected.hidden;
		end,
		handler = function()
			local wnd = active_display().selected;
			wnd:show();
			wnd.space:resize();
		end
	},
	{
		name = "target_opacity",
		label = "Opacity",
		kind = "value",
		hint = "(0..1)",
		description = "Change both the canvas and decoration opacity",
		validator = gen_valid_num(0, 1),
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (wnd) then
				local opa = tonumber(val);
				blend_image(wnd.border, opa);
				blend_image(wnd.canvas, opa);
			end
		end
	},
	{
		name = "delete_protect",
		label = "Delete Protect",
		kind = "value",
		description = "Prevent the window from being accidentally deleted",
		set = {LBL_YES, LBL_NO, LBL_FLIP},
		initial = function() return active_display().selected.delete_protect and
			LBL_YES or LBL_NO; end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (val == LBL_FLIP) then
				val = not wnd.delete_protect;
			else
				val = val == LBL_YES;
			end
			wnd.delete_protect = val;
		end
	},
	{
		name = "migrate",
		label = "Migrate",
		kind = "action",
		submenu = true,
		description = "Reassign the window to a different display",
		handler = function()
			local res = {};
			local wnd = active_display().selected;
			local cur = active_display(false, true).name;
			for d in all_displays_iter() do
				if (cur ~= d.name) then
					table.insert(res, {
						name = "migrate_" .. string.hexenc(d.name),
						label = d.name,
						kind = "action",
						handler = function()
							display_migrate_wnd(wnd, d.name);
						end
					});
				end
			end
			return res;
		end,
		eval = function()
			return #(displays_alive()) > 1;
		end
	},
	{
		name = "destroy",
		label = "Destroy",
		kind = "action",
		description = "Delete the selected window",
		handler = function()
			active_display().selected:destroy();
		end
	},
	{
		name = "move_resize",
		label = "Move/Resize",
		kind = "action",
		description = "Controls for moving or resizing the window",
		handler = moverz_menu,
		submenu = true
	},
	{
		name = "schemes",
		label = "Schemes",
		kind = "action",
		submenu = true,
		description = "Apply a window- local UI scheme",
		eval = function()	return
			#(ui_scheme_menu("window", active_display().selected)) > 0;
		end,
		handler = function()
			return ui_scheme_menu("window", active_display().selected);
		end
	},
	{
		name = "cursortag",
		label = "Cursor Tag",
		description = "Set the current window as the 'drag' mouse state",
		kind = "action",
		interactive = true,
		external_block = true,
		handler = function()
			local wnd = active_display().selected;

-- this approach doesn't work well when dragging across mixed-DPI but the
-- changes for that need to be done on the mouse.lua side
			local icon = null_surface(32, 32);
			if (not valid_vid(icon)) then
				return;
			end

-- now we have something representing the state, forward all this to the
-- mouse support scripts and have a callback that queries the target wnd
-- if the source is accepted or not.
--
-- For external clients (and wayland in particular) make sure that there
-- is a handler in extevh/atypes that periodically updates the tag-icon.
--
-- This is quite complicated as it involves both window state,
-- client state, active tiler, input dispatch etc.
--
-- Basic flow:
--  mouse.lua(set_tag) ->
--   tiler(canvas_mh:motion->mouse_update_state) -> callback below -> fin.
--   tiler(canvas_mh:release) -> callback below (accept or !accept)
--   dispatch(escape) -> tiler:cancellation -> mouse:drop -> callback below
--
-- The return of the callback for the first case determines the visible
-- "current target would accept the drop"
--
			image_sharestorage(wnd.canvas, icon);
			show_image(icon);
			shader_setup(icon, "ui", "regmark");

			mouse_cursortag(wnd, "window",
				function(srcwnd, accept, dstwnd)
					if (not dstwnd or not srcwnd or
						accept == false or not dstwnd.receive_cursortag) then
						return;
					end
					return dstwnd:receive_cursortag(accept == nil, srcwnd);
				end, icon
			)
		end,
	},
	{
		name = "slice",
		label = "Slice",
		kind = "value",
		description = "Slice out a window canvas region into a new window",
		set = {"Active", "Passive", "Active-Dynamic", "Passive-Dynamic"},
		eval = function() return not mouse_blocked(); end,
		external_block = true,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			local dyn = val == "Active-Dynamic" or val == "Passive-Dynamic"
			local act = val == "Active" or val == "Active-Dynamic"

			suppl_wnd_slice(active_display().selected,
			function(cwin, t, l, d, r, w, h)
-- we got a window, link the external reference and make sure destroying
-- this window won't break things
				if (valid_vid(wnd.external, TYPE_FRAMESERVER) and act) then
					cwin.external = wnd.external;
					cwin.external_prot = true;
				end

-- if dynamic, we hook up a mouse-motion handler on the canvas and slide
-- the crop region accordingly so that it is centered around the mouse
-- cursor
				setup_slice_wnd(cwin, wnd, dyn, w, h);
			end);
		end
	},
	{
		name = "crop",
		label = "Crop",
		kind = "value",
		initial = function()
			local wnd = active_display().selected;
			if (wnd.crop_values) then
				return string.format("%.0f %.0f %.0f %.0f", unpack(wnd.crop_values));
			end
			return "0 0 0 0";
		end,
		hint = "(top left down right px)",
		description = "Crop a certain number of pixels from the canvas region",
		kind = "value",
		validator = suppl_valid_typestr("ffff", 0, 10000, 0),
-- setting crop rebuild impostor if used
		handler = function(ctx, val)
			local wnd = active_display().selected;
			local cropv = suppl_unpack_typestr("ffff", val, 0, 10000, 0);
			wnd:set_crop(cropv[1], cropv[2], cropv[3], cropv[4]);
			wnd.titlebar:destroy_impostor();
			local impv = wnd.titlebar.last_impostor;
			if (impv) then
				wnd:append_crop(impv, 0, 0, 0);
				set_impostor(wnd, impv);
			end
		end
	},
};
