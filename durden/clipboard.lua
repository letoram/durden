-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
--
-- Description: Basic clipboard handling, currently text only but there's
-- little stopping us from using more advanced input and output formats.
--
local function clipboard_add(ctx, source, message, multipart)
	if (multipart) then
		if (ctx.mpt[source] == nil) then
			ctx.mpt[source] = {};
		end

-- simple cutoff to prevent nasty clients from sending multipart forever
		table.insert(ctx.mpt[source], message);
		if (#ctx.mpt[source] < ctx.mpt_cutoff) then
			return;
		end
	end

	local msg = message;
	if (ctx.mpt[source]) then
		msg = table.concat(ctx.mpt[source], "") .. message;
		ctx.mpt[source] = nil;
	end

	if (ctx.locals[source] == nil) then
		ctx.locals[source] = {};
	end

	table.insert(ctx.locals[source], 1, msg);
	if (#ctx.locals[source] > ctx.history_size) then
		table.remove(ctx.locals[source], #ctx.locals[source]);
	end

	if (not ctx.locals[source].blocked) then
		ctx:set_global(msg);
	end
end

local function clipboard_setglobal(ctx, msg)
	table.insert(ctx.globals, 1, msg);
	if (#ctx.globals > ctx.history_size) then
		table.remove(ctx.globals, #ctx.globals);
	end
end

-- by default, we don't retain history that is connected to a dead window
local function clipboard_lost(ctx, source)
	ctx.mpt[source] = nil;
	ctx.locals[source] = nil;
end

local function clipboard_locals(ctx, source)
	return ctx.locals[source] and ctx.locals[source] or {};
end

local function clipboard_text(ctx)
	return ctx.global and ctx.global or "";
end

return {
	mpt = {}, -- mulitpart tracking
	locals = {}, -- local clipboard history (of history_size size)
	globals = {},
	history_size = 10,
	mpt_cutoff = 10,
	add = clipboard_add,
	text = clipboard_text,
	lost = clipboard_lost,
	set_global = clipboard_setglobal,
	list_local = clipboard_locals,
};
