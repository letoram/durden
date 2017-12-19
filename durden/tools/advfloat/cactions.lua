--
-- define and use on-over, "on-drag-over", "on-drag-out", "on-drop"
-- desktop subregions
-- missing: menu paths for binding, modifying, resetting and saving
--
local cactions = system_load("tools/advfloat/cactions_cfg.lua")();

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

global_menu_register("settings/wspaces/float",
{
	name = "action_regions",
	kind = "action",
	submenu = true,
	description = "Manage the mouse-action regions",
	label = "Action Region",
	handler = action_submenu
});
