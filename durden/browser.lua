-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Brower covers a lbar- based resource picker for
-- existing resources.

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

local function browse_cb(ctx, instr, done, lastv)
	if (done) then
		if (instr == "..") then
			local path = ctx.path;
			if (#path > ctx.minlen) then
				table.remove(path, #path);
			end
			browse_file(path, ctx.fltext, ctx.namespace, ctx.trigger, 0);
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
				fn(pn);
			elseif (ctx.trigger) then
				ctx.trigger(pn);
			end
		end
		return;
	end

-- glob and tag the resulting table with the type
	local path = table.concat(ctx.path, "/");
	if (ctx.paths[path] == nil) then
		ctx.paths[path] = glob_resource(path .. "/*", ctx.namespace);
		ctx.paths[path] = ctx.paths[path] and ctx.paths[path] or {};
		for i=1,#ctx.paths[path] do
			local elem = ctx.paths[path][i];
			local ign;
		 	ign, ctx.paths[path][elem] = resource(elem, ctx.namespace);
		end
	end

-- sweep through and color code accordingly, filter matches
	local mlbl = gconfig_get("lbar_menulblstr");
	local msellbl = gconfig_get("lbar_menulblselstr");
	local res = #ctx.path > ctx.minlen and {".."} or {};
	for i,v in ipairs(ctx.paths[path]) do
		if (ctx.paths[path][v] == "directory") then
			table.insert(res, {mlbl, msellbl, v});
		else
		if (string.sub(v,1,string.len(instr)) == instr
			and match_ext(v, ctx.fltext)) then
				table.insert(res, v);
			end
		end
	end
	return {set = res, valid = false};
end

function browse_file(pathtbl, extensions, mask, donecb, tblmin)
	active_display():lbar(browse_cb, {
		base = prefix,
		path = pathtbl,
		paths = {},
		minlen = tblmin ~= nil and tblmin or #pathtbl,
		fltext = extensions,
		namespace = mask,
		trigger = donecb
	}, {force_completion = true});
end
