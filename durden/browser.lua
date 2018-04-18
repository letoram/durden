-- Copyright: 2015-2018, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Brower covers a lbar- based resource picker for
-- existing resources.

local last_path = {};
local last_min = 0;
local last_rest = {};

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

local sort_mode = sort_az_nat;
local sort_lut = {
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

local function match_ext(v, tbl)
	if (tbl == nil) then
		return true;
	end

	local ext = string.match(v, "^.+(%..+)$");
	ext = ext ~= nil and string.sub(ext, 2) or ext;
	if (ext == nil or string.len(ext) == 0) then
		return false;
	end

	if (tbl[string.lower(ext)]) then
		return tbl[ext];
	else
		return tbl["*"];
	end
end

local browser_path = menu_path_new();

local function step_up(ctx)
	local path = ctx.path;
	if (#path > ctx.minlen) then
		table.remove(path, #path);
	end
-- already manage path and dont need from path stack, but want lbar state
	local op, octx = browser_path:pop();
	browse_file(path, ctx.fltext,
		ctx.namespace, ctx.trigger, 0, {restore = octx});
end

local old_timer;
local function drop_timer()
	_G[APPLID .. "_clock_pulse"] = old_timer;
	old_timer = nil;
end

-- preview handler and browse timer works in tandem,
-- preview handler is activated on new selection which checks the
-- set for an available preview function. It stores needed metadata
-- in a shared context that is activated / reset in the tick counter.
-- this is done in order to have a delay (as load+decode is costly
-- and shouldn't happen immediately on new selection).
local function preview_handler(ctx, index, lastset, anchor, xofs, basew, mh)
	if (index == nil or index == -1) then
		if (ctx.cb_ctx.in_preview) then
			for k,v in ipairs(ctx.cb_ctx.in_preview) do
				v:destroy();
			end
			ctx.cb_ctx.in_preview = {};
		end
		return;
	end

-- this is also called when the active set has changed, so filter
-- and reset / reload, any source material caching is up to the preview-h
	if (ctx.cb_ctx.preview and ctx.cb_ctx.preview.used) then
		if (#lastset ~= ctx.cb_ctx.preview.count) then
			for k,v in ipairs(ctx.cb_ctx.in_preview) do
				v:destroy();
			end
			ctx.cb_ctx.in_preview = {};
		end
	end

	if (ctx.cb_ctx.in_preview and lastset[index] and
		type(lastset[index]) == "table" and lastset[index][4]) then
			ctx.cb_ctx.preview = {
				trigger = lastset[index][4],
				xofs = xofs,
				anchor = anchor,
				basew = basew,
				name = lastset[index][3],
				count = #lastset,
				mh = mh
			};
	end
end

local function browser_timer(ctx)
	ctx.counter = ctx.counter + 1;
	if (ctx.counter > gconfig_get("browser_timer")
		and ctx.preview and not ctx.preview.used) then
		local res = ctx.preview.trigger(table.concat(ctx.path, "/"),
			ctx.preview.name,
			ctx.namespace,
			ctx.preview.anchor,
			ctx.preview.xofs,
			ctx.preview.basew,
			ctx.preview.mh
		);
		ctx.preview.used = true;
		if (res) then
			table.insert(ctx.in_preview, res);
		end
	end
end

local function flt_prefix(val, instr)
	return (string.sub(val,1,string.len(instr)) == instr);
end

local function flt_ptn(val, instr)
	local stat, res = pcall(string.match, val, instr);
	if (not stat) then
	else
		return res;
	end
end

local function browse_cb(ctx, instr, done, lastv, inpctx)
	ctx.counter = 0;
	instr = instr and instr or "";

	if (done) then
		drop_timer();
		if (ctx.subst) then
-- drop substitution state, rerun current path
			ctx.subst = false;
			if (sort_lut[instr]) then
				sort_lut[instr]();
			end
			browse_file(ctx.path, ctx.fltext,
				ctx.namespace, ctx.trigger, 0, {restore = ctx});
			return;
		end

-- first, special cases
		if (instr == "..") then
			step_up(ctx);
			return;

-- drop cached and retry
		elseif (instr == ".") then
			ctx.paths[ctx.path] = nil;
			browse_file(ctx.path, ctx.fltext,
				ctx.namespace, ctx.trigger, 0, {restore = ctx});
			return;

-- reset the path tracking entirely
		elseif (instr == "/") then
			browser_path:reset();
			browse_file(ctx.initial, ctx.fltext, ctx.namespace, ctx.trigger, 0);
			return;
		end

-- block traversal
		string.gsub(instr, "..", "");
		local pn = string.format("%s/%s", table.concat(ctx.path, "/"), instr);
		local r, v = resource(pn, ctx.namespace);
		if (v == "directory") then
			table.insert(ctx.path, instr);
-- if we filtered down to only one entry and .. then just reset to the path
			if (#lastv == 2) then
				inpctx = {};
			end
			browser_path:append(instr, instr, inpctx);
			browse_file(ctx.path, ctx.fltext, ctx.namespace, ctx.trigger, 0);
		else
			local fn = match_ext(pn, ctx.fltext);
			if (type(fn) == "function") then
				fn(pn, ctx.path);
			elseif (type(fn) == "table") then
				fn.run(pn, ctx.path);
			elseif (ctx.trigger) then
				ctx.trigger(pn, ctx.path);
			end
			local m1, m2 = dispatch_meta();
			if (m1) then
				browse_file(ctx.path, ctx.fltext, ctx.namespace, ctx.trigger, 0,
					{restore = inpctx});
			else
				browser_path:reset();
			end
		end
		return;
	end

-- glob and tag the resulting table with the type, current solution isn't
-- ideal as this may be I/O operations stalling heavily on weird filesystems
-- so we need an asynch glob_resource and all the problems that come there.
	last_path = ctx.path;
	last_min = ctx.minlen;
	last_rest = inpctx;

	local path = table.concat(ctx.path, "/");
	if (ctx.paths[path] == nil) then
		ctx.paths[path] = glob_resource(path .. "/*", ctx.namespace);
		ctx.paths[path] = ctx.paths[path] and ctx.paths[path] or {};
		for i=1,#ctx.paths[path] do
			local elem = ctx.paths[path][i];
			local ign;
		 	ign, ctx.paths[path][elem] = resource(path .. "/" .. elem, ctx.namespace);
		end
	end

-- sweep through and color code accordingly, filter matches
	local mlbl = gconfig_get("lbar_menulblstr");
	local msellbl = gconfig_get("lbar_menulblselstr");
	local res = {};

-- first, just populate the list of candidates based on filter and/or type,
-- use a special % namespace for switching filter modes, search results etc.
	local filter = flt_prefix;
	local lstr = string.len(instr);
	ctx.subst = false;

-- * is more intuitive wildcard, so substitute that with %.* pattern
	if (lstr > 0) then
		if (string.find(instr, "%*")) then
			filter = flt_ptn;
			instr = string.gsub(instr, "%*", "%%.%*");

-- but if we start with double %%, switch to pattern mode
		elseif (string.sub(instr, 1, 2) == "%%") then
			filter = flt_ptn;
			instr = string.sub(instr, 3);

-- and only one? substitute with commands
		elseif (string.sub(instr, 1, 1) == "%") then
			ctx.subst = true;
			for k,v in pairs(sort_lut) do table.insert(res, k); end
		end
	end

-- optional: set helper based on input string (hover timer)
	local dirc = 1;
	if (not ctx.subst) then
	for i,v in ipairs(ctx.paths[path]) do
			if (ctx.paths[path][v] == "directory" and filter(v, instr)) then
				table.insert(res, dirc, {mlbl, msellbl, v});
				dirc = dirc + 1;
			else
				local ext = match_ext(v, ctx.fltext);
				if (ext and filter(v, instr)) then
-- if extension comes with color hint, use that
					if (type(ext) == "table") then
						table.insert(res, {ext.col, ext.selcol, v, ext.preview});
					else
						table.insert(res, v);
					end
			end
		end
	end
	end

-- sort now
	if (not ctx.subst and type(sort_mode) == "function") then
		table.sort(res, sort_mode);
	elseif (not ctx.subst and type(sort_mode) == "string") then
		if (sort_mode == "random") then
			local size = #res;
			for i=size,1,-1 do
				local rand = math.random(size);
				res[i], res[rand] = res[rand], res[i];
			end
		end
	end

-- add .. to the alternatives
	if (not ctx.subst and instr ~= "..") then
		table.insert(res, ".");
	end

	if (not ctx.subst and dpath ~= ctx.initial) then
		table.insert(res, "..");
	end

	return {set = res, valid = false};
end

function browse_file(pathtbl, extensions, mask, donecb, tblmin, opts)
	opts = opts and opts or {};

-- first determine if we should just try and restore the last path
-- visited or if we should start a new session
	if (not pathtbl) then
		pathtbl = last_path;
		tblmin = last_min;
		if (not opts.restore) then
			opts.restore = last_rest;
		end
		local tp = {};
		if (table.concat(browser_path.path, "/") ~=
			table.concat(pathtbl, "/")) then
			local tp = {};
			for i=1,#pathtbl do
				table.insert(tp, {pathtbl[i], pathtbl[i]});
			end
			browser_path:force(tp);
		end
	end

	local dup = {};

	for k,v in ipairs(pathtbl) do dup[k] = v; end

	local lbctx = {
		base = prefix,
		path = pathtbl,
		initial = dup,
		paths = {},
		counter = 0,
		minlen = tblmin ~= nil and tblmin or #pathtbl,
		fltext = extensions,
		namespace = mask,
		trigger = donecb,
		in_preview = {},
		opts = opts
	};

-- extend lbar so that we can cleanup allocations made for handling previews
	local lbar = active_display():lbar(browse_cb, lbctx,
		{force_completion = true, restore = opts.restore,
		on_step = preview_handler});

	lbar.on_cancel = function()
		if (valid_vid(lbctx.preview_del)) then
			delete_image(lbctx.preview_del);
		end
		browser_path:reset();
		drop_timer();
		local m1, m2 = dispatch_meta();
		if (m1) then
			step_up(lbctx);

-- forward cancel so the queue may be processed
		elseif (extensions.on_cancel) then
			extensions:on_cancel();
		end
	end

-- a little hack to be able to add meta + direction handling,
-- this is to be used for filter (prefix, regex) and preview mode switching
-- (simple/advance) and for playlist management (add- to queue)
	lbar.meta_handler =
	function(ctx, sym, iotbl, lutsym, meta)
		if (sym == SYSTEM_KEYS["next"]) then
			if (extensions.on_queue) then
				return extensions:on_queue("lastfile");
			end
		elseif (sym == SYSTEM_KEYS["previous"]) then
			if (extensions.on_queue) then
				return extensions:on_queue();
			end
		elseif (sym == SYSTEM_KEYS["right"]) then
			if (extensions.on_preview) then
				return extensions:on_preview(true);
			end
		elseif (sym == SYSTEM_KEYS["left"]) then
			if (extensions.on_preview) then
				return extensions:on_preview(false);
			end
		end
	end

-- need to hook a timer to have some delay before switching to preview
	old_timer = _G[APPLID .. "_clock_pulse"];
	_G[APPLID .. "_clock_pulse"] = function(...)
		browser_timer(lbctx); old_timer(...);
	end
end
