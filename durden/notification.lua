--
-- This is currently just a simple hook- interface for other tools and
-- widgets to attach to in order to be able to track and react on
-- notifications.
--

local listeners = {};

function notification_register(key, handler)
	listeners[key] = handler;
end

function notification_deregister(key)
	listeners[key] = nil;
end

--
-- add timestamp and attach to messages, form is:
-- source  [string identifier],
-- symref  [=nil, recpt. pick] - icon or emoji ref, nil
-- short   [short description],
-- long    [longer description, if present],
-- urgency [1 = normal, 1 = important, 2 = urgent, 4 = critical]
--
function notification_add(source, symref, short, long, urgency)
	if (not gconfig_get("notifications_enable")) then
		return;
	end

	urgency = math.clamp(urgency, 1, 4);

-- decent place to introduce some rate-limiting here
	for _,v in pairs(listeners) do
		v(source, symref, short, long, urgency);
	end

	if (valid_vid(symref)) then
		delete_image(symref);
	end
end
