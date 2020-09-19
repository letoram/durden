-- debugging tool for collecting a system trace mixed with durden- level events

local collecting = false
local collected = false

local domains = {
	"display", "wayland", "dispatch", "wm", "idevice", "timers",
	"notification", "client", "connection", "clibboard", "tools",
	"warning", "config", "stdout"
}

local function benchmark_handler(trace)
-- drop our listeners, and let durden_ipc set up its own again
	for _, v in ipairs(domains) do
		_G[v .. "_debug_listener"] = nil
	end

	durden_ipc_monitoring(true)
	collected = trace
	collecting = false
end

-- google trace format takes json..
local escape_char_map = {
  [ "\\" ] = "\\\\",
  [ "\"" ] = "\\\"",
  [ "\b" ] = "\\b",
  [ "\f" ] = "\\f",
  [ "\n" ] = "\\n",
  [ "\r" ] = "\\r",
  [ "\t" ] = "\\t",
}

local function escape_char(c)
  return escape_char_map[c] or string.format("\\u%04x", c:byte())
end

local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local listeners = {}
local function enable_collection(size)
	durden_ipc_monitoring(false)

	for _, v in ipairs(domains) do
		local reg = _G[v .. "_debug_listener"]
		if reg then
			_G[v .. "_debug_listener"] =
			function(msg)
				benchmark_tracedata(v, msg)
			end
		end
	end

	collecting = true
	benchmark_enable(size, benchmark_handler)
end

-- note for large dumps this isn't good enough, the loop here can trigger ANR as we don't
-- asynch write-out, again with the limits to open_nonblock..
local rewrites = {
	"feed-poll",
	"feed-render",
	"process-rendertarget"
};

local function save_dump(dst)
	local ref = collected
	collected = false

	zap_resource("output/" .. dst)

	if not open_rawresource("output/" .. dst) then
		return
	end

	local sample_line =
	function(val, suffix)
		local ph = "I"
		if val.trigger == 1 then
			ph = "B"
		elseif val.trigger == 2 then
			ph = "E"
		end

		local name = val.subsystem
		local msg = val.message

-- for some known paths we can do minor rewriting:
		if rewrites[val.subsystem] then
			if #msg then
				name = msg
			end
		end

-- this signifies the end of a frame and the quantifier tells the next deadline
		if val.subsystem == "frame-over" then
		end

		return string.format(
			[[{"name":"%s", "cat":"%s,%s,%s", "ph":"%s","pid":0,"tid":0,"ts":%s,"args":[%s, %s, "%s"]}%s]],
			name, -- name
			val.system, val.subsystem, val.path, -- cat
			ph, -- ph
			tostring(val.timestamp), -- ts
			val.identifier, -- args 0
			encode_string(msg), -- args 1
			tostring(val.quantity), -- args 2
			suffix
		)
	end

	write_rawresource("[")
	for i=1,#ref-1 do
		write_rawresource(sample_line(ref[i], ",\n"))
	end
	write_rawresource(sample_line(ref[#ref], "]"))
	close_rawresource()
end

local trace_menu = {
{
	name = "collect",
	kind = "value",
	label = "Collect",
	hint = "(1..5000 kb)",
	description = "Start collecting events",
	validator = gen_valid_num(1, 5000),
	eval = function()
		return not collecting and not collected
	end,
	handler = function(ctx, val)
		enable_collection(tonumber(val))
	end,
},
{
	name = "stop",
	kind = "action",
	label = "Stop",
	description = "Stop current trace collection",
	eval = function()
		return collecting
	end,
	handler = function()
		benchmark_enable(false);
	end,
},
{
	name = "drop",
	kind = "action",
	label = "Drop",
	description = "Drop collected trace",
	eval = function()
		return collected ~= false
	end,
	handler = function()
		collected = false
	end
},
{
	name = "flush",
	kind = "value",
	label = "Flush",
	description = "Flush buffer trace to file",
	hint = "(stored in output/)",
	eval = function()
		return collected ~= false
	end,
	validator = suppl_valid_vsymbol,
	handler = function(ctx, val)
		save_dump(val)
		collected = false
	end
}
}

menus_register("global", "tools", {
	name = "tracing",
	kind = "action",
	submenu = true,
	handler = trace_menu,
	label = "Tracing",
	description = "Record durden, engine and system events"
})
