
local inputh = function(wm, iot)
	if (valid_vid(wm:active_space().background_src, TYPE_FRAMESERVER)) then
		target_input(wm:active_space().background_src, iot);
	end
end

display_add_listener(
function(event, name, tiler, id)
	if (event == "added" and tiler) then
		tiler:fallthrough_input(inputh);
	end
end);
