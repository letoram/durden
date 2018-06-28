-- Description:
--
-- menu related management functions, depends on the lbar- ui suppl
-- script for the input management and UI components
-- this also takes care of binding helpers and widget activation
--

local menu_hook;
local cpath = uiprim_buttonlist();
local menu_path_pop;
cpath = uiprim_buttonlist();

local function sort_az(a, b)
	return
		string.lower((type(a) == "table" and a[3] or a)) <
		string.lower((type(b) == "table" and b[3] or b));
end

-- like a normal sort, but the case of
-- a1.jpg a11.jpg a2.jpg becomes
-- a1.jpg a2.jpg a11.jpg
local function sort_az_nat(a, b)
-- extract the strings
	a = type(a) == "table" and a[3] or a;
	b = type(b) == "table" and b[3] or b;

-- find first digit point
	local s_a, e_a = string.find(a, "%d+");
	local s_b, e_b = string.find(b, "%d+");

-- if they exist and are at the same position
	if (s_a ~= nil and s_b ~= nil and s_a == s_b) then

-- extract and compare the prefixes
		local p_a = string.sub(a, 1, s_a-1);
		local p_b = string.sub(b, 1, s_b-1);

-- and if those match, compare the values
		if (p_a == p_b) then
			return
				tonumber(string.sub(a, s_a, e_a)) <
				tonumber(string.sub(b, s_b, e_b));
		end
	end

-- otherwise normal a-Z
	return string.lower(a) < string.lower(b);
end

local function sort_za(a, b)
	return
		string.lower((type(a) == "table" and a[3] or a)) >
		string.lower((type(b) == "table" and a[3] or b));
end

local sort_mode = "normal";
local sort_lut = {
["normal"] = function()
	sort_mode = "normal";
end,
["random"] = function()
	sort_mode = "random";
end,
["numeric(a->Z)"] = function()
	sort_mode = sort_az;
end,
["natural(a->Z)"] = function()
	sort_mode = sort_az_nat;
end,
["reverse(Z->a)"] = function()
	sort_mode = sort_za;
end
};

local function flt_prefix(val, instr)
	return (
		string.lower(
			string.sub(val,1,string.len(instr))) == string.lower(instr));
end

local function flt_ptn(val, instr)
	local stat, res = pcall(string.match, val, instr);
	if (not stat) then
	else
		return res;
	end
end

local function run_hook(path)
	if (not menu_hook) then
		return true;
	else
		local ch = menu_hook;
		menu_hook = nil;
		ch(path);
		cpath:reset();
		return false;
	end
end

-- preview handler cleanup function
local function flush_phs(lbar, active_phs)
	local torem = {};

	for k,v in pairs(active_phs) do
		if (v.clock ~= lbar.ucount) then
			table.insert(torem, k);
		end
	end
	for _,v in ipairs(torem) do
		active_phs[v]:update(nil);
		active_phs[v] = nil;
	end
end

--
-- multiple reasons that will put us here:
-- normal menu -> escape
-- normal menu -> commit invalid entry
-- normal menu -> m1 + select -> return
-- normal menu -> value -> return
-- normal menu -> value
--
local function menu_cancel(wm, m1_overr, dangerous)
	local m1, m2 = dispatch_meta();

-- the dangerous path is a special one, and that if is there is a menu
-- path that will perform state transition on activation in the chain,
-- as "going up" would reactivate that one. Can possibly be deprecated
-- but needs investigating.
	if ((m1 or m1_overr) and not dangerous) then
		local path, ictx = cpath:pop();
		dispatch_symbol(path, {restore = ictx});
	else
		run_hook(cpath:get_path());
		cpath:reset();
		iostatem_restore();
	end
end

--
-- special case for value input where there is a set of permitted values
--
local function set_input(ctx, instr, done, lastv)
	local m1, m2 = dispatch_meta();
	if (not done) then
		local dset = ctx.set;
		if (type(ctx.set) == "function") then
			dset = ctx.set();
		end

		return {set = table.i_subsel(dset, instr)};
	end

-- let the presence of a menu hook handler decide where we go
	if (run_hook(cpath:get_path() .. "=" .. instr)) then
		if (ctx.handler) then
			ctx:handler(instr);
		else
			warning("broken menu entry");
		end

		local m1, m2 = dispatch_meta();
		menu_cancel(active_display(), false, ctx.dangerous);
	end
end

