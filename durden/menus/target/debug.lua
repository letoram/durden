local function query_tracetag()
	local bar = tiler_lbar(active_display(), function(ctx,msg,done,set)
		if (done and active_display().selected) then
			image_tracetag(active_display().selected.canvas, msg);
		end
		return {};
	end);
	bar:set_label("tracetag (wnd.canvas):");
end

local overlay_menu =
{
	{
		name = "add_overlay",
		label = "Add Overlay",
		kind = "action",
		description = "Create / Attach a random color as an overlay to the window",
		handler = function()
			local wnd = active_display().selected;
			local col = fill_surface(
				150, 100,
				math.random(32, 255),
				math.random(32, 255),
				math.random(32, 255)
			);
			show_image(col);
			local key = tostring(CLOCK);
			local ol = wnd:add_overlay(tostring(CLOCK), col, {
				mouse_handler = suppl_detach_overlay_mh(wnd, key, col)
			});
			ol.xofs = math.random(100);
			ol.yofs = math.random(100);
			wnd:synch_overlays();
		end,
	},
	{
		name = "del_overlay",
		label = "Drop Overlays",
		kind = "action",
		description = "Delete all overlays attached to the window",
		handler = function()
			local wnd = active_display().selected;
			local keys = {};
			for key,_ in pairs(wnd.overlays) do
				table.insert(keys, key);
			end
			for _,v in ipairs(keys) do
				wnd:drop_overlay(key);
			end
		end
	}
};

return {
	{
		name = "query_tracetag",
		label = "Tracetag",
		kind = "action",
		handler = query_tracetag
	},
	{
		name = "overlays",
		label = "Overlays",
		kind = "action",
		submenu = true,
		handler = overlay_menu
	}
};
