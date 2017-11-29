--
-- External Clipboard Manager (CLIPBOARD segment as primary)
-- artificially restricted to one active clipboard manager.
--

local cm = nil;
local function clipboard_event(ctx, msg, source)
	if (not cm or source == cm) then
		return;
	end

	if (msg and string.len(msg) > 0 and
		valid_vid(cm, TYPE_FRAMESERVER)) then
		local mode = gconfig_get("clipboard_access");
		if (mode == "passive" or mode == "full") then
			message_target(cm, msg);
		end
	end
end

CLIPBOARD:set_monitor(clipboard_event);

return {
	atype = "clipboard",
	default_shader = {"simple", "noalpha"},
	actions = {},
	props = {},

-- Intercept creation so that the window won't be made visible
-- (as the ws_attach() function will never be called)
	intercept = function(ctx, wnd, source, tbl)
		if (gconfig_get("clipboard_access") == "none") then
			active_display():message(
				"rejected clipboard injection/monitor connection attempt");
			return false;
		end

-- patch in a nonsense source so that we retain control over [source]
-- and can safely just return false and have the window destroy.
		if (valid_vid(cm)) then
			delete_image(cm);
			cm = nil;
		end
		wnd.vid = null_surface(1, 1);
		wnd.external = nil;
		if (valid_vid(wnd.vid)) then
			link_image(wnd.vid, wnd.anchor);
		end
		link_image(source, WORLDID);
		cm = source;

-- and set a dumb handler that only takes message/termination requests
-- into account, this does not setup a pasteboard for a/v operation and
-- copy- operations (stepframe, resized, ...) is also not used.
		target_updatehandler(source,
			function(src, stat)
				if (stat.kind == "terminated") then
					delete_image(source);
				elseif (stat.kind == "message") then
					local mode = gconfig_get("clipboard_access");
					if (mode == "active" or mode == "full") then
						CLIPBOARD:add(source, stat.message, stat.multipart);
					end
				end
			end
		)

-- here is a decent place to add the support for flushing the current global
-- clipboard history, though it is not particularly easy to actually add since
-- the storm of long, possibly multipart_ messages may not fit the event-queue
-- of the target, so the message_target call result would have to be treated
-- as a 'short_write' and retry.

-- will cause the wnd to be destroy, but we've already take control over source
		return false;
	end,
-- won't be used
	dispatch = {
	}
};
