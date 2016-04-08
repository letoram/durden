local function set_temporary(wnd, slot, opts, val)
	target_coreopt(wnd.external, slot, val);
-- note: IF meta1 is set, we SAVE to persistant config
-- [get from tgt/config IDs or from registered UUID
end

local function list_values(wnd, ind, optslot, trigfun)
	local res = {};
	for k,v in ipairs(optslot.values) do
		table.insert(res, {
			handler = function()
				trigfun(wnd, ind, optslot, v);
			end,
			label = v,
			name = "val_" .. v,
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
				name = "opt_" .. v.description,
				label = v.description,
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
		name = "set",
		label = "Set",
		kind = "action",
		submenu = true,
		handler = function()
			return list_coreopts(active_display().selected, set_temporary);
		end
	},
};
