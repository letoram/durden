local function shared_reset(wnd)
	if (valid_vid(wnd.external, TYPE_FRAMESERVER)) then
		reset_target(wnd.external);
	end
end

local function gen_load_menu()
	local res = {};
	local lst = glob_resource("*", APPL_STATE_RESOURCE);
	for i,v in ipairs(lst) do
		table.insert(res, {
			label = v,
			name = "load_" .. util.hash(v),
			kind = "action",
			handler = function(ctx)
				restore_target(active_display().selected.external, v);
			end
		});
	end
	return res;
end

local function grab_file(handler, open)
	dispatch_symbol_bind(
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
		"/browse/shared",
		{ show_invisible = false; }
	);
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
		name = "force_load",
		label = "Load",
		kind = "action",
		hidden = true,
		interactive = true,
		description = "Browse for a file and send it to the client in open mode",
		handler = function()
-- cache source and re-validate as the asynch- nature of the grab_ menu may
-- have the source die while we are waiting
			local source = active_display().selected.external;
			grab_file(function(path)
				if valid_vid(source, TYPE_FRAMESERVER) then
					restore_target(source, path, SHARED_RESOURCE);
				end
			end, true);
		end
	},
	{
		name = "force_store",
		label = "Store",
		kind = "action",
		hidden = true,
		description = "Select a place for the client to store data",
		handler = function()
			local source = active_display().selected.external;
			grab_file(function(path)
				if valid_vid(source, TYPE_FRAMESERVER) then
					snapshot_target(source, path, SHARED_RESOURCE);
				end
			end, false);
		end
	},
	{
		name = "load",
		label = "Load",
		kind = "action",
		submenu = true,
		description = "Send a previous save state to the client",
		eval = function()
			return (#glob_resource("*", APPL_STATE_RESOURCE)) > 0;
		end,
		handler = function(ctx, v)
			return gen_load_menu();
		end
	},
	{
		name = "save",
		label = "Save",
		kind = "value",
		submenu = true,
		initial = "",
		description = "Allocate a state store and send to the client for writing",
		validator = function(str) return str and string.len(str) > 0; end,
		prefill = "testy_test",
		handler = function(ctx, val)
			snapshot_target(active_display().selected.external, val);
		end,
		eval = function()
			local wnd = active_display().selected;
			return active_display().selected.stateinf ~= nil;
		end
	}
};
