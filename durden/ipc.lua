
-- needed to track available connections
local clients = {};
local control_socket;

-- debug monitoring is loud and costly and requires multiple hooks
-- there's a number of subsystems we need to hook in order to get a
-- reasonable debug/monitor view:
--
-- NOTIFICATION: [notifications] -
-- DISPLAY: [displays] - added/removed/rediscovered/reset/...
-- WM: [tilers] - window state changes
-- CONNECTION: [external connections] - rate limiting etc.
-- INPUT: [input / iostatem] - device arriving, ...
-- DISPATCH: [dispatch] - menu paths getting activated
-- WAYLAND: [special] - wayland clients
-- IPC: [ipc] - clients connecting
-- TIMERS: [timers] - when fired
--
local debug_count = 0;
local all_categories = {
	"NOTIFICATION",
	"DISPLAY",
	"WM",
	"CONNECTION",
	"INPUT",
	"DISPATCH",
	"WAYLAND",
	"IPC",
	"TIMERS",
	"CLIPBOARD",
	"CLIENTS"
};

local monitor_state = false;
local function toggle_monitoring(on)
	if (on and monitor_state or off and not monitor_state) then
		return;
	end

	local domains = {
		display = "DISPLAY:",
		wayland = "WAYLAND:",
		dispatch = "DISPATCH:",
		wm = "WM:",
		input = "INPUT:",
		timers = "TIMERS:",
		notification = "NOTIFICATION:",
		extconn = "CLIENT:",
		clipboard = "CLIPBOARD:"
	};

-- see suppl_add_logfn for the function that constructs the logger,
-- each subsystem references that to get the message log function that
-- will queue or forward to a set listener (that we define here)
	for k,v in pairs(domains) do
		local regfn = _G[k .. "_debug_listener"];
		if (regfn) then
			regfn( on and
				function(msg)
					for _, cl in ipairs(clients) do
						if (cl.category_map and cl.category_map[string.upper(k)]) then
							table.insert(cl.buffer, v .. msg);
						end
					end
				end or nil
			);
		end
	end

	monitor_state = on;
end

local function update_control(key, val)
-- close automatically unlinks
	if (control_socket) then
		control_socket:close();
		control_socket = nil;
	end

	for k,v in ipairs(clients) do
		v.connection:close();
	end
	clients = {};

	if (val == ":disabled") then
		return;
	end

	zap_resource("ipc/" .. val);
	control_socket = open_nonblock("=ipc/" .. val);
end

gconfig_listen("control_path", "ipc", update_control);
update_control("", gconfig_get("control_path"));

-- unsetting these values will prevent all external communication that is not
-- using the nonauth- connection or regular input devices
local sbar_fn = gconfig_get("status_path");
if (sbar_fn ~= nil and string.len(sbar_fn) > 0 and sbar_fn ~= ":disabled") then
	zap_resource("ipc/" .. sbar_fn);
	STATUS_CHANNEL = open_nonblock("<ipc/" .. sbar_fn);
end

local ochan_fn = gconfig_get("output_path");
if (ochan_fn ~= nil and string.len(ochan_fn) > 0 and ochan_fn ~= ":disabled") then
	zap_resource("ipc/" .. ochan_fn);
	OUTPUT_CHANNEL = open_nonblock("<ipc/" .. ochan_fn, true);
end

-- grammar:
-- | element splits group
-- %{ ... } gives formatting command
-- %% escape %
--
-- handled formatting commands:
--  Frrggbb - set foreground color
--  Grrggbb - set group background
--  F- - set default color
--  G- - set group default background
--  Iidentifier - set group icon [if identifier match, overrides text]
--  S+, S-, Sf, Sl, Sn - switch tiler/display
--  | step group
--  Aidentifier - bind command or output to click
--
-- ignored formatting commands:
--  l [ align left, not supported   ]
--  r [ align right, not supported  ]
--  c [ align center, not supported ]
--  Brrggbb - set background color, not supported (engine limit)
--  Urrggbb - set underline color, not supported (engine limit)
--
-- most of these are limited as there are in-durden ways of achieving same res.
--
local function process_fmt(dfmt, tok, i)
	local col;

