
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
-- IDEVICE: [iostatem] - device appearing, disappearing, entering idle, ..
-- DISPATCH: [dispatch] - menu paths getting activated
-- WAYLAND: [special] - wayland clients
-- IPC: [ipc] - other IPC user actions
-- TIMERS: [timers] - when fired
-- CLIENTS: [clients] - events related
-- TOOLS: [tools] - domain used for toolscripts, prefix with name=xxx:"
-- X11: [atyles/x11] - Xarcan bridging
-- CONFIG: gconfig settings changes
-- STDOUT: wraps print calls
--
local debug_count = 0;
local all_categories = {
	"NOTIFICATION",
	"DISPLAY",
	"WM",
	"CONNECTION",
	"IDEVICE",
	"DISPATCH",
	"WAYLAND",
	"IPC",
	"TIMERS",
	"CLIPBOARD",
	"CLIENT",
	"TOOLS",
	"WARNING",
	"CONFIG",
	"X11",
	"STDOUT"
};

local print_override = suppl_add_logfn("stdout");
local warning_override = suppl_add_logfn("warning");
local fmt = string.format;

print = function(...)
	local tbl = {...};

	local count = 0
	for _, v in pairs(tbl) do
		count = count + 1
	end

	local out = {};
	for i=1,count do
		if tbl[i] then
			table.insert(out, tostring(tbl[i]));
		else
			table.insert(out, "(nil)");
		end
	end

	print_override(table.concat(out, "\t"));
end

warning = function(...)
	local tbl = {...};
	local fmtstr = string.rep("%s\t", #tbl);
	local msg = fmt(fmtstr, ...);
	warning_override(msg);
end

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
		idevice = "IDEVICE:",
		timers = "TIMERS:",
		notification = "NOTIFICATION:",
		client = "CLIENT:",
		connection = "CONNECTION:",
		clipboard = "CLIPBOARD:",
		tools = "TOOLS:",
		warning = "WARNING:",
		config = "CONFIG:",
		stdout = "STDOUT:",
		x11 = "X11:"
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
							cl.connection:write(v .. msg);
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
			if type(res.hint) == "table" then
				hint = res.hint[2];
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
-- remove missing categories and empty entries
			categories[i] = string.trim(string.upper(categories[i]));
			if (#categories[i] == 0) then
				table.remove(categories, i);
			end
			if (not table.find_i(all_categories, categories[i])
				and categories[i] ~= "ALL" and categories[i] ~= "NONE") then
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

local function get_cmderror()
	local set = {};
	for k,v in pairs(commands) do
		table.insert(set, k);
	end
	table.sort(set);
	return table.concat(set, " ");
end

-- splint into "cmd argument", resolve argument as a menu path and forward
-- to the relevant entry in commands, special / ugly handling for monitor
-- which takes both forms.
do_line = function(line, cl)
	local ind = string.find(line, " ");

	if (string.sub(line, 1, 7) == "monitor") then
		for _,v in ipairs(commands.monitor(cl, string.sub(line, 9))) do
			cl.connection:write(v .. "\n");
		end
		return;
	end

	if (not ind) then
		cl.connection:write(fmt("EINVAL: missing cmd(%s) arg) - \n", get_cmderror()));
		return;
	end

	cmd = string.sub(line, 1, ind-1);
	line = string.sub(line, ind+1);

	if not (commands[cmd]) then
		cl.connection:write(fmt("EINVAL: missing command(%s) - \n", get_cmderror()));
		return;
	end

-- This will actually resolve twice, since exec/write should trigger the
-- command, but this will go through dispatch in order for queueing etc.
-- to work. Errors on queued commands will not be forwarded to the caller.
	local res, msg, remainder = menu_resolve(line);

	if (not res or type(res) ~= "table") then
		cl.connection:write(fmt("EINVAL: %s\n", msg));
	else
		for _,v in ipairs(commands[cmd](cl, line, res, remainder)) do
			cl.connection:write(v .. "\n");
		end
	end
end

-- The asio data-handler isn't portable on accept as it is strictly not
-- data-in. Keep a polling approach going on a timer.
local seqn = 1;
local function poll_control_channel()
	local nc = control_socket:accept();

	if (nc) then
		local client = {
			connection = nc,
			seqn = seqn
		};
		nc:lf_strip(true);

-- This is a bit of a gamble, but since the feature is so 'fringe' and the
-- actual set of paths with possible adverse effects so small, ignore the
-- gpublock state and dispatch regardless. The bigger problem path to look
-- out for is anything /display and we could add the safety just for that
-- path explicitly.
		nc:data_handler(
			function(gpublock)
				local line, ok = nc:read();
				while line do
					do_line(line, client);
					line, ok = nc:read();
				end
				if not ok then
					local ind = table.find_i(clients, client);
					remove_client(ind);
				end
				return ok;
			end
		);
		seqn = seqn + 1;
		table.insert(clients, client);
	end
end

-- open question is if we should check lock-state here and if we're in locked
-- input, also disable polling status / control
timer_add_periodic("control", 1, false,
function()
	if (control_socket) then
		poll_control_channel();
	end
end, true
);

function durden_ipc_monitoring(on)
	toggle_monitoring(on and debug_count > 0)
end

-- chain here rather than add some other hook mechanism, then the entire feature
-- can be removed by dropping the system_load() call.
local dshut = durden_shutdown;
durden_shutdown = function()
	dshut();

	if (gconfig_get("control_path") ~= ":disabled") then
		zap_resource("ipc/" .. gconfig_get("control_path"));
	end
end
