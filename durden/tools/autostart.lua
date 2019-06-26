--
-- This tool simply keeps track of paths to start when the tool itself is
-- loaded Decent improvements on this would be to detect a key that causes a
-- script failure and mask- that one out on the next iteration.
--
local items = {};
local log = suppl_add_logfn("tools");

local function synch_table()
	drop_keys("autostart_%");
	local lst = {};
	for i,v in ipairs(items) do
		lst["autostart_" .. tostring(i)] = v;
	end
	store_key(lst);
end

local oldshutdown = durden_shutdown;
durden_shutdown = function(...)
	store_key("autostart_ok", 1);
	return oldshutdown(...);
end

-- even with manual gaps, this will give us a compact item list
local ind = 1;
while true do
	local val = get_key("autostart_" .. tostring(ind));
	if not val then
		break
	end
	ind = ind + 1;
	table.insert(items, val);
end
log("name=autostart:kind=status:message=loaded " .. tostring(#items));
if (get_key("autostart_ok")) then
	for i,v in ipairs(items) do
		dispatch_symbol(v);
	end
	store_key("autostart_ok", "");
end

local function gen_rm_menu()
	local res = {};
	for i,v in ipairs(items) do
		table.insert(res,{
			name = tostring(i),
			description = v,
			label = tostring(i),
			kind = "action",
-- self modifying, need refresh
			handler = function()
				log("name=autostart:kind=removed:index=" .. tostring(i));
				table.remove(items, i);
				synch_table();
			end
		});
	end
	return res;
end

local root =
{
{
	name = "add",
	kind = "action",
	label = "Add",
	description = "Append a new item to the autostart list",
	interactive = true,
	handler = function(ctx)
		dispatch_symbol_bind(function(path)
			if path and #path > 0 then
				log("name=autostart:kind=added:path=" .. path);
				table.insert(items, path);
				synch_table();
			end
		end);
	end
},
{
	name = "remove",
	label = "Remove",
	kind = "action",
	description = "Remove an existing autostart item",
	eval = function()
		return #items > 0;
	end,
	submenu = true,
	handler = function()
		return gen_rm_menu();
	end,
},
{
	name = "run",
	label = "Run",
	kind = "action",
	description = "Run the current list of autostart items in sequence",
	eval = function()
		return #items > 0;
	end,
	handler = function()
		for i,v in ipairs(items) do
			dispatch_symbol(v);
		end
	end
},
};

menus_register("global", "settings/tools",
{
	name = "autostart",
	label = "Autostart",
	submenu = true,
	kind = "action",
	handler = root
});