-- can support more here (e.g. embed glyph, bold/italic)
	while (tok[i] and tok[i].fmt) do
		if (string.len(tok[i].msg) > 0) then
			if tok[i].msg == "F-" then
				dfmt.col = gconfig_get("text_color");
			elseif string.match(tok[i].msg, "F#%x%x%x%x%x%x") then
				dfmt.col = "\\#"  .. string.sub(tok[i].msg, 3);
			elseif tok[i].msg == "G-" then
				dfmt.bg = nil;
			elseif string.match(tok[i].msg, "G#%x%x%x%x%x%x") then
				dfmt.bg = {
					tonumber(string.sub(tok[i].msg, 3, 4), 16),
					tonumber(string.sub(tok[i].msg, 5, 6), 16),
					tonumber(string.sub(tok[i].msg, 7, 8), 16)
				};
			elseif string.match(tok[i].msg, "S%d") then
				dfmt.disp = tostring(string.sub(tok[i].msg, 2));
			elseif tok[i].msg == "S+" then
				dfmt.disp = dfmt.disp + 1;
				dfmt.disp = dfmt.disp > display_count() and
					1 + (display_count() % dfmt.disp) or dfmt.disp;
			elseif tok[i].msg == "S-" then
				dfmt.disp = dfmt.disp - 1;
				dfmt.disp = dfmt.disp <= 0 and display_count() or dfmt.disp;
			elseif tok[i].msg == "Sf" then
				dfmt.disp = 1;
			elseif tok[i].msg == "Sl" then
				dfmt.disp = display_count();
			elseif string.byte(tok[i].msg, 1) == string.byte("A", 1) then
				dfmt.action = string.sub(tok[i].msg, 2);
			else
				if (DEBUGLEVEL > 0) then
					print("status parse, ignoring bad format " .. tok[i].msg);
				end
			end
		end

		i = i + 1;
	end

	return i;
end

local function status_parse(line)
	local tok = {};

	local cs = "";
	local i = 1;
	local in_p = false;
	local in_g = false;

-- first tokenize
	while i <= string.len(line) do
		local ni = string.utf8forward(line, i);
		if (not ni) then
			break;
		end
		local ch = string.sub(line, i, ni-1);

