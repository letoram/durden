--
-- Decode archetype, settings and menus specific for decode- frameserver
-- session (e.g. stream selection, language, subtitle overlays)
--
return {
	atype = "multimedia",
	actions = {},
	dispatch = {
		streaminfo = function(wnd, tbl)
			print("streaminfo:", tbl.lang);
		end
	};
};
