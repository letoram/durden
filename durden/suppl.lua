-- Copyright: None claimed, Public Domain
-- Description: Cookbook- style functions for the normal tedium
-- (string and table manipulation, mostly plucked from the AWB
-- project)

function string.split(instr, delim)
	if (not instr) then
		return {};
	end

	local res = {};
	local strt = 1;
	local delim_pos, delim_stp = string.find(instr, delim, strt);

	while delim_pos do
		table.insert(res, string.sub(instr, strt, delim_pos-1));
		strt = delim_stp + 1;
		delim_pos, delim_stp = string.find(instr, delim, strt);
	end

	table.insert(res, string.sub(instr, strt));
	return res;
end

function string.utf8back(src, ofs)
	if (ofs > 1 and string.len(src)+1 >= ofs) then
		ofs = ofs - 1;
		while (ofs > 1 and utf8kind(string.byte(src,ofs) ) == 2) do
			ofs = ofs - 1;
		end
	end

	return ofs;
end

function string.utf8forward(src, ofs)
	if (ofs <= string.len(src)) then
		repeat
			ofs = ofs + 1;
		until (ofs > string.len(src) or
			utf8kind( string.byte(src, ofs) ) < 2);
	end

	return ofs;
end

function string.utf8lalign(src, ofs)
	while (ofs > 1 and utf8kind(string.byte(src, ofs)) == 2) do
		ofs = ofs - 1;
	end
	return ofs;
end

function string.utf8ralign(src, ofs)
	while (ofs <= string.len(src) and string.byte(src, ofs)
		and utf8kind(string.byte(src, ofs)) == 2) do
		ofs = ofs + 1;
	end
	return ofs;
end

function string.translateofs(src, ofs, beg)
	local i = beg;
	local eos = string.len(src);

	-- scan for corresponding UTF-8 position
	while ofs > 1 and i <= eos do
		local kind = utf8kind( string.byte(src, i) );
		if (kind < 2) then
			ofs = ofs - 1;
		end

		i = i + 1;
	end

	return i;
end

function string.utf8len(src, ofs)
	local i = 0;
	local rawlen = string.len(src);
	ofs = ofs < 1 and 1 or ofs;

	while (ofs <= rawlen) do
		local kind = utf8kind( string.byte(src, ofs) );
		if (kind < 2) then
			i = i + 1;
		end

		ofs = ofs + 1;
	end

	return i;
end

function string.insert(src, msg, ofs, limit)
	if (limit == nil) then
		limit = string.len(msg) + ofs;
	end

	if ofs + string.len(msg) > limit then
		msg = string.sub(msg, 1, limit - ofs);

-- align to the last possible UTF8 char..

		while (string.len(msg) > 0 and
			utf8kind( string.byte(msg, string.len(msg))) == 2) do
			msg = string.sub(msg, 1, string.len(msg) - 1);
		end
	end

	return string.sub(src, 1, ofs - 1) .. msg ..
		string.sub(src, ofs, string.len(src)), string.len(msg);
end

function string.delete_at(src, ofs)
	local fwd = string.utf8forward(src, ofs);
	if (fwd ~= ofs) then
		return string.sub(src, 1, ofs - 1) .. string.sub(src, fwd, string.len(src));
	end

	return src;
end

function string.trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"));
end

-- to ensure "special" names e.g. connection paths for target alloc,
-- or for connection pipes where we want to make sure the user can input
-- no matter keylayout etc.
strict_fname_valid = function(val)
	for i in string.gmatch(val, "%W") do
		if (i ~= '_') then
			return false;
		end
	end
	return true;
end

function string.utf8back(src, ofs)
	if (ofs > 1 and string.len(src)+1 >= ofs) then
		ofs = ofs - 1;
		while (ofs > 1 and utf8kind(string.byte(src,ofs) ) == 2) do
			ofs = ofs - 1;
		end
	end

	return ofs;
end


function table.remove_match(tbl, match)
	if (tbl == nil) then
		return;
	end

	for k,v in ipairs(tbl) do
		if (v == match) then
			table.remove(tbl, k);
			return v;
		end
	end

	return nil;
end

