-- slightly more involved since we want to create a hidden window (so
-- still indexable etc.) without causing any relayouting and have it
-- attached to the right tiler. Can't switch to it yet since the window
-- is not yet fully qualified.
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
	local newwnd = wnd.wm:add_hidden_window(source, {
		alternate = wnd
	});
end

function terminal_build_argenv(group)
	local bc = gconfig_get("term_bgcol");
	local fc = gconfig_get("term_fgcol");
	local cp = group and group or gconfig_get("extcon_path");
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

function spawn_terminal(cmd, group)
	local lstr = terminal_build_argenv(group);
	if (cmd) then
		lstr = lstr .. ":" .. cmd;
	end

	local guid;
	_,_,guid = launch_avfeed(lstr, "terminal",
	function(source, status)
		if (status.kind == "preroll") then
			local wnd = durden_launch(source, "", "terminal");
			if (not wnd) then
				warning("durden launch preroll state failed");
				return;
			end
			wnd.scalemode = "stretch";

-- fake registration so we use the same path as a normal external connection
			extevh_default(source, {
				kind = "registered", segkind = "terminal", title = "", guid = guid});
			local wnd_w = wnd.max_w - wnd.pad_left - wnd.pad_right;
			local wnd_h = wnd.max_h - wnd.pad_top - wnd.pad_bottom;

			target_displayhint(source,
				wnd_w, wnd_h, wnd.dispmask, wnd.wm.disptbl);
			durden_devicehint(source);

-- spawn a new listening endpoint if the terminal act as a connection group
-- but with different controls for connection point respawn (to maintain
-- respect for rate-limiting etc.)
			if (group) then
				local cpoint = target_alloc(group,
					function(s, st) durden_new_connection(s, st, true); end);
				link_image(cpoint, wnd.anchor);

-- register a pre-window creation hook tied to the group- connection path and
-- use this to associate the new window with the parent window
				extevh_set_intercept(group,
					function(path)
						return {alternate = wnd};
					end
				);
				wnd:add_handler("destroy", function()
					extevh_set_intercept(group, nil);
				end, true);
			end

		elseif (status.kind == "terminated") then
			delete_image(source);
		end
	end);
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
		selcol = HC_PALETTE[3], preview = decprev };

-- decode- frameserver doesn't have a way to query type and extension for
-- a specific resource, and running probes on all files in a folder with
-- 10k entries might be a little excessive
	local ffmts = {jpg = imghnd, png = imghnd, bmp = imghnd,
		ogg = audhnd, m4a = audhnd, flac = audhnd, mp3 = audhnd,
		mp4 = dechnd, wmv = dechnd, mkv = dechnd, avi = dechnd,
		flv = dechnd, mpg = dechnd, mpeg = dechnd, mov = dechnd,
		webm = dechnd
	};

	browse_file(nil, ffmts, SHARED_RESOURCE, nil, nil, {});
end

register_global("spawn_terminal", spawn_terminal);

return {
{
	name = "browse",
	label = "Browse",
	kind = "action",
	description = "Open the built-in resource browser",
	namespace = "@/browse/",
	handler = system_load("menus/global/browse.lua")()
},
{
	name = "remote",
	label = "Remote Desktop",
	kind = "value",
	helpsel = function() return CLIPBOARD.urls; end,
	description = "Connect to a remote desktop session",
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
			kind = "registered", segkind = "remoting", title = ""});
	else
		active_display():message(
			"remoting frameserver failed, broken or out-of-resources");
	end
end
},
{
	name = "decode",
	label = "Media URL",
	description = "Open a URL via the decode frameserver",
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
	description = "Open a new console shell",
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
	description = "Open a custom/build- defined audio-video feed",
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
	description = "List trusted predefined external applications",
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
	description = "Open a new shell-group where new clients share a window",
	default = "",
	eval = function()
		return string.match(FRAMESERVER_MODES, "terminal") ~= nil;
	end,
	handler = function(ctx, val)
		local str = "durden_term_";
		for i=1,8 do
			str = str .. string.char(string.byte("a") + math.random(1,10));
		end
		spawn_terminal(val, str);
	end
}
};
