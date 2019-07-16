local function gen_trigger_menu(event)
	local res = {
		{
			name = "add",
			hidden = true,
			label = "Add",
			description = "Add a new trigger event",
			kind = "value",
			validator = function(val)
				if #val == 0 or not string.find(val, "=") then
					return;
				end
			end,
			handler = function(val)
				local wnd = active_display().selected;
				wnd:add_handler(event, function(wnd)
					dispatch_symbol_wnd(wnd, val);
				end);
				wnd.trigger_log = wnd.trigger_log and wnd.trigger_log or {};
				table.insert(wnd.trigger_log, {#wnd.trigger_log, event, path});
			end
		},
		{
			name = "bind",
			label = "Bind",
			description = "Bind a path to the " .. event .. " trigger",
			kind = "action",
			interactive = true,
			handler = function()
				dispatch_symbol_bind(
				function(path)
					if (not path or #path == 0) then
						return;
					end

					local wnd = active_display().selected;
					wnd:add_handler(event, function(wnd)
						dispatch_symbol_wnd(wnd, path);
					end);
					wnd.trigger_log = wnd.trigger_log and wnd.trigger_log or {};
					table.insert(wnd.trigger_log, {#wnd.trigger_log, event, path});
				end);
			end,
		}
	};

	local wnd = active_display().selected;
	if (not wnd.trigger_log) then
		return res;
	end

	for i, v in ipairs(wnd.trigger_log) do
		table.insert(res, {
			name = "remove_" .. tostring(i),
			label = tostring(i),
			description = "Remove " .. v[3],
			kind = "action",
			handler = function()
				wnd:drop_handler(v[2], v[3]);
				table.remove(wnd.trigger_log, i);
			end,
		});
	end

	return res;
end

return {
{
	name = "select",
	kind = "action",
	label = "Select",
	submenu = true,
	description = "Triggered when the window is selected/focused",
	handler = function() return gen_trigger_menu("select"); end
},
{
	name = "deselect",
	kind = "action",
	label = "Deselect",
	submenu = true,
	description = "Triggered when the window is deselected/defocused",
	handler = function() return gen_trigger_menu("deselect"); end
},
{
	name = "destroy",
	kind = "action",
	label = "Destroy",
	submenu = true,
	description = "Triggered just before the window is destroyed",
	handler = function() return gen_trigger_menu("destroy"); end
}
};
