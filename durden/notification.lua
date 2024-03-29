--
-- This is currently just a simple hook- interface for other tools and
-- widgets to attach to in order to be able to track and react on
-- notifications.
--

local listeners = {};
local log, fmt = suppl_add_logfn("notification");

function notification_register(key, handler)
	listeners[key] = handler;
end

function notification_deregister(key)
	listeners[key] = nil;
end

function notification_debug(msg, long)
	if (not long) then
		long = ""
	end
	notification_add("debug", nil, msg, long, 1);
end

--
-- add timestamp and attach to messages, form is:
-- source  [string identifier],
-- symref  [=nil, recpt. pick] - icon or emoji ref, nil
-- short   [short description],
-- long    [longer description, if present],
-- urgency [1 = normal, 2 = important, 3 = urgent, 4 = critical]
-- pathref [/some/optional/menu/path]
--
function notification_add(source, symref, short, long, urgency, pathref)
	if (not gconfig_get("notifications_enable")) then
		return;
	end

	log(
		fmt(
				"source=%s:urgency=%d:msg=%s:path=%s:long=%s",
				source, urgency, short,
				pathref and pathref or "",
				long and long or ""
			)
	);

	if (type(urgency) ~= "number") then
		urgency = 1;
	end
	urgency = math.clamp(urgency, 1, 4);

-- decent place to introduce some rate-limiting here
	for _,v in pairs(listeners) do
		v(source, symref, short, long, urgency, pathref);
	end

	if (valid_vid(symref)) then
		delete_image(symref);
	end
end