--
-- special case of input where a value is queried, and both a help
-- function is present, a label that indicates initial / current state,
-- a feedback color to help validation etc.
--
local function value_entry_input(ctx, instr, done, lastv)
	if (not done) then
		if (ctx.validator ~= nil and not ctx.validator(instr)) then
			return false;
		end

		if (ctx.helpsel) then
			return {set = table.i_subsel(ctx:helpsel(), instr)};
		end

		return true;
	end

-- special treatment
	if (instr == "..") then
		menu_cancel(active_display(), true, ctx.dangerous);
		return;
	end

-- validate if necessary
	if (ctx.validator ~= nil and not ctx.validator(instr)) then
		menu_hook = nil;
		cpath:reset();
		return;
	end

-- slightly more cumbersome as we need to handle all permuations of
-- hook_on/off, valid but empty string with menu item default value
	if (not instr) then
		cpath:reset();
		return;
	end

	if (not run_hook(cpath:get_path() .. "=" .. instr)) then
		return;
	end

	menu_cancel(active_display(), false, ctx.dangerous);
	ctx:handler(instr);
end

-- set a temporary hook that will override menu navigation
-- and instead send the path to the specified function one time
function menu_hook_launch(fun)
	menu_hook = fun;
end

local function query_value(ctx, mask)
	local hintstr = string.format("%s %s %s",
		ctx.label and ctx.label or "",
		ctx.initial and ("[ " .. (type(ctx.initial) == "function"
			and tostring(ctx.initial()) or ctx.initial) .. " ] ") or "",
		ctx.hint and ((type(ctx.hint) == "function"
		and ctx.hint() or ctx.hint) .. ":") or ""
	);

-- explicit set to chose from?
	local res;
	if (ctx.set) then
		res = active_display():lbar(set_input,
			ctx, {label = hintstr, force_completion = true, prefill = ctx.prefill});
	else
-- or a "normal" run with custom input and validator feedback
		res = active_display():lbar(
			value_entry_input, ctx, {password_mask = mask, label = hintstr});
	end
	if (not res.on_cancel) then
		res.on_cancel = menu_cancel;
	end
	return res;
end

local function update_menu(ctx, instr, lastv, inp_st)
-- special case, control character
	local res = {};
	local lstr = string.len(instr);
	local flt_fun = flt_prefix;
	ctx.subst = false;

	if (lstr > 0) then
-- * is a more intuitive wildcard, so substitute that with %.* pattern
		if (string.find(instr, "%*")) then
			flt_fun = flt_ptn;
			instr = string.gsub(instr, "%*", "%%.*");
-- but if we start with double %%, switch to pattern mode
		elseif (string.sub(instr, 1, 2) == "%%") then
			flt_fun = flt_ptn;
			instr = string.sub(instr, 3);

-- only one? substitute with commands
		elseif(string.sub(instr, 1, 1) == "%") then
			ctx.subst = true;
			for k,v in pairs(sort_lut) do
				table.insert(res, k);
			end
		end
	end

-- generate the subset of fields from the expected range
	local subs = ctx.list;
	local mlbl = gconfig_get("lbar_menulblstr");
	local msellbl = gconfig_get("lbar_menulblselstr");

-- all the conditions that determine visibility based on context (binding, ...)
-- it is written against the ideal of 'interactive user' but that isn't right
-- when binding to keys vs. timers vs..
	local filter = function(a)
		if (not flt_fun(a.label, instr)) then
			return false;
		end

		if (a.invisible and not ctx.show_invisible) then
			return false;
		end
		if (a.block_external and ctx.block_external) then
			return false;
		end
		return (not a.eval or a.eval(ctx.handler, instr));
	end

-- and filter these through the possible eval() function
	inp_st.lastm = {};
	for _,v in ipairs(subs) do
		if (filter(v)) then
			if (v.submenu) then
				table.insert(res, {mlbl, msellbl, v.label});
			else
				if (v.format and v.select_format) then
					table.insert(res, {v.format, v.select_format, v.label});
				else
					table.insert(res, v.label);
				end
			end
-- save a copy to the eval:ed table itself so we can show a help description
			table.insert(inp_st.lastm, v);
		end
	end

	if (type(sort_mode) ~= "string") then
		table.sort(res, sort_mode);
	else
		if (sort_mode == "random") then
			local sz = #res;
			for i=sz,1,-1 do
				local rand = math.random(sz);
				res[i], res[rand] = res[rand], res[i];
			end
		end
	end

	if (not ctx.subst) then
		table.insert(res, "..");
	end

	return {
		set = res, valid = false
	};
