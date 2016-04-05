function spawn_terminal()
	local bc = gconfig_get("term_bgcol");
	local fc = gconfig_get("term_fgcol");
	local cp = gconfig_get("extcon_path");

-- we want the dimensions in beforehand so we can pass them immediately
-- and in that way avoid the cost of a _resize() + signal cycle
	local wnd = durden_prelaunch();
	wnd:set_title("");

	local ppcm = tostring(active_display(true, true).ppcm);
	local ppcm = string.gsub(ppcm, ',', '.');

	local lstr = string.format(
		"font_hint=%s:font=[ARCAN_FONTPATH]/%s:width=%d:height=%d:ppcm=%s:"..
		"font_sz=%d:bgalpha=%d:bgr=%d:bgg=%d:bgb=%d:fgr=%d:fgg=%d:fgb=%d:%s",
		TERM_HINT_RLUT[tonumber(gconfig_get("term_font_hint"))],
		gconfig_get("term_font"),
		wnd.width, wnd.height, ppcm, gconfig_get("term_font_sz"),
		gconfig_get("term_opa") * 255.0 , bc[1], bc[2], bc[3],
		fc[1], fc[2],fc[3], (cp and string.len(cp) > 0) and
			("env=ARCAN_CONNPATH="..cp) or ""
	);

	local fbf = gconfig_get("font_fb");
	if (fbf and resource(fbf, SYS_FONT_RESOURCE)) then
		lstr = lstr .. string.format(":font_fb=[ARCAN_FONTPATH]/%s", fbf);
	end

	if (not gconfig_get("term_autosz")) then
		lstr = lstr .. string.format(":width=%d:height=%d", wnd.width, wnd.height);
	end

	local vid = launch_avfeed(lstr, "terminal");
	image_tracetag(vid, "terminal");

	if (valid_vid(vid)) then
		durden_launch(vid, "", "terminal", wnd);
		extevh_default(vid, {
			kind = "registered", segkind = "terminal", title = "", guid = 1});
		image_sharestorage(vid, wnd.canvas);
--		hide_image(wnd.border);
--		hide_image(wnd.canvas);
	else
		active_display():message( "Builtin- terminal support broken" );
		wnd:destroy();
	end
end

local function run_uri(val, feedmode)
	local vid = launch_avfeed(val, feedmode);
	if (valid_vid(vid)) then
		durden_launch(vid, "", feedmode);
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

local function imgwnd(fn)
	load_image_asynch(fn, function(src, stat)
		if (stat.kind == "loaded") then
			local wnd = active_display():add_window(src, {scalemode = "stretch"});
			string.gsub(fn, "\\", "\\\\");
			wnd:set_title("image:" .. fn);
		elseif (valid_vid(src)) then
			delete_image(src);
		end
	end);
end

local function dechnd(source, status)
	print("status.kind:", status.kind);
end

-- track lastpath so we can meta-launch browse internal and resume old path
local lastpath = "";
local function decwnd(fn, path)
	lastpath = path;
	local vid = launch_decode(fn, function() end);
	if (valid_vid(vid)) then
		durden_launch(vid, fn, "decode");
	end
end

local function launch(str, cfg)
	local vid = launch_target(str, cfg, LAUNCH_INTERNAL, def_handler);
	if (valid_vid(vid)) then
		local wnd = durden_launch(vid, cfg, str);
		wnd.config_target = str;
		wnd.config_config = cfg;
		wnd_settings_load(wnd);
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
	local ffmts = {
	jpg = imgwnd,
	png = imgwnd,
	bmp = imgwnd};
-- Don't have a good way to query decode for extensions at the moment,
-- would be really useful in cases like this (might just add an info arg and
-- then export through message, coreopt or similar).
	for i,v in ipairs({"mp3", "flac", "wmv", "mkv", "avi", "asf", "flv",
		"mpeg", "mov", "mp4", "ogg"}) do
		ffmts[v] = decwnd;
	end

	browse_file(nil, ffmts, SHARED_RESOURCE, nil);
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
	handler = function(ctx, val)
		local vid = launch_avfeed(get_remstr(val), "remoting");
		durden_launch(vid, "", "remoting");
		extevh_default(vid, {
			kind = "registered", segkind = "remoting", title = "", guid = 2});
	end;
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
		spawn_terminal(cmd);
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
}
};
