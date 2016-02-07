function spawn_terminal()
	local bc = gconfig_get("term_bgcol");
	local fc = gconfig_get("term_fgcol");
	local cp = gconfig_get("extcon_path");

	local lstr = string.format(
		"font_hint=%s:font=[ARCAN_FONTPATH]/%s:"..
		"font_sz=%d:bgalpha=%d:bgr=%d:bgg=%d:bgb=%d:fgr=%d:fgg=%d:fgb=%d:%s",
		gconfig_get("term_font_hint"), gconfig_get("term_font"),
		gconfig_get("term_font_sz"),
		gconfig_get("term_opa") * 255.0 , bc[1], bc[2], bc[3],
		fc[1], fc[2],fc[3], (cp and string.len(cp) > 0) and
			("env=ARCAN_CONNPATH="..cp) or ""
	);

	if (not gconfig_get("term_autosz")) then
		lstr = lstr .. string.format(":cell_w=%d:cell_h=%d",
			gconfig_get("term_cellw"), gconfig_get("term_cellh"));
	end

	local vid = launch_avfeed(lstr, "terminal");
	if (valid_vid(vid)) then
		local wnd = durden_launch(vid, "", "terminal");
		extevh_default(vid, {
			kind = "registered", segkind = "terminal", title = "", guid = 1});
		wnd.space:resize();
	else
		active_display():message( "Builtin- terminal support broken" );
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

	browse_file({}, ffmts, SHARED_RESOURCE, nil);
end

register_global("spawn_terminal", spawn_terminal);

return {
{
	name = "uriopen_terminal",
	label = "Terminal",
	kind = "action",
	hint = "(m1_accept for args)",
	eval = function()
		return string.match(FRAMESERVER_MODES, "terminal") ~= nil;
	end,
	handler = spawn_terminal
},
{
	name = "uriopen_remote",
	label = "Remote Desktop",
	kind = "value",
	hint = "(user:pass@host+port)",
	eval = function()
		return string.match(FRAMESERVER_MODES, "remoting") ~= nil;
	end,
	handler = function(ctx, val)
		local vid = launch_avfeed(get_remstr(val), "remoting");
		durden_launch(vid, "", "remoting");
	end;
},
{
	name = "uriopen_decode",
	label = "Media URL",
	kind = "value",
	hint = "(protocol://user:pass@host:port)",
	eval = function()
		return string.match(FRAMESERVER_MODES, "decode") ~= nil;
	end,
	handler = function(ctx, val)
		run_uri(val, "decode");
	end
},
{
	name = "browse",
	label = "Browse",
	kind = "action",
	handler = browse_internal
},
{
	name = "uriopen_avfeed",
	label = "AV Feed",
	kind = "action",
	hint = "(m1_accept for args)",
	eval = function()
		return string.match(FRAMESERVER_MODES, "avfeed") ~= nil;
	end,
	handler = function(ctx, val)
		local m1, m2 = dispatch_meta();
		if (m1) then
			query_args( function(argstr)
			local vid = launch_avfeed(argstr, "avfeed");
			durden_launch(vid, "", "avfeed");
			end);
		else
			local vid = launch_avfeed("", "avfeed");
			durden_launch(vid, "", "avfeed");
		end
	end
}
};
