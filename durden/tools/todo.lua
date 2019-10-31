--
-- simple todo tool,
--
-- todo items has a name, description, priority and group.
-- only one group is active at a time.
--
-- when enabling the tool, a presenter is picked, which is what UI element
-- which will provide description and controls.
--
local log = suppl_add_logfn("tools");
local load_items, store_items;
local last_item;
local active_group = "default";

local presenter = function()
end;

local items = {
};

local function set_current(item)
	if not item then
		log("name=todo:kind=item_clear");
		presenter();
		return;
	end

	table.remove_match(items, item);
	table.insert(items, 1, item);
	log(string.format("name=todo:kind=item:" ..
		"task=%s:group=%s:description=%s", active_group, item.name, item.description));
	presenter(item);
	store_items();
end

local function find_item(key)
	for i,v in ipairs(items) do
		if v.name == key then
			return v;
		end
	end
end

local function insert_item(item)
	if find_item(item.name) then
		return;
	end

-- locate insertion point
	if #items == 0 then
		set_current(item);
		last_item = item;
	else
		local pos = 2;
		repeat
			if items[pos] and items[pos].priority <= item.priority then
				pos = pos + 1;
			else
				break;
			end
		until pos > #items;
		table.insert(items, pos, item);
		store_items();
		last_item = item;
	end
end

local sbar_btn;
local function present_sbar(item, dir)
	if sbar_btn then
		sbar_btn:destroy();
		sbar_btn = nil;
	end

	if not item then
		return;
	end

	local wm = active_display();
	local pad = gconfig_get("sbar_tpad") * wm.scalef;

	sbar_btn = active_display().statusbar:add_button(
		dir, "sbar_item_bg", "sbar_item", item.name, pad, wm.font_resfn, nil, nil,
	{
		click = function(btn)
-- popup that match to the paths global/tools/todo/items/current/..
			local menu = menu_resolve("/global/tools/todo/items/current", nil, false);
			for i=#menu,1,-1 do
				if menu[i].kind == "value" then
					table.remove(menu, i);
				end
			end

-- add the description as a no-op item first
			if #item.description > 0 then
				table.insert(menu, 1, {
					label = item.description,
					name = "description",
					kind = "action",
					handler = function() end,
					eval = false,
					format = HC_PALETTE[2]
				});
			end

			local pos = image_surface_resolve(btn.bg);
			uimap_popup(menu, pos.x, pos.y + pos.height, btn.bg);
		end
	});

	if not sbar_btn then
		return;
	end

	sbar_btn:set_description(item.description);
end

-- format:
-- priority:name:
local function unpack_str(v)
	local _, v = string.split_first(v, "=");
	local list = string.split(v, ":");
	local prio = table.remove(list, 1);
	local name = table.remove(list, 1);
	local descr = table.remove(list, 1);
	descr = descr and descr or "";

	local rest = table.concat(list, ":");
	if not prio or not name or not tonumber(prio) or #name == 0 then
		log("name=todo:kind=error:message=malformed entry:raw=" .. v);
		return;
	end
	insert_item({
		name = name,
		priority = tonumber(prio),
		description = descr
	});
end

load_items = function()
	items = {};
	for _,v in ipairs(match_keys("todo_item_" .. active_group .. "_%")) do
		unpack_str(v);
	end
	table.sort(items,
	function(a, b)
		return a.priority < b.priority;
	end);
end

store_items = function()
	local list = {};

	for i,v in ipairs(items) do
		list["todo_item_" .. active_group .. "_" .. tostring(i)] =
			string.format("%d:%s:%s", v.priority, v.name, v.description);
	end

-- would be nice if we had a shared prefix 'flush and store' atomically..
	drop_keys("todo_item_" .. active_group .. "_%");
	store_key(list);
end

load_items();

local reserved = {
	last = true,
	current = true
};

