-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
--
-- Description: Basic clipboard handling, currently text only but there's
-- little stopping us from using more advanced input and output formats.
--

local function clipboard_add(ctx, source, msg, multipart)
	if (multipart) then
		if (ctx.mpt[source] == nil) then
			ctx.mpt[source] = {};
		end

-- simple cutoff to prevent nasty clients from sending multipart forever
		table.insert(ctx.mpt[source], msg);
		if (#ctx.mpt[source] < ctx.mpt_cutoff) then
			return;
		end
	end

-- quick-check for uri. like strings (not that comprehensive), store
-- in a separate global history that we can grab from at will
	if (string.len(msg) < 1024) then
		for k in string.gmatch(msg, "%a+://[^%s]+") do
			table.insert_unique_i(ctx.urls, 1, k);
			if (#ctx.urls > 10) then
				table.remove(ctx.urls, #ctx.urls);
			end
		end
	end

	if (ctx.mpt[source]) then
		msg = table.concat(ctx.mpt[source], "") .. msg;
		ctx.mpt[source] = nil;
	end

	if (ctx.locals[source] == nil) then
		ctx.locals[source] = {};
	end

-- default is promote to global, but less trusted won't be allowed to
	if (not ctx.locals[source].blocked) then
		ctx:set_global(msg);
	end

-- skip duplicates
	for k,v in ipairs(ctx.locals[source]) do
		if (v == msg) then
			return;
		end
	end

	table.insert_unique_i(ctx.locals[source], 1, msg);
	if (#ctx.locals[source] > ctx.history_size) then
		table.remove(ctx.locals[source], #ctx.locals[source]);
	end
end

local function clipboard_setglobal(ctx, msg)
	table.insert_unique_i(ctx.globals, 1, msg);
	if (#ctx.globals > ctx.history_size) then
		table.remove(ctx.globals, #ctx.globals);
	end
end

-- by default, we don't retain history that is connected to a dead window
local function clipboard_lost(ctx, source)
	ctx.mpt[source] = nil;
	ctx.locals[source] = nil;
end

local function clipboard_save(ctx, fn)
	zap_resource(fn);
	local wout = open_nonblock(fn, 1);
	if (not wout) then
		warning("clipboard/save: couldn't open " .. fn .. " for writing.");
		return false;
	end

	wout:write(string.format("local res = { globals = {}; urls = {}; };\n"));
	for k,v in ipairs(ctx.globals) do
		wout:write(string.format("table.insert(res.globals, %q);\n", v));
	end
	for k,v in ipairs(ctx.urls) do
		wout:write(string.format("table.insert(res.urls, %q);\n", v));
	end

	wout:write("return res;\n");
	wout:close();
	return true;
end

local function clipboard_load(ctx, fn)
	if (not resource(fn)) then
		return;
	end

	local res = system_load(fn, 0);
	if (not res) then
		warning("parsing error loading clipboard history from: " .. fn);
		return;
	end

	local okstate, map = pcall(res);
	if (not okstate) then
		warning("execution error loading clipboard history from: " .. fn);
		return;
	end

	if (map and type(map) == "table" and
		map.globals and type(map.globals) == "table" and
		map.urls and type(map.urls) == "table") then
		ctx.globals = map.globals;
		ctx.urls = map.urls;
	end

	return true;
end

local function clipboard_locals(ctx, source)
	return ctx.locals[source] and ctx.locals[source] or {};
end

local function clipboard_text(ctx)
	return ctx.global and ctx.global or "";
end

-- premade filters to help in cases where we get a lot of junk like
-- copy / paste from terminals.
local pastemodes = {
	normal = {"Normal", function(instr) return instr; end},
	trim = {"Trim", function(instr)
		return (string.gsub(instr, "^%s*(.-)%s*$", "%1")); end},
	nocrlf = {"No CR/LF", function(instr)
		return (string.gsub(instr, "[\n\r]+", "")); end},
	nodspace = {"Single Spaces", function(instr)
		return (string.gsub(instr, "%s+", " ")); end}
};

function clipboard_pastemodes(ctx, key)
	local res = {};

-- try match by index, else match by labelstr else default
	if (key) then
		local ent = pastemodes[key] and pastemodes[key] or pastemodes[1];
		for k,v in pairs(pastemodes) do
			if (v[1] == key) then
				ent = v;
				break;
			end
		end

		return ent[2], ent[1];
	end

	for k,v in pairs(pastemodes) do
		table.insert(res, v[1]);
	end
	table.sort(res);
	return res;
end

return {
	mpt = {}, -- mulitpart tracking
	locals = {}, -- local clipboard history (of history_size size)
	globals = {},
	urls = {},
	history_size = 10,
	mpt_cutoff = 10,
	add = clipboard_add,
	text = clipboard_text,
	lost = clipboard_lost,
	save = clipboard_save,
	load = clipboard_load,
	pastemodes = clipboard_pastemodes,
	set_global = clipboard_setglobal,
	list_local = clipboard_locals,
};
