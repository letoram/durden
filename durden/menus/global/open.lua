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
	local cursor = gconfig_get("term_cursor");
	local blink = gconfig_get("term_blink");

	local lstr = string.format(
		"cursor=%s:blink=%s:bgalpha=%d:bgr=%d:bgg=%d:bgb=%d:fgr=%d:fgg=%d:fgb=%d:%s%s%s",
		cursor, blink,
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

local function setup_group_cp(wnd, group)
-- link the newly created connection point ot the anchor of the window
	local cpoint = target_alloc(group,
		function(source, status)
			durden_new_connection(source, status);
		end
	);
	link_image(cpoint, wnd.anchor);

-- whenever 'group' path is used by a window that is about to be spawned,
-- lookup and return override options that would associate the new window
-- with the alternate.
	extevh_set_intercept(group,
		function(path)
			cpoint = target_alloc(group,
				function(source, status)
					durden_new_connection(source, status);
				end
			);
			return {alternate = wnd};
		end
	);

	wnd:add_handler("destroy", function()
		extevh_set_intercept(group, nil);
	end, true
	);

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
				kind = "registered",
				segkind = "terminal",
				title = "",
				guid = guid
			});

-- the window hint for the preroll stage can be derived from the parent constraints
			local wnd_w = math.clamp(
				wnd.max_w - wnd.pad_left - wnd.pad_right, 32, MAX_SURFACEW);
			local wnd_h = math.clamp(
				wnd.max_h - wnd.pad_top - wnd.pad_bottom, 32, MAX_SURFACEH);

			target_displayhint(source, wnd_w, wnd_h, wnd.dispmask, wnd.wm.disptbl);
			durden_devicehint(source);

-- spawn a new listening endpoint if the terminal act as a connection group
-- but with different controls for connection point respawn (to maintain
-- respect for rate-limiting etc.)
			if (group) then
				setup_group_cp(wnd, group);
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
	local proto = "a12";
	local port = "6680";
	local user = "";
	local pass = "";
	local host = "";

-- empty string is possible when used as validator
	if not val or #val == 0 then
		return;
	end

-- grab protocol specifier
	local first, rest = string.split_first(val, "://");
	if first ~= "" then
		if first == "a12" then
		elseif first == "vnc" then
		else
			return nil;
		end
	end

-- grab user credentials (optional)
	first, rest = string.split_first(rest, "@");
	if first ~= "" then

	end

-- see if there is a host:port or only host
	first, rest = string.split_first(rest, ":");
	if first ~= "" then
		host = first;
		port = rest;
		local pnum = tonumber(port);
		if not pnum or pnum <= 0 or pnum > 65535 then
			return nil;
		end
	else
		host = rest;
	end

-- and build the final string
	if #host == 0 then
		return nil;
	end

	local res = string.format("protocol=%s:port=%s:host=%s", proto, port, host);
	if #user > 0 then
		res = "user=" .. string.sub(user, ":", "\t") .. ":" .. res;
	end

	if #pass > 0 then
		res = "pass=" .. string.sub(pass, ":", "\t") .. ":" .. res;
	end

	return res;
end

local function launch(str, cfg, tag)
	local tags = list_target_tags(str)
	local mode = LAUNCH_INTERNAL;

-- use a tag to indicate that the target should be launched in
-- external mode where we suspend everything in beforehand. This is
-- quite preliminary and we should allow other hooks for the case
-- so that a binding like "all windows migrate" could be possible
-- on enter external.
	for i,v in ipairs(tags) do
		if v == "external" then
			mode = LAUNCH_EXTERNAL;
		end
	end

	local vid = launch_target(str, cfg, mode, def_handler);
-- if this is external, we should also have an 'on return' hook
-- though this might come indirectly as a display-reset event might
-- arrive to reset input state tracking etc.

	if (valid_vid(vid)) then
		if (gconfig_get("gamma_access") ~= "none") then
			target_flags(vid, TARGET_ALLOWCM, true);
		end
		local wnd = durden_launch(vid, cfg, str);
		durden_devicehint(vid);
		wnd.config_target = str;
		wnd.config_config = cfg;
		if (type(tag) == "string") then
			wnd.group_tag = tag;
		end
	end
end

local function target_cfgmenu(str, cfgs)
	local res = {};
	for k,v in ipairs(cfgs) do
		table.insert(res,{
			name = "launch_" .. string.hexenc(util.hash(str))
				.. "_" .. string.hexenc(util.hash(v)),
			kind = "value",
			validator = function(val)
				return not val or #val == 0 or suppl_valid_name(val);
			end,
			label = v,
			force_completion = true,
			handler = function(ctx, val) launch(str, v, val); end
		});
	end
	return res;
end

local function target_submenu()
	local res = {};
	local targets = list_targets();
	for k,v in ipairs(targets) do
		local cfgs = target_configurations(v);
		local short = "launch_" .. string.hexenc(util.hash(v));
		if (#cfgs == 1) then
			table.insert(res, {
				name = short,
				kind = "value",
				hint = "(optional window tag)",
				validator = function(val)
					return not val or #val == 0 or suppl_valid_name(val);
				end,
				label = v,
				handler = function(ctx, val)
					launch(v, cfgs[1], val);
				end,
			});
		elseif (#cfgs > 1) then
			table.insert(res, {
				name = "launch_" .. string.hexenc(util.hash(v)),
				kind = "action",
				label = v,
				handler = function()
					return target_cfgmenu(v, cfgs, val);
				end,
				submenu = true
			});
		end
	end
	return res;
end

return {
{
	name = "browse",
	label = "Browse",
	kind = "action",
	alias = function() return browse_get_last(); end,
	interactive = true,
	description = "Open the built-in resource browser",
	handler = function()
	end
},
{
	name = "remote",
	label = "Remote Desktop",
	kind = "value",
	helpsel = function() return CLIPBOARD.urls; end,
	description = "Connect to a remote desktop session",
	initial = "a12://",
	hint = "(vnc:// or a12:// user:pass@host:port)",
	validator = function(val)
		return get_remstr(val) ~= nil;
	end,
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