end

-- event handler hook to deal with 'meta-launch' destroying and rebuilding/
-- resuming the menu with preview handlers intact edge case
local function lbar_create(lbar, old_state)
	if (not old_state or not old_state.active_phs) then
		return;
	end

-- just set the state and relink, after on_create an input/refresh will
-- trigger which will verify against the existing state and prune
	lbar.active_phs = old_state.active_phs;
	for k,v in pairs(old_state.active_phs) do
		if (valid_vid(v.vid)) then
			link_image(v.vid, lbar.text_anchor);
		end
	end
end

--
-- This is the main input handler for the 'launch bar' used for mixing
-- CLI style input with menu selection.
--
local function normal_menu_input(ctx, instr, done, lastv, inp_st)
	if (not done) then
		return update_menu(ctx, instr, lastv, inp_st);
	end

-- we have had the substituted input (mode selection prefix), change the
-- global sorting method, question is if this should be applied to /browse/x/
-- only, as the random etc. make little sense.
	if (ctx.subst) then
		ctx.subst = false;
		if (sort_lut[instr]) then
			sort_lut[instr]();
		end
		dispatch_symbol(cpath:get_path(), {});
		return;
	end

-- some action that would cause the lbar to terminate, first take the 'cancel'
-- option that requests us to go back to the previously active path
	if (instr == "..") then
		menu_cancel(active_display(), true, ctx.dangerous);
		return;
	end

-- activation, find the matching label - if there's a mismatch, cancel hard
	local tgt = nil;
	for k,v in ipairs(ctx.list) do
		if (v.label and string.lower(v.label) == string.lower(instr)) then
			tgt = v;
		end
	end
	if (tgt == nil) then
		cpath:reset();
		return;
	end

-- we should query the user for an input value, unless there's a hook and
-- we explicitly want to bind the value-query and not the final value
	local m1, m2 = dispatch_meta();

	if (tgt.kind == "value") then
		cpath:push(tgt.name, tgt.label, inp_st);
		if (m1 and not run_hook(cpath:get_path())) then
			return;
		else
			return query_value(tgt, tgt.password_mask);
		end
	end

-- alias path just triggers dispatch, which will resolve a new menu chain
	if (tgt.alias) then
		cpath:reset();
		local path = type(tgt.alias) == "function" and tgt.alias() or tgt.alias;
		if (menu_hook) then
			run_hook(path);
			return;
		end
		dispatch_symbol(path);
		if (tgt.handler) then
			tgt.handler();
		end
		return;
	end

	if (tgt.submenu) then
		if (m1 and menu_hook) then
			cpath:push(tgt.name, tgt.label, inp_st);
			run_hook(cpath:get_path());
			return;
		end

-- navigate down, generate dynamic menu if needed
		if (type(tgt.handler) == "function") then
			ctx.list = tgt.handler(ctx.handler);
		else
			ctx.list = tgt.handler;
		end

-- add a tag about the context that we used to get here so that
-- we can resume our previous state on meta+escape
-- cpath:set_tag({});

		menu_launch(ctx.wm, ctx, {}, cpath:get_path(true) .. tgt.name,
			function(path, index)
				return tgt.label;
			end);
		return;
	end

-- save the input and the menu state, this might not be needed if we
-- start going with the path always and just reconstructing the whole
-- chain
	if (not tgt.handler) then
		run_hook(nil);
		cpath:reset();
		return;
	end

-- actually run the menu path, to fix the whole mess with active_display()
-- needed in target menus, here is the point to instrument
	if (menu_hook) then
		cpath:push(tgt.name, tgt.label, inp_st);
		run_hook(cpath:get_path());
		return;
	end

	tgt.handler(ctx.handler, instr, ctx);

-- With m1 held, we just relaunch the same path we were at before the
-- action was activated.
	if (m1) then
		dispatch_symbol(cpath:get_path(), {
			restore = inp_st,
			on_create = lbar_create
		});

		return;
	end

	cpath:reset();
end

