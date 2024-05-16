--
-- External Clipboard Manager (CLIPBOARD segment as primary)
-- artificially restricted to one active clipboard manager.
--

local log, fmt = suppl_add_logfn("clipboard");
local cm = nil;

local function clipboard_event(msg, source)
	if (not cm or source == cm) then
		return;
	end

	if (msg and string.len(msg) > 0 and valid_vid(cm.external, TYPE_FRAMESERVER)) then
		local mode = gconfig_get("clipboard_access");
		if (mode == "passive" or mode == "full") then
			message_target(cm.external, msg);
		end
	end
end

CLIPBOARD:add_monitor(clipboard_event);

local clipboard_dispatch =
{
	segment_request =
	function(...)
	end,

	terminated =
	function(wnd, ...)
		CLIPBOARD:set_provider(wnd)
		if cm == wnd then
			cm = nil
		end
		return false
	end,

	message =
	function(wnd, source, stat)
		local mode = gconfig_get("clipboard_access");
		if (mode == "active" or mode == "full") then
			CLIPBOARD:add(source, stat.message, stat.multipart);
		else
			log("rejected:reason=external_copy_blocked")
		end
	end,

	registered =
	function(wnd, source, stat)
		if cm then
			log("collision:message=got existing clipboard manager")
			wnd:destroy();
			return;
		end

		if gconfig_get("clipboard_access") == "none" then
			log("rejected:reason=external_blocked")
			wnd:destroy()
			return
		end

		log("accepted:kind=external_manager")
		cm = wnd
	end
}

return {
	atype = "clipboard",
	default_shader = {"simple", "noalpha"},
	actions = {},
	props =
	{
		attach_block = true
	},
	dispatch = clipboard_dispatch
};
