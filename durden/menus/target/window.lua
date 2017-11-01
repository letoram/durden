local swap_menu = {
	{
		name = "up",
		label = "Up",
		kind = "action",
		handler = grab_global_function("swap_up")
	},
	{
		name = "merge_collapse",
		label = "Merge/Collapse",
		kind = "action",
		handler = grab_shared_function("mergecollapse")
	},
	{
		name = "down",
		label = "Down",
		kind = "action",
		handler = grab_global_function("swap_down")
	},
	{
		name = "left",
		label = "Left",
		kind = "action",
		handler = grab_global_function("swap_left")
	},
	{
		name = "right",
		label = "Right",
		kind = "action",
		handler = grab_global_function("swap_right")
	},
};

local select_menu = {
	{
		name = "up",
		label = "Up",
		kind = "action",
		handler = grab_shared_function("step_up")
	},
	{
		name = "down",
		label = "Down",
		kind = "action",
		handler = grab_shared_function("step_down")
	},
	{
		name = "left",
		label = "Left",
		kind = "action",
		handler = grab_shared_function("step_left")
	},
	{
		name = "right",
		label = "Right",
		kind = "action",
		handler = grab_shared_function("step_right")
	},
};

local moverz_menu = {
{
	name = "grow_shrink_h",
	label = "Resize(H)",
	kind = "value",
	validator = gen_valid_num(-0.5, 0.5),
	hint = "(step: -0.5 .. 0.5)",
	handler = function(ctx, val)
		local num = tonumber(val);
		local wnd = active_display().selected;
		wnd:grow(val, 0);
	end
},
{
	name = "grow_shrink_v",
	label = "Resize(V)",
	kind = "value",
	validator = gen_valid_num(-0.5, 0.5),
	hint = "(-0.5 .. 0.5)",
	handler = function(ctx, val)
		local num = tonumber(val);
		local wnd = active_display().selected;
		wnd:grow(0, val);
	end
},
{
	name = "fullscreen",
	label = "Toggle Fullscreen",
	kind = "action",
	handler = grab_shared_function("fullscreen")
},
{
	name = "maxtog",
	label = "Toggle Maximize",
	kind = "action",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	handler = function()
		active_display().selected:toggle_maximize();
	end
},
{
	name = "move_h",
	label = "Move(H)",
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
	name = "move_v",
	label = "Move(V)",
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
	name = "x",
	label = "Set(X)",
	eval = function()
		return active_display().selected.space.mode == "float";
	end,
	kind = "value",
	initial = function(val)
		return tostring(image_surface_properties(
			active_display().selected.anchor).x);
	end,
	validator = function(val) return tonumber(val) ~= nil; end,
	handler = function(ctx, val)
		local wnd = active_display().selected;
		wnd:move(tonumber(val),
			image_surface_properties(wnd.anchor).y, false, true);
	end
},
{
	name = "y",
	label = "Set(Y)",
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
		wnd:move(image_surface_properties(wnd.anchor).x,
			tonumber(val), false, true);
	end
},
{
	name = "set_width",
	label = "Set(W)",
	kind = "value",
	eval = function(ctx, val)
		return active_display().selected.space.mode == "float";
	end,
	validator = gen_valid_num(32, VRESW),
	handler = function(ctx, val)
		local wnd = active_display().selected;
		print("set", tonumber(val), wnd.width, wnd.height);
		wnd:resize(tonumber(val), wnd.height);
	end
},
{
	name = "set_height",
	label = "Set(H)",
	kind = "value",
	eval = function(ctx, val)
		return active_display().selected.space.mode == "float";
	end,
	validator = gen_valid_num(32, VRESH),
	handler = function(ctx, val)
		local wnd = active_display().selected;
		wnd:resize(wnd.width, tonumber(val));
	end
},
{
	name = "tiling_float",
	label = "Float(Tile)",
	kind = "value",
	set = {LBL_YES, LBL_NO},
	eval = function()
-- missing: window draw order when a window is float disabled
-- missing: enable controls that are blocked for non-workspace-float
		return false;
	end,
	initial = function(ctx, val)
		return active_display().selected.tile_ignore and LBL_YES or LBL_NO;
	end,
	handler = function(ctx, val)
		local wnd = active_display().selected;
		wnd.tile_ignore = val == LBL_YES;
		wnd:resize(wnd.width, wnd.height);
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
			handler = function()
				wnd:swap_alternate(wnd.alternate_ind);
			end
		});
		table.insert(res, {
			name = "step_p",
			label = "Step+",
			kind = "action",
			handler = function()
				wnd:swap_alternate((wnd.alternate_ind + 1) >
					#wnd.alternate and 1 or (wnd.alternate_ind + 1));
			end
		});
		table.insert(res, {
			name = "step_n",
			label = "Step-",
			kind = "action",
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
			name = "move_space_" .. tostring(k),
			label = (adsp[i] and adsp[i].label) and adsp[i].label or tostring(i);
			kind = "action",
			handler = function()
				wnd:assign_ws(i);
			end
		});
	end
	return res;
end

return {
	{
		name = "tag",
		label = "Tag",
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
		handler = swap_menu
	},
	{
		name = "select",
		label = "Select",
		kind = "action",
		submenu = true,
		handler = select_menu
	},
	{
		name = "reassign_name",
		label = "Reassign",
		kind = "action",
		submenu = true,
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
		eval = function()
			return #active_display().selected.alternate > 0;
		end,
		handler = function()
			return gen_altsw(active_display().selected);
		end,
	},
	{
		name = "canvas_to_bg",
		label = "Workspace-Background",
		kind = "action",
		handler = grab_shared_function("wnd_tobg");
	},
	{
		name = "titlebar_toggle",
		label = "Titlebar On/Off",
		kind = "action",
		handler = function()
			local wnd = active_display().selected;
			wnd.hide_titlebar = not wnd.hide_titlebar;
			wnd:set_title();
		end
	},
	{
		name = "target_opacity",
		label = "Opacity",
		kind = "value",
		hint = "(0..1)",
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
		handler = grab_shared_function("migrate_wnd_bydspname"),
		eval = function()
			return gconfig_get("display_simple") == false and #(displays_alive()) > 1;
		end
	},
	{
		name = "destroy",
		label = "Destroy",
		kind = "action",
		handler = function()
			grab_shared_function("destroy")();
		end
	},
	{
		name = "moverz",
		label = "Move/Resize",
		kind = "action",
		handler = moverz_menu,
		submenu = true
	},
	{
		name = "schemes",
		label = "Schemes",
		kind = "action",
		submenu = true,
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
					if (x2-x1 <= 0 or y2 - y1 <= 0) then
						return;
					end

-- create clone with proper texture coordinates, this has problems with
-- source windows that do other coordinate transforms as well and switch
-- back and forth.
					local new = null_surface(x2-x1, y2-y1);
					image_sharestorage(wnd.canvas, new);
					local s1 = (x1-props.x) / props.width;
					local t1 = (y1-props.y) / props.height;
					local s2 = (x2-props.x) / props.width;
					local t2 = (y2-props.y) / props.height;
					if (wnd.origo_ll) then
						local tmp_1 = t2;
						t2 = t1;
						t1 = tmp_1;
					end

-- bind to a window, with optional input-routing but run this as a one-off
-- timer to handle the odd case where the add-window event would trigger
-- another selection region to nest. setting this too short seems to fail
-- to trigger the hook altogether (interesting)
					local source_name = wnd.name;
					timer_add_periodic("wndspawn", 10, true, function()
						image_set_txcos(new, {s1, t1, s2, t1, s2, t2, s1, t2});
						show_image(new);
						local cwin = active_display():add_window(new, {scalemode = "aspect"});
						if (not cwin) then
							delete_image(new);
							return;
						end
-- define mouse-cursor coordinate range-remap
						cwin.mouse_remap_range = {
							s1, t1, s2, t2
						};
						cwin:set_title("Slice");
						cwin.source_name = wnd.name;
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
	}
};
