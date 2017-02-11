-- Copyright: 2015-2017, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Brower covers a lbar- based resource picker for
-- existing resources.

local last_path = {};
local last_min = 0;
local last_rest = {};

local function match_ext(v, tbl)
	if (tbl == nil) then
		return true;
	end

	local ext = string.match(v, "^.+(%..+)$");
	ext = ext ~= nil and string.sub(ext, 2) or ext;
	if (ext == nil or string.len(ext) == 0) then
		return false;
	end

	return tbl[ext];
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
	if (ctx.counter > 10 and ctx.preview and not ctx.preview.used) then
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

local function browse_cb(ctx, instr, done, lastv, inpctx)
	ctx.counter = 0;

	if (done) then
		drop_timer();
		if (instr == "..") then
			step_up(ctx);
			return;
		elseif (instr == "/") then
			browser_path:reset();
			browse_file(ctx.initial, ctx.fltext, ctx.namespace, ctx.trigger, 0);
			return;
		end

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

	for i,v in ipairs(ctx.paths[path]) do
		if (string.sub(v,1,string.len(instr)) == instr) then
			if (ctx.paths[path][v] == "directory") then
				table.insert(res, {mlbl, msellbl, v});
			else
				local ext = match_ext(v, ctx.fltext);
				if (ext) then
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

	table.insert(res, "..");
	return {set = res, valid = false};
end

function browse_file(pathtbl, extensions, mask, donecb, tblmin, opts)
	opts = opts and opts or {};

	if (not pathtbl) then
		pathtbl = last_path;
		tblmin = last_min;
		if (not opts.restore) then
			opts.restore = last_rest;
		end
		local tp = {};
		if (#browser_path.path ~= #pathtbl) then
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
		opts = opts
	};

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
		end
	end

	if (gconfig_get("preview_mode") == "auto") then
		lbctx.in_preview = {};
	end

-- a little hack to be able to add meta + direction handling,
-- this is to be used for filter (prefix, regex) and preview mode switching
-- (simple/advance) and for playlist management (add- to queue)
	lbar.meta_handler = function(wm, sym, iotbl, lutsym, meta)
		if (sym == SYSTEM_KEYS["caret_right"]) then
			if (not lbctx.in_preview) then
				lbctx.in_preview = {};
			end
			return true;
		elseif (sym == SYSTEM_KEYS["caret_left"]) then
			if (lbctx.in_preview) then
				for i,v in ipairs(lbctx.in_preview) do
					v:destroy();
				end
				lbctx.in_preview = nil;
			end
			return true;
		end
	end

-- need to hook a timer to have some delay before switching to preview
	old_timer = _G[APPLID .. "_clock_pulse"];
	_G[APPLID .. "_clock_pulse"] = function(...)
		browser_timer(lbctx); old_timer(...);
	end
end
