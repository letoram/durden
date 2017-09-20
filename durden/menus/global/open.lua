
-- slightly more involved since we want to create a hidden window (so
-- still indexable etc.) without causing any relayouting and have it
-- attached to the right tiler
local function group_attach(wnd, source)
	local ddisp = nil;
	local adisp = nil;

-- problem one: we need the display the window is on, not the wm
	for d in all_displays_iter() do
		local wnd = d.tiler:find_window(wnd.canvas);
		if (wnd) then
			ddisp = d;
		end
		if (not d.tiler.deactivated) then
			adisp = d;
		end
	end

-- should never happen, but safeguard
	if (not ddisp or not adisp) then
		warning("group_attach on wnd without tiler");
		delete_image(source);
		return;
	end

-- now we can fake default attachment to..
	rendertarget_attach(ddisp.rt, source, RENDERTARGET_DETACH);
	set_context_attachment(ddisp.rt);
	local newwnd = wnd.wm:add_hidden_window(source);
	table.insert(wnd.dependents, newwnd);
	set_context_attachment(adisp.rt);

-- need to subscribe to events in the parent when it comes to resize, ...
-- and remove those should we disappear
	newwnd:make_dependent(wnd);
end

function terminal_build_argenv(group)
	local bc = gconfig_get("term_bgcol");
	local fc = gconfig_get("term_fgcol");
	local cp = gconfig_get("extcon_path");
	local palette = gconfig_get("term_palette");

	local lstr = string.format(
		"bgalpha=%d:bgr=%d:bgg=%d:bgb=%d:fgr=%d:fgg=%d:fgb=%d:%s%s%s",
		gconfig_get("term_opa") * 255.0 , bc[1], bc[2], bc[3],
		fc[1], fc[2], fc[3],
			(cp and string.len(cp) > 0) and ("env=ARCAN_CONNPATH="..cp) or "",
		string.len(palette) > 0 and (":palette="..palette) or "",
		gconfig_get("term_append_arg")
	);

	if (gconfig_get("term_bitmap")) then
		lstr = lstr .. ":" .. "force_bitmap";
	end

	return lstr;
end

function spawn_terminal(cmd)
	local lstr = terminal_build_argenv();
	if (cmd) then
		lstr = lstr .. ":" .. cmd;
	end

	launch_avfeed(lstr, "terminal",
	function(source, status)
		if (status.kind == "preroll") then
			local wnd = durden_launch(source, "", "terminal");
			if (not wnd) then
				warning("durden launch preroll state failed");
				return;
			end
			wnd.scalemode = "stretch";
			extevh_default(source, {
				kind = "registered", segkind = "terminal", title = "", guid = 1});
			local wnd_w = wnd.max_w - wnd.pad_left - wnd.pad_right;
			local wnd_h = wnd.max_h - wnd.pad_top - wnd.pad_bottom;
			target_displayhint(source, wnd_w, wnd_h,
				wnd.dispmask, wnd.wm.disptbl);
			durden_devicehint(source);

		elseif (status.kind == "terminated") then
			delete_image(source);
		end
	end);

-- second part of setting up a group, we need to register the path
-- (and deregister on destroy) so we can intercept the window creation
--		if (group) then
--			extevh_intercept(group, function(source)
--				group_attach(wnd, source);
--			end, true);
--			wnd:add_handler("destroy", function()
--				extevh_intercept(group, nil, true);
--			end, true);
--		end
end

local function run_uri(val, feedmode)
	local vid = launch_avfeed(val, feedmode);
	if (valid_vid(vid)) then
		durden_launch(vid, "", feedmode);
		durden_devicehint(vid);
	else
		active_display():message(
			string.format("Couldn't launch %s (broken or out-of-resources)", feedmode));
	end
end

