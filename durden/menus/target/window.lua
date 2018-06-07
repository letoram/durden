local swap_menu = {
	{
		name = "up",
		label = "Up",
		kind = "action",
		description = "(Tiling) Swap position with window parent",
		function()
			active_display():swap_up();
		end
	},
	{
		name = "down",
		label = "Down",
		description = "(Tiling) Swap position with first window child",
		kind = "action",
		handler = function()
			active_display():swap_down();
		end
	},
	{
		name = "left",
		label = "Left",
		description = "(Tiling) Swap position with parent sibling (to the left)",
		kind = "action",
		handler = function()
			active_display():swap_left();
		end
	},
	{
		name = "right",
		label = "Right",
		kind = "action",
		description = "(Tiling) Swap position with parent sibling (to the right)",
		handler = function()
			active_display():swap_right();
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
		active_display().selected:move(tonumber(val), 0, true);
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
		active_display().selected:move(0, tonumber(val), true);
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

local function gen_altsw(wnd)
	local res = {};
	if (wnd.alternate_ind and wnd.alternate[wnd.alternate_ind]) then
		table.insert(res, {
			name = "last",
			label = "Last",
			kind = "action",
			description = "Select the last active alternate-slot client",
			handler = function()
				wnd:swap_alternate(wnd.alternate_ind);
			end
		});
		table.insert(res, {
			name = "step_p",
			label = "Step+",
			kind = "action",
			description = "Select the next (index) alternate-slot client",
			handler = function()
				wnd:swap_alternate((wnd.alternate_ind + 1) >
					#wnd.alternate and 1 or (wnd.alternate_ind + 1));
			end
		});
		table.insert(res, {
			name = "step_n",
			label = "Step-",
			kind = "action",
			description = "Select the previous (index) alternate-slot client",
			handler = function()
				wnd:swap_alternate(wnd.alternate_ind > 1 and
					(wnd.alternate_ind - 1) or #wnd.alternate);
			end
		});
	end

	for i=1,#wnd.alternate do
		table.insert(res, {
			name = tostring(i),
			label = tostring(i),
			kind = "action",
			description = "Swap in a specific alternate-slot client",
			handler = function()
				wnd:swap_alternate(i);
			end
		});
	end
	return res;
end

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

local titlebar_table = {
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

return {
	{
		name = "tag",
		label = "Tag",
		description = "Assign a custom text-tag",
		kind = "value",
		validator = function() return true; end,
		handler = function(ctx, val)
			local wnd = active_display().selected;
			if (wnd) then
				wnd:set_prefix(string.gsub(val, "\\", "\\\\"));
			end
		end
	},
	{
		name = "swap",
		label = "Swap",
		kind = "action",
		submenu = true,
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
		name = "alternate",
		label = "Alternate-Switch",
		kind = "action",
		submenu = true,
		description = "Alternate-client slot controls",
		eval = function()
			return #active_display().selected.alternate > 0;
		end,
		handler = function()
			return gen_altsw(active_display().selected);
		end,
	},
	{
		name = "titlebar",
		label = "Titlebar",
		kind = "action",
		submenu = true,
		description = "Titlebar behavior controls",
		handler = titlebar_table
	},
	{
		name = "canvas_to_bg",
		label = "Workspace-Background",
		kind = "action",
		description = "Set windows contents as workspace background",
		handler = function()
			local wnd = active_display().selected;
			if (valid_vid(wnd.external)) then
				wnd.space:set_background(wnd.external);
				wnd.dispstat_block = true;
			else
				wnd.space:set_background(wnd.canvas);
			end
		end
	},
	{
		name = "border_toggle",
		label = "Border Toggle",
		kind = "action",
		description = "Toggle the server-side decorated window border on/off",
		handler = function()
			local wnd = active_display().selected;
			wnd:set_border(not wnd.show_border, true);
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
		set = {LBL_YES, LBL_NO},
		initial = function() return active_display().selected.delete_protect and
			LBL_YES or LBL_NO; end,
		handler = function(ctx, val)
			active_display().selected.delete_protect = val == LBL_YES;
		end
	},
	{
		name = "migrate",
		label = "Migrate",
		kind = "action",
		submenu = true,
		description = "Reassign the window to a different display",
		handler = function()
			active_display():message("MISSING: REASSING");
		end,
		eval = function()
			return gconfig_get("display_simple") == false and #(displays_alive()) > 1;
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
		name = "slice_clone",
		label = "Slice/Clone",
		kind = "value",
		description = "Slice out a window canvas region into a new window",
		set = {"Active", "Passive"},
		eval = function() return not mouse_blocked(); end,
		external_block = true,
		handler = function(ctx, val)
-- like with all suppl_region_select calls, this is race:y as the
-- selection state can go on indefinitely and things might've changed
-- due to some event (thing wnd being destroyed while select state is
-- active)
			local wnd = active_display().selected;
			local props = image_surface_resolve(wnd.canvas);

			suppl_region_select(255, 0, 255,
				function(x1, y1, x2, y2)
-- grab the current values
					local wnd = active_display().selected;
					local props = image_surface_resolve(wnd.canvas);
					local px2 = props.x + props.width;
					local py2 = props.y + props.height;

-- and actually clamp
					x1 = x1 < props.x and props.x or x1;
					y1 = y1 < props.y and props.y or y1;
					x2 = x2 > px2 and px2 or x2;
					y2 = y2 > py2 and py2 or y2;

-- safeguard against range problems
					if (x2 - x1 <= 0 or y2 - y1 <= 0) then
						return;
					end

-- create clone with proper texture coordinates, this has problems with
-- source windows that do other coordinate transforms as well and switch
-- back and forth.
					local new = null_surface(x2-x1, y2-y1);
					image_sharestorage(wnd.canvas, new);

-- calculate crop in source surface relative coordinates
					local t = (y1 - props.y) / props.height;
					local l = (x1 - props.x) / props.width;
					local d = (py2 - y2) / props.height;
					local r = (px2 - x2) / props.width;

-- bind to a window, with optional input-routing but run this as a one-off
-- timer to handle the odd case where the add-window event would trigger
-- another selection region to nest.
					local source_name = wnd.name;

					timer_add_periodic("wndspawn", 2, true, function()
						if (not wnd.add_handler) then
							return;
						end

						show_image(new);
						local cwin = active_display():add_window(new, {scalemode = "stretch"});
						if (not cwin) then
							delete_image(new);
							return;
						end

						local function recrop()
							local sprops = image_storage_properties(wnd.canvas);
							cwin.origo_ll = wnd.origo_ll;
							cwin:set_crop(
								t * sprops.height, l * sprops.width,
								d * sprops.height, r * sprops.width, false, true
							);
						end

-- add event handlers so that we update the scaling every time the source changes
						wnd:add_handler("resize", recrop);
						cwin:add_handler("destroy", function()
							if (wnd.drop_handler)
								then wnd:drop_handler("resize", recrop);
							end
						end
						);

						recrop();
						cwin:set_title("Slice");
						cwin.source_name = wnd.name;
						cwin.name = cwin.name .. "_crop";

-- add references to the external source
					if (valid_vid(wnd.external, TYPE_FRAMESERVER) and
						val == "Active") then
						cwin.external = wnd.external;
						cwin.external_prot = true;
					end
				end, true);
			end
			);
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
