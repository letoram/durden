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
	description = "Warning: This can put the UI in an unstable state, Proceed?",
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
		description = "Change variables for shaders that belong to the 'UI' category",
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
		description = "Change variables for shaders that belong to the 'Effect' category",
		kind = "action",
		submenu = true,
		eval = function() return #build_list("effect") > 0; end,
		handler = function()
			return build_list("effect");
		end
		},
		{
		name = "rebuild",
		description = "Recompile / Rescan the list of shaders",
		label = "Reset",
		kind = "action",
		submenu = true,
		handler = rebuild_query
		}
	};
end