function string.dump(msg)
	local bt ={};
	for i=1,string.len(msg) do
		local ch = string.byte(msg, i);
		bt[i] = ch;
	end
	print(table.concat(bt, ','));
end

function table.remove_vmatch(tbl, match)
	if (tbl == nil) then
		return;
	end

	for k,v in pairs(tbl) do
		if (v == match) then
			tbl[k] = nil;
			return v;
		end
	end

	return nil;
end

function table.find_i(table, r)
	for k,v in ipairs(table) do
		if (v == r) then return k; end
	end
end

function table.i_subsel(table, label, field)
	local res = {};
	local ll = label and string.lower(label) or "";
	local i = 1;

	for k,v in ipairs(table) do
		local match = field and v[field] or v;
		if (type(match) ~= "string") then
			warning("invalid entry in table subselect");
			if (DEBUGLEVEL > 1) then print(debug.traceback()); end
			break;
		end
		match = string.lower(match);
		if (string.len(ll) == 0 or string.sub(match, 1, string.len(ll)) == ll) then
			res[i] = v;
			i = i + 1;
		end
	end

	return res;
end

-- streaming is incomplete still in that we havn't set up mechanism for
-- credential-store-fetch
local function build_recargs(vsrc, asrc, streaming)
	local argstr = string.format("vcodec=%s:fps=%.3f:vpreset=%d:container=%s",
		gconfig_get("enc_vcodec"), gconfig_get("enc_fps"),
		gconfig_get("enc_vpreset"), streaming and "stream" or
		gconfig_get("enc_container")
	);

	if (not asrc or #asrc == 0) then
		argstr = argstr .. ":noaudio";
	end

	return argstr, gconfig_get("enc_srate");
end

function suppl_setup_rec(wnd, val)
	local svid = type(wnd) == "table" and wnd.external or wnd;
	local aarr = {};

	if (not valid_vid(svid)) then
		return;
	end

-- work around link_image constraint
	local props = image_storage_properties(svid);
	local pw = props.width + props.width % 2;
	local ph = props.height + props.height % 2;

	local nsurf = null_surface(pw, ph);
	image_sharestorage(svid, nsurf);
	local varr = {nsurf};

	local db = alloc_surface(pw, ph);
	if (not valid_vid(db)) then
		delete_image(nsurf);
		warning("setup_rec, couldn't allocate output buffer");
		return;
	end

	local argstr, srate = build_recargs(varr, aarr, false);
	local res = define_recordtarget(db, val, argstr, varr, aarr,
		RENDERTARGET_NODETACH, RENDERTARGET_SCALE, srate,
		function(source, stat)
			if (stat.kind == "terminated") then
				delete_image(source);
			end
		end
	);

	if (not valid_vid(res)) then
		delete_image(db);
		delete_image(nsurf);
		warning("setup_rec, failed to spawn recordtarget");
		return;
	end

-- link the recordtarget with the source for automatic deletion
	link_image(res, svid);
	return res;
end

function drop_keys(matchstr)
	local rst = {};
	for i,v in ipairs(match_keys(matchstr)) do
		local pos, stop = string.find(v, "=", 1);
		local key = string.sub(v, 1, pos-1);
		rst[key] = "";
	end
	store_key(rst);
end

-- reformated PD snippet
function utf8valid(str)
  local i, len = 1, #str
	local find = string.find;
  while i <= len do
		if (i == find(str, "[%z\1-\127]", i)) then
			i = i + 1;
		elseif (i == find(str, "[\194-\223][\123-\191]", i)) then
			i = i + 2;
		elseif (i == find(str, "\224[\160-\191][\128-\191]", i)
			or (i == find(str, "[\225-\236][\128-\191][\128-\191]", i))
 			or (i == find(str, "\237[\128-\159][\128-\191]", i))
			or (i == find(str, "[\238-\239][\128-\191][\128-\191]", i))) then
			i = i + 3;
		elseif (i == find(str, "\240[\144-\191][\128-\191][\128-\191]", i)
			or (i == find(str, "[\241-\243][\128-\191][\128-\191][\128-\191]", i))
			or (i == find(str, "\244[\128-\143][\128-\191][\128-\191]", i))) then
			i = i + 4;
    else
      return false, i;
    end
  end

  return true;
end

-- will return ctx (initialized if nil in the first call), to track state
-- between calls iotbl matches the format from _input(iotbl) and sym should be
-- the symbol table lookup. The redraw(ctx, caret_only) will be called when
-- the caller should update whatever UI component this is used in
function text_input(ctx, iotbl, sym, redraw, opts)
	ctx = ctx == nil and {
		caretpos = 1,
		limit = -1,
		chofs = 1,
		ulim = VRESW / gconfig_get("font_sz"),
		msg = "",
		undo = function(ctx)
			if (ctx.oldmsg) then
				ctx.msg = ctx.oldmsg;
				ctx.caretpos = ctx.oldpos;
--				redraw(ctx);
			end
		end,
		caret_left   = SYSTEM_KEYS["caret_left"],
		caret_right  = SYSTEM_KEYS["caret_right"],
		caret_home   = SYSTEM_KEYS["caret_home"],
		caret_end    = SYSTEM_KEYS["caret_end"],
		caret_delete = SYSTEM_KEYS["caret_delete"],
		caret_erase  = SYSTEM_KEYS["caret_erase"]
	} or ctx;

	ctx.view_str = function()
		local rofs = string.utf8ralign(ctx.msg, ctx.chofs + ctx.ulim);
		local str = string.sub(ctx.msg, string.utf8ralign(ctx.msg, ctx.chofs), rofs-1);
		return str;
	end

	ctx.caret_str = function()
		return string.sub(ctx.msg, ctx.chofs, ctx.caretpos - 1);
	end

	local caretofs = function()
		if (ctx.caretpos - ctx.chofs + 1 > ctx.ulim) then
				ctx.chofs = string.utf8lalign(ctx.msg, ctx.caretpos - ctx.ulim);
		end
	end

	if (iotbl.active == false) then
		return ctx;
	end

	if (sym == ctx.caret_home) then
		ctx.caretpos = 1;
		ctx.chofs    = 1;
		caretofs();
		redraw(ctx);

	elseif (sym == ctx.caret_end) then
		ctx.caretpos = string.len( ctx.msg ) + 1;
		ctx.chofs = ctx.caretpos - ctx.ulim;
		ctx.chofs = ctx.chofs < 1 and 1 or ctx.chofs;
		ctx.chofs = string.utf8lalign(ctx.msg, ctx.chofs);

		caretofs();
		redraw(ctx);

	elseif (sym == ctx.caret_left) then
		ctx.caretpos = string.utf8back(ctx.msg, ctx.caretpos);
		if (ctx.caretpos < ctx.chofs) then
			ctx.chofs = ctx.chofs - ctx.ulim;
			ctx.chofs = ctx.chofs < 1 and 1 or ctx.chofs;
			ctx.chofs = string.utf8lalign(ctx.msg, ctx.chofs);
		end

		caretofs();
		redraw(ctx);

	elseif (sym == ctx.caret_right) then
		ctx.caretpos = string.utf8forward(ctx.msg, ctx.caretpos);
		if (ctx.chofs + ctx.ulim <= ctx.caretpos) then
			ctx.chofs = ctx.chofs + 1;
			caretofs();
			redraw(ctx);
		else
			caretofs();
			redraw(ctx, caret);
		end

	elseif (sym == ctx.caret_delete) then
		ctx.msg = string.delete_at(ctx.msg, ctx.caretpos);
		caretofs();
		redraw(ctx);

	elseif (sym == ctx.caret_erase) then
		if (ctx.caretpos > 1) then
			ctx.caretpos = string.utf8back(ctx.msg, ctx.caretpos);
			if (ctx.caretpos <= ctx.chofs) then
				ctx.chofs = ctx.caretpos - ctx.ulim;
				ctx.chofs = ctx.chofs < 0 and 1 or ctx.chofs;
			end

			ctx.msg = string.delete_at(ctx.msg, ctx.caretpos);
			caretofs();
			redraw(ctx);
		end

	else
		local keych = iotbl.utf8;
		if (keych == nil or keych == '') then
			return ctx;
		end

		ctx.oldmsg = ctx.msg;
		ctx.oldpos = ctx.caretpos;
		ctx.msg, nch = string.insert(ctx.msg, keych, ctx.caretpos, ctx.nchars);

		ctx.caretpos = ctx.caretpos + nch;
		caretofs();
		redraw(ctx);
	end

	assert(utf8valid(ctx.msg) == true);
	return ctx;
end

function merge_dispatch(m1, m2)
	local kt = {};
	local res = {};
	if (m1 == nil) then
		return m2;
	end
	if (m2 == nil) then
		return m1;
	end
	for k,v in pairs(m1) do
		res[k] = v;
	end
	for k,v in pairs(m2) do
		res[k] = v;
	end
	return res;
end

-- add m2 to m1, overwrite on collision
function merge_menu(m1, m2)
	local kt = {};
	local res = {};
	if (m2 == nil) then
		return m1;
	end

	if (m1 == nil) then
		return m2;
	end

	for k,v in ipairs(m1) do
		kt[v.name] = k;
		table.insert(res, v);
	end

	for k,v in ipairs(m2) do
		if (kt[v.name]) then
			res[kt[v.name]] = v;
		else
			table.insert(res, v);
		end
	end
	return res;
end

local menu_hook = nil;

local function lbar_props()
	local pos = gconfig_get("lbar_position");
	local dir = 1;
	local wm = active_display();
	local barh = gconfig_get("lbar_sz") * wm.scalef;
	local yp = 0;

	yp = math.floor(0.5*(wm.height-barh));

	return yp, barh, dir;
end

local function hlp_add_btn(helper, lbl)
	local yp, tileh, dir = lbar_props();
	local pad = gconfig_get("lbar_pad");

	local btn = uiprim_button(active_display().order_anchor,
		"lbar_tile", "lbar_tiletext", lbl, pad,
		active_display().font_resfn, 0, tileh
	);

-- if ofs + width, compact left and add a "grow" offset on pop
	local ofs = #helper > 0 and helper[#helper].ofs or 0;
	local yofs = (tileh + 1) * dir;
	move_image(btn.bg, ofs, yofs);
	move_image(btn.bg, ofs, yp); -- switch, lbar height
	nudge_image(btn.bg, 0, yofs, gconfig_get("transition") * 0.5, INTERP_SINE);
	if (#helper > 0) then
		helper[#helper].btn:switch_state("inactive");
	end
	table.insert(helper, {btn = btn, yofs = yofs, ofs = ofs + btn.w});
end

local function menu_path_append(ctx, new, lbl)
	local path = ctx.path;
	local helper = ctx.helper;

	table.insert(path, new);
	local res = table.concat(path, "/");
	hlp_add_btn(ctx.helper, lbl);

	if (DEBUGLEVEL > 1) then
		print("menu path switch:", res);
	end

	return res;
end

local function menu_path_pop(ctx)
	local path = ctx.path;
	local helper = ctx.helper;

	table.remove(path, #path);
	local res = table.concat(path, "/");
	local as = gconfig_get("transition") * 0.5;
	local hlp = helper[#helper];
	if (not hlp) then
		return res;
	end

	blend_image(hlp.btn.bg, 0.0, as);
	if (as > 0) then
		tag_image_transform(hlp.btn.bg,
			MASK_OPACITY, function() hlp.btn:destroy(); end);
	else
		hlp.btn:destroy();
	end

	table.remove(helper, #helper);
	if (#helper > 0) then
		helper[#helper].btn:switch_state("active");
	end
	return res;
end

local function menu_path_reset(ctx, prefix)
	for k,v in ipairs(ctx.helper) do
		v.btn:destroy();
	end
	ctx.helper = {};
	ctx.helper.add = hlp_add_btn;
	ctx.path = {};
end

local widgets = {};

function suppl_widget_scan()
	local res = glob_resource("widgets/*.lua", APPL_RESOURCE);
	for k,v in ipairs(res) do
		local res = system_load("widgets/" .. v, false);
		if (res) then
			local ok, wtbl = pcall(res);
-- would be a much needed feature to have a compact and elegant
-- way of specifying a stronger contract on fields and types in
-- place like this.
			if (ok and wtbl and wtbl.name and type(wtbl.name) == "string" and
				string.len(wtbl.name) > 0 and wtbl.paths and
				type(wtbl.paths) == "table") then
				widgets[wtbl.name] = wtbl;
				warning("got widget:" .. v);
			else
				warning("widget " .. v .. " failed to load");
			end
		end
	end
end

function menu_path_new()
-- scan for menu widgets
	suppl_widget_scan();
	return {
		helper = {},
		path = {},
		reset = menu_path_reset,
		pop = menu_path_pop,
		append = menu_path_append
	};
end

local cpath = menu_path_new();

local function menu_cancel(wm)
	local m1, m2 = dispatch_meta();
	if (m1) then
		launch_menu_path(active_display(), LAST_ACTIVE_MENU, cpath:pop());
	else
		cpath:reset();
		iostatem_restore();
	end
end

local function seth(ctx, instr, done, lastv)
	local m1, m2 = dispatch_meta();
	if (not done) then
		local dset = ctx.set;
		if (type(ctx.set) == "function") then
			dset = ctx.set();
		end

		return {set = table.i_subsel(dset, instr)};
	end

	if (menu_hook) then
		local fun = menu_hook;
		menu_hook = nil;
		fun(table.concat(cpath.path, "/") .. "=" .. instr);
	else
		if (ctx.handler) then
			ctx.handler(ctx, instr);
		else
			warning("broken menu entry");
		end
	end
	cpath:reset();
end

local function normh(ctx, instr, done, lastv)
	if (not done) then
		if (ctx.validator ~= nil and not ctx.validator(instr)) then
			return false;
		end

		if (ctx.helpsel) then
			return {set = table.i_subsel(ctx:helpsel(), instr)};
		end

		return true;
	end

-- validate if necessary
	if (ctx.validator ~= nil and not ctx.validator(instr)) then
		menu_hook = nil;
		if (not ctx.noreset) then
			cpath:reset();
		end
		return;
	end

-- slightly more cumbersome as we need to handle all permuations of
-- hook_on/off, valid but empty string with menu item default value
	instr = instr and instr or "";
	local hf = function(arg) ctx:handler(arg); end
	if (menu_hook) then
		hf =
		function(arg)
			local rp = table.concat(cpath.path, "/") .. "=" .. instr;
			local fun = menu_hook;
			menu_hook = nil;
			fun(rp);
		end
	end

	if (string.len(instr) > 0) then
		hf(instr);
	elseif (ctx.default) then
		hf(instr);
	end

	if (not ctx.noreset) then
		cpath:reset();
	end
end

function suppl_access_path()
	return cpath;
end

--
-- used to find and activate support widgets and tie to the set ctx
--
function suppl_widget_path(ctx, ident)
	local match = {};
	local fi = 0;

	for k,v in pairs(widgets) do
		for i,j in ipairs(v.paths) do
			if (j == ident) then
-- insertion sort the floaters so we can treat them special later
				if (v.float) then
					table.insert(match, 1, v);
					fi = fi + 1;
				else
					table.insert(match, v);
				end
			end
		end
	end

	local nm = #match;
	if (nm == 0) then
		return;
	end

-- create anchors linked to background for automatic deletion, as they
-- are used for clipping, distribute in a fair away between top and bottom
-- but with special treatment for floating widgets
	local start = fi+1;
	local ad = active_display();
	local sub_sz = gconfig_get("lbar_sz") * ad.scalef;
	local rh = ad.height * 0.5 - sub_sz;
	local y2 = ad.height * 0.5 + sub_sz;

	if (nm - fi > 0) then
		local ndiv = (#match - fi) / 2;
		local cellw = ndiv > 1 and ad.width / ndiv or ad.width;
		local cx = 0;
		local ay = 0;
		while start <= nm do
			local anch = null_surface(cellw, rh);
			show_image(anch);
			link_image(anch, ctx.anchor);
			image_inherit_order(anch, true);
			move_image(anch, cx, ay);
			match[start].show(ctx, anch);
			start = start + 1;
			if (ay == 0) then
				ay = y2;
			else
				ay = 0;
				cx = cx + cellw;
			end
		end
	end
end

function suppl_run_value(ctx, mask)
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
		res = active_display():lbar(seth,
			ctx, {label = hintstr, force_completion = true, prefill = ctx.prefill});
	else
-- or a "normal" run with custom input and validator feedback
		res = active_display():lbar(normh, ctx, {
			password_mask = mask, label = hintstr});
	end
	if (not res.on_cancel) then
		res.on_cancel = menu_cancel;
	end
	return res;
end

local function lbar_fun(ctx, instr, done, lastv)
	if (done) then
		local tgt = nil;
		for k,v in ipairs(ctx.list) do
			if (string.lower(v.label) == string.lower(instr)) then
				tgt = v;
			end
		end
		if (tgt == nil) then
			cpath:reset();
			return;
		end

-- a little odd combination, used to manually build a path to a specific menu
-- item for shortcuts. handler_hook needs to be set and either meta+submenu or
-- just non-submenu for the hook to be called instead of the default handler
		if (tgt.kind == "action") then
			cpath:append(tgt.name, tgt.label);
			local m1, m2 = dispatch_meta();
			if (menu_hook and
				(tgt.submenu and m1 or not tgt.submenu)) then
					local hf = menu_hook;
					menu_hook = nil;
					hf(table.concat(cpath.path, "/"));
					cpath:reset();
					return;
			elseif (tgt.submenu) then
				ctx.list = type(tgt.handler) == "function"
					and tgt.handler() or tgt.handler;
				local nlb = launch_menu(ctx.wm, ctx, tgt.force, tgt.hint);
				return nlb;
			elseif (tgt.handler) then
				tgt.handler(ctx.handler, instr, ctx);
				cpath:reset();
				return;
			end
		elseif (tgt.kind == "value") then
			cpath:append(tgt.name, tgt.label);
			return suppl_run_value(tgt, tgt.password_mask);
		end
	end

	local subs = table.i_subsel(ctx.list, instr, "label");
	local res = {};
	local mlbl = gconfig_get("lbar_menulblstr");
	local msellbl = gconfig_get("lbar_menulblselstr");

	for i=1,#subs do
			if ((subs[i].eval == nil or subs[i].eval(ctx, instr)) and
			(ctx.show_invisible or not subs[i].invisible)) then
			if (subs[i].submenu) then
					table.insert(res, {mlbl, msellbl, subs[i].label});
				else
					table.insert(res, subs[i].label);
				end
		end
	end

	return {set = res, valid = false};
end

function shared_valid01_float(inv)
	if (string.len(inv) == 0) then
		return true;
	end

	local val = tonumber(inv);
	return val and (val >= 0.0 and val <= 1.0) or false;
end

function gen_valid_num(lb, ub)
	return function(val)
		if (string.len(val) == 0) then
			return true;
		end
		local num = tonumber(val);
		if (num == nil) then
			return false;
		end
		return not(num < lb or num > ub);
	end
end

function gen_valid_float(lb, ub)
	return gen_valid_num(lb, ub);
end

--
-- ctx is expected to contain:
--  list [# of {name, label, kind, validator, handler}]
--  + any data the handler might need
--
function launch_menu(wm, ctx, fcomp, label, opts, last_bar)
	if (ctx == nil or ctx.list == nil or type(ctx.list) ~= "table") then
		cpath:reset();
		return;
	end

	if (#ctx.list == 0) then
		cpath:reset();
		return;
	end

	local found = false;
	for i,v in ipairs(ctx.list) do
		if (v.eval == nil or v.eval()) then
			found = true;
			break;
		end
	end

	if (not found) then
		return;
	end

	fcomp = fcomp == nil and true or false;

	opts = opts and opts or {};
	opts.force_completion = fcomp;
	opts.label = label;
	ctx.wm = wm;

-- this was initially written to be independent, that turned out to be a
-- terrible design decision.
	local bar = wm:lbar(lbar_fun, ctx, opts);
	if (not bar) then
		return;
	end

	if (not bar.on_cancel) then
		bar.on_cancel = menu_cancel;
	end

	return bar;
end

-- part and convert terminal escape sequences for coloring to valid
-- string output for render_text
function esc_to_fontstr(msg)

-- 1. look for 0x1b, 0x5b
-- scan for m
-- split by ;
-- covert numbers (0 to \!b\!i   1 to \b   \4
-- and lut for colors etc.
--
-- truecolor: \x1b[38;5;R;G;Bm  (38 fg, 48 bg)
--
end

-- set a temporary hook that will override menu navigation
-- and instead send the path to the specified function one time
function launch_menu_hook(fun)
	menu_hook = fun;
	cpath:reset();
end

function get_menu_tree(menu, pref)
	local res = {};

	local recfun = function(fun, mnu, pref)
		if (not mnu) then
			return;
		end

		for k,v in ipairs(mnu) do
			table.insert(res, pref .. v.name);
			if (v.submenu and (not v.eval or v.eval())) then
				fun(fun,
					type(v.handler) == "function" and v.handler() or
					v.handler, pref .. v.name .. "/"
				);
			end
		end
	end

	recfun(recfun, menu, pref and pref or "/");
	return res;
end

--
-- navigate a tree of submenus to reach a specific function without performing
-- the visual / input triggers needed, used to provide the same interface for
-- keybinding as for setup. gfunc should be a menu spawning function.
--
function launch_menu_path(wm, gfunc, pathdescr)
	if (not gfunc) then
		return;
	end

	if (DEBUGLEVEL > 2) then
		print("launch_menu_path: ", pathdescr);
	end

	if (not pathdescr or string.len(pathdescr) == 0) then
		gfunc();
		return;
	end

-- just filter first character if it happens to be a separator (legacy),
-- handles /////// style typos too
	if (string.sub(pathdescr, 1, 1) == "/") then
		launch_menu_path(wm, gfunc, string.sub(pathdescr, 2));
		return;
	end

-- = is reserved to match binding value menu item kinds
	local vt = string.split(pathdescr, "=");
	local arg = nil;

-- use first splitpoint and merge together again after that
	if (#vt > 0) then
		arg = table.concat(vt, "=", 2);
		pathdescr = vt[1];
	end

-- finally seperate into individual elements
	local elems = string.split(pathdescr, "/");
	if (#elems > 0 and string.len(elems[1]) == 0) then
		table.remove(elems, 1);
	end

-- temporarily replace menu functions, and otherwise simulate
-- normal user interaction
	local cl = nil;
	local old_launch = launch_menu;
	launch_menu = function(wm, ctx, fcomp, label)
		cl = ctx;
	end

	gfunc();
	if (cl == nil) then
		launch_menu = old_launch;
		return;
	end

	for i,v in ipairs(elems) do
		local found = false;

-- linear search for matching name as we index on number (want deterministic
-- but manually managed presentation order)
		for m,n in ipairs(cl.list) do
			if (n.name == v) then
				found = n;
				break;
			end
		end

-- something bad with the keybinding, eval() function will be handled elsewhere
		if (not found) then
			warning(string.format(
				"run_menu_path(%s) failed at index %d, couldn't find %s",
				pathdescr, i, v)
			);
			launch_menu = old_launch;
			return;
		end

		if (found.eval and not found.eval(arg)) then
			if (DEBUGLEVEL > 0) then
				warning(string.format(
					"run_menu_path(%s) evaluation function failed", pathdescr));
			end
			launch_menu = old_launch;
			return;
		end

-- something broken with the menu item? any such cases should be noted
		if (found.handler == nil) then
			warning("missing handler for: " .. found.name);
		elseif (found.submenu) then
-- special handling if the last entry ends up as a menu, meaning it should
-- be visible in the UI, unwise to add to a timer or command_channel
			launch_menu = i == #elems and old_launch or launch_menu;
			local menu = type(found.handler) == "function" and
				found.handler() or found.handler;
			launch_menu(wm, {list=menu}, found.force, found.hint);
		else
-- or revert and activate the handler, with arg if value- action
			launch_menu = old_launch;
			found.handler(cl.handler, arg);
			return;
		end
	end

	launch_menu = old_launch;
end