-- Check so that [table] match all the criteria for a valid table entry,
-- this is primarily used as a safeguard for dynamic script loading that
-- wants to make sure that the format is still compliant.
function menu_validate(table, prefix)
	prefix = prefix and prefix or "";

	if not type(table) == "table" then
		return false, (prefix .. "not a table");
	end

	local typektbl = {
		name = "string",
		label = "string",
		kind = "string",
		description = "string"
	};

	for k, v in pairs(typektbl) do
		if not table[k] then
			return false, (prefix .. " missing field: " .. k);
		elseif type(table[k]) ~= v then
			return false,
				string.format(
					"%s wrong type on: %s, expected: %s, got: %s", prefix, k, v, type(table[k]));
		end
	end

	if (table[kind] == "action") then
		if (table[submenu]) then
			if (type(table[handler]) == "function") then
-- could probably recurse suppl_menu_validate on the returned function, but since
-- these MAY be context sensitive (i.e. selected window) this is possibly bad and
-- marginally unusable, maybe as a pcall...
			elseif (type(table[handler]) == "table") then
				return menu_validate(table[handler], prefix .. "/" .. table[name]);
			else
				return false, (prefix .. " invalid type on submenu");
			end
		elseif (type(table[handler]) ~= "function") then
			return false, (prefix .. " handler is not a function");
		end
	end

-- not much that can be done here, set, initial, validator, eval are all optional,
-- should possibly have a verbose mode that exposes all these little things that
-- 'should be' there but isn't directly a failure
	if (table[kind] == "value") then
		if (type(table[handler]) ~= "function") then
			return false, (prefix .. " missing handler on value");
		end
	end

	return true;
end

function menu_default_lookup(tbl)
	return function(path, index, elem)
		if (tbl[index]) then
			return tbl[index], {};
		else
			return "broken", {};
		end
	end
end

--
-- Take a menu path and a context destination and return what it would
-- actually give you. This does not activate the path or set any value
-- itself, to do that, invoke the handler or run through menu_launch.
--
function menu_resolve(line, wnd)
	local ns = string.sub(line, 1, 1);
	if (ns ~= "/") then
		warning("ignoring unknown path: " .. line);
		return nil, "invalid namespace";
	end

	local path = string.sub(line, 2);
	local sepind = string.find(line, "=");
	local val = nil;
	if (sepind) then
		path = string.sub(line, 2, sepind-1);
		val = string.sub(line, sepind+1);
	end

	local items = string.split(path, "/");
	local menu = menus_get_root();
	if (path == "/" or path == "") then
		return menu;
	end

	local restbl = {};

	while #items > 0 do
		local ent = nil;
		if (not menu) then
			return nil, "missing menu", table.concat(items, "/");
		end

-- first find in current menu
		for k,v in ipairs(menu) do
			if (v.name == items[1]) then
				ent = v;
				break;
			end
		end
-- validate the fields
		if (not ent) then
			return nil, "couldn't find entry", table.concat(items, "/");
		end
		if (ent.eval and not ent.eval()) then
			return nil, "entry not visible", table.concat(items, "/");
		end

