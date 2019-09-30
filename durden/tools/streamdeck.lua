local cps = {};
local log = suppl_add_logfn("tools");

local primary_handler;
local function reset_cp(tbl, source)
	if (valid_vid(source)) then
		delete_image(source);
	end

	log("name=streamdeck:kind=reset:cp=" .. tbl.name);
	tbl.buttons = {};
	tbl.bg = nil;

-- re-open
	tbl.vid = target_alloc(tbl.name,
		tbl.cell_w * tbl.cols, tbl.cell_h * tbl.rows,
		function(...)
			return primary_handler(tbl, ...);
		end
	);
	if (valid_vid(tbl.vid)) then
		target_flags(tbl.vid, TARGET_BLOCKADOPT);
	else
-- add reopen timer and backoff here
	end
end

local function add_button(ctx, dst)
	if not valid_vid(ctx.lbl) then
		return
	end
	table.insert(dst, {
		vid = ctx.lbl,
		action = function()
			if ctx.click then
				ctx:click();
			end
		end
	});
end

local function gen_tbar(ctx, dst)
	local wnd = active_display().selected;
	if not wnd then
		return;
	end
	for _,v in ipairs(wnd.titlebar.buttons.left) do
		add_button(v, dst);
	end
	for _,v in ipairs(wnd.titlebar.buttons.right) do
		add_button(v, dst);
	end
end

local function run_label(wnd, label)
	local tbl = {
		kind = "digital",
		label = label,
		translated = true,
		active = true,
		devid = 8,
		subid = 8
	};
	wnd:input_table(tbl);
	tbl.active = false;
	wnd:input_table(tbl);
end

local function gen_labels(ctx, dst)
	local wnd = active_display().selected;
-- basic sanity check
	if not wnd or not wnd.input_labels or #wnd.input_labels == 0 then
		return;
	end

-- Request that the icon manager provides one for the labels that specify
-- a reference visual symbol ID. Not every labelhint provides this, so the
-- question is if that should be used as a filter. The current stance is
-- yes, so we reject labels where this is missing.
	for i,v in ipairs(wnd.input_labels) do
		if v[4] and #v[4] > 0 then
			table.insert(dst, {
				vid = icon_lookup(v[4], ctx.density),
				action = function()
-- avoid any dangling reference being kept
					if wnd.input_table then
						run_label(wnd, v[1]);
					end
				end
			});
		end
	end
end

local function gen_custom(ctx, dst)
	if not ctx.custom or #ctx.custom == 0 then
		return;
	end

	for i,v in ipairs(ctx.custom) do
		table.insert(dst, {
			vid = icon_lookup(v[1], ctx.density);
			action = v[2]
		});
	end
end

-- sweep all windows matching the active display and set
-- them as buttons where the button action becomes a select action
local function gen_windows(ctx, dst)
	local wm = active_display();
	local space = wm:active_space();

-- sort the space based on their euclidian distance
	local windows = space:linearize();
	table.sort(windows, function(a, b)
		local av = math.sqrt(a.x * a.x + a.y + a.y);
		local bv = math.sqrt(b.x * b.x + b.y + b.y);
		return av < bv;
	end);

-- and translate into the button destination list
	for _, v in ipairs(windows) do
		table.insert(dst, {
			vid = v.canvas,

-- more interesting options other than selection exist here,
-- but likely better to do as separate modes of operation rather
-- than the button flood fill
			action = function()
				if v.select then
					v:select();
				end
			end
		});
	end
end

local function build_buttonlist(tbl)
-- the keys here match the priorities that is set on the table
-- as part of the connection submenu, those that have a non-zero
-- priority will be added accordingly.
	local keys = {
		{"titlebar", gen_tbar},
		{"labels", gen_labels},
		{"custom", gen_custom},
		{"windows", gen_windows}
	};
	local buttons = {};

-- increment the values here to match #keys, first-come on equal
-- priority values
	for i=1,5 do
		for _,v in ipairs(keys) do
			if tbl.priorities[v[1]] and tbl.priorities[v[1]] == i then
				log(string.format("name=streamdeck:kind=rebuild:" ..
					"category=%s:priority=%d:cp=%s", v[1], i, tbl.name));
				v[2](tbl, buttons);
			end
		end
	end
	return buttons;