-- handle %% %{
		if (ch == '%') then
			if (in_g) then
				warning("status-channel parse, malformed input (pct in fmt-cmd)");
				return {};
			end

			if (in_p) then
				cs = cs .. '%';
				in_p = false;

			elseif (not in_g) then
				in_p = true;
			end

		elseif (in_p and ch ~= '{') then
			warning("status-channel parse, malformed input (pct to npct/bracket)");
			return {};

-- handle transition msg%{ to fmt group state
		elseif (in_p) then
			in_g = true;
			in_p = false;
			if (string.len(cs) > 0) then
				table.insert(tok, {fmt = false, msg = cs});
				cs = "";
			end

-- handle transition fmt-group -> default
		elseif (in_g and ch == '}') then
			in_g = false;
			if (string.len(cs) == 0) then
				warning("status-channel parse, malformed input (empty fmt group)");
				return {};
			end
			table.insert(tok, {fmt = true, msg = cs});
			cs = "";

		elseif (ch == '|') then
			if (not in_g and not in_p) then
				table.insert(tok, {fmt = false, msg = cs});
			end
			cs = "";
			table.insert(tok, {newgrp = true, msg = ""});
		else
			cs = cs .. ch;
		end

		i = ni;
	end

-- handle EoS state
	if (not in_g and not in_p) then
		table.insert(tok, {fmt = false, msg = cs});
	end

-- now process the token stream and build a table of groups with entries
-- that carries active format state and coupled message
	local i = 1;
	local groups = {};
	local cfmt = {disp = 1};
	local cg = {};

	while i <= #tok do
		if (tok[i].newgrp) then
			table.insert(groups, cg);
			cg = {};
			cfmt.action = nil;
			i = i + 1;
		elseif (tok[i].fmt) then
			i = process_fmt(cfmt, tok, i);
		else
			local newfmt = {};
			for k,v in pairs(cfmt) do
				newfmt[k] = v;
			end
			table.insert(cg, {newfmt, tok[i].msg});
			i = i + 1;
		end
	end
	if (#cg > 0) then
		table.insert(groups, cg);
	end

-- normalize group to display
	local res = {};
	for i,v in ipairs(groups) do
		if (#v > 0) then
			local pd = v[#v][1].disp;
			if (not res[pd]) then res[pd] = {}; end
			table.insert(res[pd], v);
		end
	end

	return res;
end

local function gen_cmdtbl(cmd)
	if (not cmd) then
		return nil;
	end

	local res = {
	click = function(btn)
			if (string.sub(cmd, 1, 1) == "/") then
				dispatch_symbol(cmd);
			else
				if (OUTPUT_CHANNEL) then
					OUTPUT_CHANNEL:write(string.format("%s\n", cmd));
				end
			end
		end,
		over = function(btn)
			btn:switch_state("active");
		end,
		out = function(btn)
			btn:switch_state("inactive");
		end
	};
	res.rclick = res.click;
	return res;
end

local function poll_status_channel()
	local line = STATUS_CHANNEL:read();
	if (line == nil or string.len(line) == 0) then
		return;
	end

-- generate render_text compatible tables based on input line and add to
-- the suitable statusbar for each display.
	local lst = status_parse(line);

	local ind = 1;
	for disp in all_tilers_iter() do
		if (lst[ind]) then
			for i=#lst[ind],1,-1 do
				local di = #lst[ind]-i+1;
				local grp = lst[ind][i];
				local fmttbl = {};
				local bg = nil;
				local cmd = nil;
				for k,v in ipairs(grp) do
					table.insert(fmttbl, v[1].col and v[1].col or "");
					table.insert(fmttbl, v[2]);
					if (v[1].bg) then
						bg = v[1].bg;
					end
					if (v[1].action) then
						cmd = v[1].action;
					end
				end
				local btn = disp.statusbar.buttons.right[di];
				local mh = gen_cmdtbl(cmd);
				if (btn == nil) then
-- we can't currently handle a text background color as font renderer does not
-- provide a background color state, so we need to wait for changes to arcan
-- for that
					local btn = disp.statusbar:add_button("right", "sbar_msg_bg",
						"sbar_msg_text", fmttbl, gconfig_get("sbar_tpad") * disp.scalef,
						disp.font_resfn, nil, nil, mh);
					btn:switch_state("inactive");
				else
					local cw = btn.last_label_w;
					disp.statusbar:update("right", di, fmttbl);
					if ((not btn.minw or btn.minw == 0 and cw) or (cw and cw > btn.minw)) then
						btn:constrain(nil, cw, nil, nil, nil);
					end
					btn:update_mh(mh);
				end
			end
			ind = ind + 1;
		end
	end
end

local function list_path(res, noappend)
	local list = {};
	for k,v in ipairs(res) do
		if (v.name and v.label) then
			local ent;
			if (v.submenu) then
				ent = v.name .. (noappend and "" or "/");
			else
				ent = v.name;
			end

			if (not v.block_external and (not v.eval or v:eval())) then
				table.insert(list, ent);
			end
		end
	end
	table.sort(list);
	return list;
end

local function ent_to_table(res, ret)
	table.insert(ret, "name: " .. res.name);
	table.insert(ret, "label: " .. res.label);

	if (res.description and type(res.description) == "string") then
		table.insert(ret, "description: " .. res.description);
	end

	if (res.alias) then
		local ap = type(res.alias) == "function" and res.alias() or res.alias;
		table.insert(ret, "alias: " .. ap);
		return;
	end

	if (res.kind == "action") then
		table.insert(ret, res.submenu and "kind: directory" or "kind: action");
	else
		table.insert(ret, "kind: value");
		if (res.initial) then
			local val = tostring(type(res.initial) ==
				"function" and res.initial() or res.initial);
			table.insert(ret, "initial: " .. val);
		end
		if (res.set) then
			local lst = res.set;
			if (type(lst) == "function") then
				lst = lst();
			end
			table.sort(lst);
			table.insert(ret, "value-set: " .. table.concat(lst, " "));
		end
		if (res.hint) then
			local hint = res.hint;
			if (type(res.hint) == "function") then
				hint = res:hint();
			end
			table.insert(ret, "hint: " .. hint);
		end
	end
end

local commands;
commands = {
-- enumerate the contents of a path
	ls = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		local tbl = list_path(res);
		table.insert(tbl, "OK");
		return tbl;
	end,

-- list and read all the entries in one directory
	readdir = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		if (type(res[1]) ~= "table") then
			return {"EINVAL, readdir argument is not a directory"};
		end

		local ret = {};
		for _,v in ipairs(res) do
			if (type(v) == "table") then
				ent_to_table(v, ret);
			end
		end
		table.insert(ret, "OK");
		return ret;
	end,

-- present more detailed information about a single target
	read = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		local tbl = {};
		if (type(res[1]) == "table") then
			table.insert(tbl, "kind: directory");
			table.insert(tbl, "size: " .. tostring(#res));
		else
			ent_to_table(res, tbl);
		end
		table.insert(tbl, "OK");

		return tbl;
	end,

-- run a value assignment, first through the validator and then act
	write = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		if (res.kind == "value") then
			if (not res.validator or res.validator(remainder)) then
				res:handler(remainder);
				return {"OK"};
			else
				return {"EINVAL, value rejected by validator"};
			end
		else
			return {"EINVAL, couldn't dispatch"};
		end
	end,

-- only evaluate a value assignment
	eval = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		if (not res.handler) then
			return {"EINVAL, broken menu entry\n"};
		end

		if (res.validator) then
			if (not res.validator(remainder)) then
				return {"EINVAL, validation failed\n"};
			end
		end

		return {"OK\n"};
	end,

-- enable periodic output of event categories, see list at the top
	monitor = function(client, line)
		line = line and line or "";

		local categories = string.split(line, " ");
		for i=#categories,1,-1 do
			categories[i] = string.trim(categories[i]);
			if (#categories[i] == 0) then
				table.remove(categories, i);
			end
		end
		if (#categories == 0) then
			return {"EINVAL: missing categories: NONE, ALL or space separated list from " ..
				table.concat(all_categories, " ") .. "\n"};
		end

		client.category_map = {};
		if (string.upper(categories[1]) == "ALL") then
			categories = all_categories;

		elseif (string.upper(categories[1]) == "NONE") then
			clients.in_monitor = false;
			clients.category_map = nil;
			if (client.in_monitor) then
				client.in_monitor = false;
				debug_count = debug_count - 1;
			end
			return {"OK\n"};
		end

		client.in_monitor = true;
		debug_count = debug_count + 1;

		for i,v in ipairs(categories) do
			client.category_map[string.upper(v)] = true;
		end

		toggle_monitoring(debug_count > 0);
		return {"OK\n"};
	end,

-- execute no matter what
	exec = function(client, line, res, remainder)
		if (client.in_monitor) then
			return {"EINVAL: in monitor: only monitor <group1> <group2> ... allowed"};
		end

		if (dispatch_symbol(line, res, true)) then
			return {"OK\n"};
		else
			return {"EINVAL: target path is not an executable action.\n"};
		end
	end
};

local function remove_client(ind)
	local cl = clients[ind];
	if (cl.categories and #cl.categories > 0) then
		debug_count = debug_count - 1;
	end
	cl.connection:close();
	table.remove(clients, ind);
end

local do_line;
local function client_flush(cl, ind)
	while true do
		local line, ok = cl.connection:read();
		if (not ok) then
			remove_client(ind);
			return;
		end
		if (not line) then
			break;
		end
		if (string.len(line) > 0) then
			if (monitor_state) then
				for _,v in ipairs(clients) do
					if (v.category_map and v.category_map["IPC"]) then
						table.insert(v.buffer, string.format(
							"IPC:client=%d:command=%s\n", v.seqn, line));
					end
				end
			end
			do_line(line, cl, ind);
		end
	end

	while #cl.buffer > 0 do
		local line = cl.buffer[1];
		local i, ok = cl.connection:write(line);
		if (not ok) then
			remove_client(ind);
			return;
		end
		if (i == string.len(line)) then
			table.remove(cl.buffer, 1);
		else
			cl.buffer[1] = string.sub(line, i+1);
		end
	end
end

-- splint into "cmd argument", resolve argument as a menu path and forward
-- to the relevant entry in commands, special / ugly handling for monitor
-- which takes both forms.
do_line = function(line, cl, ind)
	local ind = string.find(line, " ");

	if (string.sub(line, 1, 7) == "monitor") then
		for _,v in ipairs(commands.monitor(cl, string.sub(line, 9))) do
			table.insert(cl.buffer, v .. "\n");
		end
		return;
	end

	if (not ind) then
		return;
	end
	cmd = string.sub(line, 1, ind-1);
	line = string.sub(line, ind+1);

	if (not commands[cmd]) then
		table.insert(cl.buffer,
			string.format("EINVAL: bad command(%s)\n", cmd));
		return;
	end

-- This will actually resolve twice, since exec/write should trigger the
-- command, but this will go through dispatch in order for queueing etc.
-- to work. Errors on queued commands will not be forwarded to the caller.
	local res, msg, remainder = menu_resolve(line);

	if (not res or type(res) ~= "table") then
		table.insert(cl.buffer, string.format("EINVAL: %s\n", msg));
	else
		for _,v in ipairs(commands[cmd](cl, line, res, remainder)) do
			table.insert(cl.buffer, v .. "\n");
		end
	end
end

-- Alas, arcan doesn't expose a decent asynch callback mechanism tied to
-- the socket (which should also be rate-limited and everything else like
-- that needed so we don't stall) so we have to make do with the normal
-- buffering for now, when it is added there we should only need to add
-- a function argument to the open_nonblock and to the write call
-- (table + callback, release when finished)
local seqn = 1;
local function poll_control_channel()
	local nc = control_socket:accept();

	if (nc) then
		local client = {
			connection = nc,
			buffer = {},
			seqn = seqn
		};
		seqn = seqn + 1;
		table.insert(clients, client);
	end

	for i=#clients,1,-1 do
		client_flush(clients[i], i);
	end
end

-- open question is if we should check lock-state here and if we're in locked
-- input, also disable polling status / control
timer_add_periodic("status_control", 1, false,
function()
	if (STATUS_CHANNEL) then
		poll_status_channel();
	end

	if (control_socket) then
		poll_control_channel();
	end
end, true
);

-- chain here rather than add some other hook mechanism, then the entire feature
-- can be removed by dropping the system_load() call.
local dshut = durden_shutdown;
durden_shutdown = function()
	dshut();

	if (gconfig_get("status_path") ~= ":disabled") then
		zap_resource("ipc/" .. gconfig_get("status_path"));
	end
	if (gconfig_get("control_path") ~= ":disabled") then
		zap_resource("ipc/" .. gconfig_get("control_path"));
	end
	if (gconfig_get("output_path") ~= ":disabled") then
		zap_resource("ipc/" .. gconfig_get("output_path"));
	end
end
