-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Brower covers a lbar- based resource picker for
-- existing resources.

local last_path = {};
local last_min = 0;

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

local function browse_cb(ctx, instr, done, lastv, inputv)
	if (done) then
		if (inputv == "/") then
			while (#ctx.path > ctx.minlen) do
				table.remove(ctx.path, #ctx.path);
			end
			browser_path:reset();
			browse_file(ctx.path, ctx.fltext, ctx.namespace, ctx.trigger, 0);
			return;
		end
		if (instr == "..") then
			local path = ctx.path;
			if (#path > ctx.minlen) then
				table.remove(path, #path);
			end
			browser_path:pop();
			browse_file(path, ctx.fltext, ctx.namespace, ctx.trigger, 0);
			return;
		elseif (instr == "/") then
			browse_file(ctx.initial, ctx.fltext, ctx.namespace, ctx.trigger, 0);
			return;
		end

		string.gsub(instr, "..", "");
		local pn = string.format("%s/%s", table.concat(ctx.path, "/"), instr);
		local r, v = resource(pn, ctx.namespace);
		if (v == "directory") then
			table.insert(ctx.path, instr);
			browse_file(ctx.path, ctx.fltext, ctx.namespace, ctx.trigger, 0);
		else
			local fn = match_ext(pn, ctx.fltext);
			if (type(fn) == "function") then
				fn(pn, ctx.path);
			elseif (type(fn) == "table") then
				fn[1](pn, ctx.path);
			elseif (ctx.trigger) then
				ctx.trigger(pn, ctx.path);
			end
			local m1, m2 = dispatch_meta();
			if (m1) then
				browse_file(ctx.path, ctx.fltext, ctx.namespace, ctx.trigger, 0);
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
						table.insert(res, {ext[2], ext[3], v});
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
	if (not pathtbl) then
		pathtbl = last_path;
		tblmin = last_min;
	end

	local dup = {};
	for k,v in ipairs(pathtbl) do dup[k] = v; end
	active_display():lbar(browse_cb, {
		base = prefix,
		path = pathtbl,
		initial = dup,
		paths = {},
		minlen = tblmin ~= nil and tblmin or #pathtbl,
		fltext = extensions,
		namespace = mask,
		trigger = donecb,
		opts = opts and opts or {},
	}, {force_completion = true});
end