end

-- the meat of the whole unit, step the order of prioritised
-- targets and allocate / render to grid
local function relayout_grid(tbl)
	log("name=streamdeck:kind=relayout:cp=" .. tbl.name);
	local list = build_buttonlist(tbl);
	log("name=streamdeck:kind=status:size=" ..
		tostring(#list) .. ":limit=" .. tostring(#tbl.buttons));
-- should consider adding some overflow or pagination here, still build
-- the list as before, then share a slice at page boundaries.
	for i,v in ipairs(tbl.buttons) do
		local ent = list[i];
		if ent then
			image_sharestorage(ent.vid, v.vid);
			v.action = ent.action;
			blend_image(v.vid, tbl.opacity);
			rotate_image(v.vid, tbl.rotation);
		else
			v.action = nil;
			hide_image(v.vid);
-- custom
		end
	end
end

local function build_rendertarget(tbl, source)
	local w = tbl.cell_w * tbl.cols;
	local h = tbl.cell_h * tbl.rows;

-- first the composition buffer
	local buf = alloc_surface(w, h);
	if not valid_vid(buf) then
		return reset_cp(tbl, source);
	end

-- then the background image that will be used for the pipeline
	local bg = null_surface(w, h);
	if not valid_vid(bg) then
		delete_image(buf);
		return;
	end

-- setup the rendertarget itself and connect to the frameserver,
-- then tie the lifecycle of it to the frameserver vid as well
	define_rendertarget(buf, {bg});
	rendertarget_bind(buf, source);
	link_image(buf, source);
	blend_image(bg, 1.0, 10);
	log(string.format(
		"name=streamdeck:kind=rtbind:w=%d:h=%d:cp=%s", w, h, tbl.name));

-- then a null surface for each grid cell, or as many as we can
-- this is slightly 'problematic' as there are not that many nodes
-- allowed in the scene graph, so allocation might fail.
	local cr = 0;
	local cc = 0;

-- this is where we assume uniformly shaped buttons, for certain
-- cases, say, touchbar, we might want wider cells and cover other
-- forms of allocation and traversal
	for i=1,tbl.rows*tbl.cols do
		local cell = null_surface(tbl.cell_w, tbl.cell_h);

-- limited amount of vids. this can realistically fail so go with
-- a best effort basis
		if valid_vid(cell) then
			rendertarget_attach(buf, cell, RENDERTARGET_DETACH);
			link_image(cell, bg);
			order_image(cell, 2);
			move_image(cell, cc * tbl.cell_w, cr * tbl.cell_h);

			table.insert(tbl.buttons, {vid = cell, action = function() end});
			cc = cc + 1;
			if cc == tbl.cols then
				cc = 0;
				cr = cr + 1;
			end
		end
	end
	tbl.bg = bg;
end

primary_handler = function(tbl, source, status, iotbl)
-- got the requested output, build the offscreen composition
	if status.kind == "registered" then
		if status.segkind ~= "encoder" then
			return reset_cp(tbl, source);
		end

		tbl.active = true;
		log("name=streamdeck:kind=registered:cp=" .. tbl.name);
		build_rendertarget(tbl, source);
		relayout_grid(tbl);

-- the button presses
	elseif status.kind == "input" then
-- only go with 'on-rising press'
		if iotbl.digital and iotbl.active then
			local button = tbl.buttons[iotbl.subid];
			if not button then
				return;
			end
			button = button.action;

-- ok, we have something to dispatch, prepare for custom hooks
			if type(button) == "function" then
				button(tbl, source);

-- and normal symbol dispatch into the menu system
			elseif type(button) == "string" then
				dispatch_symbol(button);
			end
		end

-- on client initiated termination, we re-open the connection
-- point and go from there
	elseif status.kind == "terminated" then
		reset_cp(tbl, source);
	end
end

-- we need hooks to determine when to rebuild the button mapping. The slightly
-- problematic part is that frame delivery status is not actively tracked so we
-- don't know when to rebuild workspace previews. This should probably be
-- solved in the tiler layer.
local hooks_active = false;
local function rebuild_all()
	log("name=streamdeck:kind=rebuild");
	for _, v in ipairs(cps) do
		if valid_vid(v.vid) then
			relayout_grid(v);
		end
	end
end

local function hook_tiler(tiler)
	table.insert(tiler.on_wnd_create, rebuild_all);
	table.insert(tiler.on_wnd_destroy, rebuild_all);
	table.insert(tiler.on_wnd_select, rebuild_all);
end

local function enable_hooks()
	if hooks_active then
		return;
	end

-- need to handle events on all displays
	for tiler in all_tilers_iter() do
		hook_tiler(tiler);
	end

-- and track those that are hotplugged
	tiler_create_listener(
	function()
		hook_tiler(tiler);
	end);

	hooks_active = true;
end

local function add_cpoint(ctx, val)
	local tbl = {
		name = val,
	};

	table.insert(cps, {
		name = val,
		vid = vid,
		cell_w = 72,
		cell_h = 72,
		rows = 3,
		cols = 5,
		font_sz = 6,
		density = 36.171,
		show_labels = true,
		background = nil,
		rotation = 0,
		opacity = 1.0,
		custom = {},
		priorities = {},
		buttons = {}
	});
end

local function gen_destroy_menu()
	local res = {};
	for i,v in ipairs(cps) do
		table.insert(res, {
			name = v.name,
			kind = "action",
			label = v.name,
			description = "Close the " .. v.name .. " connection point",
			handler = function()
-- since the table might be modified with the menu not rebuild, the index might
-- have changed between building the closure and invoking it, so search
				for j,k in ipairs(cps) do
					if k == v then
						delete_image(v.vid);
						table.remove(cps, j);
						return;
					end
				end
			end
		});
	end
end

local function close_cpoint(name)
	local i = table.find_key_i(cps, "name", name);
	if not i then
		return;
	end
	if valid_vid(cps[i].vid) then
		delete_image(cps[i].vid);
	end
	table.remove(cps, i);
end

local function valid_constraints(val, name, tbl)
	local tmp = {};
	val = tonumber(val);
	if not val or val <= 0 then
		return false;
	end

	for k,v in pairs(tbl) do
		tmp[k] = v;
	end

	tmp[name] = val;
	if tmp.cell_w * tmp.cols > MAX_SURFACEW then
		return false;
	end
	if tmp.cell_h * tmp.rows > MAX_SURFACEH then
		return false;
	end
	if tmp.cell_w < 8 or tmp.cell_h < 8 or
		tmp.cell_w >= 256 or tmp.cell_h >= 256 then
		return false;
	end
	return true;
end

local function gen_map_tbl(tbl, key, label, desc)
	if not tbl.priorities[key] then
		tbl.priorities[key] = 0;
	end

	return {
		name = key,
		label = label,
		kind = "value",
		hint = "(priorities, 0 <= n <= 5))",
		initial = function()
			return tostring(tbl.priorities[key]);
		end,
		validator = gen_valid_num(0, 5),
		description = desc,
		handler = function(ctx, val)
			log("name=streamdeck:kind=set_priority:key=" .. key .. ":value=" .. val);
			tbl.priorities[key] = tonumber(val);
			if tbl.update then
				tbl:update();
			end
		end
	};
end

local function gen_map_menu(tbl)
	local res = {};
	res[1] = gen_map_tbl(tbl, "titlebar", "Titlebar", "Current window titlebar buttons");
	res[2] = gen_map_tbl(tbl, "labels", "Labels", "Current window input labels");
	res[3] = gen_map_tbl(tbl, "custom", "Custom", "Custom button bindings");
	res[4] = gen_map_tbl(tbl, "windows", "Windows", "Current workspace windows");
	return res;
end

local function gen_cpoint_menu(name, tbl)
	local res = {};
	table.insert(res, {
		name = "open",
		kind = "action",
		label = "Open",
		eval = function()
			return not valid_vid(tbl.vid);
		end,
		description = "Bind the connection point and start accepting connections",
		handler = function()
			log("name=streamdeck:kind=open:cp=" .. tbl.name);
			enable_hooks();
			reset_cp(tbl, BADID);
		end
	});
	table.insert(res, {
		name = "destroy",
		kind = "action",
		label = "Destroy",
		eval = function()
			return valid_vid(tbl.vid);
		end,
		description = "Remove connection point definition and terminate any active connections",
		handler = function()
			close_cpoint(name);
		end
	});
	table.insert(res, {
		label = "Mapping",
		description = "Control how content and state gets mapped and displayed on the connected device",
		name = "mapping",
		kind = "action",
		submenu = true,
		handler = function()
			return gen_map_menu(tbl);
		end
	});
	table.insert(res, {
		name = "rows",
		kind = "value",
		description = "Change the number of button rows",
		initial = function()
			return tostring(tbl.rows);
		end,
		hint = "(n > 0)",
		validator = function(val)
			return valid_constraints(val,	"rows", tbl);
		end,
		handler = function(ctx, val)
			tbl.rows = tonumber(val);
		end
	});
	table.insert(res, {
		name = "cols",
		kind = "value",
		description = "Change the number of button cols",
		initial = function() return tostring(tbl.cols); end,
		hint = "(n > 0)",
		validator = function(val)
			return valid_constraints(val, "cols", tbl);
		end,
		handler = function(ctx, val)
			tbl.cols = tonumber(val);
		end
	});
	table.insert(res, {
		name = "rotation",
		kind = "value",
		description = "Set cell rotation",
		initial = function() return tostring(tbl.rotation); end,
		hint = "(-180..180)",
		validator = gen_valid_num(-180, 180),
		handler = function(ctx, val)
			tbl.rotation = tonumber(val);
		end
	});
	table.insert(res, {
		name = "cell_w",
		kind = "value",
		description = "Change the pixel width for each button",
		initial = function() return tostring(tbl.cell_w); end,
		hint = "(8 <= n < 256)",
		validator = function(val)
			return valid_constraints(val, "cell_w", tbl);
		end,
		handler = function(ctx, val)
			tbl.cell_w = tonumber(val);
		end
	});
	table.insert(res, {
		name = "cell_h",
		kind = "value",
		description = "Change the pixel height for a button",
		initial = function() return tostring(tbl.cell_h); end,
		hint = "(8 <= n < 256)",
		validator = function(val)
			return valid_constraints(val, "cell_h", tbl);
		end,
		handler = function(ctx, val)
			tbl.cell_h = tonumber(val);
		end
	});
	table.insert(res, {
		name = "custom",
		kind = "value",
		description = "Add a new custom item binding",
		widget = "special:icon",
		validator = function(val)
			return suppl_valid_vsymbol(val);
		end,
		handler = function(ctx, val)
			dispatch_symbol_bind(
			function(path)
				if not path or #path == 0 then
					return;
				end
				table.insert(ctx.custom, {val, path});
			end);
		end
	});
	return res;
end

local function gen_cpoints_menu()
	local res = {};
	for k,v in ipairs(cps) do
		table.insert(res, {
			name = v.name,
			label = v.name,
			description = "Modify connection point '" .. v.name,
			kind = "action",
			submenu = true,
			handler = gen_cpoint_menu(v.name, v)
		});
	end
	return res;
end

local menu = {
	{
		name = "define",
		kind = "value",
		label = "Define",
		validator = function(val)
			for k,v in ipairs(cps) do
				if v.name == val then
					return false;
				end
			end
			return strict_fname_valid(val);
		end,
		description = "Bind a named connection point for the device handler",
		hint = "(a-Z_0-9)",
		handler = add_cpoint
	},
	{
		label = "Connection Points",
		name = "cpoints",
		kind = "action",
		submenu = true,
		eval = function()
			return #cps > 0;
		end,
		description = "Open/Close or change settings for defined connection points",
		handler = function(ctx, val)
			return gen_cpoints_menu();
		end
	},
};

menus_register("global", "tools",
{
	name = "streamdeck",
	label = "Stream Deck",
	description = "Support for ElGato Stream- Deck like devices",
	kind = "action",
	submenu = true,
	handler = menu
});

