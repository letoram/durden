-- just leverage the normal 'fallthrough input' in the tiler input handler
-- dispatch function. Check if we should forward to an active client or swallow
-- certain actions like right-click for popup.

local inputh = function(wm, iot)
	if (valid_vid(wm:active_space().background_src, TYPE_FRAMESERVER)) then
		target_input(wm:active_space().background_src, iot);
	end
end

display_add_listener(
function(event, name, tiler, id)
	if (event == "added" and tiler and tiler.fallthrough_input) then
		tiler:fallthrough_input(inputh);
	end
end);