local function get_remstr(val)
	local sp = string.split(val, "@");
	if (sp == nil or #sp == 1) then
		return "host=" .. val;
	end

	local base = "";
	local cred = string.split(sp[1], ":");
	if (cred and #cred == 2) then
		base = string.format("user=%s:password=%s:", cred[1], cred[2]);
	else
		base = string.format("password=%s:", sp[1]);
	end

	local disp = string.split(sp[2], "+");
	if (disp and #disp == 2 and tonumber(disp[2])) then
		local num = tonumber(disp[2]);
		base = string.format("%shost=%s:port=%d", base, disp[1], num);
	else
		base = string.format("%shost=%s", base, disp[1]);
	end

	return base;
end

local function setup_wnd(vid, title, scalemode)
	local wnd = active_display():add_window(vid, {scalemode = scalemode});
	if (wnd) then
		wnd:set_title(title);
	end
end

local prev_cache = {};
local function imgwnd(fn, pctx)
	if (pctx and valid_vid(pctx.vid)) then
-- if finished, just take new window and take ownership of vid
-- otherwise update vid with new handler that spawns window on activation
		local st = image_state(pctx.vid);
		if (st == "asynchronous state") then
			pctx.spawn = pctx.vid;
			pctx.title = "image:" .. fn;
			pctx.vid = BADID;
		else
			pctx.vid = BADID;
		end
	else
		load_image_asynch(fn, function(src, stat)
			if (stat.kind == "loaded") then
				setup_wnd(src, "image:" .. fn, "stretch");
			elseif (valid_vid(src)) then
				delete_image(src);
				active_display():message("couldn't load " .. fn);
			end
		end);
	end
end

local function setup_prev(src, anchor, xofs, basew)
	local time = gconfig_get("animation");
	link_image(src, anchor);
	resize_image(src, basew, 0);
	local props = image_surface_properties(src);
	resize_image(src, 8, 8);
	move_image(src, xofs + basew * 0.5, 0);
	resize_image(src, basew, 0, time);
	blend_image(src, 1.0, time);
	nudge_image(src, -basew * 0.5, -props.height, time);
	image_inherit_order(src, true);
end

local function imgprev(path, name, space, anchor, xofs, basew, mh)
-- cache loaded paths, on trigger we know we are "focused" and
-- should be a bit larger
	local fn = path .. "/" .. name;
	if (not resource(fn, space)) then
		return;
	end

	for k,v in pairs(prev_cache) do
		if (valid_vid(v)) then
			instant_image_transform(v);
			blend_image(v, k == fn and 1.0 or 0.3, gconfig_get("animation"));
		end
	end

	if (prev_cache[fn]) then
		return;
	end

	local vid = load_image_asynch(fn,
	function(src, stat)
		if (stat.kind == "loaded") then
			if (stat.spawn) then
				spawn_wnd(stat);
			else
				setup_prev(src, anchor, xofs, basew);
				if (mh) then mh.child = src; end
			end
		else
-- death is easy, destroy will be called by lbar
		end
	end);
	prev_cache[fn] = vid;
	return {
		vid = vid,
		name = name,
		destroy = function(ctx)
			prev_cache[fn] = nil;
			if (valid_vid(ctx.vid)) then
				delete_image(vid);
			end
		end,
		activate = function(ctx)
			imgwnd(fn, ctx);
		end
	};
end

-- track lastpath so we can meta-launch browse internal and resume old path
local lastpath = "";
local function decwnd(fn, path)
	lastpath = path;
	local vid = launch_decode(fn, function() end);
	if (valid_vid(vid)) then
		durden_launch(vid, "", fn);
		durden_devicehint(vid);
	else
		active_display():message("decode- frameserver broken or out-of-resources");
	end
end

local function launch(str, cfg)
	local vid = launch_target(str, cfg, LAUNCH_INTERNAL, def_handler);
	if (valid_vid(vid)) then
		if (gconfig_get("gamma_access") ~= "none") then
			target_flags(vid, TARGET_ALLOWCM, true);
		end
		local wnd = durden_launch(vid, cfg, str);
		durden_devicehint(vid);
		wnd.config_target = str;
		wnd.config_config = cfg;
	else
		active_display():message("target broken or out-of-resources");
	end
end

local function target_cfgmenu(str, cfgs)
	local res = {};
	for k,v in ipairs(cfgs) do
		table.insert(res,{
			name = "launch_" .. hexenc(util.hash(str))
				.. "_" .. hexenc(util.hash(v)),
			kind = "action",
			label = v,
			force_completion = true,
			handler = function() launch(str, v); end
		});
	end
	return res;
end

local function target_submenu()
	local res = {};
	local targets = list_targets();
	for k,v in ipairs(targets) do
		local cfgs = target_configurations(v);
		local nent = {
			name = "launch_" .. hexenc(util.hash(v)),
			kind = "action",
			label = v
		};

		if (#cfgs > 0) then
			if (#cfgs > 1) then
				nent.submenu = true;
				nent.handler = function() return target_cfgmenu(v, cfgs); end
			else
				nent.handler = function() launch(v, cfgs[1]); end
			end
			table.insert(res, nent);
		end
	end
	return res;
end

local function browse_internal()
	local imghnd = { run = imgwnd, col = HC_PALETTE[1],
		selcol = HC_PALETTE[1], preview = imgprev };
	local audhnd = { run = decwnd, col = HC_PALETTE[2],
		selcol = HC_PALETTE[2] };
	local dechnd = { run = decwnd, col = HC_PALETTE[3],
		selcol = HC_PALETTE[3] };

-- decode- frameserver doesn't have a way to query type and extension for
-- a specific resource, and running probes on all files in a folder with
-- 10k entries might be a little excessive
	local ffmts = {jpg = imghnd, png = imghnd, bmp = imghnd,
		ogg = audhnd, m4a = audhnd, flac = audhnd, mp3 = audhnd,
		mp4 = dechnd, wmv = dechnd, mkv = dechnd, avi = dechnd,
		flv = dechnd, mpg = dechnd, mpeg = dechnd, mov = dechnd,
	};

	local opts = {
		auto_preview = (gconfig_get("preview_mode") == "auto")
	};

	browse_file(nil, ffmts, SHARED_RESOURCE, nil, nil, opts);
end

register_global("spawn_terminal", spawn_terminal);

return {
{
	name = "browse",
	label = "Browse",
	kind = "action",
	namespace = "@/browse/",
	handler = browse_internal
},
{
	name = "remote",
	label = "Remote Desktop",
	kind = "value",
	helpsel = function() return CLIPBOARD.urls; end,
	hint = "(user:pass@host+port)",
	eval = function()
		return string.match(FRAMESERVER_MODES, "remoting") ~= nil;
	end,
-- missing, hash url, allow hint-set on clipboard url grab
	handler =
function(ctx, val)
	local vid = launch_avfeed(get_remstr(val), "remoting");
	if (valid_vid(vid, TYPE_FRAMESERVER)) then
		durden_devicehint(vid);
		durden_launch(vid, "", "remoting");
		extevh_default(vid, {
			kind = "registered", segkind = "remoting", title = "", guid = 2});
	else
		active_display():message(
			"remoting frameserver failed, broken or out-of-resources");
	end
end
},
{
	name = "decode",
	label = "Media URL",
	kind = "value",
	helpsel = function() return CLIPBOARD.urls; end,
	hint = "(protocol://user:pass@host:port)",
	eval = function()
		return string.match(FRAMESERVER_MODES, "decode") ~= nil;
	end,
	handler = function(ctx, val)
		run_uri(val, "decode");
	end
},
{
	name = "terminal",
	label = "Terminal",
	kind = "value",
	hint = "(append arguments)",
	default = "",
	eval = function()
		return string.match(FRAMESERVER_MODES, "terminal") ~= nil;
	end,
	handler = function(ctx, val)
		spawn_terminal(val);
	end
},
{
	name = "avfeed",
	label = "AV Feed",
	kind = "value",
	default = "(append arguments)",
	hint = "(m1_accept for args)",
	eval = function()
		return string.match(FRAMESERVER_MODES, "avfeed") ~= nil;
	end,
	default = "",
	handler = function(ctx, val)
		local vid = launch_avfeed(val, "avfeed");
		durden_launch(vid, "", "avfeed");
	end
},
{
	name = "target",
	label = "Target",
	submenu = true,
	kind = "action",
	force_completion = true,
	eval = function()
		local tgt = list_targets();
		return tgt ~= nil and #tgt > 0;
	end,
	handler = target_submenu
},
{
	name = "terminal_group",
	label = "Terminal(Group)",
	kind = "value",
	hint = "(append arguments)",
	default = "",
	eval = function()
		return false;
--		return string.match(FRAMESERVER_MODES, "terminal") ~= nil;
	end,
	handler = function(ctx, val)
		local str = "durden_term_";
		for i=1,8 do
			str = str .. string.char(string.byte("a") + math.random(1,26));
		end
		spawn_terminal(val, false, str);
	end
}
};
