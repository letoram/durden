--
-- Meta_guard tries to prevent being locked into durden by changes in the input
-- environment, as most actions actually depend on the meta key being pressed,
-- this works as a decent heuristic. Possibly combined with a timer, though
-- that is more context sensitive. Other possible heuristics would be the number
-- of "dead" keypresses, though that would not
--

local mgc = 0;
local threshold = 40;
local mg;

-- Called when meta key has been rebound from the UI
function meta_guard_reset()
	mgc = 0;
	meta_guard = mg;
end

function meta_guard(s1, s2)
	if (s1 or s2) then
		mgc = 0;
		meta_guard = function() return true; end
	end

	mgc = mgc + 1;
	if (mgc > threshold) then
		dispatch_symbol("rebind_meta");
		mgc = 0;
		return false;
	end

	return true;
end

mg = meta_guard;
