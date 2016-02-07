local function set_temporary(wnd, slot, val)
	print("set_temporary", wnd, slot, val);
end

local function list_values(wnd, ind, optslot, trigfun)
	local res = {};
	for k,v in ipairs(optslot.values) do
		table.insert(res, {
			handler = function()
				trigfun(wnd, ind, optslot, v);
			end,
			name = "coreopt_val_" .. v,
			kind = "action"
		});
	end
	return res;
end

local function list_coreopts(wnd, trigfun)
	local res = {};
	for k,v in ipairs(wnd.coreopt) do
		if (#v.values > 0 and v.description) then
			table.insert(res, {
				name = "coreopt_" .. v.description,
				kind = "action",
				submenu = true,
				handler = function()
					return list_values(wnd, k, v, trigfun);
				end
			});
		end
	end
	return res;
end

return {
	{
		name = "coreopt_set",
		label = "Set",
		kind = "action",
		submenu = true,
		eval = function()
			return active_display().selected.coreopt ~= nil;
		end,
		handler = function()
			list_coreopts(active_display().selected, set_temporary);
		end
	},
};
