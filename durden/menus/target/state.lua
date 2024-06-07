local function shared_reset(wnd)
	if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		reset_target(wnd.external);
	end
end

local function gen_restore_menu()
	local res = {};
	local lst = glob_resource("*", APPL_STATE_RESOURCE);
	for i,v in ipairs(lst) do
		table.insert(res, {
			label = v,
			name = "restore_" .. util.hash(v),
			kind = "action",
			handler = function(ctx)
				restore_target(active_display().selected.external, v);
			end
		});
	end
	return res;
end

local function grab_file(id, handler, open)
	browse_override_ext(id)
	dispatch_symbol_bind(
-- callback (on entry)
		function(path)
			if (not path) then
				return;
			end

			local ln, kind = resource(path);
			if (not ln or not kind) then
				return;
			end

			if (kind == "file") then
				handler(path);
			end
		end,
-- base path
		"/browse/shared",
-- menu options
		{ show_invisible = false,
			force_completion = open and true or false,
			on_entry = function(ctx, path)
				if (#path > 0) then
					browse_override_ext();
					handler(path);
				end
			end
		}
	);
end

local function gen_type_menu(wnd, open)
	local res = {}
	local dst = open and "input_extensions" or "output_extensions"
	local lst = wnd.ephemeral_ext and wnd.ephemeral_ext or wnd[dst]

-- client has not announced any capability
	if not lst then
		return res
	end

-- or this happened on the wrong window
	local source = wnd.external;
	if not valid_vid(source, TYPE_FRAMESERVER) then
		return res
	end

	local grab =
	function(identifier)
		grab_file(identifier,
		function(path)
			if valid_vid(source, TYPE_FRAMESERVER) then
				if open then
					restore_target(source, path, SHARED_RESOURCE, identifier);
				else
					snapshot_target(source, path, SHARED_RESOURCE, identifier);
				end
			end
		end)
	end

	for i,v in ipairs(string.split(lst, ";")) do
-- we have naming restrictions that don't apply to the extension so
-- swap for a placeholder
		local name = suppl_valid_name(v) and v or "unkn_ext";
		if v == "*" then
			name = "wildcard";
		end

		table.insert(res, {
			name = string.format("%d_%s", i, name),
			label = v,
			kind = "action",
			handler = function()
				grab(v);
			end
		})
	end

	return res;
end

local function gen_statedst_wnd()
	local lst = {};
	local sel = active_display().selected;

-- enumerate all windows and add the external ones that aren't the source
	for wnd in all_windows() do
		if (wnd ~= sel and valid_vid(wnd.external, TYPE_FRAMESERVER)) and
			wnd.stateinf and wnd.stateinf.typeid == sel.stateinf.typeid then
			table.insert(lst, {
				name = wnd.name,
				label = wnd.name,
				description = wnd:get_name(),
				kind = "action",
				handler = function(ctx, val)
					bond_target(sel.external, wnd.external)
				end
			});
		end
	end

	return lst;
end

return {
	{
		name = "suspend",
		label = "Suspend",
		kind = "action",
		description = "Block frame-transfers and request that the client enter a wait state",
		handler = function()
			active_display().selected:set_suspend(true);
		end
	},
	{
		name = "resume",
		label = "Resume",
		kind = "action",
		description = "Unblock frame-transfers and request that the client resumes processing",
		handler = function()
			active_display().selected:set_suspend(false);
		end
	},
	{
		name = "toggle",
		label = "Toggle",
		kind = "action",
		description = "Toggle between suspend and resume state",
		handler = function()
			active_display().selected:set_suspend();
		end
	},
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		dangerous = true,
		description = "Request that the client soft-resets to an initial state",
		handler = function()
			shared_reset(active_display().selected);
		end
	},
	{
		name = "open",
		label = "Open",
		kind = "action",
		interactive = true,
		description = "Browse for a file and request that the client tries to open it",
		eval = function()
			return #gen_type_menu(active_display().selected, true) > 0;
		end,
		handler = function()
-- cache source and re-validate as the asynch- nature of the grab_ menu may
-- have the source die while we are waiting
			local menu = gen_type_menu(active_display().selected, true);
			menu[1].handler();
		end
	},
	{
		name = "save",
		label = "Save",
		kind = "action",
		interactive = true,
		eval =
		function()
			return #gen_type_menu(active_display().selected, false) > 0;
		end,
		description = "Query for a path and filename and request that the client saves to it",
		handler =
		function()
			local menu = gen_type_menu(active_display().selected, false);
			menu[1].handler();
		end
	},
	{
		name = "save_as",
		label = "Save As",
		kind = "action",
		description = "Pick a data type and filename then request that the client saves to it",
		interactive = true,
		submenu = true,
		eval =
		function()
			return #gen_type_menu(active_display().selected, false) > 1;
		end,
		handler =
		function()
			return gen_type_menu(active_display().selected, false);
		end
	},
	{
		name = "restore",
		label = "Restore",
		kind = "action",
		submenu = true,
		description = "Restore client state from a previous snapshot",
		eval = function()
			return (#glob_resource("*", APPL_STATE_RESOURCE)) > 0;
		end,
		handler = function(ctx, v)
			return gen_restore_menu();
		end
	},
	{
		name = "snapshot",
		label = "Snapshot",
		kind = "value",
		initial = "",
		description = "Request that the client makes a snapshot of its state",
		validator = function(str) return str and string.len(str) > 0; end,
		handler = function(ctx, val)
			snapshot_target(active_display().selected.external, val);
		end,
		eval = function()
			local wnd = active_display().selected;
			return active_display().selected.stateinf ~= nil;
		end
	},
	{
		name = "bond",
		label = "Bond",
		kind = "action",
		description = "Forward the state of one client to another",
		submenu = true,
		eval =
		function()
			return
				active_display().selected.stateinf ~= nil and
				#gen_statedst_wnd() > 0;
		end,
		handler =
		function()
			return gen_statedst_wnd();
		end,
	},
	{
		name = "seek",
		kind = "action",
		label = "Seek",
		description = "Seek to a specific or relative point in time",
		eval = function()
			return active_display().selected.streamstatus ~= nil;
		end,
		submenu = true,
		handler = seek_menu
	},
	{
	name = "push_accessibility",
	label = "Accessibility",
	kind = "action",
	handler = function()
		local wnd = active_display().selected;
		local vid = target_alloc(wnd.external, function() end, "accessibility")
		if not valid_vid(vid) then
			return;
		end
		local newwnd =
			durden_launch(vid, "accessibility", "", nil, {attach_parent = wnd});
		if not newwnd then
			return
		end
		extevh_apply_atype(newwnd, "tui", vid, {});
		newwnd.allowed_segments = {};
	end
	},
	{
	name = "push_debug",
	label = "Debug",
	kind = "value",
	set = {"builtin", "client"},
	description = "Send a debug- window to the client",
	eval = function()
		return valid_vid(
			active_display().selected.external, TYPE_FRAMESERVER);
	end,
	handler = function(ctx, val)
		local wnd = active_display().selected;
		local vid = target_alloc(wnd.external,
			function() end, "debug", val == "builtin");
		if not valid_vid(vid) then
			return;
		end

		local newwnd = durden_launch(vid, "debug", "", nil, {attach_parent = wnd});
		if (not newwnd) then
			return;
		end

		extevh_apply_atype(newwnd, wnd.atype, vid, {});
		newwnd.allowed_segments = table.copy(newwnd.allowed_segments);
		table.insert(newwnd.allowed_segments, "handover");
	end
	}
};
