-- just leverage the normal 'fallthrough input' in the tiler input handler
-- dispatch function. Check if we should forward to an active client or swallow
-- certain actions like right-click for popup.

local inputh = function(wm, iot)
	if (valid_vid(wm:active_space().background_src, TYPE_FRAMESERVER)) then
		target_input(wm:active_space().background_src, iot);
	end
end

-- toggle fallthrough on and off so the wallpaper can have normal click/rclick
-- when the background is not set to an actual client
local function background_hook(space, vid, generic)
	space:set_background_old(vid, generic);
	if type(vid) ~= "number" or not valid_vid(vid, TYPE_FRAMESERVER) then
		space.wm:fallthrough_input();
	else
		space.wm:fallthrough_input(inputh);
	end
end

menus_register("target", "window",
{
	name = "canvas_to_bg",
	label = "Workspace-Background",
	kind = "action",
	description = "Set windows contents as workspace background",
	handler = function()
		local wnd = active_display().selected;

		if (valid_vid(wnd.external)) then
-- hook set_background so that we can turn input block/grab on/off
			if (not wnd.space.set_background_old) then
				wnd.space.set_background_old = wnd.space.set_background;
				wnd.space.set_background = background_hook;
			end

			wnd.space:set_background(wnd.external);

-- disable 'focus hints' for the window as otherwise some clients will block io
			wnd.dispstat_block_old = wnd.dispstat_block;
			wnd.dispstat_block = true;
		else
			wnd.dispstat_block = wnd.dispstat_block_old;
			wnd.space:set_background(wnd.canvas);
		end
	end
});
