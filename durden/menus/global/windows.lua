--
-- These are primarily to let the output/ipc system address individual
-- windows. The caveat with this approach is that too much of the menu
-- system was written using the active_display().selected approach for
-- some reason (really stupid, yes..) so in order to use window-target
-- invocation, we need to fake-select, run then revert-select. This is
-- problematic when the window operation itself would change selection
--
-- The workaround, with rewriting menu being out of scope, is to ret.
-- the window itself, and have the ipc-invoker fake-select the window,
-- run the remainder and revert selection if window is still alive.
--
local function insert_first(dst, name, v)
	if (not dst[name]) then
		dst[name] = v;
		return;
	end
	local ind = 1;
	while true do
		local newname = name .. "_" .. tostring(ind);
		if (not dst[newname]) then
			dst[newname] = v;
			return;
		end
		ind = ind + 1;
	end
end

local function get_all_windows(fltfun)
	local res = {};
	local count = 0;

	for ent in all_spaces_iter() do
		for i,v in ipairs(ent.children) do
			local name = fltfun(v);
			if (name) then
				count = count + 1;
				insert_first(res, name, v);
			end
		end
	end
	return count, res;
end

local function nameflt(wtbl)
	return wtbl.name;
end

local function wsflt(wtbl)
	return wtbl.name;
end

local function tagflt(wtbl)
	return wtbl.name;
end

local function titleflt(wtbl)
	return wtbl.name;
end

-- linearize map, sort, add menu structure, go.
local function wndlist_to_menu(count, wtbl)
	local rtbl = {};
	for k,v in pairs(wtbl) do
		table.insert(rtbl, {
			name = k,
			label = k,
			kind = "action",
			submenu = true,
			handler = function()
			end
		});
	end
-- table.sort format with arguments
	return rtbl;
end

return {
	{
		name = "name",
		label = "All",
		submenu = true,
		kind = "action",
		eval = function() return get_all_windows(nameflt) > 0; end,
		handler = function()
			return wndlist_to_menu(get_all_windows(nameflt));
		end,
	},
	{
		name = "workspace",
		label = "Workspace",
		submenu = true,
		eval = function() return get_all_windows(wsflt) > 0; end,
		handler = function()
			return wndlist_to_menu(get_all_windows(wsflt));
		end,
	},
	{
		name = "tag",
		label = "Tag",
		kind = "action",
		submenu = true,
		eval = function() return get_all_windows(tagflt) > 0; end,
		handler = function()
			return wndlist_to_menu(get_all_windows(tagflt));
		end,
	},
	{
		name = "title",
		label = "Title",
		kind = "action",
		submenu = true,
		eval = function() return get_all_windows(titleflt) > 0; end,
		handler = function()
			return wndlist_to_menu(get_all_windows(titleflt));
		end
	},
};
