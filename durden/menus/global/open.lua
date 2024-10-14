-- This version just allows n children to be connected through the group
-- with two possible use cases, one being single 'swallow' where a window
-- gets hidden and we have another in its place.
--
-- The other is slightly more advanced as the hidden windows gets minimized
-- into the titlebar, and then 'swapped' into place on click
--
local function setup_group_cp(pwnd, group, limit)
	local n_children = 0;

	listen_ratelimit(group,
-- eval
		function()
			return n_children < limit;
		end,
-- handler
		function(source, status, ...)
			local wargs = {
-- make sure at the direct time of attachment, this will take the place of
-- [wnd] in the tiling hierarchy, reducing number of forced relayouts and
-- invalid sizing hints
				swallow_window = pwnd
			};
			local wnd = durden_launch(source, "", "external", nil, wargs);

			if not wnd then
				delete_image(source);
				return;
			end
			n_children = n_children + 1;
			wnd.external_connection = true;

-- let the child crash-recover to our outer connection point even if in group
			durden_devicehint(source);

-- need to track this to enfore limit on children
			wnd:add_handler("destroy",
				function(wnd, was_selected)
					n_children = n_children - 1;
				end, true
			);
		end,
		0, gconfig_get("extcon_rlimit")
	);

-- make sure to remove the listening point when the window disappear
	pwnd:add_handler("destroy", function()
		listen_cancel(group);
	end, true);
end

function spawn_terminal(cmd, group)
	local lstr = ""

	if cmd ~= "cli=lua" then
		lstr = suppl_terminal_build_argenv(group);
		if (cmd) then
			lstr = lstr .. ":" .. cmd;
		end
	else
		lstr = "cli=lua";
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

			if gconfig_get("tui_colorscheme") then
				suppl_tgt_color(source, gconfig_get("tui_colorscheme"))
			end

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
				setup_group_cp(wnd, group, 1);
			end

		elseif (status.kind == "terminated") then
			delete_image(source);
		end
	end);
end

local function run_uri(val, feedmode)
	local vid = launch_decode(val, feedmode);

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
			proto = "vnc"
		else
			return nil;
		end
	end

-- grab user credentials (optional), in a12 there's not a user:pass but
-- rather a keytag with an optional authentication secret.
	first, rest = string.split_first(rest, "@");
	local suffix = "";
	if first ~= "" then
		if proto == "a12" then
			suffix = ":tag=" .. first;
		else
			user = first;
		end
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

	local res = string.format("protocol=%s:port=%s:host=%s" .. suffix, proto, port, host);
	if #user > 0 then
		res = "user=" .. string.sub(user, ":", "\t") .. ":" .. res;
	end

	if #pass > 0 then
		res = "pass=" .. string.sub(pass, ":", "\t") .. ":" .. res;
	end

	return res;
end

local function launch(str, cfg, tag)
	local configs, tgttag = target_configurations(str)
	local mode = LAUNCH_INTERNAL;

-- use a tag to indicate that the target should be launched in
-- external mode where we suspend everything in beforehand. This is
-- quite preliminary and we should allow other hooks for the case
-- so that a binding like "all windows migrate" could be possible
-- on enter external.
	if tgttag == "external" then
		mode = LAUNCH_EXTERNAL;
	end

	local vid = launch_target(str, cfg, mode, def_handler);
-- if this is external, we should also have an 'on return' hook
-- though this might come indirectly as a display-reset event might
-- arrive to reset input state tracking etc.
	local client_log, fmt = suppl_add_logfn("client");

	if (valid_vid(vid)) then
		client_log(fmt("launch:status=ok:vid=%d:name=%s:config=%s", vid, str, cfg))
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
	else
		client_log(fmt("launch:status=fail:name=%s:config=%s:mode=%d", str, cfg, mode))
	end
end

local function target_cfgmenu(str, cfgs, noquery)
	local res = {};
	for k,v in ipairs(cfgs) do
		table.insert(res,{
			name = "launch_" .. string.hexenc(util.hash(str))
				.. "_" .. string.hexenc(util.hash(v)),
			alt_name = "launch_" .. str,
			kind = noquery and "action" or "value",
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

local function target_submenu(noquery)
	local res = {};
	local targets = list_targets();
	for k,v in ipairs(targets) do
		local cfgs = target_configurations(v);
		local short = "launch_" .. string.hexenc(util.hash(v));
		if (#cfgs == 1) then
			table.insert(res, {
				name = short,
				kind = noquery and "action" or "value",
				hint = "(optional window tag)",
				validator = function(val)
					return not val or #val == 0 or suppl_valid_name(val);
				end,
				label = v,
				handler = function(ctx, val)
					launch(v, cfgs[1], val, noquery);
				end,
			});
		elseif (#cfgs > 1) then
			table.insert(res, {
				name = "launch_" .. string.hexenc(util.hash(v)),
				kind = "action",
				label = v,
				handler = function()
					return target_cfgmenu(v, cfgs, val, noquery);
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
	description = "Connect to a remote desktop session or generic a12 source",
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
		if string.find(val, "://") then
			val = "stream=" .. val;
		end
		run_uri(val, "decode");
	end
},
{
	name = "terminal",
	label = "Terminal",
	description = "A CLI shell running through a terminal emulator",
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
	name = "lash",
	label = "Lash",
	description = "A terminal liberated shell",
	kind = "action",
	handler = function(ctx)
		spawn_terminal("cli=lua")
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
	handler = function() return target_submenu(true); end
},
{
	name = "target_tag",
	label = "Target (Tagging)",
	description = "Target but query for a window tag and options, mainly useful for automation",
	submenu = true,
	kind = "action",
	force_completion = true,
	eval = function()
		local tgt = list_targets();
		return tgt ~= nil and #tgt > 0;
	end,
	handler = function() return target_submenu(false); end
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
