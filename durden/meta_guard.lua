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
function meta_guard_reset(force)
	if (force) then
		mgc = threshold + 1;
		if (mg) then
			mg();
		else
			meta_guard();
		end
	else
		mgc = 0;
		meta_guard = mg;
	end
end

function meta_guard(s1, s2)
	if (s1 or s2) then
		mgc = 0;
		active_display():message();
		meta_guard = function() return true; end
		return true;
	end

	local bindcall = function(sym, lbl)
		tiler_tbar(active_display(), lbl, gconfig_get("tbar_timeout"),
			function()
			dispatch_symbol(sym);
		end, SYSTEM_KEYS["cancel"]);
	end

	mgc = mgc + 1;
	if (mgc > threshold) then
		suppl_binding_queue(function()
			bindcall("/global/input/bind/meta", LBL_METAGUARD_META);
		end);

		suppl_binding_queue(function()
			bindcall("/global/input/bind/basic", LBL_METAGUARD_BASIC);
		end);

		suppl_binding_queue(function()
			bindcall("/global/input/bind/menu", LBL_METAGUARD_MENU);
		end);

		suppl_binding_queue(function()
			bindcall("/global/input/bind/target_menu", LBL_METAGUARD_TMENU);
		end);

		mgc = 0;
		active_display():message();
		suppl_binding_queue(false);

		return false;
	else
		active_display():message(string.format(LBL_METAGUARD, threshold - mgc), -1);
	end

	return true;
end

mg = meta_guard;