local function item_menu(item, current)
	local res = {
		{
			name = "complete",
			label = "Complete",
			description = "Mark task as completed (remove it)",
			kind = "action",
			handler = function()
				log(string.format(
					"name=todo:kind=complete:focus=%s:name=%s",
					current and "yes" or "no", item.name)
				);
				table.remove_match(items, item);
				if last_item == item then
					last_item = nil;
				end
				if (current) then
					set_current(items[1]);
				end
				store_items();
			end
		},
		{
			name = "priority",
			label = "Priority",
			kind = "value",
			hint = "(1=high..5=low, default=3)",
			description = "Change the task priority",
			validator = gen_valid_num(1, 5),
			handler = function(ctx, val)
				table.remove_match(items, item);
				item.priority = tonumber(val);
				insert_item(item);
				store_items();
			end
		},
		{
			name = "description",
			label = "Description",
			description = "Change the long form item description",
			kind = "value",
			validator = shared_valid_str,
			handler = function(ctx, val)
				item.description = val;
				store_items();
			end
		}
	};

	if (current) then
		table.insert(res, {
			name = "postpone",
			label = "Postpone",
			kind = "action",
			description = "Schedule this task for later and switch to another one",
			eval = function()
				return #items > 1;
			end,
			handler = function()
-- re-use the insertion function, with the edge case if we get added first again due to priortiy
				local item = table.remove(items, 1);
				insert_item(item);
				if (items[1] == item) then
					local item = table.remove(items, 1);
					table.insert(items, 2, item);
				end
				set_current(items[1]);
			end
		});
	else
		table.insert(res, {
			name = "set",
			label = "Set",
			kind = "action",
			description = "Set the task as the currently active one",
			handler = function()
				set_current(item);
				store_items();
			end
		});
	end

	return res;
end

local function gen_item_menu()
	local list = {};

	if (#items > 0) then
		table.insert(list, {
			name = "current",
			label = "Current",
			submenu = true,
			kind = "action",
			description = "View or Modify the currently active task",
			handler = function()
				return item_menu(items[1], true);
			end
		});
	end

	if (last_item) then
		table.insert(list, {
			name = "latest",
			label = "Latest",
			kind = "action",
			description = "View or Modify the latest created task",
			handler = function()
				return item_menu(last_entry, items[1] == last_entry);
			end
		});
	end

	for i, v in ipairs(items) do
		table.insert(list, {
			name = string.lower(v.name),
			label = v.name,
			kind = "action",
			submenu = true,
			handler = function()
				return item_menu(v, i == 1);
			end,
		});
	end

	return list;
end

local method_menu = {
	{
		name = "statusbar",
		label = "Statusbar",
		kind = "value",
		set = {"left", "right"},
		description = "Enable task tracking and present as buttons in the statusbar",
		handler = function(ctx, val)
			load_items();
			presenter = function(item)
				present_sbar(item, val);
			end;
			todo_enabled = true;
			set_current(items[1]);
		end,
	}
};

local todo_menu = {
-- track enable/disable state so we don't have a weird permutation set
-- or 'UAF' like UI behaviours for when one presentation method is set
-- while another is active
	{
		name = "enable",
		label = "Enable",
		description = "Pick a method to activate/enable task tracking",
		kind = "action",
		submenu = true,
		eval = function()
			return not todo_enabled;
		end,
		handler = method_menu
	},
	{
		name = "disable",
		label = "Disable",
		kind = "action",
		eval = function()
			return todo_enabled;
		end,
		handler = function()
			presenter();
			todo_enabled = nil;
			presenter = function()
			end;
		end
	},
	{
		name = "group",
		label = "Set Group",
		kind = "value",
		description = "Set the active task group",
		initial = function()
			return active_group;
		end,
		validator = function(val)
			return shared_valid_str(val) and suppl_valid_name(val);
		end,
		eval = function()
			return not todo_enabled;
		end,
		handler = function(ctx, val)
			items = {};
			last_item = nil;
			active_group = val;
			load_items();
		end
	},
	{
		name = "add",
		label = "Add",
		kind = "value",
		validator = function(val)
			if not shared_valid_str(val) then
				return;
			end
			local key, rest = string.split_first(val, ":");
			return suppl_valid_name(key) and not reserved[key] and not find_item(key);
		end,
		description = "Add a new task",
		hint = "name(a-Z,0-9):description",
		handler = function(ctx, val)
			local key, rest = string.split_first(val, ":");
			rest = rest and rest or "";
			insert_item( {
				name = key,
				priority = 3,
				description = rest
			});
		end
	},
	{
		name = "items",
		label = "Items",
		description = "View or Modify current list of tasks",
		kind = "action",
		submenu = true,
		eval = function()
			return #items > 0;
		end,
		handler = gen_item_menu
	},
};

menus_register("global", "tools",
{
	name = "todo",
	label = "Todo",
	description = "Simple task tracker",
	kind = "action",
	submenu = true,
	handler = todo_menu
}
);
