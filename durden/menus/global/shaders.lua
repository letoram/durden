local function build_list(group)
	local res = {};
	for i,v in ipairs(shader_list({group})) do
		local key, dom = shader_getkey(v, {group});
		local rv = shader_uform_menu(key, dom);
		if (rv and #rv > 0) then
			table.insert(res, {
				name = key,
				label = v,
				submenu = true,
				kind = "action",
				handler = function()
					return rv;
				end
			});
		end
	end
	return res;
end

local rebuild_query = {
{
	name = "no",
	label = "No",
	kind = "action",
	handler = function() end
},
{
	name = "yes",
	label = "Yes",
	kind = "action",
	dangerous = true,
		handler = function()
			shdrmgmt_scan();
		end
	}
};

return function()
	return
	{
		{
		name = "ui",
		label = "UI",
		kind = "action",
		submenu = true,
		eval = function() return #build_list("ui") > 0; end,
		handler = function()
			return build_list("ui");
		end
		},
		{
		name = "effect",
		label = "Effect",
		kind = "action",
		submenu = true,
		eval = function() return #build_list("effect") > 0; end,
		handler = function()
			return build_list("effect");
		end
		},
		{
		name = "rebuild",
		label = "Reset",
		kind = "action",
		submenu = true,
		handler = rebuild_query
		}
	};
end