-- action or value assignment
		if (not ent.submenu) then
			if (#items ~= 1) then
				return nil, "path overflow, action node reached", table.concat(items, "/");
			end
-- it's up to the caller to validate
			if ((ent.kind == "value" or ent.kind == "action") and ent.handler) then
				return ent, "", val;
			else
				return nil, "invalid formatted menu entry", items[1];
			end

-- submenu, just step, though this can be dynamic..
		else
			if (type(ent.handler) == "function") then
				menu = ent.handler();
				table.insert(restbl, ent.label);
			elseif (type(ent.handler) == "table") then
				menu = ent.handler;
				table.insert(restbl, ent.label);
			else
				menu = nil;
			end
			table.remove(items, 1);
		end
	end
	return menu, "", val, restbl;
end

-- starting at [path], trigger callback when a value or handler is triggered,
-- set block_interactive to ignore paths that would produce user interactive
-- triggers like a region selection or binding bar.
function menu_bind(path, block_interactive, callback)
	local menu, msg, val, enttbl = menu_resolve(path);
	if (not menu) then
		callback(nil);
		return;
	end

	local menu_opts = {
		list = menu,
		show_invisible = true,
		block_external = block_interactive,

-- tracking additions to be able to manage previews and sorting
		counter = 0
	};

	menu_launch(active_display(), menu_opts, sym,
		function(path, index)
			if (enttbl[index]) then
				return enttbl[index], {};
			else
				return "broken", {};
			end
		end
	);
end

local function in_set(set, key)
	for _, v in ipairs(set) do
		local sk = type(v) == "table" and v[3] or v;
		if (sk and sk == key) then
			return true;
		end
	end
	return false;
end

-- [wm] should result to a valid tiler, like active_display() for the UI
-- [ctx] is the menu- specific UI behavior
-- [lbar_opts] is a table of other UI behavior controls that will be passed
--        to the corresponding lbar stage from uiprim.
-- [path] tells the current path to forward to cpath
function menu_launch(wm, ctx, lbar_opts, path, path_lookup)
	if (ctx == nil or ctx.list == nil or
		type(ctx.list) ~= "table" or #ctx.list == 0) then
		cpath:reset();
		return;
	end

	lbar_opts = lbar_opts and lbar_opts or {};

-- make sure at least one entry is valid
	local found = false;
	for i,v in ipairs(ctx.list) do
		if (v.eval == nil or v.eval()) then
			found = true;
			break;
		end
	end

	if (not found) then
		cpath:reset();
		return;
	end

	local menu_helper = gconfig_get("menu_helper");
	local last_i;

-- on_item is used to update selection state (could also be used to
-- preview everything immediately rather than on selection)
	lbar_opts.on_item =
	function(lbar, i, key, selected, anchor, ofs, width, last)
		if (not lbar.inp.lastm) then
			return;
		end

		local ent = table.find_key_i(lbar.inp.lastm, "label", key);
		if (ent) then
			ent = lbar.inp.lastm[ent];
		else
			if (last) then
				flush_phs(lbar, lbar.active_phs);
			end
			return;
		end
		local phk = lbar.active_phs[key];

-- if there's no preview on the item and it's selected, build it
-- this could be altereted to spawn previews on everything
-- immediately
		if (not phk) then
			if ((selected or gconfig_get("browser_trigger") ==
				"visibility") and ent.preview) then
				phk = ent:preview(anchor, ofs, width);
				lbar.active_phs[key] = phk;
			end
		end

-- update selection status and track when it was last seen so that
-- we can delete outdated items even when jumping between lbars
		if (phk) then
			phk.clock = lbar.ucount;
			phk:update(selected, ofs, width);
		end

		if (last) then
			flush_phs(lbar, lbar.active_phs);
		end
	end

-- needed to do this due to the legacy of on_cancel and the done
-- part to input callback, rougly speaking, due to all the paths
-- and the problems of "input done" -> internal destroy -> input
-- done callback -> spawning new lbars meaning that all anchored
-- previews would be dead from internal destroy yet we'd want to
-- use them if dispatch_meta is held on an non-menu action.
	lbar_opts.on_accept = function(lbar, accept)
		local m1, m2 = dispatch_meta();
		if (m1 and accept) then
			for k,v in pairs(lbar.active_phs) do
				if (valid_vid(v.vid)) then
					link_image(v.vid, v.vid);
				end
			end
			lbar.inp.active_phs = lbar.active_phs;
			lbar.active_phs = {};
		end
	end

	lbar_opts.on_step = function(lbar, i, key, anchor, ofs, w, mh)
		if (i == -1 or not i or not lbar.inp.lastm) then
			return;
		end

		local ent = table.find_key_i(lbar.inp.lastm, "label", key);
		if (ent) then
			ent = lbar.inp.lastm[ent];
		end

		if (menu_helper and ent and ent.description) then
			lbar:set_helper(ent.description);
		else
			lbar:set_helper("");
		end
	end

	lbar_opts.overlay = {
		active_phs = {}
	}

	ctx.wm = wm;

-- lbar/menu/tiler etc. was all written to be 'independent' and turned out
-- tightly coupled and just awfully messy. Refactor in baby steps.
	local bar = wm:lbar(normal_menu_input, ctx, lbar_opts);
	if (not bar) then
		return;
	end

-- activate any path triggered widget and synch helper buttons
	if (path) then
		cpath:set_path(path, path_lookup);
		suppl_widget_path(bar, bar.text_anchor, path);
		cpath.on_cancel = function()
			bar:destroy(true);
			menu_cancel(active_display(), true, false);
		end
	else
		cpath.on_cancel = function() end;
	end

-- there might be another 'on cancel' handler for specialized purposes,
-- but otherwise provide the default behavior
	suppl_chain_callback(bar, "on_cancel", menu_cancel);

	return bar;
end
